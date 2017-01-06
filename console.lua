local console = {}

console.HORIZONTAL_MARGIN = 10 -- Horizontal margin between the text and window.
console.VERTICAL_MARGIN = 10 -- Vertical margins between components.
console.PROMPT = "> " -- The prompt symbol.
console.MAX_LINES = 200 -- How many lines to store in the buffer.
console.FONT_SIZE = 12
console.FONT = nil

console.ENV = setmetatable({}, {__index = _G})

local function clamp(x, min, max)
  return x < min and min or (x > max and max or x)
end

local function map(tbl, f)
    local t = {}
    for k,v in pairs(tbl) do t[k] = f(v) end
    return t
end

local function filter(tbl, f)
  local t, i = {}, 1
  for _, v in ipairs(tbl) do
    if f(v) then t[i], i = v, i + 1 end
  end
  return t
end

local function push(tbl, ...)
  for _, v in ipairs({...}) do table.insert(tbl, v) end
end

local enabled = false

-- Store the printed lines in a buffer.
local lines = {}
function console.clear() lines = {} end

-- Print a colored text to the console. Colored text is simply represented
-- as a table of values that alternate between an {r, g, b, a} object and a
-- string value.
function console.colorprint(coloredtext) table.insert(lines, coloredtext) end

-- Wrap the print function to store to the buffer.
local normal_print = print
_G.print = function(...)
  local args = {...}
  local line = table.concat(map({...}, tostring), "\t")
  push(lines, line)

  while #lines > console.MAX_LINES do
    table.remove(lines, 1)
  end
end

local current_command, cursor = "", 1
function clear_command()
  current_command = ""
  cursor = 0
end
function clamp_cursor()
  cursor = clamp(cursor, 0, current_command:len())
end

function console.draw()
  if console.FONT == nil then
    console.FONT = love.graphics.newFont(console.FONT_SIZE)
  end

  if not enabled then return end
  love.graphics.setColor(0, 0, 0, 100)
  love.graphics.rectangle('fill', 0, 0,
    love.graphics.getWidth(),
    love.graphics.getHeight())

  love.graphics.setColor(255, 255, 255, 255)
  love.graphics.setFont(console.FONT)

  local line_start = love.graphics.getHeight() - console.VERTICAL_MARGIN*3 - console.FONT:getHeight()
  local wraplimit = love.graphics.getWidth() - console.HORIZONTAL_MARGIN*2

  for i = #lines, 1, -1 do
    local textonly = lines[i]
    if type(lines[i]) == "table" then
      textonly = table.concat(filter(lines[i], function(val)
        return type(val) == "string"
      end), "")
    end
    width, wrapped = console.FONT:getWrap(textonly, wraplimit)

    love.graphics.printf(
      lines[i], console.HORIZONTAL_MARGIN,
      line_start - #wrapped * console.FONT:getHeight(),
      wraplimit, "left")
    line_start = line_start - #wrapped * console.FONT:getHeight()
  end

  love.graphics.line(0,
    love.graphics.getHeight() - console.VERTICAL_MARGIN
      - console.FONT_SIZE - console.VERTICAL_MARGIN,
    love.graphics.getWidth(),
    love.graphics.getHeight() - console.VERTICAL_MARGIN
      - console.FONT_SIZE - console.VERTICAL_MARGIN)

  clamp_cursor()
  love.graphics.printf(
    console.PROMPT .. current_command,
    console.HORIZONTAL_MARGIN,
    love.graphics.getHeight() - console.VERTICAL_MARGIN - console.FONT_SIZE,
    love.graphics.getWidth() - console.HORIZONTAL_MARGIN*2, "left")

  if love.timer.getTime() % 1 > 0.5 then
    local cursorx = console.HORIZONTAL_MARGIN +
      console.FONT:getWidth(console.PROMPT .. current_command:sub(0, cursor))
    love.graphics.line(
      cursorx,
      love.graphics.getHeight() - console.VERTICAL_MARGIN - console.FONT_SIZE,
      cursorx,
      love.graphics.getHeight() - console.VERTICAL_MARGIN)
  end
end

function console.isEnabled() return enabled end

function console.textinput(input)
  if input == "~" then
    enabled = not enabled
    return
  end

  if not enabled then return end

  current_command =
    current_command:sub(0, cursor) .. input ..
    current_command:sub(cursor + 1)
  cursor = cursor + 1
  clamp_cursor()
end

local function execute(command)
  if command == "clear" then
    console.clear()
    return
  elseif command == "quit" or command == "exit" then
    love.event.quit(0)
    return
  end

  print(console.PROMPT .. command)

  local chunk, error = load("return " .. command)
  if not chunk then
    chunk, error = load(command)
  end

  if chunk then
    setfenv(chunk, console.ENV)
    local values = {pcall(chunk)}
    if values[1] then
      table.remove(values, 1)
      print(unpack(values))
    else
      console.colorprint({{255, 0, 0, 255}, values[2]})
    end
  else
    console.colorprint({{255, 0, 0, 255}, error})
  end
end

function console.keypressed(key, scancode, isrepeat)
  if not enabled then return end

  if key == 'backspace' then
    if cursor > 0 then
      current_command =
        current_command:sub(0, cursor - 1) .. current_command:sub(cursor + 1)
      cursor = cursor - 1
      clamp_cursor()
    end
  elseif key == "left" then
    cursor = cursor - 1
    clamp_cursor()
  elseif key == "right" then
    cursor = cursor + 1
    clamp_cursor()
  elseif key == "c" then
    if love.keyboard.isDown("lctrl", "lgui") then
      clear_command()
    end
  elseif key == "=" or key == "+" then
    if love.keyboard.isDown("lctrl", "lgui") then
      console.FONT_SIZE = console.FONT_SIZE + 1
      console.FONT = love.graphics.newFont(console.FONT_SIZE)
    end
  elseif key == "return" then
    execute(current_command)
    clear_command()
  end
end

return console
