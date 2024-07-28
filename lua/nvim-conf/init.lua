local M = {}

local default_config = {}
local cache = {}

-- Function to load workspace configuration and merge it with default
local function load()
  cache = vim.deepcopy(default_config)
  local workspace_config_path = vim.fn.getcwd() .. '/.vim/conf.lua'
  if vim.fn.filereadable(workspace_config_path) == 1 then
    local content = table.concat(vim.fn.readfile(workspace_config_path), '\n')
    local workspace_config =
      require('nvim-conf.safe_loader').safe_load(content)
    cache = vim.tbl_deep_extend('force', cache, workspace_config)
  end
end

function M.set_defaults(opts)
  default_config = opts
  cache = vim.deepcopy(opts)
end

local function dispatch_config_on_context(ctx, config)
  local result = {}
  for key, value in pairs(config) do
    if type(value) == 'table' then
      result[key] = dispatch_config_on_context(ctx, value)
    elseif type(value) == 'function' then
      result[key] = value(ctx)
    else
      result[key] = value
    end
  end
  return result
end

---@class Context
---@field filetype string
local Context = {}
Context.__index = Context

function Context.new()
  local self = setmetatable({}, Context)
  return self
end

function Context:populate_env()
  if not self.filetype then
    self.filetype = vim.bo.filetype
  end
end

M.Context = Context

---get configuration
---@param ctx? Context
---@param force_reload? boolean
function M.get(ctx, force_reload)
  if not ctx then
    ctx = M.Context.new()
  end

  ctx:populate_env()

  if force_reload then
    cache = nil
  end

  if not cache then
    load()
  end

  local config = cache
  return dispatch_config_on_context(ctx, config)
end

function M.function_value(fn)
  return function(_)
    return fn
  end
end

function M.per_filetype(filetype_opt_map)
  return function(ctx)
    for filetypes, value in pairs(filetype_opt_map) do
      filetypes = vim.split(filetypes, '[, ]')
      if table.concat(filetypes, ','):find(ctx.filetype) then
        return value
      end
    end
  end
end

return M
