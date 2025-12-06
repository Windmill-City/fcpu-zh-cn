---@param signal_id SignalID
function signalToStr(signal_id)
  local type = signal_id.type == 'virtual' and 'virtual-signal' or signal_id.type or 'item';
  local name = signal_id.name
  local quality = signal_id.quality
  if name and not quality then
    return '['.. type ..'='.. name .. ']'
  elseif name then
    return '['.. type ..'='.. name ..',quality='.. quality ..']'
  elseif quality then
    return '[quality='.. quality .. ']'
  end
  return '[quality=normal]'
end

---@param signal_id SignalID
---@return string
function hash_FromSignalType(signal_id)
  local q = signal_id.quality and (signal_id.quality ~= 'normal') and ','..signal_id.quality or ''
  local hash = signal_id and (signal_id.type or 'item') ..'='.. signal_id.name .. q
  return hash
end

---@param hash string
---@return SignalID
function hash_ToSignalType(hash)
  local t, n, q = string.match(hash, '(%a+)=([%a%d%-_:]+),?([%a]*)')
  local signal_id = { type = t, name = n, quality = (q ~= '' and q or nil) }
  return signal_id;
end

---@param signal Signal
---@return LogisticFilter
local function signalToSlot(signal)
  local t, n, q
  if type(signal.signal) == 'string' then
    local str = signal.signal --[[@as string]]
    local i, j = string.find(str, '/', 1, true)
    if i and j then
      t = string.sub(str, 1, i - 1)
      n = string.sub(str, j + 1)
    end
    local k, l = string.find(str, ',', j + 1, true)
    if k and l then
      n = string.sub(str, j + 1, k - 1)
      q = string.sub(str, l + 1)
    end
  else
    t = signal.signal.type
    n = signal.signal.name
    q = signal.signal.quality
  end

  return {
    value = {
      type = t or 'item',
      name = n,
      comparator = '=',
      quality = q or 'normal'
    },
    min = signal.count
  }
end

---@param control LuaConstantCombinatorControlBehavior
function get_ctrl_signals_limit(control)
  return MC_OUTPUT
  --return control.sections[1].filters_count
end

---@param control LuaConstantCombinatorControlBehavior
function get_ctrl_signals_count(control)
  --assert(control.type == defines.control_behavior.type.constant_combinator)
  return MC_OUTPUT
  --return control.sections[1].filters_count
end

---@param control LuaConstantCombinatorControlBehavior
---@param index integer
---@return Signal
function get_ctrl_slot_signal(control, index)
  --assert(control.type == defines.control_behavior.type.constant_combinator)
  local slot = control.sections[1].get_slot(index)
  if not slot.value then
    return NULL_SIGNAL
  end
  ---@type SignalID
  local signal_id = slot.value.type ..'/'.. slot.value.name
  return { signal = signal_id, count = slot.min or 0 }
end

---@param control LuaConstantCombinatorControlBehavior
---@param index integer
---@param signal Signal?
function set_ctrl_slot_signal(control, index, signal)
  --assert(control.type == defines.control_behavior.type.constant_combinator)
  if signal then
    local slot = signalToSlot(signal)
    control.sections[1].set_slot(index, slot)
  else
    control.sections[1].clear_slot(index)
  end
end
