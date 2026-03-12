# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import json
import logging

from a2a.server.agent_execution import AgentExecutor, RequestContext
from a2a.server.events import EventQueue
from a2a.server.tasks import TaskUpdater
from a2a.types import (
    DataPart,
    Part,
    Task,
    TaskState,
    TextPart,
    UnsupportedOperationError,
)
from a2a.utils import (
    new_agent_parts_message,
    new_agent_text_message,
    new_task,
)
from a2a.utils.errors import ServerError
from a2ui.a2a import try_activate_a2ui_extension
from agent import RestaurantAgent

logger = logging.getLogger(__name__)


class RestaurantAgentExecutor(AgentExecutor):
  """Restaurant 데모의 A2A 실행 오케스트레이터.

  큰 흐름:
  1) 클라이언트 메시지에서 텍스트 또는 `userAction` 이벤트를 해석
  2) UI 확장(A2UI) 활성 여부에 따라 UI/text 에이전트 선택
  3) 선택된 에이전트의 stream 결과를 Task 상태 이벤트로 전달
  4) Flutter/Lit 호환을 위한 표면(surface) 보정 로직 적용

  이 클래스는 "비즈니스 로직"보다 "입출력 연결/정규화"가 핵심이다.
  """

  def __init__(self, ui_agent: RestaurantAgent, text_agent: RestaurantAgent):
    # Instantiate two agents: one for UI and one for text-only.
    # The appropriate one will be chosen at execution time.
    self.ui_agent = ui_agent
    self.text_agent = text_agent

  async def execute(
      self,
      context: RequestContext,
      event_queue: EventQueue,
  ) -> None:
    """A2A 요청 1건을 처리하고 Task 이벤트를 순차적으로 발행한다.

    입력:
    - `context.message.parts`: 텍스트 또는 DataPart(userAction)
    - `context.requested_extensions`: A2UI extension 활성화 정보

    출력:
    - working/input_required/completed 상태 이벤트
    - 최종적으로 agent가 생성한 A2UI/Text parts

    초보자 체크:
    - 버튼 클릭은 대개 `userAction`으로 들어온다.
    - 일반 채팅 입력은 `context.get_user_input()` 경로를 탄다.
    """
    query = ""
    ui_event_part = None
    action = None

    logger.info(f"--- Client requested extensions: {context.requested_extensions} ---")
    use_ui = try_activate_a2ui_extension(context)

    # A2UI 확장이 활성화되면 UI JSON 응답을 생성하는 agent를 사용한다.
    # 아니면 텍스트 응답용 agent를 사용한다.
    if use_ui:
      agent = self.ui_agent
      logger.info("--- AGENT_EXECUTOR: A2UI extension is active. Using UI agent. ---")
    else:
      agent = self.text_agent
      logger.info(
          "--- AGENT_EXECUTOR: A2UI extension is not active. Using text agent. ---"
      )

    # 메시지 파트 스캔: DataPart(userAction) 우선, 없으면 TextPart를 사용한다.
    if context.message and context.message.parts:
      logger.info(
          f"--- AGENT_EXECUTOR: Processing {len(context.message.parts)} message"
          " parts ---"
      )
      for i, part in enumerate(context.message.parts):
        if isinstance(part.root, DataPart):
          if "userAction" in part.root.data:
            logger.info(f"  Part {i}: Found a2ui UI ClientEvent payload.")
            ui_event_part = part.root.data["userAction"]
          else:
            logger.info(f"  Part {i}: DataPart (data: {part.root.data})")
        elif isinstance(part.root, TextPart):
          logger.info(f"  Part {i}: TextPart (text: {part.root.text})")
          # Flutter renderer는 일부 경로에서 userAction을 TextPart(JSON 문자열)로 보낼 수 있다.
          if not ui_event_part:
            try:
              parsed = json.loads(part.root.text)
              if isinstance(parsed, dict) and "userAction" in parsed:
                ui_event_part = parsed["userAction"]
                logger.info(
                    f"  Part {i}: Extracted userAction from TextPart JSON payload."
                )
            except Exception:
              pass
        else:
          logger.info(f"  Part {i}: Unknown part type ({type(part.root)})")

    # 예약 폼에 다시 주입할 컨텍스트.
    # LLM이 빈 값을 내놓는 경우를 보완하기 위한 서버 측 안전장치다.
    book_ctx = {}
    if ui_event_part:
      logger.info(f"Received a2ui ClientEvent: {ui_event_part}")
      action = ui_event_part.get("name") or ui_event_part.get("actionName")
      ctx = ui_event_part.get("context", {})

      if action == "book_restaurant":
        restaurant_name = ctx.get("restaurantName", "Unknown Restaurant")
        address = ctx.get("address", "Address not provided")
        image_url = ctx.get("imageUrl", "")
        book_ctx = {
            "restaurantName": restaurant_name,
            "address": address,
            "imageUrl": image_url or "",
        }
        query = (
            f"USER_WANTS_TO_BOOK: {restaurant_name}, Address: {address}, ImageURL:"
            f" {image_url}"
        )

      elif action == "submit_booking":
        restaurant_name = ctx.get("restaurantName", "Unknown Restaurant")
        party_size = ctx.get("partySize", "Unknown Size")
        reservation_time = ctx.get("reservationTime", "Unknown Time")
        dietary_reqs = ctx.get("dietary", "None")
        image_url = ctx.get("imageUrl", "")
        query = (
            f"User submitted a booking for {restaurant_name} for {party_size} people at"
            f" {reservation_time} with dietary requirements: {dietary_reqs}. The image"
            f" URL is {image_url}"
        )

      else:
        query = f"User submitted an event: {action} with data: {ctx}"
    else:
      logger.info("No a2ui UI event part found. Falling back to text input.")
      query = context.get_user_input()

    logger.info(f"--- AGENT_EXECUTOR: Final query for LLM: '{query}' ---")

    task = context.current_task

    if not task:
      task = new_task(context.message)
      await event_queue.enqueue_event(task)
    updater = TaskUpdater(event_queue, task.id, task.context_id)

    async for item in agent.stream(query, task.context_id):
      is_task_complete = item["is_task_complete"]
      if not is_task_complete:
        await updater.update_status(
            TaskState.working,
            new_agent_text_message(item["updates"], task.context_id, task.id),
        )
        continue

      # 예약 제출이면 최종 완료, 그 외에는 다음 입력을 기다린다.
      final_state = (
          TaskState.completed
          if action == "submit_booking"
          else TaskState.input_required
      )

      final_parts = item["parts"]

      # book_ctx(restaurantName/address/imageUrl)를 booking-form dataModelUpdate에 주입한다.
      # 이유: 모델 응답이 빈 값을 포함할 때도 폼/이미지가 안정적으로 렌더되게 하기 위함.
      if book_ctx and action == "book_restaurant":
        for part in final_parts:
          if not isinstance(part.root, DataPart):
            continue
          data = part.root.data
          if "dataModelUpdate" not in data:
            continue
          dmu = data["dataModelUpdate"]
          if dmu.get("surfaceId") != "booking-form" or "contents" not in dmu:
            continue
          contents = dmu["contents"]
          if not isinstance(contents, list):
            continue
          key_to_value = {
              "restaurantName": book_ctx.get("restaurantName", ""),
              "address": book_ctx.get("address", ""),
              "imageUrl": book_ctx.get("imageUrl", ""),
          }
          for entry in contents:
            if isinstance(entry, dict) and entry.get("key") in key_to_value:
              entry["valueString"] = key_to_value[entry["key"]]
          logger.info(
              "--- Injected book_ctx into booking-form dataModelUpdate: %s ---",
              book_ctx,
          )
          break

      # Flutter web 안정성을 위해 dietary 텍스트 입력을 제거한다.
      # (웹 런타임 IME composing assertion 회피)
      if action == "book_restaurant":
        removed_dietary_component = False
        removed_dietary_model = False
        for part in final_parts:
          if not isinstance(part.root, DataPart):
            continue
          data = part.root.data

          if (
              "surfaceUpdate" in data
              and data["surfaceUpdate"].get("surfaceId") == "booking-form"
          ):
            components = data["surfaceUpdate"].get("components")
            if isinstance(components, list):
              # Remove dietary field component.
              old_count = len(components)
              components[:] = [
                  comp
                  for comp in components
                  if not (
                      isinstance(comp, dict)
                      and comp.get("id") == "dietary-field"
                  )
              ]
              if len(components) != old_count:
                removed_dietary_component = True

              for comp in components:
                if not isinstance(comp, dict):
                  continue
                cid = comp.get("id")
                component = comp.get("component", {})
                if cid == "booking-form-column":
                  explicit_list = (
                      component.get("Column", {})
                      .get("children", {})
                      .get("explicitList")
                  )
                  if isinstance(explicit_list, list) and "dietary-field" in explicit_list:
                    explicit_list[:] = [
                        item for item in explicit_list if item != "dietary-field"
                    ]
                    removed_dietary_component = True
                elif cid == "submit-button":
                  ctx = (
                      component.get("Button", {})
                      .get("action", {})
                      .get("context")
                  )
                  if isinstance(ctx, list):
                    old_ctx_count = len(ctx)
                    ctx[:] = [
                        item
                        for item in ctx
                        if not (
                            isinstance(item, dict)
                            and item.get("key") == "dietary"
                        )
                    ]
                    if len(ctx) != old_ctx_count:
                      removed_dietary_component = True

          if (
              "dataModelUpdate" in data
              and data["dataModelUpdate"].get("surfaceId") == "booking-form"
          ):
            contents = data["dataModelUpdate"].get("contents")
            if isinstance(contents, list):
              old_contents_count = len(contents)
              contents[:] = [
                  item
                  for item in contents
                  if not (
                      isinstance(item, dict)
                      and item.get("key") == "dietary"
                  )
              ]
              if len(contents) != old_contents_count:
                removed_dietary_model = True

      # Flutter 샘플은 현재 `surfaceId='default'`만 표시한다.
      # booking/confirmation surface를 default로 리매핑해 화면 업데이트가 보이도록 맞춘다.
      remap_candidates = set()
      if action == "book_restaurant":
        remap_candidates.add("booking-form")
      elif action == "submit_booking":
        # Model may emit either "confirmation" or "booking-confirmation".
        remap_candidates.update(["confirmation", "booking-confirmation"])
      if remap_candidates:
        for part in final_parts:
          if not isinstance(part.root, DataPart):
            continue
          data = part.root.data
          if "beginRendering" in data:
            sid = data["beginRendering"].get("surfaceId")
            if sid in remap_candidates:
              data["beginRendering"]["surfaceId"] = "default"
          if "surfaceUpdate" in data:
            sid = data["surfaceUpdate"].get("surfaceId")
            if sid in remap_candidates:
              data["surfaceUpdate"]["surfaceId"] = "default"
          if "dataModelUpdate" in data:
            sid = data["dataModelUpdate"].get("surfaceId")
            if sid in remap_candidates:
              data["dataModelUpdate"]["surfaceId"] = "default"

      logger.info("--- FINAL PARTS TO BE SENT ---")
      for i, part in enumerate(final_parts):
        logger.info(f"  - Part {i}: Type = {type(part.root)}")
        if isinstance(part.root, TextPart):
          logger.info(f"    - Text: {part.root.text[:200]}...")
        elif isinstance(part.root, DataPart):
          logger.info(f"    - Data: {str(part.root.data)[:200]}...")
      logger.info("-----------------------------")

      await updater.update_status(
          final_state,
          new_agent_parts_message(final_parts, task.context_id, task.id),
          final=(final_state == TaskState.completed),
      )
      break

  async def cancel(
      self, request: RequestContext, event_queue: EventQueue
  ) -> Task | None:
    """취소는 현재 데모에서 미지원."""
    raise ServerError(error=UnsupportedOperationError())
