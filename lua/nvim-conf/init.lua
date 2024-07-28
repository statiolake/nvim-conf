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

local function resolve_config_on_context(ctx, config, literal_only)
  local result = {}
  for key, value in pairs(config) do
    if type(value) == 'table' then
      result[key] = resolve_config_on_context(ctx, value, literal_only)
    elseif not literal_only and type(value) == 'function' then
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

local recursion_level = 0
---get configuration
---@param ctx? Context
function M.get(ctx)
  recursion_level = recursion_level + 1

  if recursion_level > 2 then
    error 'too many levels of recursion in nvim-conf.get(); this is a bug of nvim-conf'
  end

  local literal_only = recursion_level >= 2

  if not cache then
    load()
  end

  if not ctx then
    ctx = M.Context.new()
  end
  ctx:populate_env()

  local config = cache
  local res = resolve_config_on_context(ctx, config, literal_only)

  recursion_level = recursion_level - 1

  return res
end

function M.function_value(fn)
  return function(_)
    return fn
  end
end

function M.lazy_value(fn)
  return function(_)
    return fn()
  end
end

function M.per_filetype_value(filetype_opt_map)
  return function(ctx)
    local priorities = {}
    local min_priority = 0

    for filetypes, value in pairs(filetype_opt_map) do
      filetypes = vim.split(filetypes, '[, ]')
      if table.concat(filetypes, ','):find(ctx.filetype) then
        min_priority = math.min(min_priority, -#filetypes - 1)
        table.insert(priorities, {
          priority = -#filetypes,
          value = value,
        })
      end
    end

    if filetype_opt_map['_'] then
      table.insert(priorities, {
        priority = min_priority,
        value = filetype_opt_map['_'],
      })
    end

    table.sort(priorities, function(a, b)
      return a.priority < b.priority
    end)

    local merged = nil
    for _, entry in ipairs(priorities) do
      if type(entry.value) == 'table' then
        if type(merged) ~= 'table' then
          merged = vim.deepcopy(entry.value)
        else
          merged = vim.tbl_deep_extend('force', merged, entry.value)
        end
      else
        merged = entry.value
      end
    end

    return merged
  end
end

return M
