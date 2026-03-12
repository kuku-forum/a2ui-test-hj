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
import os

from google.adk.tools.tool_context import ToolContext

logger = logging.getLogger(__name__)


def get_restaurants(
    cuisine: str, location: str, tool_context: ToolContext, count: int = 5
) -> str:
  """레스토랑 목록 JSON 문자열을 반환한다.

  학습 포인트:
  - 이 함수는 LLM이 직접 호출하는 "tool 함수"다.
  - 입력(`cuisine`, `location`)을 받아 내부 JSON 데이터를 필터링/슬라이싱해서
    결과를 문자열(JSON)로 반환한다.
  - `tool_context.state["base_url"]`가 있으면 데이터 안의 localhost URL을 현재
    실행 중인 에이전트 주소로 치환해, 클라이언트에서 이미지/링크가 깨지지 않게 한다.

  Args:
      cuisine: 사용자가 원하는 음식 종류(현재 샘플 로직에서는 로깅/의미 전달용).
      location: 사용자가 입력한 위치 문자열.
      tool_context: ADK tool context. 세션 상태(`base_url`)를 읽는 데 사용.
      count: 반환할 최대 레스토랑 개수.

  Returns:
      A2UI/에이전트에서 후속 처리하기 쉬운 JSON 문자열(list of dict).
  """
  logger.info(f"--- TOOL CALLED: get_restaurants (count: {count}) ---")
  logger.info(f"  - Cuisine: {cuisine}")
  logger.info(f"  - Location: {location}")

  items = []
  location_lower = location.lower().strip()
  # 학습 포인트: 데모에서는 위치 파싱을 아주 단순화했다.
  # 영어/약어/한글 표기를 모두 뉴욕으로 매핑해 초보자가 동작을 쉽게 재현할 수 있다.
  # Match English and common variants (e.g. Korean "뉴욕" = New York)
  is_new_york = (
      "new york" in location_lower
      or "ny" in location_lower
      or "nyc" in location_lower
      or "뉴욕" in location
  )
  if is_new_york:
    try:
      script_dir = os.path.dirname(__file__)
      file_path = os.path.join(script_dir, "restaurant_data.json")
      with open(file_path) as f:
        restaurant_data_str = f.read()
        if base_url := tool_context.state.get("base_url"):
          restaurant_data_str = restaurant_data_str.replace(
              "http://localhost:10002", base_url
          )
          logger.info(f"Updated base URL from tool context: {base_url}")
        all_items = json.loads(restaurant_data_str)

      # 요청 개수만큼만 잘라 반환한다.
      items = all_items[:count]
      logger.info(
          f"  - Success: Found {len(all_items)} restaurants, returning {len(items)}."
      )

    except FileNotFoundError:
      logger.error(f"  - Error: restaurant_data.json not found at {file_path}")
    except json.JSONDecodeError:
      logger.error(f"  - Error: Failed to decode JSON from {file_path}")

  return json.dumps(items)
