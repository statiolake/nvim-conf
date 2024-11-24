local M = {}

---@class Context
---@field filetype string
local Context = {}
Context.__index = Context

function Context.new()
  local self = setmetatable({}, Context)
  self.filetype = vim.bo.filetype
  return self
end

M.Context = Context

return M
