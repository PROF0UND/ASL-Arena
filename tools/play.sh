#!/usr/bin/env bash
# Start the hand tracker and the game together (Linux/macOS). Arguments go to the game:
#   tools/play.sh                  # main menu
#   tools/play.sh --quick-duel     # straight into a fight
#   tools/play.sh --host           # host a match
#   tools/play.sh --join=<ip>      # join a match
# Environment overrides:
#   GODOT=/path/to/godot           # Godot binary (default: `godot` on PATH, else ~/Downloads/Godot_v4.7.2...)
#   TRACKER_ARGS="--camera 1"      # extra tracker flags (default: --no-preview)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$(command -v godot || echo "$HOME/Downloads/Godot_v4.7.2-stable_linux.x86_64")}"
TRACKER_DIR="$ROOT/asl recognition"
PYTHON="$TRACKER_DIR/.venv/bin/python"

if [[ -x "$PYTHON" ]]; then
	# shellcheck disable=SC2086  # TRACKER_ARGS is meant to split into separate flags
	"$PYTHON" "$TRACKER_DIR/tracker.py" ${TRACKER_ARGS:---no-preview} &
	TRACKER_PID=$!
	trap 'kill "$TRACKER_PID" 2>/dev/null || true' EXIT
else
	echo "No tracker environment at '$TRACKER_DIR/.venv' (see README: Hand tracking). Keyboard input only."
fi

"$GODOT" --path "$ROOT" -- "$@"
