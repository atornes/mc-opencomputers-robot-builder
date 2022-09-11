mover = {}

local pos_x = 0
local pos_y = 0
local pos_z = 0

local comp = require("component")
local sides = require("sides")
local nav = comp.navigation
local r = comp.robot

function mover:init()
  local x,y,z = nav.getPosition()
  pos_x = math.floor(x)
  pos_y = math.floor(y)
  pos_z = math.floor(z)
end

function mover:getFacing()
  return nav.getFacing()
end

function mover:getPos()
  return pos_x, pos_y, pos_z
end

local function getAngle(source_x, source_z, target_x, target_z)
  local diff_x = target_x - source_x
  local diff_z = target_z - source_z
  return math.abs(math.atan(diff_x / diff_z))
end

local function getTargetFacingSide(source_x, source_z, target_x, target_z)
  local diff_x = target_x - source_x
  local diff_z = target_z - source_z
  local dir1 = diff_x > 0 and sides.posx or sides.negx
  local dir2 = diff_z > 0 and sides.posz or sides.negz

  local angle = getAngle(source_x, source_z, target_x, target_z)

  return angle < math.pi / 4 and dir2 or dir1
end

local function shouldTurnClockwise(source_side, target_side)
  if source_side == sides.north and target_side == sides.west then return false
  elseif source_side == sides.south and target_side == sides.east then return false
  elseif source_side == sides.east and target_side == sides.north then return false
  elseif source_side == sides.west and target_side == sides.south then return false
  else return true end
end

local function turnTo(source_side, target_side)
  local clockwise = shouldTurnClockwise(source_side, target_side)
  while source_side ~= target_side
  do
    r.turn(clockwise)
    source_side = mover:getFacing()
  end
end

local function updatePos(side)
  if side == sides.posx then
    pos_x = pos_x + 1
  elseif side == sides.negx then
    pos_x = pos_x - 1
  elseif side == sides.posz then
    pos_z = pos_z + 1
  elseif side == sides.negz then
    pos_z = pos_z - 1
  elseif side == sides.posy then
    pos_y = pos_y + 1
  elseif side == sides.negy then
    pos_y = pos_y - 1
  end
  
  print("X: " .. pos_x .. " Y: " .. pos_y .. " Z: " .. pos_z)
end

local function canMove(side)
  local canNotMove, _ = r.detect(side)
  return not canNotMove
end

local function moveForward() -- Returns stuck
  local facing = mover:getFacing()
  local canMoveForward = canMove(sides.front)
  
  local triedUp = false
  local deltaUp = 0
  local triedDown = false
  local deltaDown = 0
  local triedLeft = false
  local maxLeft = 6

  while not canMoveForward do
    if not triedUp then
      local canMoveUp = canMove(sides.up)
      if canMoveUp then
        r.move(sides.up)
        updatePos(sides.up)
        deltaUp = deltaUp + 1
      else
        triedUp = true
        for i=0, deltaUp, 1 
        do
          r.move(sides.down)
          updatePos(sides.down)
        end
      end
    elseif not triedDown then
      local canMoveDown = canMove(sides.down)
      if canMoveDown then
        r.move(sides.down)
        updatePos(sides.down)
        deltaDown = deltaDown + 1
      else
        triedDown = true
        for i=0, deltaDown, 1 
        do
          r.move(sides.up)
          updatePos(sides.up)
        end
      end
    elseif not triedLeft then
      r.turn(false)
      if canMove(sides.front) then
        r.move(sides.front)
        facing = mover:getFacing()
        updatePos(facing)
        r.turn(true)

        maxLeft = maxLeft - 1
        if maxLeft == 0 then
          triedLeft = true
        end
      else
        r.turn(true)
        triedLeft = true
      end
    else
      break
    end
    
    canMoveForward = canMove(sides.front)
  end

  if canMoveForward then
    print(r.move(sides.front))
    updatePos(facing)
    return false
  else
    print("Stuck!!!!")
    return true
  end
end

function mover:moveTo(x, y, z)
    local cx, cy, cz = mover:getPos()
    while cx ~= x or cz ~= z
    do
      local turn_to = getTargetFacingSide(cx, cz, x, z)
      local facing = mover:getFacing()
      turnTo(facing, turn_to)
      
      local stuck = moveForward()
      if stuck then
        break
      end

      cx, cy, cz = mover:getPos()
    end
    
    while cy ~= y 
    do
      if cy > y then
        if canMove(sides.down) then
          r.move(sides.down)
          updatePos(sides.down)
        else
          print("Stuck down!!")
          break
        end
      elseif cy < y then
        if canMove(sides.up) then
          r.move(sides.up)
          updatePos(sides.up)
        else
          print("Stuck up!!")
          break
        end
      end
      
      cx, cy, cz = mover:getPos()
    end
end