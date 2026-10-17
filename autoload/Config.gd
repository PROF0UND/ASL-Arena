extends Node
## Every tunable number lives here so balancing never means hunting through scripts.

# --- Signs ---
const STARTER_LETTERS := ["A", "B", "C", "I", "L", "O", "V", "W", "Y"]
const QUICK_DUEL_LETTERS := ["A", "B", "L", "V", "Y"]
const SIGN_HINTS := {
	"A": "Make a fist. Rest your thumb against the side of your index finger.",
	"B": "Flat hand, fingers together pointing up. Fold your thumb across your palm.",
	"C": "Curve your fingers and thumb into the shape of a C.",
	"I": "Make a fist and raise only your pinky.",
	"L": "Index finger up, thumb out to the side: an L.",
	"O": "Touch all your fingertips to your thumb to make an O.",
	"V": "Index and middle fingers up and apart, like a peace sign.",
	"W": "Index, middle and ring fingers up and spread apart.",
	"Y": "Thumb and pinky out, the other fingers folded down.",
}

# --- Sign input ---
const TRACKER_PORT := 4242
const HOLD_TIME := 0.5                  # seconds a sign must be held to count
const MIN_CONFIDENCE := 0.4             # tracker readings below this are ignored
const TRACKER_STALE_TIME := 0.5         # no packet for this long means no hand
const KEYBOARD_CONFIDENCE := 1.0        # holding a letter key
const KEYBOARD_SLOPPY_CONFIDENCE := 0.5 # holding Shift + letter key

# --- Networking & movement ---
const NET_PORT := 7777
const PLAYER_SPEED := 120.0
const POSITION_SEND_RATE := 20.0

# --- Arena rules ---
const MAX_HP := 100
const GUARD_WAIT_TIME := 10.0  # after the first player reaches the arena
const GUARD_SPEED := 110.0
const ESCORT_SPEED := 80.0
const PROMPT_RANGE := 180.0    # how close to the opponent before letters appear
const PROMPT_GAP := 0.8        # pause between one prompt ending and the next
const HINT_DELAY := 5.0        # show the hand-sign card after this long
const PROMPT_TIMEOUT := 10.0   # give up on the letter after this long
const LETTER_COOLDOWN := 6.0   # per letter, so knowing few signs means few attacks
const DROP_INTERVAL := 12.0
const DROP_PICKUP_RADIUS := 16.0

# --- Fireballs ---
const QUALITY_WEAK_BELOW := 0.6
const QUALITY_STRONG_ABOVE := 0.85
const FIREBALL_LIFETIME := 2.5
const FIREBALL_TIERS := {
	"weak": {"damage": 4, "speed": 160.0, "radius": 4.0, "color": Color(1.0, 0.8, 0.45)},
	"medium": {"damage": 10, "speed": 220.0, "radius": 6.0, "color": Color(1.0, 0.55, 0.15)},
	"strong": {"damage": 20, "speed": 300.0, "radius": 9.0, "color": Color(1.0, 0.25, 0.05)},
}

# --- NPCs ---
const NPC_ADVICE := [
	"Hold each sign steady for half a second. Rushing it won't count!",
	"Keep your hand inside the camera frame. The sensei can't read what it can't see.",
	"A clean sign throws a big fireball. A sloppy one barely sparks.",
	"C and O look alike. C stays open, O touches.",
	"Rushing into the arena with one sign? Your fireballs will be few and far between.",
	"Watch for glowing drops in the arena. They teach new signs mid-fight.",
	"Good lighting makes your signs easier to read.",
	"V is two fingers, W is three. Count before you cast!",
]


func tier_for(quality: float) -> String:
	if quality < QUALITY_WEAK_BELOW:
		return "weak"
	if quality > QUALITY_STRONG_ABOVE:
		return "strong"
	return "medium"
