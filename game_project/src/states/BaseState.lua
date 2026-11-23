--[[
    Inflate - BaseState
    Every state inherits these empty methods so the StateMachine can always call them.
]]

BaseState = Class{}

function BaseState:init() end
function BaseState:enter(params) end
function BaseState:exit() end
function BaseState:update(dt) end
function BaseState:render() end
