# ASL Arena

Learn ASL fingerspelling from the sensei in your dojo, walk the stone path past NPCs giving advice,
then duel your opponent in the arena by signing letters at your webcam to throw fireballs.

Built with Godot 4.7 (GDScript, desktop export). Hand tracking is a separate Python process
that sends results to the game over localhost UDP.

## Running

Open the folder in Godot 4.7 and press Play, or from a terminal:

```bash
godot --path .                      # main menu
godot --path . -- --quick-duel      # straight into the arena vs a dummy
godot --path . -- --host            # host a match (you are Player 1)
godot --path . -- --join=<host-ip>  # join a match (you are Player 2)
```

To test multiplayer on one machine, run two windows: one `--host`, one `--join=127.0.0.1 --tracker-port=4243`.
Each window needs its own tracker port, because only one process can listen on 4242.

Networking uses ENet on port **7777**. On venue wifi, put both laptops on a phone hotspot.
On Windows, click "Allow" on the firewall prompt the first time.

## Controls

| Action | Input |
|---|---|
| Move | **WASD** (or arrow keys), so your right hand stays free for signing |
| Hold a sign | Webcam via the tracker, **or** hold **Space + the letter key** (Space keeps you standing still) |
| Sloppy sign (weak fireball) | Space + Shift + letter key |
| Leave dojo | Esc |

## Game flow

1. Each player starts in their own home. Walk up to the house door to enter the **dojo**. The board shows one
   hand sign at a time from `L W I U K P` (the letters the model recognizes best): hold it to learn it.
   Hand-sign pictures live in `assets/signs/<letter>.png` (64×64); a letter without a picture shows the letter.
2. Walk out through your home's gate onto the **bridge** (NPCs there give tips), then off the far end into the **arena**.
   Each area is its own screen; walking through a gate or off the bridge fades to the next one. The arena is one-way.
3. When one player reaches the arena, the other has **10 seconds**. After that, guards walk onto their screen and escort them in.
4. In the fight, when you're close to your opponent, a random letter **you've learned** appears over your head.
   Sign it to throw a fireball. Its power depends on sign quality: weak below 0.6 confidence,
   strong above 0.85, medium in between.
   - After 5s the hint card shows how to make the sign. After 10s the prompt times out.
   - Each letter has a cooldown, so rushing in with one sign means few attacks.
   - Glowing **drops** in the arena teach a new letter mid-fight.

Every number above lives in [autoload/Config.gd](autoload/Config.gd).

## Hand tracking

The tracker lives in [asl recognition/](asl%20recognition/): MediaPipe finds the hand, the crop is classified by a
Teachable Machine model (`Model/keras_model.h5`, A–Z), and [tracker.py](asl%20recognition/tracker.py) sends the
result to the game. It needs **Python 3.11 or 3.12** (TensorFlow/MediaPipe don't support newer Pythons).

One-time setup:

```bash
# Linux / macOS
cd "asl recognition"
uv venv -p 3.12 .venv          # or: python3.12 -m venv .venv
uv pip install -p .venv/bin/python -r requirements.txt
```

```powershell
# Windows
cd "asl recognition"
py -3.12 -m venv .venv
.venv\Scripts\pip install -r requirements.txt
```

Run it:

```bash
tools/play.sh --quick-duel                      # Linux/macOS: starts the tracker and the game together
"asl recognition/.venv/bin/python" "asl recognition/tracker.py"   # tracker alone, with a preview window
```

On Windows, run `.venv\Scripts\python tracker.py` in one terminal and the game in another.
Useful tracker flags: `--camera 1` (other webcam), `--no-preview`, `--letters LWIUKP`,
`--mirror-input` (classify the mirrored image; try it if letters are recognized poorly).

## Tracker → game contract (UDP JSON, 127.0.0.1:4242, ~30/s)

```json
{
  "letter": "A",
  "confidence": 0.92,
  "hand_present": true,
  "landmarks": [[0.51, 0.84], [0.47, 0.78], "... 21 [x, y] points, MediaPipe order, normalized 0..1"]
}
```

- `letter` is `null` when a hand is visible but not recognized.
- `hand_present: false` means no hand is in frame.
- `landmarks` can be `[]`. It's only used to draw the hand skeleton in the camera panel.
- The game handles the 0.5s hold-to-confirm. The tracker just reports what it sees in each frame.

[tools/fake_sender.py](tools/fake_sender.py) sends exactly this format (it uses only the standard library).
Use it to test the game without a camera:

```bash
python3 tools/fake_sender.py                # cycles through letters
python3 tools/fake_sender.py --interactive  # type "A", "B 0.7", "?" or Enter for no hand
```

## Project layout

```
autoload/      Config (tunables), Net (ENet host/join), GameState (match state, host-authoritative),
               SignInput (keyboard + UDP tracker, hold-to-confirm)
scenes/menu/   Main menu
scenes/world/  World.tscn — the map: Home1 → Bridge1 → Arena ← Bridge2 ← Home2, linked by Portal nodes
scenes/zones/  MapZone (one painted screen: background, walkable rect, blockers, optional dojo door),
               Portal (doorway to another screen), Arena
scenes/actors/ Player (wizard sprite; P2 is recolored red by a shader), NPC, Guard
scenes/dojo/   Dojo lesson overlay
scenes/arena/  HUD, combat prompt loop, fireballs, sign drops, hand-skeleton view
tools/         fake_sender.py
```

Art lives in `assets/`. Screens are 320×240 per frame, exported as horizontal animation strips.
Open a screen in World.tscn to see its walkable area (green), blockers (red), dojo door (yellow) and portals (blue)
drawn over the art. NPCs and guards are still red-box placeholders.
