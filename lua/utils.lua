local M = {}

local charset = "qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890"
math.randomseed(os.clock())

M.randomString = function(length)
  -- generate random string with specified length. it's used for tmp buffer, cell id generation.
  local ret = {}
  local r
  for _ = 1, length do
    r = math.random(1, #charset)
    table.insert(ret, charset:sub(r, r))
  end
  return table.concat(ret)
end

return M
