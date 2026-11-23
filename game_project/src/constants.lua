--[[
    Inflate - global constants
]]

-- window size (real pixels) and virtual size (game pixels)
WINDOW_WIDTH = 1280
WINDOW_HEIGHT = 720

-- the game is designed for 320 x 180 (BASE). The real view (VIRTUAL_WIDTH /
-- VIRTUAL_HEIGHT) grows to fill the window with no black bars - you just see
-- a bit more of the level. Screen.resize updates it. Menus keep a 320 x 180
-- layout centred inside the view (Screen.beginUI).
BASE_WIDTH = 320
BASE_HEIGHT = 180
VIRTUAL_WIDTH = BASE_WIDTH
VIRTUAL_HEIGHT = BASE_HEIGHT

TILE_SIZE = 16

LEVEL_COUNT = 15               -- levels live in src/levels/level1.lua .. level15.lua

-- camera
CAMERA_FOLLOW_SPEED = 6        -- higher = snappier follow
CAMERA_LOOKAHEAD = 0.35        -- how far ahead (x speed) the camera looks
CAMERA_LOOKAHEAD_MAX = 40      -- px
CAMERA_LOOKAHEAD_SPEED = 3     -- how quickly the lookahead catches up

---------------------------------------------------------------------------
-- BALL PHYSICS (tune these to change the feel)
---------------------------------------------------------------------------
GRAVITY = 900                  -- px/s^2
MAX_FALL_SPEED = 420
GROUND_FRICTION = 700          -- slow-down when no key is held on the ground
AIR_CONTROL = 0.65             -- fraction of ground acceleration available in the air
AIR_FRICTION = 120
JUMP_CUT = 0.5                 -- releasing jump early keeps this much upward speed
JUMP_MIN_TIME = 0.10           -- a jump always rises this long before it can be cut (quick taps on phones)
COYOTE_TIME = 0.08             -- can still jump this long after rolling off an edge
JUMP_BUFFER_TIME = 0.12        -- a jump pressed this early before landing still counts
SQUASH_TIME = 0.1              -- how long the squash frame shows after landing
WALL_RESTITUTION = 0.3         -- bounce back off walls
WALL_BOUNCE_MIN = 60           -- slower than this just stops at the wall
FALL_OUT_MARGIN = 48           -- px below the level before the ball counts as fallen

-- the 3 ball sizes, smallest to biggest
--   fanHover  px an up-fan (vent) floats this size above the vent (0 = falls through)
--   windPush  px/s a side blower pushes this size
--   waterSpeed  px/s in water: negative floats up, positive sinks
--   fallPush  px/s^2 a waterfall pushes this size down (on top of gravity)
BALL_SIZES = {
    { name = 'small',  diameter = 8,  accel = 620, maxSpeed = 115, jumpSpeed = 284,
      gravity = 0.95, restitution = 0.35, bounceMin = 90,  pitch = 1.4,
      fanHover = 72, windPush = 140, waterSpeed = -120, fallPush = 1800 },
    { name = 'normal', diameter = 18, accel = 520, maxSpeed = 100, jumpSpeed = 280,
      gravity = 1.0,  restitution = 0.45, bounceMin = 80,  pitch = 1.0,
      fanHover = 32, windPush = 77, waterSpeed = -50, fallPush = 900 },
    { name = 'big',    diameter = 22, accel = 400, maxSpeed = 85,  jumpSpeed = 255,
      gravity = 1.1,  restitution = 0.2,  bounceMin = 110, pitch = 0.7,
      fanHover = 0,  windPush = 28, waterSpeed = 70, fallPush = 250 },
}
BALL_START_SIZE = 2

---------------------------------------------------------------------------
-- AIR (health) AND INTERACTIONS
---------------------------------------------------------------------------
AIR_MAX = 100
SPIKE_DAMAGE = 25
ENEMY_DAMAGE = 25
GROW_COST = 10                 -- air spent to grow one size (shrinking is free)
HURT_INVULN_TIME = 1.0         -- seconds of flashing / no damage after a hit
HURT_BOUNCE_SPEED = 220        -- upward kick when hurt
HURT_PUSH_SPEED = 80           -- sideways kick away from an enemy
LOW_AIR = 0.25                 -- below this fraction the air bar turns red and blinks

PUMP_REFILL_TIME = 0.4         -- seconds to refill to full
PUMP_PRESS_TIME = 0.3          -- handle stays down this long
PUMP_COOLDOWN = 0.8

BREAK_SPEED = 50               -- Big ball rolling faster than this breaks cracked blocks
BREAK_IMPACT = 100             -- Big ball landing harder than this breaks cracked blocks (any real fall, not rolling)

---------------------------------------------------------------------------
-- ENEMIES
---------------------------------------------------------------------------
CRAWLER_SPEED = 22             -- px/s walking speed
STUN_TIME = 2.0                -- seconds a knocked-over crawler stays harmless
KNOCK_SPEED = 50               -- Big ball rolling faster than this knocks crawlers over
STOMP_BOUNCE = 230             -- upward speed after the Big ball squashes an enemy
STOMP_TOLERANCE = 5            -- px: how far into the enemy's top still counts as a stomp
BUZZER_RANGE = 18              -- px the buzzer bobs up and down
BUZZER_PERIOD = 2.2            -- seconds for one full bob

-- smart cave enemies (crystal levels)
BEETLE_SIGHT = 112             -- px: a beetle sees the ball this far along its floor
BEETLE_WINDUP = 0.45           -- seconds it shakes before charging (the warning)
BEETLE_CHARGE_SPEED = 150      -- px/s
BEETLE_CHARGE_TIME = 1.6       -- longest charge (seconds)
BEETLE_COOLDOWN = 1.5          -- rest after a charge
BAT_SIGHT_X = 40               -- px sideways a hanging bat looks ...
BAT_SIGHT_Y = 144              -- ... and px down
BAT_LEAD = 0.35                -- aims this many seconds ahead of a rolling ball
BAT_SWOOP_SPEED = 125          -- px/s diving
BAT_RETURN_SPEED = 60          -- px/s flying back up
BAT_DIVE_TIME = 1.5            -- longest dive (seconds)
BAT_COOLDOWN = 1.5             -- rest on the ceiling after a swoop
-- the Shade: can't be hurt, chases the ball, a bit slower than it
SHADE_WAKE_DIST = 96           -- px: wakes when the ball is this close (and in sight)
SHADE_GIVEUP_DIST = 200        -- px: stops chasing when the ball is further than this
SHADE_SPEED = 74               -- px/s (balls: Small 115, Normal 100, Big 85)
SHADE_ACCEL = 260
SHADE_RETURN_SPEED = 35        -- px/s walking home
SHADE_ROAR_TIME = 0.6          -- seconds it roars after waking (head start)
SHADE_STUCK_TIME = 2.5         -- blocked this long (wall, gap, tunnel) -> gives up
SHADE_HIT_PAUSE = 0.8          -- stands still this long after hurting the ball
SHADE_SAFE_X = 48              -- never comes closer than this to a checkpoint ...
SHADE_SAFE_Y = 64              -- ... on about the same floor

-- jungle creatures (level 15)
FROG_SIGHT = 120               -- px: a frog hops toward the ball when it is this close
FROG_SIT_TIME = {0.7, 1.3}     -- seconds it sits between hops (random in this range)
FROG_CROUCH_TIME = 0.2         -- crouches this long before a hop (the warning)
FROG_HOP_SPEED = 80            -- px/s sideways during a hop
FROG_JUMP_SPEED = 250          -- px/s upward at the start of a hop
SNAKE_SIGHT = 52               -- px: pops out of the grass when the ball is this close
SNAKE_RISE_TIME = 0.25         -- seconds raising its head (the warning)
SNAKE_LUNGE_SPEED = 150        -- px/s
SNAKE_LUNGE_DIST = 26          -- px it lunges forward
SNAKE_OUT_TIME = 0.9           -- stays up this long, then slides back and hides
SNAKE_COOLDOWN = 1.2           -- hidden at least this long before it can strike again
MONKEY_RANGE = 150             -- px: throws coconuts at a ball this close (sideways)
MONKEY_COOLDOWN = 1.8          -- seconds between throws
MONKEY_WINDUP = 0.35           -- holds the coconut up this long before throwing (the warning)
COCONUT_GRAVITY = 520
COCONUT_FLIGHT = 0.85          -- seconds a coconut takes to reach where the ball was
COCONUT_DAMAGE = 15
BUG_RANGE = 48                 -- px a jungle beetle drifts left / right of its spot
BUG_SPEED = 32                 -- px/s drifting
BUG_SIGHT = 88                 -- px: dives at a ball this close (in sight)
PLANT_SIGHT = 40               -- px: a snapper plant opens when the ball is this close
PLANT_WARN_TIME = 0.4          -- open mouth (the warning)
PLANT_BITE_TIME = 0.35         -- biting (reaches one tile up)
PLANT_TIRED_TIME = 1.1         -- droops afterwards: safe to pass
PLANT_REACH = 16               -- px the bite reaches above the plant
PIRANHA_SPEED = 34             -- px/s swimming
PIRANHA_SIGHT_X = 44           -- px: leaps at a ball this close sideways ...
PIRANHA_SIGHT_Y = 96           -- ... and this far above it
PIRANHA_COOLDOWN = 1.6         -- seconds between leaps

-- waterfalls (W in a level): a column of falling water that pushes the ball
-- down (BALL_SIZES fallPush). Stops at solid ground or a pool's surface.

-- juice
HIT_FREEZE_TIME = 0.06         -- tiny pause when squashing an enemy
SHAKE_SMALL = {2, 0.15}        -- {pixels, seconds}
SHAKE_BIG = {3, 0.25}
LANDING_DUST_IMPACT = 160      -- landings harder than this kick up dust

-- fans (factory levels). Vents (F / U / V) blow upward, blowers (< >) sideways.
FAN_RANGE = 6                  -- tiles: how high a vent's air column reaches (stops at solid tiles)
WIND_RANGE = 36                -- tiles: how far a blower's wind reaches (stops at solid tiles)
FAN_RISE_SPEED = 150           -- fastest a vent lifts the ball (px/s)
FAN_SINK_SPEED = 70            -- above its float height the ball sinks back this fast
FAN_PULL = 5                   -- how firmly the ball is pulled to its float height
FAN_SMOOTH = 6                 -- how quickly the ball's speed follows the air (higher = snappier)
WIND_SMOOTH = 8                -- how quickly side wind takes hold / lets go
-- on/off vents: U and V take turns. ON, then WARN (slowing down), then OFF
FAN_ON_TIME = 2.2
FAN_WARN_TIME = 0.6
FAN_OFF_TIME = 1.6
FAN_SPIN_FPS = 14              -- fan blade animation speed at full power

-- water (water levels). Small floats up fast, Normal slowly, Big sinks (waterSpeed).
WATER_MOVE = 0.7               -- top rolling / swimming speed in water (fraction of normal)
WATER_PULL = 6                 -- how firmly a floating ball is held at the surface
WATER_SMOOTH = 5               -- how quickly the ball's speed follows the water (drag)
WATER_SINK_SPEED = 60          -- a floating size that fell in sinks at most this fast before rising
WATER_AIR_DRAIN = 2.5          -- air lost per second while completely under water
BUBBLE_REFILL = 40             -- air gained per second inside a bubble stream
BUBBLE_RANGE = 24              -- tiles: how high a bubble stream rises (stops at the surface)
SPLASH_SPEED = 80              -- entering / leaving water faster than this splashes

-- pressure plates + gates. Only the Big ball is heavy enough to press a plate.
-- A gate opens while ALL plates of its group are active.
GATE_HOLD_GRACE = 1.0          -- a hold plate stays active this long after Big rolls off
TIMER_TICK = 0.5               -- a running timer plate ticks this often ...
TIMER_TICK_FAST = 0.25         -- ... and this often near the end
TIMER_FAST_AT = 1.5            -- seconds left when the ticking speeds up

-- gravity orbs: touching one flips gravity for the ball (up or back down)
FLIP_SMALL_GRAVITY = 0.8       -- upside down the Small ball "falls" up a bit slower

-- moving platforms (one-way: land on top, jump up through from below)
PLATFORM_SPEED = 40            -- px per second (a level can give each its own)
PLATFORM_PAUSE = 0.6           -- seconds a platform waits at each end
PLATFORM_BIG_SLOW = 0.75       -- the heavy Big ball slows a platform down ...
PLATFORM_SAG = 2               -- ... and makes it sag this many pixels

-- springs, checkpoints, key + door
SPRING_SPEED = 430             -- launch speed (about 6 tiles high for the Normal ball)
SPRING_PRESS_TIME = 0.2        -- spring shows its "extended" frame this long
MESSAGE_TIME = 1.5             -- seconds a message like "FIND THE KEY!" stays up
RESPAWN_INVULN_TIME = 1.0      -- grace period after respawning at a checkpoint

POP_RESTART_TIME = 1.2         -- seconds after popping before the level restarts
GOAL_DELAY = 1.0               -- seconds after touching the flag before the win screen
CONTROLS_HINT_TIME = 5         -- seconds the controls hint shows at level start

-- background clear colour (dark navy); replaced by the palette in step 2
BACKGROUND_COLOR = {0.07, 0.08, 0.16}
