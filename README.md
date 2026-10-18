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
| Move | Arrow keys |
| Hold a sign | Webcam via the tracker, **or** hold the letter key |
| Sloppy sign (weak fireball) | Shift + letter key |
| Leave dojo | Esc |

## Game flow

1. Each player starts in their own home. Walk onto the yellow door to enter the **dojo**. The sensei
   teaches the starter letters `A B C I L O V W Y` one at a time: hold the sign to learn it.
2. Follow the stone walkway to the **arena**. NPCs along the way give tips.
3. When one player reaches the arena, the other has **10 seconds**. After that, guards walk over and escort them in.
4. In the fight, when you're close to your opponent, a random letter **you've learned** appears over your head.
   Sign it to throw a fireball. Its power depends on sign quality: weak below 0.6 confidence,
   strong above 0.85, medium in between.
   - After 5s the hint card shows how to make the sign. After 10s the prompt times out.
   - Each letter has a cooldown, so rushing in with one sign means few attacks.
   - Glowing **drops** in the arena teach a new letter mid-fight.

Every number above lives in [autoload/Config.gd](autoload/Config.gd).

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
scenes/world/  World.tscn — places the zones; move/swap them here to change the map
scenes/zones/  Home (with dojo), Walkway (with NPCs), Arena
scenes/actors/ Player, NPC, Guard  (red-box placeholders)
scenes/dojo/   Dojo lesson overlay
scenes/arena/  HUD, combat prompt loop, fireballs, sign drops, hand-skeleton view
tools/         fake_sender.py
```

Art is placeholder: red boxes for characters, a green background, and outlined zones.
Swap in sprites by replacing the `Body` ColorRect in each actor scene.
