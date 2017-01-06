local console = {}

-- Utilty functions for mapping and filtering a table, and pushing a set of
-- elements to the end of a table.
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

console.HORIZONTAL_MARGIN = 10 -- Horizontal margin between the text and window.
console.VERTICAL_MARGIN = 10 -- Vertical margins between components.
console.PROMPT = "> " -- The prompt symbol.

console.MAX_LINES = 200 -- How many lines to store in the buffer.
console.HISTORY_SIZE = 100 -- How much of history to store.

-- Color configurations.
console.BACKGROUND_COLOR = {0, 0, 0, 100}
console.TEXT_COLOR = {255, 255, 255, 255}
console.ERROR_COLOR = {255, 0, 0, 255}

console.FONT_SIZE = 12
console.FONT = love.graphics.newFont(console.FONT_SIZE)

-- The scope in which lines in the console are executed.
console.ENV = setmetatable({}, {__index = _G})

-- Builtin commands.
console.COMMANDS = {
  clear = function() console.clear() end,
  quit = function() love.event.quit(0) end,
  exit = function() love.event.quit(0) end
}

-- Overrideable function that is used for formatting return values.
console.INSPECT_FUNCTION = function(...)
  return table.concat(map({...}, tostring), "\t")
end

-- Store global state for whether or not the console is enabled / disabled.
local enabled = false
function console.isEnabled() return enabled end

-- Store the printed lines in a buffer.
local lines = {}
function console.clear() lines = {} end

-- Store previously executed commands in a history buffer.
local history = {}
function console.addHistory(command)
  table.insert(history, 1, command)
end

-- Print a colored text to the console. Colored text is simply represented
-- as a table of values that alternate between an {r, g, b, a} object and a
-- string value.
function console.colorprint(coloredtext) table.insert(lines, coloredtext) end

-- Wrap the print function and redirect it to store into the line buffer.
local normal_print = print
_G.print = function(...)
  local args = {...}
  local line = table.concat(map({...}, tostring), "\t")
  push(lines, line)

  while #lines > console.MAX_LINES do
    table.remove(lines, 1)
  end
end

-- Helper object that encapuslates operations on the current command.
local command = {
  clear = function(self)
    -- Clear the current command.
    self.text, self.cursor, self.history_index = "", 0, 0
  end,
  insert = function(self, input)
    -- Inert text at the cursor.
    self.text = self.text:sub(0, self.cursor) ..
      input .. self.text:sub(self.cursor + 1)
    self.cursor = self.cursor + 1
  end,
  delete_backward = function(self)
    -- Delete the character before the cursor.
    if self.cursor > 0 then
      self.text = self.text:sub(0, self.cursor - 1) ..
        self.text:sub(self.cursor + 1)
      self.cursor = self.cursor - 1
    end
  end,
  forward_character = function(self)
    self.cursor = math.min(self.cursor + 1, self.text:len())
  end,
  backward_character = function(self)
    self.cursor = math.max(self.cursor - 1, 0)
  end,
  previous = function(self)
    -- If there is no more history, don't do anything.
    if self.history_index + 1 > #history then return end

    -- If this is the first time, then save the command in case the user
    -- navigates back to the present command.
    if self.history_index == 0 then self.saved_command = self.text end

    self.history_index = math.min(self.history_index + 1, #history)
    self.text = history[self.history_index]
    self.cursor = self.text:len()
  end,
  next = function(self)
    -- If there is no more history, don't do anything.
    if self.history_index - 1 < 0 then return end
    self.history_index = math.max(self.history_index - 1, 0)

    if self.history_index == 0 then self.text = self.saved_command
    else self.text = history[self.history_index] end
    self.cursor = self.text:len()
  end
}
command:clear()

function console.draw()
  -- Only draw the console if enabled.
  if not enabled then return end

  -- Fill the background color.
  love.graphics.setColor(unpack(console.BACKGROUND_COLOR))
  love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(),
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
      - console.FONT:getHeight() - console.VERTICAL_MARGIN,
    love.graphics.getWidth(),
    love.graphics.getHeight() - console.VERTICAL_MARGIN
      - console.FONT:getHeight() - console.VERTICAL_MARGIN)

  love.graphics.printf(
    console.PROMPT .. command.text,
    console.HORIZONTAL_MARGIN,
    love.graphics.getHeight() - console.VERTICAL_MARGIN - console.FONT:getHeight(),
    love.graphics.getWidth() - console.HORIZONTAL_MARGIN*2, "left")

  if love.timer.getTime() % 1 > 0.5 then
    local cursorx = console.HORIZONTAL_MARGIN +
      console.FONT:getWidth(console.PROMPT .. command.text:sub(0, command.cursor))
    love.graphics.line(
      cursorx,
      love.graphics.getHeight() - console.VERTICAL_MARGIN - console.FONT:getHeight(),
      cursorx,
      love.graphics.getHeight() - console.VERTICAL_MARGIN)
  end
end

function console.textinput(input)
  -- Use the "~" key to enable / disable the console.
  if input == "~" then
    enabled = not enabled
    return
  end

  -- If disabled, ignore the input, otherwise insert at the cursor.
  if not enabled then return end
  command:insert(input)
end

function console.execute(command)
  -- If this is a builtin command, execute it and return immediately.
  if console.COMMANDS[command] then
    console.COMMANDS[command]()
    return
  end

  -- Reprint the command + the prompt string.
  print(console.PROMPT .. command)

  local chunk, error = load("return " .. command)
  if not chunk then
    chunk, error = load(command)
  end

  if chunk then
    setfenv(chunk, console.ENV)
    local values = { pcall(chunk) }
    if values[1] then
      table.remove(values, 1)
      print(console.INSPECT_FUNCTION(unpack(values)))

      -- Bind '_' to the first returned value, and bind 'last' to a list
      -- of returned values.
      console.ENV._ = values[1]
      console.ENV.last = values
    else
      console.colorprint({console.ERROR_COLOR, values[2]})
    end
  else
    console.colorprint({console.ERROR_COLOR, error})
  end
end

function console.keypressed(key, scancode, isrepeat)
  -- Ignore if the console isn't enabled.
  if not enabled then return end

  local ctrl = love.keyboard.isDown("lctrl", "lgui")
  local shift = love.keyboard.isDown("lshift")

  if key == 'backspace' then command:delete_backward()

  elseif key == "up" then command:previous()
  elseif key == "down" then command:next()

  elseif key == "left" then command:backward_character()
  elseif key == "right" then command:forward_character()

  elseif key == "c" and ctrl then command:clear()

  elseif key == "=" and shift and ctrl then
      console.FONT_SIZE = console.FONT_SIZE + 1
      console.FONT = love.graphics.newFont(console.FONT_SIZE)
  elseif key == "-" and ctrl then
      console.FONT_SIZE = math.max(console.FONT_SIZE - 1, 1)
      console.FONT = love.graphics.newFont(console.FONT_SIZE)

  elseif key == "return" then
    console.addHistory(command.text)
    console.execute(command.text)
    command:clear()
  end
end

return console
