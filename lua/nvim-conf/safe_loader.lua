local M = {}

local function create_safe_env()
  return {
    -- Allow access to basic Lua functions
    ipairs = ipairs,
    next = next,
    pairs = pairs,
    pcall = pcall,
    tonumber = tonumber,
    tostring = tostring,
    type = type,
    unpack = unpack,
    -- String manipulation
    string = { sub = string.sub, upper = string.upper, lower = string.lower },
    -- Table operations
    table = {
      insert = table.insert,
      remove = table.remove,
      sort = table.sort,
    },
    -- Math functions
    math = {
      abs = math.abs,
      ceil = math.ceil,
      floor = math.floor,
      max = math.max,
      min = math.min,
      pow = math.pow,
      random = math.random,
      randomseed = math.randomseed,
    },
    -- Add other necessary functions or modules here
  }
end

-- Function to safely load and evaluate configuration
function M.safe_load(content)
  local fn, err = loadstring(content)
  if not fn then
    error('Failed to load configuration: ' .. err)
  end

  local safe_env = create_safe_env()
  setfenv(fn, safe_env)

  local ok, result = pcall(fn)
  if not ok then
    error('Failed to execute configuration: ' .. result)
  end
  return result
end

return M
