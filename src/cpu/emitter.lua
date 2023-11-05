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

function Emitter.make_address(addr, is_ptr)
  Assert.check(addr ~= nil)
  return { type = 'address', addr = tonumber(addr), pointer = is_ptr }
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

function Emitter.make_register(name, address)
  return { type = 'register', location = name, addr = address.addr, pointer = address.pointer }
end

function Emitter.make_register_ro(addr)
  return { type = 'register', location = 'readonly', addr = tonumber(addr), pointer = false }
end

function Emitter.make_memory(name, index, addr, is_ptr)
  return { type = 'memory', location = name, addr = tonumber(addr), pointer = is_ptr, index = tonumber(index) }
end

function Emitter.make_wire(name, address)
  return { type = 'wire', color = name, addr = address.addr, pointer = address.pointer}
end


return Emitter
