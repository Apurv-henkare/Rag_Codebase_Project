--[[
    Inflate - Dependencies
    Loads libraries, game classes and states, and builds the global asset tables.
    All art and sound are generated here at startup from code.
]]

-- libraries
Class = require 'lib/class'
push  = require 'lib/push'
Timer = require 'lib/knife.timer'

-- core
require 'src/constants'
require 'src/Util'
require 'src/StateMachine'

-- art + audio generators
require 'src/art/Palette'
require 'src/art/SpriteBuilder'
require 'src/art/Sprites'
require 'src/art/JungleSprites'
require 'src/art/PixelFont'
require 'src/art/Background'
require 'src/audio/SoundGen'

-- world
require 'src/Animation'
require 'src/GameObject'
require 'src/Tile'
require 'src/TileMap'
require 'src/GameLevel'
require 'src/LevelMaker'
require 'src/Camera'
require 'src/Entity'
require 'src/Ball'
require 'src/Enemy'
require 'src/Particles'
require 'src/HUD'
require 'src/Menu'
require 'src/SaveData'
require 'src/TouchControls'
require 'src/Screen'

-- states
require 'src/states/BaseState'
require 'src/states/entity/ball/BallGroundState'
require 'src/states/entity/ball/BallAirState'
require 'src/states/entity/ball/BallPopState'
require 'src/states/entity/enemy/EnemyPatrolState'
require 'src/states/entity/enemy/EnemyStunnedState'
require 'src/states/entity/enemy/EnemySquashedState'
require 'src/states/entity/enemy/EnemyFlyState'
require 'src/states/entity/enemy/EnemyChargeState'
require 'src/states/entity/enemy/EnemyHangState'
require 'src/states/entity/enemy/EnemySwoopState'
require 'src/states/entity/enemy/EnemySleepState'
require 'src/states/entity/enemy/EnemyChaseState'
require 'src/states/entity/enemy/EnemyReturnState'
require 'src/states/entity/enemy/EnemyHopState'
require 'src/states/entity/enemy/EnemyLurkState'
require 'src/states/entity/enemy/EnemyThrowState'
require 'src/states/entity/enemy/EnemyDriftState'
require 'src/states/entity/enemy/EnemySnapState'
require 'src/states/entity/enemy/EnemySwimState'
require 'src/states/game/LevelCompleteState'
require 'src/states/game/StartState'
require 'src/states/game/PlayState'
require 'src/states/game/ArtPreviewState'
require 'src/states/game/LevelSelectState'
require 'src/states/game/PauseState'
require 'src/states/game/GameCompleteState'

BACKGROUND_COLOR = Palette.get('K')

-- build every asset once
gTextures = {}
gFrames = {}
SpriteBuilder.buildAll(Sprites.defs, gTextures, gFrames)

gSounds = {}
SoundGen.buildAll(gSounds)

gFonts = {
    ['pixel'] = PixelFont.font,
}

Background.init()
