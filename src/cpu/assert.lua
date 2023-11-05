local Assert = {}


--- Throws an exception, the exception has a control character prepended to that
--- we can substring the message to only display the error message and not the stack-trace
--- to the user.
local function exception(e)
  error('@'..e, 2)
end

-- Assertion Helper Functions
function Assert.exception(...)
  exception(...)
end

function Assert.deprecated(since_ver, ...)
  -- TODO: implement non fatal warning show to user
end

function Assert.todo(msg)
  exception("NOT IMPLEMENTED".. (msg and (': '..msg) or ''))
end

function Assert.check(b, ...)
  if not b then
    if ... and 0 < #... then
      exception(...)
    else
      error('Assertion failed: condition not met', 2)
    end
  end
end

function Assert.one(_)
  if #_ ~= 1 then
    exception("Expecting one parameter after opcode")
  end
end

function Assert.two(_)
  if #_ ~= 2 then
    exception("Expecting two parameters after opcode")
  end
end

function Assert.one_or_two(_)
  if #_ < 1 then
    exception("Expecting at least one parameters after opcode")
  end
  if 2 < #_ then
    exception("Expecting no more than two parameters after opcode")
  end
  return #_
end

function Assert.two_or_three(_)
  if #_ ~= 2 and #_ ~= 3 then
    exception("Expecting two or three parameters after opcode")
  end
  return #_
end

function Assert.two_or_more(_)
  if #_ < 2 then
    exception("Expecting at least two parameters after opcode")
  end
  return #_
end

function Assert.three(_)
  if #_ ~= 3 then
    exception("Expecting three parameters after opcode")
  end
end

function Assert.three_or_four(_)
  if #_ ~= 3 and #_ ~= 4 then
    exception("Expecting three or four parameters after opcode")
  end
  return #_
end

function Assert.type(_, valid)
  -- wire, register, memory
  for i,v in ipairs(valid) do
    if _.type == v then
      return
    end
    if v == 'input' then
      -- Allow reading from output scalar buffer:
      if _.type == 'wire' and _.color ~= nil then
      -- Block reading from output scalar buffer:
      --if _.type == 'wire' and (_.color == 'red' or _.color == 'green') then
        return
      end
    elseif v == 'output' then
      if _.type == 'wire' and _.color == 'out' then
        return
      elseif _.type == 'output' then
        Assert.todo()
        return
      end
    elseif v == 'register' and _.type == 'memory' and _.addr ~= nil then
      return
    end
  end
  exception("Expecting parameter to be a "..(table.concat(valid, ' or ')))
end

function Assert.is_reference(...)
  for _,v in ipairs(table.pack(...)) do
    if not (v.type == 'register' and v.addr ~= nil) then
      if not (v.type == 'memory' and v.addr ~= nil) then
        --if not (v.type == 'channel' and v.addr ~= nil) then
          if not (v.type == "reference") then
            exception("Expecting parameter to be a reference")
          end
        --end
      end
    end
  end
end

function Assert.is_memory_bank(...)
  for _,v in ipairs(table.pack(...)) do
    if not (v.type == 'memory' and v.bank ~= nil and v.addr == nil) then
      exception("Expecting parameter to be a memory bank")
    end
  end
end

function Assert.is_channel_readable(...)
  for _,v in ipairs(table.pack(...)) do
    if not (v.type == 'memory' and v.bank ~= nil and v.addr == nil) then
      if not (v.type == 'wire' and (v.color == 'red' or v.color == 'green')) then
        --if not (v.type == 'channel' and v.addr == nil) then
          exception("Expecting parameter to be a memory or input wire")
        --end
      end
    end
  end
end

function Assert.is_channel_writable(...)
  for _,v in ipairs(table.pack(...)) do
    if not (v.type == 'memory' and v.bank ~= nil and v.addr == nil) then
      if not (v.type == 'wire' and v.color == 'out') then
        --if not (v.type == 'channel' and v.addr == nil) then
          exception("Expecting parameter to be a memory or output")
        --end
      end
    end
  end
end

function Assert.regs_index_range(index, max)
  if index == nil then
    exception("No register address specified.")
  end
  if index < 1 or index > max then
    exception("Invalid regs address: "..index..". Out of range.")
  end
end

function Assert.memory_index_range(index, max)
  if index == nil then
    exception("No memory address specified.")
  end
  if index < 1 or index > max then
    exception("Invalid memory address: "..index..". Out of range.")
  end
end


function Assert.result_signal(reg, signal)
  return
    (signal.count == nil or reg.count == signal.count) and
    (signal.signal == nil or
      (signal.signal.type == nil or reg.signal.type == signal.signal.type) and
      (signal.signal.name == nil or reg.signal.name == signal.signal.name)
    )
end

return Assert
