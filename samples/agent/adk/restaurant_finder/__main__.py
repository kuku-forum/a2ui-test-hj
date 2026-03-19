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
import collections
import json
import logging
import os
from datetime import datetime
from typing import Any

import click
import uvicorn
from a2a.server.apps import A2AStarletteApplication
from a2a.server.request_handlers import DefaultRequestHandler
from a2a.server.tasks import InMemoryTaskStore
from agent import RestaurantAgent
from agent_executor import RestaurantAgentExecutor
from dotenv import load_dotenv
from starlette.middleware.cors import CORSMiddleware
from starlette.requests import Request
from starlette.responses import HTMLResponse, StreamingResponse
from starlette.routing import Route
from starlette.staticfiles import StaticFiles

load_dotenv()
logger = logging.getLogger(__name__)


# ── 인-메모리 로그 버퍼 + SSE 스트리밍 ──────────────────────────────────────────

class _SSELogHandler(logging.Handler):
  """로그 레코드를 메모리에 쌓고 SSE 클라이언트로 스트리밍한다."""

  MAX_RECORDS = 2000

  def __init__(self) -> None:
    super().__init__()
    self.records: collections.deque[dict] = collections.deque(maxlen=self.MAX_RECORDS)
    self._queues: list[asyncio.Queue] = []

  def emit(self, record: logging.LogRecord) -> None:
    msg = self.format(record)
    entry = {
        "t": datetime.fromtimestamp(record.created).strftime("%H:%M:%S.%f")[:-3],
        "lvl": record.levelname,
        "msg": msg,
    }
    self.records.append(entry)
    for q in list(self._queues):
      try:
        q.put_nowait(entry)
      except Exception:
        pass

  def subscribe(self) -> asyncio.Queue:
    q: asyncio.Queue = asyncio.Queue(maxsize=500)
    self._queues.append(q)
    return q

  def unsubscribe(self, q: asyncio.Queue) -> None:
    try:
      self._queues.remove(q)
    except ValueError:
      pass


_log_handler = _SSELogHandler()
_log_handler.setFormatter(logging.Formatter("%(name)s | %(message)s"))


# ── /debug 웹 로그 뷰어 HTML ────────────────────────────────────────────────────

_DEBUG_HTML = r"""<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8">
<title>A2UI Agent – Debug Logs</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{background:#1e1e1e;color:#d4d4d4;font-family:'Consolas','Menlo',monospace;font-size:13px}
#bar{position:sticky;top:0;background:#252526;border-bottom:1px solid #3a3a3a;
     padding:8px 14px;display:flex;gap:10px;align-items:center;z-index:10;flex-wrap:wrap}
#bar h1{font-size:14px;color:#4ec9b0;white-space:nowrap}
#filter{flex:1;min-width:160px;background:#3c3c3c;color:#d4d4d4;border:1px solid #555;
        padding:4px 8px;border-radius:4px;font-family:inherit;font-size:12px}
.btn{background:#3c3c3c;color:#d4d4d4;border:1px solid #555;padding:4px 10px;
     border-radius:4px;cursor:pointer;font-size:12px;white-space:nowrap}
.btn:hover{background:#4a4a4a}
#status{font-size:11px;color:#858585;white-space:nowrap}
#log{padding:6px 0}
.row{padding:3px 14px;border-bottom:1px solid #2a2a2a;display:flex;gap:8px;word-break:break-all}
.row:hover{background:#2a2a2a}
.t{color:#858585;white-space:nowrap;flex-shrink:0}
.badge{flex-shrink:0;font-weight:bold;width:56px;text-align:center}
.msg{white-space:pre-wrap;flex:1}
.INFO .badge{color:#4ec9b0}
.WARNING .badge{color:#ce9178}
.ERROR .badge{color:#f44747}
.PROMPT .badge{color:#dcdcaa;font-size:12px}
.RESPONSE .badge{color:#b5cea8;font-size:12px}
.QUERY .badge{color:#9cdcfe;font-size:12px}
.A2UI .badge{color:#c586c0;font-size:12px}
</style>
</head>
<body>
<div id="bar">
  <h1>🔍 A2UI Agent Logs</h1>
  <input id="filter" placeholder="필터 (PROMPT, RESPONSE, query, error …)" oninput="applyFilter()">
  <select class="btn" id="lvlFilter" onchange="applyFilter()">
    <option value="">ALL</option>
    <option value="PROMPT">PROMPT</option>
    <option value="RESPONSE">RESPONSE</option>
    <option value="QUERY">QUERY</option>
    <option value="A2UI">A2UI</option>
    <option value="WARNING">WARNING</option>
    <option value="ERROR">ERROR</option>
  </select>
  <button class="btn" onclick="clearLogs()">🗑 Clear</button>
  <label class="btn" style="cursor:default">
    <input type="checkbox" id="scroll" checked> Auto-scroll
  </label>
  <span id="status">● connecting…</span>
</div>
<div id="log"></div>
<script>
let all=[], filter='', lvl='';

function classify(e){
  const m=e.msg;
  if(m.includes('[PROMPT]')) return 'PROMPT';
  if(m.includes('[RESPONSE]')) return 'RESPONSE';
  if(m.includes('[QUERY]')) return 'QUERY';
  if(m.includes('[A2UI]') || m.includes('A2UI') || m.includes('surface')) return 'A2UI';
  return e.lvl;
}

function esc(s){return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')}

function render(e){
  const cls=classify(e);
  const txt=e.msg;
  const lo=(txt+e.t).toLowerCase();
  if(filter && !lo.includes(filter)) return null;
  if(lvl && cls!==lvl) return null;
  const d=document.createElement('div');
  d.className='row '+cls;
  d.innerHTML=`<span class="t">${e.t}</span><span class="badge">[${cls}]</span><span class="msg">${esc(txt)}</span>`;
  return d;
}

function applyFilter(){
  filter=document.getElementById('filter').value.toLowerCase();
  lvl=document.getElementById('lvlFilter').value;
  const c=document.getElementById('log');
  c.innerHTML='';
  all.forEach(e=>{const el=render(e);if(el)c.appendChild(el);});
  scroll();
}

function scroll(){
  if(document.getElementById('scroll').checked)
    window.scrollTo(0,document.body.scrollHeight);
}

function clearLogs(){all=[];document.getElementById('log').innerHTML='';}

const es=new EventSource('/debug/stream');
const st=document.getElementById('status');
es.onopen=()=>{st.style.color='#4ec9b0';st.textContent='● connected';};
es.onerror=()=>{st.style.color='#f44747';st.textContent='● disconnected';};
es.onmessage=ev=>{
  const e=JSON.parse(ev.data);
  all.push(e);
  const el=render(e);
  if(el){document.getElementById('log').appendChild(el);scroll();}
};
</script>
</body>
</html>"""


async def _debug_page(_request: Request) -> HTMLResponse:
  return HTMLResponse(_DEBUG_HTML)


async def _debug_stream(request: Request) -> StreamingResponse:
  q = _log_handler.subscribe()

  async def generator():
    # 기존 로그를 먼저 전송
    for entry in list(_log_handler.records):
      yield f"data: {json.dumps(entry, ensure_ascii=False)}\n\n"
    # 이후 실시간 스트리밍
    try:
      while True:
        if await request.is_disconnected():
          break
        try:
          entry = await asyncio.wait_for(q.get(), timeout=20.0)
          yield f"data: {json.dumps(entry, ensure_ascii=False)}\n\n"
        except asyncio.TimeoutError:
          yield ": keepalive\n\n"
    finally:
      _log_handler.unsubscribe(q)

  return StreamingResponse(
      generator(),
      media_type="text/event-stream",
      headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
  )


# ── 메인 ─────────────────────────────────────────────────────────────────────


class MissingAPIKeyError(Exception):
  """Exception for missing API key."""


@click.command()
@click.option("--host", default="localhost")
@click.option("--port", default=10002)
def main(host: str, port: int) -> None:
  """Restaurant Finder A2A 서버 진입점.

  실행 후 브라우저에서 http://<host>:<port>/debug 를 열면
  LLM 프롬프트·응답·A2UI 파트를 실시간으로 확인할 수 있습니다.
  """
  # 로그 핸들러를 root 로거에 연결 (모든 로거 메시지 캡처)
  root_logger = logging.getLogger()
  root_logger.setLevel(logging.INFO)
  logging.basicConfig(
      level=logging.INFO,
      format="%(asctime)s %(levelname)-8s %(name)s | %(message)s",
      datefmt="%H:%M:%S",
  )
  root_logger.addHandler(_log_handler)

  try:
    if not os.getenv("OPENAI_API_KEY"):
      raise MissingAPIKeyError(
          "OPENAI_API_KEY environment variable is not set. "
          "Get your API key at: https://platform.openai.com/api-keys"
      )

    base_url = f"http://{host}:{port}"

    ui_agent = RestaurantAgent(base_url=base_url, use_ui=True)
    text_agent = RestaurantAgent(base_url=base_url, use_ui=False)
    agent_executor = RestaurantAgentExecutor(ui_agent, text_agent)
    request_handler = DefaultRequestHandler(
        agent_executor=agent_executor,
        task_store=InMemoryTaskStore(),
    )
    server = A2AStarletteApplication(
        agent_card=ui_agent.get_agent_card(), http_handler=request_handler
    )

    app = server.build()

    app.add_middleware(
        CORSMiddleware,
        allow_origin_regex=r"http://localhost:\d+",
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.mount("/static", StaticFiles(directory="images"), name="static")

    # /debug 와 /debug/stream 을 라우터 앞에 삽입
    app.router.routes.insert(0, Route("/debug", endpoint=_debug_page))
    app.router.routes.insert(0, Route("/debug/stream", endpoint=_debug_stream))

    logger.info(
        f"[A2UI] 서버 시작: http://{host}:{port}  |  "
        f"로그 뷰어: http://{host}:{port}/debug"
    )
    uvicorn.run(app, host=host, port=port)
  except MissingAPIKeyError as e:
    logger.error(f"Error: {e}")
    exit(1)
  except Exception as e:
    logger.error(f"An error occurred during server startup: {e}")
    exit(1)


if __name__ == "__main__":
  main()
