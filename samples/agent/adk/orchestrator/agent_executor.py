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

import asyncio
import logging
import json
from typing import List, Optional, override
from google.adk.agents.invocation_context import new_invocation_context_id
from google.adk.events.event_actions import EventActions

from a2a.server.agent_execution import RequestContext
from google.adk.agents.llm_agent import LlmAgent
from google.adk.artifacts import InMemoryArtifactService
from a2a.server.events.event_queue import EventQueue
from google.adk.memory.in_memory_memory_service import InMemoryMemoryService
from google.adk.runners import Runner
from google.adk.sessions import InMemorySessionService
from google.adk.a2a.converters.request_converter import AgentRunRequest
from google.adk.a2a.executor.a2a_agent_executor import (
    A2aAgentExecutorConfig,
    A2aAgentExecutor,
)
from a2ui.a2a import is_a2ui_part, try_activate_a2ui_extension, A2UI_EXTENSION_URI
from a2ui.core.schema.constants import A2UI_CLIENT_CAPABILITIES_KEY
from google.adk.a2a.converters import event_converter
from a2a.server.events import Event as A2AEvent
from google.adk.events.event import Event
from google.adk.agents.invocation_context import InvocationContext
from google.adk.a2a.converters import part_converter
from subagent_route_manager import SubagentRouteManager

from agent import OrchestratorAgent
import part_converters

logger = logging.getLogger(__name__)


class OrchestratorAgentExecutor(A2aAgentExecutor):
  """Orchestrator 데모의 A2A executor.

  역할:
  - ADK 이벤트를 A2A 이벤트로 변환
  - A2UI surfaceId를 추적해 "어떤 subagent가 그 surface를 만들었는지" 저장
  - 이후 userAction(surfaceId 기반)을 올바른 subagent로 라우팅할 수 있게 지원
  """

  def __init__(self, agent: LlmAgent):
    config = A2aAgentExecutorConfig(
        gen_ai_part_converter=part_converters.convert_genai_part_to_a2a_part,
        a2a_part_converter=part_converters.convert_a2a_part_to_genai_part,
        event_converter=self.convert_event_to_a2a_events_and_save_surface_id_to_subagent_name,
    )

    runner = Runner(
        app_name=agent.name,
        agent=agent,
        artifact_service=InMemoryArtifactService(),
        session_service=InMemorySessionService(),
        memory_service=InMemoryMemoryService(),
    )

    super().__init__(runner=runner, config=config)

  @classmethod
  def convert_event_to_a2a_events_and_save_surface_id_to_subagent_name(
      cls,
      event: Event,
      invocation_context: InvocationContext,
      task_id: Optional[str] = None,
      context_id: Optional[str] = None,
      part_converter: part_converter.GenAIPartToA2APartConverter = part_converter.convert_genai_part_to_a2a_part,
  ) -> List[A2AEvent]:
    """ADK 이벤트를 A2A 이벤트로 변환하고 라우팅 메타데이터를 기록한다.

    학습 포인트:
    - `event.author`는 현재 응답을 생성한 subagent 이름이다.
    - A2UI `beginRendering.surfaceId`를 키로 사용해
      surfaceId -> subagent_name 매핑을 세션에 저장한다.
    """
    a2a_events = event_converter.convert_event_to_a2a_events(
        event,
        invocation_context,
        task_id,
        context_id,
        part_converter,
    )

    for a2a_event in a2a_events:
      # 가능하면 현재 subagent의 카드 메타데이터를 이벤트에 첨부해 클라이언트가 참고하게 한다.
      subagent_card = None
      if active_subagent_name := event.author:
        # We need to find the subagent by name
        if subagent := next(
            (
                sub
                for sub in invocation_context.agent.sub_agents
                if sub.name == active_subagent_name
            ),
            None,
        ):
          try:
            subagent_card = json.loads(subagent.description)
          except Exception:
            logger.warning(
                f"Failed to parse agent description for {active_subagent_name}"
            )
      if subagent_card:
        if a2a_event.metadata is None:
          a2a_event.metadata = {}
        a2a_event.metadata["a2a_subagent"] = subagent_card

      for a2a_part in a2a_event.status.message.parts:
        if (
            is_a2ui_part(a2a_part)
            and (begin_rendering := a2a_part.root.data.get("beginRendering"))
            and (surface_id := begin_rendering.get("surfaceId"))
        ):
          # surfaceId를 만든 subagent를 저장해 다음 userAction 라우팅에 재사용한다.
          asyncio.run_coroutine_threadsafe(
              SubagentRouteManager.set_route_to_subagent_name(
                  surface_id,
                  event.author,
                  invocation_context.session_service,
                  invocation_context.session,
              ),
              asyncio.get_event_loop(),
          )

    return a2a_events

  @override
  async def _prepare_session(
      self,
      context: RequestContext,
      run_request: AgentRunRequest,
      runner: Runner,
  ):
    """세션 초기화 시 A2UI 사용 여부/클라이언트 capability를 상태로 주입한다."""
    session = await super()._prepare_session(context, run_request, runner)

    if try_activate_a2ui_extension(context):
      client_capabilities = (
          context.message.metadata.get(A2UI_CLIENT_CAPABILITIES_KEY)
          if context.message and context.message.metadata
          else None
      )

      # system 상태 델타로 use_ui/client_capabilities를 넣어
      # remote subagent 호출 시 A2UI 확장 정보 전파에 사용한다.
      await runner.session_service.append_event(
          session,
          Event(
              invocation_id=new_invocation_context_id(),
              author="system",
              actions=EventActions(
                  state_delta={
                      # These values are used to configure A2UI messages to remote agent calls
                      "use_ui": True,
                      "client_capabilities": client_capabilities,
                  }
              ),
          ),
      )

    return session
