local console = require "console"
love.keyboard.setKeyRepeat(true)

local rectangle = {
  x = 100, y = 100,
  width = 100, height = 100,
  r = 1, g = 1, b = 1
}
console.ENV.rectangle = rectangle

function love.keypressed(key, scancode, isrepeat)
  console.keypressed(key, scancode, isrepeat)
end

function love.textinput(text)
  console.textinput(text)
end

function love.draw()
  love.graphics.setColor(rectangle.r, rectangle.g, rectangle.b, 1)
  love.graphics.rectangle("fill", rectangle.x, rectangle.y,
    rectangle.width, rectangle.height)
  console.draw()
end
