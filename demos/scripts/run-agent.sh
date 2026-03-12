#!/usr/bin/env bash
# Run an ADK agent in the background. Exports LITELLM_MODEL from demos/.env.
# Usage: source scripts/load-env.sh; run_agent "restaurant_finder" [port]
# Or: run_agent "contact_lookup" 10003

run_agent() {
  local name="$1"
  local port="${2:-10002}"
  local root="$A2UI_ROOT"
  local agent_dir="$root/samples/agent/adk/$name"
  if [[ ! -d "$agent_dir" ]]; then
    echo "Agent dir not found: $agent_dir"
    return 1
  fi
  cd "$agent_dir"
  uv run . --port "$port" &
  echo $!
}
