#!/usr/bin/env bash
# Run a demo by name. Usage: ./run-demo.sh <name>
# Names: restaurant-lit | restaurant-react | restaurant-angular | restaurant-flutter | contact-lit | ...
#
# 학습 포인트:
# - 이 파일은 "실제 실행 로직"이 아니라 "데모 이름 -> 개별 스크립트" 라우터다.
# - 디버깅할 때는 여기서 어떤 스크립트로 분기되는지 먼저 확인하면 빠르다.

set -e
DEMOS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
name="${1:-}"

case "$name" in
  restaurant-lit)        "$DEMOS_ROOT/run-demo-restaurant-lit.sh" ;;
  restaurant-react)      "$DEMOS_ROOT/run-demo-restaurant-react.sh" ;;
  restaurant-angular)    "$DEMOS_ROOT/run-demo-restaurant-angular.sh" ;;
  contact-lit)           "$DEMOS_ROOT/run-demo-contact-lit.sh" ;;
  contact-angular)       "$DEMOS_ROOT/run-demo-contact-angular.sh" ;;
  contact-multiple-lit)  "$DEMOS_ROOT/run-demo-contact-multiple-lit.sh" ;;
  rizzcharts-angular)    "$DEMOS_ROOT/run-demo-rizzcharts-angular.sh" ;;
  orchestrator-angular)  "$DEMOS_ROOT/run-demo-orchestrator-angular.sh" ;;
  component-gallery-lit) "$DEMOS_ROOT/run-demo-component-gallery-lit.sh" ;;
  restaurant-flutter)         "$DEMOS_ROOT/run-demo-restaurant-flutter.sh" ;;
  *)
    echo "Usage: $0 <demo-name>"
    echo ""
    echo "Demo names:"
    echo "  restaurant-lit           Restaurant + Lit Shell (port 5173)"
    echo "  restaurant-react         Restaurant + React Shell (port 5003)"
    echo "  restaurant-angular       Restaurant + Angular"
    echo "  restaurant-flutter       Restaurant + Flutter (Lit-style chat + A2UI, web/Android)"
    echo "  contact-lit            Contact + Lit Shell (?app=contacts)"
    echo "  contact-angular       Contact + Angular"
    echo "  contact-multiple-lit   Contact Multiple Surfaces + Lit contact"
    echo "  rizzcharts-angular     Rizzcharts + Angular (Gemini)"
    echo "  orchestrator-angular   Orchestrator + Angular (Gemini)"
    echo "  component-gallery-lit  Component Gallery + Lit (no API key)"
    exit 1
    ;;
esac
