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

import logging
import os
import traceback
import asyncio
import click
from a2a.server.apps import A2AStarletteApplication
from a2a.server.request_handlers import DefaultRequestHandler
from a2a.server.tasks import InMemoryTaskStore
from agent import OrchestratorAgent
from agent_executor import OrchestratorAgentExecutor
from dotenv import load_dotenv
from starlette.middleware.cors import CORSMiddleware

load_dotenv()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class MissingAPIKeyError(Exception):
  """Exception for missing API key."""


@click.command()
@click.option("--host", default="localhost", type=str)
@click.option("--port", default=10002, type=int)
@click.option(
    "--subagent_urls",
    multiple=True,
    type=str,
    default=(),
    help=(
        "Subagent A2A URLs. With no URLs the server starts with no subagents. To route"
        " to agents, run them (e.g. restaurant on 10003) and pass --subagent_urls"
        " http://localhost:10003"
    ),
)
def main(host, port, subagent_urls):
  """Orchestrator A2A 서버 실행 진입점.

  학습 포인트:
  - `--subagent_urls`를 넘기면 실제 remote subagent를 연결해 라우팅한다.
  - URL을 안 넘겨도 서버는 부팅되지만, 실제 위임 대상이 없으면 라우팅 이점은 줄어든다.
  """
  try:
    # Check for API key only if Vertex AI is not configured
    if not os.getenv("GOOGLE_GENAI_USE_VERTEXAI") == "TRUE":
      if not os.getenv("OPENAI_API_KEY") and not os.getenv("GEMINI_API_KEY"):
        raise MissingAPIKeyError("Set OPENAI_API_KEY or GEMINI_API_KEY in .env")

    base_url = f"http://{host}:{port}"

    # 실사용에서는 subagent 서버를 띄운 뒤 URL을 전달하는 것이 핵심이다.
    # 데모 편의를 위해 URL이 비어도 서버 자체는 기동되도록 둔다.
    orchestrator_agent, agent_card = asyncio.run(
        OrchestratorAgent.build_agent(
            base_url=base_url, subagent_urls=list(subagent_urls)
        )
    )
    agent_executor = OrchestratorAgentExecutor(agent=orchestrator_agent)

    request_handler = DefaultRequestHandler(
        agent_executor=agent_executor,
        task_store=InMemoryTaskStore(),
    )
    server = A2AStarletteApplication(
        agent_card=agent_card, http_handler=request_handler
    )
    import uvicorn

    app = server.build()

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["http://localhost:5173"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    uvicorn.run(app, host=host, port=port)
  except MissingAPIKeyError as e:
    logger.error(f"Error: {e} {traceback.format_exc()}")
    exit(1)
  except Exception as e:
    logger.error(
        f"An error occurred during server startup: {e} {traceback.format_exc()}"
    )
    exit(1)


if __name__ == "__main__":
  main()
