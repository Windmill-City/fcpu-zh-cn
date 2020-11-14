local assert
local emitter = {}


-- Makers
function emitter.make_label(label)
  return { type = 'label', label = label }
end

function emitter.make_value(numstr)
  local number = tonumber(numstr)
  if number == nil then
    assert.exception("Can't parse number '".. numstr .."'")
  end
  return { type = 'value', count = number }
end

function emitter.make_string(str)
  return { type = 'string', str = str }
end

function emitter.make_address(addr, is_ptr)
  assert.check(addr ~= nil)
  return { type = 'address', addr = tonumber(addr), pointer = is_ptr }
end

function emitter.make_signal(signal_id, countstr)
  if countstr == '' then
    return { type = 'type', signal = signal_id }
  else
    local count = tonumber(countstr)
    if count == nil then
      assert.exception("Can't parse count '".. (countstr or 'nil') .."'")
    end
    return { type = 'signal', signal = signal_id, count = count or 0 }
  end
end

function emitter.make_register(name, address)
  return { type = 'register', location = name, addr = address.addr, pointer = address.pointer }
end

function emitter.make_register_ro(addr)
  return { type = 'register', location = 'readonly', addr = tonumber(addr), pointer = false }
end

function emitter.make_memory(name, index, addr, is_ptr)
  return { type = 'memory', location = name, index = tonumber(index), addr = tonumber(addr), pointer = is_ptr }
end

function emitter.make_wire(name, address)
  return { type = 'wire', color = name, addr = address.addr, pointer = address.pointer}
end


function emitter.bind(assert_)
    assert = assert_
end
return emitter
