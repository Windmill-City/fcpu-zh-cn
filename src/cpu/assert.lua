local exception
local assert = {}


-- Assertion Helper Functions
function assert.exception(...)
  exception(...)
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

function assert.in_register(_)
  if _.type ~= "register" then
    exception("Expecting 1st parameter to be a memory or output register")
  end
end

function assert.in_mem(_)
  if _.type ~= "register" or _.location ~= "mem" then
    exception("Expecting 1st parameter to be a memory register")
  end
end

function assert.in_register_or_wire(_)
  if not (_.type == "register" or _.type == "wire") then
    exception("Expecting 1st parameter to be a register or wire input")
  end
end

function assert.in_mem_or_val(_)
  if not ((_.type == "register" and _.location == "mem") or _.type == "num") then
    exception("Expecting 1st parameter to be an integer or memory register")
  end
end

function assert.in_mem_or_val_or_label(_)
  if not ((_.type == "register" and _.location == "mem") or _.type == "num" or _.type == "label") then
    exception("Expecting 1st parameter to be an integer, memory register or label")
  end
end

function assert.in_wire(_)
  if _.type ~= "wire" then
    exception("Expecting 1st parameter to be a wire input")
  end
end

function assert.out_mem(_)
  if _.type ~= "register" or _.location ~= "mem" then
    exception("Expecting 2nd parameter to be a memory register")
  end
end

function assert.out_register(_)
  if _.type ~= "register" then
    exception("Expecting 2nd parameter to be a memory or output register")
  end
end

function assert.out_mem_or_val(_)
  if not ((_.type == "register" and _.location == "mem") or _.type == "num") then
    exception("Expecting 2nd parameter to be an integer or memory register")
  end
end

function assert.memory_index_range(index, max)
  if index == nil then
    exception("No register address specified.")
  end
  if index < 1 or index > max then
    exception("Invalid memory address: "..index..". Out of range.")
  end
end


function assert.bind(exception_)
  exception = exception_
end
return assert
