function signalToStr(signal)
  local type = signal.type == 'virtual' and 'virtual-signal' or signal.type or 'item';
  return '['.. type ..'='.. signal.name ..']'
end

function hashSignalType(signalType)
  return signalType and (signalType.type or 'item') ..'='.. signalType.name
end

local function signalToSlot(signal)
  local t, n
  if not signal.signal.name then
    local str = signal.signal
    local i, j = string.find(str, '/')
    if i and j then
      t = string.sub(str, 1, i - 1)
      n = string.sub(str, j + 1)
    end
  end
  t = t or signal.signal.type or 'item'
  n = n or signal.signal.name

  return {
    value = {
      type = t,
      name = n,
      comparator = '=',
      quality = 'normal'
    },
    min = signal.count
  }
end

function get_ctrl_signals_limit(control)
  if MC_FACTORIO2 then
    --return control.sections[1].filters_count
    return MC_OUTPUT
  else
    return control.signals_count
  end
end

function get_ctrl_signals_count(control)
  if MC_FACTORIO2 then
    assert(control.type == defines.control_behavior.type.constant_combinator)
    return MC_OUTPUT
    --return control.sections[1].filters_count
  else
    return control.signals_count
  end
end

function get_ctrl_slot_signal(control, index)
  if MC_FACTORIO2 then
    assert(control.type == defines.control_behavior.type.constant_combinator)
    local slot = control.sections[1].get_slot(index)
    local signal = slot.value and { signal = slot.value.type ..'/'.. slot.value.name, count = slot.min or 0 } or { count = 0}
    return signal
  else
    return control.get_signal(index)
  end
end

function set_ctrl_slot_signal(control, index, signal)
  if MC_FACTORIO2 then
    assert(control.type == defines.control_behavior.type.constant_combinator)
    if signal then
      local slot = signalToSlot(signal)
      control.sections[1].set_slot(index, slot)
    else
      control.sections[1].clear_slot(index)
    end
  else
    control.set_signal(index, signal)
  end
end
