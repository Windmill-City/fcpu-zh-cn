local Assert = {}


--- Throws an exception, the exception has a control character prepended to that
--- we can substring the message to only display the error message and not the stack-trace
--- to the user.
local function exception(e)
  error(e, 2)
end

local function expecting(address, msg)
  error(Errors.ExpectingGot(msg, address.type or 'nil'), 2)
end

-- Assertion Helper Functions
function Assert.exception(...)
  exception(...)
end

function Assert.deprecated(since_ver, ...)
  -- TODO: implement non fatal warning show to user
end

function Assert.todo(msg)
  exception(Errors.NotImplemented(msg and (': '..msg) or ''))
end

---@param b boolean
---@param ... function | string
function Assert.check(b, ...)
  if not b then
    local pk = table.pack(...)
    if type(pk[1]) == 'function' then
      local fn = table.remove(pk, 1)
      local loc = fn(table.unpack(pk))
      exception(loc)
    elseif ... and 0 < #... then
      exception(...)
    else
      error(Errors.ConditionNotMet(), 2)
    end
  end
end

---@param modname string
function Assert.mod_enabled(modname)
  if not script.active_mods[modname] then
    exception(Errors.OpcodeUnavailable(modname))
  end
end

---@param _ OpRef
function Assert.one(_)
  if #_ ~= 1 then
    exception(Errors.Expecting_1())
  end
end

---@param _ OpRef
function Assert.two(_)
  if #_ ~= 2 then
    exception(Errors.Expecting_2())
  end
end

---@param _ OpRef
---@return number?
function Assert.one_or_two(_)
  if #_ < 1 then
    exception(Errors.Expecting_ge1())
  end
  if 2 < #_ then
    exception(Errors.Expecting_lt2())
  end
  return #_
end

---@param _ OpRef
---@return number?
function Assert.two_or_three(_)
  if #_ ~= 2 and #_ ~= 3 then
    exception(Errors.Expecting_2or3())
  end
  return #_
end

---@param _ OpRef
---@return number?
function Assert.two_or_more(_)
  if #_ < 2 then
    exception(Errors.Expecting_ge2())
  end
  return #_
end

---@param _ OpRef
function Assert.three(_)
  if #_ ~= 3 then
    exception(Errors.Expecting_3())
  end
end

---@param _ OpRef
---@return number?
function Assert.three_or_four(_)
  if #_ ~= 3 and #_ ~= 4 then
    exception(Errors.Expecting_3or4())
  end
  return #_
end

---@param _ OpRef
---@param valid OpRefType[]
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
      if _.type == 'lognet' then
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
    elseif v == 'signal' and (_.signal == nil and _.type == nil and _.count == 0 or _.signal ~= nil and _.count ~= nil) then
      return
    end
  end
  expecting(_, "parameter to be a "..(table.concat(valid, ' or ')))
end

---@param ... OpRef
function Assert.is_reference(...)
  for _,v in ipairs(table.pack(...)) do
    if not (v.type == 'register' and v.addr ~= nil) then
      if not (v.type == 'memory' and v.addr ~= nil) then
        --if not (v.type == 'channel' and v.addr ~= nil) then
          if not (v.type == "reference") then
            expecting(v, "parameter to be a reference")
          end
        --end
      end
    end
  end
end

---@param ... OpRef_MemoryBank
function Assert.with_memory_bank(...)
  for _,v in ipairs(table.pack(...)) do
    if not (v.bank ~= nil and v.type == 'memory') then
      expecting(v, "parameter with memory bank")
    end
  end
end

---@param ... OpRef
function Assert.is_memory_bank(...)
  for _,v in ipairs(table.pack(...)) do
    if not (v.addr == nil and v.bank ~= nil and v.type == 'memory') then
      expecting(v, "parameter to be a memory bank")
    end
  end
end

---@param ... OpRef_Channel
function Assert.is_channel_readable(...)
  for _,v in ipairs(table.pack(...)) do
    if not (v.type == 'memory' and v.bank ~= nil and v.addr == nil) then -- is_memory_bank
      if not (v.type == 'wire' and (v.color == 'red' or v.color == 'green')) then -- is_input_wire
        if not (v.type == 'channel' and v.addr == nil and (v.channel == 'lognet')) then
          expecting(v, "parameter to be an input wire or memory or lognet")
        end
      end
    end
  end
end

---@param ... OpRef_Channel
function Assert.is_channel_writable(...)
  for _,v in ipairs(table.pack(...)) do
    if not (v.type == 'memory' and v.bank ~= nil and v.addr == nil) then
      if not (v.type == 'wire' and v.color == 'out') then
        --if not (v.type == 'channel' and v.addr == nil) then
          expecting(v, "parameter to be a memory or output")
        --end
      end
    end
  end
end

function Assert.check_range(index, max, name)
  if index == nil then
    exception(Errors.NoAddress(name))
  end
  if index < 1 or index > max then
    exception(Errors.InvalidAddress(name, index, max))
  end
end


--[[function Assert.result_signal(reg, signal)
  return
    (signal.count == nil or reg.count == signal.count) and
    (signal.signal == nil or
      (signal.signal.type == nil or reg.signal.type == signal.signal.type) and
      (signal.signal.name == nil or reg.signal.name == signal.signal.name)
    )
end--[[]]

return Assert
