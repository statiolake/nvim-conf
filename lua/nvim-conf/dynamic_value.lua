local M = {}

---@class DynamicValue
---@field _dynamic_value_marker boolean
---@field fn function
local DynamicValue = {}
DynamicValue.__index = DynamicValue

function DynamicValue.new(fn)
  local self = setmetatable({}, DynamicValue)
  self._dynamic_value_marker = true
  self.fn = fn
  return self
end

function DynamicValue.safe_resolve(self, ctx)
  return pcall(self.fn, ctx)
end

M.DynamicValue = DynamicValue

function M.is_dynamic_value(value)
  return type(value) == 'table' and value._dynamic_value_marker
end

return M
