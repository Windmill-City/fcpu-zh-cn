function signalToStr(signal)
  local type = signal.type == 'virtual' and 'virtual-signal' or signal.type or 'item';
  local name = signal.name
  local quality = signal.quality
  if name and not quality then
    return '['.. type ..'='.. name .. ']'
  elseif name then
    return '['.. type ..'='.. name ..',quality='.. quality ..']'
  elseif quality then
    return '[quality='.. quality .. ']'
  end
  return '[quality=normal]'
end

function hash_FromSignalType(signalType)
  local q = signalType.quality and (signalType.quality ~= 'normal') and ','..signalType.quality or ''
  local hash = signalType and (signalType.type or 'item') ..'='.. signalType.name .. q
  return hash
end

function hash_ToSignalType(hash)
  local t, n, q = string.match(hash, '(%a+)=([%a%d%-_:]+),?([%a]*)')
  local signalType = { type = t, name = n, quality = (q ~= '' and q or nil) }
  return signalType;
end

---@return LogisticFilter
local function signalToSlot(signal)
  local t, n, q
  if type(signal.signal) == 'string' then
    local str = signal.signal
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

function get_ctrl_signals_limit(control)
  return MC_OUTPUT
  --return control.sections[1].filters_count
end

function get_ctrl_signals_count(control)
  --assert(control.type == defines.control_behavior.type.constant_combinator)
  return MC_OUTPUT
  --return control.sections[1].filters_count
end

function get_ctrl_slot_signal(control, index)
  --assert(control.type == defines.control_behavior.type.constant_combinator)
  local slot = control.sections[1].get_slot(index)
  local signal = slot.value and { signal = slot.value.type ..'/'.. slot.value.name, count = slot.min or 0 } or { count = 0}
  return signal
end

function set_ctrl_slot_signal(control, index, signal)
  --assert(control.type == defines.control_behavior.type.constant_combinator)
  if signal then
    local slot = signalToSlot(signal)
    control.sections[1].set_slot(index, slot)
  else
    control.sections[1].clear_slot(index)
  end
end
