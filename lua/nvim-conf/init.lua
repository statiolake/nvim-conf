local M = {}

M.Config = require('nvim-conf.config').Config
M.Context = require('nvim-conf.context').Context
M.DynamicValue = require('nvim-conf.dynamic_value').DynamicValue

local config = M.Config.new()
local is_workspace_config_loaded = false

-- Function to load workspace configuration and merge it with default
local function force_reload_workspace_config()
  local workspace_config_path = vim.fn.getcwd() .. '/.vim/conf.lua'
  if vim.fn.filereadable(workspace_config_path) == 1 then
    local content = table.concat(vim.fn.readfile(workspace_config_path), '\n')
    local ok, workspace_config =
      pcall(require('nvim-conf.safe_loader').safe_load, content)
    if not ok then
      print('error while loading workspace configuration:', workspace_config)
      workspace_config = {}
    end

    config:set_workspace(workspace_config)
  end
end

function M.set_defaults(opts)
  config:set_global(opts)
end

---Recursion count of get() call to handle nested configuration. Recursion
---usually occurs when get() is called within the function value of
---M.function_value().
local recursion_level = 0

---get configuration
---@param ctx? Context
function M.get(ctx)
  recursion_level = recursion_level + 1

  -- It should never reach here, because the get() of second level must be
  -- literal-only, so it shouldn't evaluate any function value.
  assert(
    recursion_level <= 2,
    string.format(
      'too deep recursion (%s) in nvim-conf.get(); this is a bug of nvim-conf',
      recursion_level
    )
  )

  -- The second level of get() resolves values in literal-only manner so that
  -- it doesn't cause an infinite recursion.
  local literal_only = recursion_level >= 2

  if not is_workspace_config_loaded then
    force_reload_workspace_config()
    is_workspace_config_loaded = true
  end

  if not ctx then
    ctx = M.Context.new()
  end

  local res = config:resolve(ctx, literal_only)

  recursion_level = recursion_level - 1

  return res
end

function M.contextual_value(fn)
  return M.DynamicValue.new(function(ctx)
    return fn(ctx)
  end)
end

function M.lazy_value(fn)
  return M.DynamicValue.new(function(_)
    return fn()
  end)
end

function M.per_filetype_value(filetype_opt_map)
  return M.DynamicValue.new(function(ctx)
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
  end)
end

return M
