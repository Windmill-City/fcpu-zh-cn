local assert = {}


--- Throws an exception, the exception has a control character prepended to that
--- we can substring the message to only display the error message and not the stack-trace
--- to the user.
local function exception(e)
  error('@'..e, 2)
end

-- Assertion Helper Functions
function assert.exception(...)
  exception(...)
end

function assert.deprecated(since_ver, ...)
  -- TODO: implement non fatal warning show to user
end

function assert.todo(msg)
  exception("NOT IMPLEMENTED".. (msg and (': '..msg) or ''))
end

function assert.check(b, ...)
  if not b then
    if ... and 0 < #... then
      exception(...)
    else
      error('Assertion failed: condition not met', 3)
    end
  end
end

function assert.one(_)
  if #_ ~= 1 then
    exception("Expecting one parameter after opcode")
  end
end

function assert.two(_)
  if #_ ~= 2 then
    exception("Expecting two parameters after opcode")
  end
end

function assert.two_or_more(_)
  if #_ < 2 then
    exception("Expecting at least two parameters after opcode")
  end
end

function assert.three(_)
  if #_ ~= 3 then
    exception("Expecting three parameters after opcode")
  end
end

function assert.type(_, valid)
  -- wire, register, memory
  for i,v in ipairs(valid) do
    if _.type == v then
      return
    end
    if v == 'input' then
      if _.type == 'wire' and _.color ~= nil then
        return
      end
    elseif v == 'output' then
      if _.type == 'wire' and _.color == 'out' then
        return
      elseif _.type == 'output' then
        assert.todo()
        return
      end
    elseif v == 'register' and _.type == 'memory' and _.addr ~= nil then
      return
    end
  end
  exception("Expecting parameter to be a "..(table.concat(valid, ' or ')))
end

function assert.is_register(...)
  for _,v in ipairs(...) do
    if v.type ~= "register" then
      if not (v.type == 'memory' and v.addr ~= nil) then
        exception("Expecting parameter to be a register")
      end
    end
  end
end

function assert.is_memory(...)
  for _,v in ipairs(...) do
    if v.type ~= "memory" or v.index == nil or v.addr ~= nil then
      exception("Expecting parameter to be a memory")
    end
  end
end

function assert.regs_index_range(index, max)
  if index == nil then
    exception("No register address specified.")
  end
  if index < 1 or index > max then
    exception("Invalid regs address: "..index..". Out of range.")
  end
end

function assert.memory_index_range(index, max)
  if index == nil then
    exception("No memory address specified.")
  end
  if index < 1 or index > max then
    exception("Invalid memory address: "..index..". Out of range.")
  end
end


function assert.result_signal(reg, signal)
  return
    (signal.count == nil or reg.count == signal.count) and
    (signal.signal == nil or
      (signal.signal.type == nil or reg.signal.type == signal.signal.type) and
      (signal.signal.name == nil or reg.signal.name == signal.signal.name)
    )
end

function assert.bind()
end
return assert
