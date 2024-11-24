local dynamic_value = require 'nvim-conf.dynamic_value'

local M = {}

---@class Config
---@field global_config table
---@field workspace_config table
local Config = {}
Config.__index = Config

function Config.new()
  local self = setmetatable({}, Config)
  self.global_config = {}
  self.workspace_config = {}
  return self
end

function Config.set_global(self, config)
  self.global_config = config
end

function Config.set_workspace(self, config)
  self.workspace_config = config
end

---@param ctx Context
---@param configs table<table>
---@param literal_only boolean
local function resolve_merge(ctx, path, configs, literal_only)
  local resolved = {}
  for _, config in ipairs(configs) do
    if dynamic_value.is_dynamic_value(config) then
      if not literal_only then
        local ok, res = config:safe_resolve(ctx)
        if not ok then
          print(
            string.format(
              'warn: error while resolving config at `%s`: %s',
              path,
              res
            )
          )
        end
        table.insert(resolved, res)
      end
    else
      table.insert(resolved, config)
    end
  end

  local result = nil
  for _, config in ipairs(resolved) do
    if type(config) ~= 'table' then
      result = config
    end
  end
  if result ~= nil then
    return result
  end

  local keys = {}
  for _, config in ipairs(resolved) do
    assert(
      type(config) == 'table',
      'config must be a table, got ' .. type(config)
    )
    for key, _ in pairs(config) do
      table.insert(keys, key)
    end
  end

  result = {}
  for _, key in ipairs(keys) do
    local sub_configs = {}
    for _, config in ipairs(resolved) do
      table.insert(sub_configs, config[key])
    end
    result[key] = resolve_merge(
      ctx,
      path == '' and key or path .. '.' .. key,
      sub_configs,
      literal_only
    )
  end

  return result
end

function Config.resolve(self, ctx, literal_only)
  return resolve_merge(
    ctx,
    '',
    { self.global_config, self.workspace_config },
    literal_only
  )
end

M.Config = Config

return M
