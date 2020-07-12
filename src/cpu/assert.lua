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

function assert.check(b, ...)
  if not b then
    if #... then
      exception(...)
    else
      exception('condition not ')
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
  end
  exception("Expecting 1st parameter to be a "..(table.concat(valid, ' or ')))
end

function assert.is_register(_)
  if _.type ~= "register" then
    exception("Expecting 1st parameter to be a register")
  end
end

function assert.is_reg_or_val(_)
  if _.type ~= "register" and _.type ~= 'value' then
    exception("Expecting 1st parameter to be an integer or register")
  end
end

function assert.is_input_or_reg_or_val(_)
  if not ((_.type == "register" and _.location == 'readonly') or _.type == 'value') then
    exception("Expecting 1st parameter to be an integer or memory register")
  end
end

function assert.reg_or_val(_)
  if not ((_.type == "register" and _.location == 'readonly') or _.type == 'value') then
    exception("Expecting 1st parameter to be an integer or memory register")
  end
end

function assert.in_mem_or_val_or_label(_)
  if not ((_.type == "register" and _.location == 'readonly') or _.type == 'value' or _.type == "label") then
    exception("Expecting 1st parameter to be an integer, memory register or label")
  end
end

function assert.out_mem(_)
  if _.type ~= "register" or _.location ~= 'readonly' then
    exception("Expecting 2nd parameter to be a memory register")
  end
end

function assert.out_register(_)
  if _.type ~= "register" then
    exception("Expecting 2nd parameter to be a memory or output register")
  end
end

function assert.out_mem_or_val(_)
  if not ((_.type == "register" and _.location == 'readonly') or _.type == 'value') then
    exception("Expecting 2nd parameter to be an integer or memory register")
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


function assert.bind()
end
return assert
