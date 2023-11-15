local Emitter = {}


-- Makers
function Emitter.make_comment()
  return { type = 'nop', name = 'comment' }
end

function Emitter.make_label(label)
  return { type = 'label', label = label }
end

function Emitter.make_value(numstr)
  local number = tonumber(numstr)
  if number == nil then
    Assert.exception("Can't parse number '".. numstr .."'")
  end
  return { type = 'value', count = number }
end

function Emitter.make_string(str)
  return { type = 'string', str = str }
end

function Emitter.make_signal(signal_id, countstr)
  if countstr == '' then
    return { type = 'type', signal = signal_id }
  else
    local count = tonumber(countstr)
    if count == nil then
      Assert.exception("Can't parse count '".. (countstr or 'nil') .."'")
    end
    return { type = 'signal', signal = signal_id, count = count or 0 }
  end
end

function Emitter.make_special_register_ro(addr)
  return { type = 'register', special = true, addr = tonumber(addr), pointer = false }
end

function Emitter.make_reference(addr, is_ptr)
  Assert.check(addr ~= nil)
  return { type = 'reference', addr = tonumber(addr), pointer = is_ptr }
end

function Emitter.make_register(name, ref) -- +[reference]
  return { type = 'register', addr = ref.addr, pointer = ref.pointer }
end

--function Emitter.make_channel(name, ref) -- +[reference]
--  return { type = 'channel', channel = name, addr = ref.addr, pointer = ref.pointer }
--end

function Emitter.make_memory(name, bank, ref) -- +[memory_bank, reference]
  return { type = 'memory', channel = name..bank, bank = tonumber(bank), addr = ref.addr, pointer = ref.pointer }
end

function Emitter.make_memory_bank(name, bank) -- +[channel]
  return { type = 'memory', channel = name..bank, bank = tonumber(bank) }
end

function Emitter.make_channel(channel)
  return { type = 'memory', channel = channel }
end

function Emitter.make_wire(name, ref)
  return { type = 'wire', color = name, addr = ref.addr, pointer = ref.pointer}
end


return Emitter
