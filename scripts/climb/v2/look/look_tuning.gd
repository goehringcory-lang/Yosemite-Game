class_name LookTuning
extends RefCounted
## Every number thread 10's look (camera, wall, light, sound) is tuned by, in
## one place. Metres and seconds unless it says pixels.

# ---------------------------------------------------------------- camera
## Zoom stops. The climber and wall are pixel art, so the camera rests only
## on these (it eases between them); 0.5 shows the whole pitch to read it.
const ZOOM_CLOSE := 1.0
const ZOOM_WIDE := 0.5
## Where the camera looks while climbing: this far above the hips...
const CLIMB_LIFT := 0.9
## ...plus this share of the way toward the aimed hold, at most LEAD_MAX.
const LEAD_SHARE := 0.35
const LEAD_MAX := 1.2
## The hips can drift this far (half-width, half-height) before the frame follows.
const DEAD_ZONE := Vector2(0.2, 0.3)
## Ease rates (1/s; higher = faster) per phase, x then y.
const RATE_CLIMB := Vector2(3.0, 4.0)
const RATE_LEAD := 5.0
const RATE_WORK := Vector2(3.0, 3.0)
const RATE_FALL := Vector2(8.0, 8.0)
const RATE_BELAY := Vector2(1.5, 1.5)
const RATE_RESULT := Vector2(1.0, 1.0)
const RATE_ZOOM := 2.0
## Reading the pitch: the pan starts at the top anchor and comes down at
## this speed (m/s) to the start; any input ends it (the director goes to climb).
const READ_PAN_SPEED := 4.5
## Seconds the read view holds at the top before panning down.
const READ_HOLD := 1.2
## A fall: the camera tracks this far below the climber...
const FALL_BIAS := 1.0
## ...and the catch shakes (vertical only) by min(SHAKE_MAX, SHAKE_BASE +
## SHAKE_PER_M x drop) pixels, dying away over SHAKE_TIME.
const SHAKE_BASE := 3.0
const SHAKE_PER_M := 2.0
const SHAKE_MAX := 10.0
const SHAKE_TIME := 0.25
## A committed move settles the view down a touch (pixels, seconds).
const SETTLE_PX := 2.5
const SETTLE_TIME := 0.12
## At most this much sky (m) shows past each side of the wall's painted rock.
const SIDE_SKY := 1.5
## Where the climber sits across the screen (0 left .. 1 right), so the
## valley shows past the arete on the right.
const FRAME_X := 0.44

# ---------------------------------------------------------------- wall
## Painted rock around the climbable face (m): to the left, to the right
## (then the arete and sky), below the start, above the top anchor.
const MARGIN_LEFT := 7.0
const MARGIN_RIGHT := 2.2
const MARGIN_BELOW := 2.5
const MARGIN_ABOVE := 4.0
## Crack width on the Camalot scale (0..7) -> drawn width in pixels.
const CRACK_PX_MIN := 1.5
const CRACK_PX_PER := 0.9
## Holds within this distance of the hips get a faint chalk tick (reach + 1 m).
const TICK_RANGE := 2.4
## Pixels a still frame is drawn at (the wall paints at PX_PER_M).
const PX := 60.0

# ---------------------------------------------------------------- light
## Headlamp radius (m) and how far toward the aimed hold it points.
const LAMP_RADIUS := 2.6
const LAMP_LEAN := 0.5
## Night: the rock outside the lamp keeps this much light (moonlight).
const NIGHT_FLOOR := 0.7
## Raking sun never gets weaker than this on a lit face, so holds read.
const SUN_MIN := 0.25

# ---------------------------------------------------------------- sound
## A sound id never plays twice within this many seconds.
const SOUND_GAP := 0.08
## Breathing starts at this pump and is loudest at 1.
const BREATH_FROM := 0.4
## Seconds the beds and breathing duck on a fall, and by how many dB.
const DUCK_TIME := 0.6
const DUCK_DB := -6.0
## A route this tall (m) is fully exposed (the beds turn to wind).
const EXPOSED_M := 460.0
