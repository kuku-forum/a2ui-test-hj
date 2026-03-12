# Flutter Gen UI SDK

The [Flutter Gen UI SDK](https://github.com/flutter/genui) is the official Flutter renderer for A2UI.

Key packages from the Flutter Gen UI SDK include:

*   [`genui`](https://pub.dev/packages/genui): The core framework for employing Generative UI in Flutter applications.
*   [`genui_a2a`](https://github.com/flutter/genui/tree/main/packages/genui_a2a): Connects Flutter apps to A2UI backend agents (A2A protocol).

## Run the Flutter demo from A2UI

From the A2UI repo you can run a Flutter client against the Restaurant Finder agent without cloning GenUI yourself:

```bash
cd demos
./run-demo-restaurant-flutter.sh
# or: ./run-demo.sh restaurant-flutter
```

**Requirements:** Flutter SDK, `OPENAI_API_KEY` in `demos/.env`. On first run the script clones the [GenUI repo](https://github.com/flutter/genui) (Verdure example) into `.genui_verdure` at the project root, then starts the agent and runs the Flutter app (Chrome by default). Override the clone path with `GENUI_CLONE=/path/to/genui`.

### Lit-style Flutter Shell (chat + A2UI on web/mobile)

For a **Lit-like experience** (chat input + A2UI surface) without cloning GenUI, use the in-repo Flutter client:

```bash
cd demos
./run-demo-restaurant-flutter-shell.sh
# or: ./run-demo.sh restaurant-flutter-shell
```

This runs the app in `samples/client/flutter/restaurant_shell`, which uses `genui` and `genui_a2ui` from pub.dev and connects to the Restaurant Finder agent. Works on **web** (`flutter run -d chrome`), **iOS**, and **Android**.