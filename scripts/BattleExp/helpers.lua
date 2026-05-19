local DEBUG = true

local function log(msg, ...)
  if not DEBUG then return end

  local args = { ... }
  -- replace any nils with 'NIL!' so string.format doesn't choke
  for i = 1, select('#', ...) do
    if args[i] == nil then
      args[i] = 'NIL!'
    else
      args[i] = args[i]
    end
  end

  local ok, result = pcall(string.format, msg, table.unpack(args))
  if ok then
    print('[BattleExp] ' .. result)
  else
    -- fallback: just print all args as-is so a bad format never silently swallows a log line
    local parts = { tostring(msg) }
    for _, v in ipairs(args) do
      table.insert(parts, tostring(v))
    end
    print(table.unpack(parts))
  end
end

return { DEBUG = DEBUG, log = log }
