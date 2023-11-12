local Controller
local Emitter

local io = {}
local control
require('src/cpu/signals')
local ioRegister = require('src/cpu/io/register')
local ICStack = require('src/cpu/io/icstack')
local ioChannel = require('src/cpu/io/channel')
local ioMemory = require('src/cpu/io/memory')
local ioWire = require('src/cpu/io/wire')

State = require('src/cpu/io/state')
State.onBind(ioRegister.bind)
State.onBind(ICStack.bind)
State.onBind(ioChannel.bind)
State.onBind(ioMemory.bind)
State.onBind(ioWire.bind)

-- Some hacks
function io.for_entity(proc)
  return proc(State.current.entity, State.current)
end

function io.add_deferred(deffer)
  Controller.add_deferred(State.current, deffer)
end


-- Registers
io.register_get = ioRegister.get
io.register_set = ioRegister.set
io.register_set_count = ioRegister.set_count


-- ICs
io.get_node = ICStack.get_node
io.ics_set = ICStack.ics_set
io.get_node_ast = ICStack.get_node_ast
io.ics_each_ast = ICStack.ics_each_ast


-- Channel
io.memory_getchannel_read = ioChannel.read
io.memory_getchannel_write = ioChannel.write
io.channel_address_of = ioChannel.address_of
io.memory_getchannel_signals = ioChannel.signals


-- Memory
io.memory_get = ioMemory.get
io.memory_set = ioMemory.set
io.memory_clear = ioMemory.clear
io.memory_address_of = ioMemory.address_of
io.memory_size = ioMemory.size


-- General wire manipulation
io.wire_get = ioWire.get
io.wire_set = ioWire.set
io.wire_find_signal = ioWire.find_signal
io.wire_count = ioWire.count


-- Control output
function io.control_get()
  local params = control.indication.parameters
  local count = params.first_constant
  local signal_id = params.output_signal
  return Emitter.make_signal(signal_id, count)
end

function io.control_set(signal)
  local params = control.indication.parameters
  params.first_constant = signal.count
  params.output_signal = signal.signal
  control.indication.parameters = params
end


-- Output wire access
function io.output_clear()
  -- Output buffer
  control.output.parameters = nil
  ioChannel.GuiCache_Invalidate('output', 0)

  -- Vector output
  local ast = io.get_node_ast('output')
  if ast and ast.deffer and ast.deffer.clr then
    return { type = 'deffer', deffer = ast.deffer.clr }
  end
end


-- Multiplex Helper Functions
function io.getsignal(_, types)
  if not types then
    types = {'signal', 'register', 'wire'}
  end
  Assert.type(_, types)
  local signal = nil
  if _.type == 'wire' or _.type == 'input' then
    signal = io.wire_get(_)
  elseif _.type == 'register' then
    signal = io.register_get(_)
  elseif _.type == 'memory' then
    signal = io.memory_get(_)
  elseif _.type == 'signal' or _.type == 'type' or _.type == 'value' then
    signal = _
  elseif _.type == 'string' then
    Assert.exception('not supported yet')
  else
    Assert.exception('trying to retrieve nil signal')
  end
  return signal
end

function io.setsignal(_, signal, types)
  if not types then
    types = {'register', 'wire'}
  end
  Assert.type(_, types)
  if _.type == 'wire' then
    io.wire_set(_, signal)
  elseif _.type == 'register' then
    io.register_set(_, signal)
  elseif _.type == 'memory' then
    io.memory_set(_, signal)
    --Assert.exception('Memory cell could not be changed. Not supported yet.')
  elseif _.type == 'output' then
    Assert.todo()
  else
    Assert.exception('unhandled')
  end
end


function io.getvalue(_, types)
  if _.type == 'value' then
    local t = types and Assert.type(_, types)
    return _.count
  elseif _.type == 'string' then
    local t = types and Assert.type(_, types)
    return _.str
  else
    local signal = io.getsignal(_, types)
    if type(signal) == 'table' then
      local value = signal.str or signal.count
      if value then
        return value
      end
    end
    Assert.exception('trying to retrieve nil count')
  end
end

function io.setvalue(_, count, types)
  -- TODO: optimize
  local signal = io.getsignal(_, types)
  signal.str = nil
  signal.count = count
  io.setsignal(_, signal, types)
end


function io.gettype(_, types)
  local signal = io.getsignal(_, types)
  if type(signal) ~= 'table' or signal.signal == nil then
    Assert.exception('trying to retrieve nil type')
  end
---@diagnostic disable-next-line: need-check-nil
  return signal.signal
end

function io.settype(_, sigtype, types)
  -- TODO: optimize
  local signal = io.getsignal(_, types)
  signal.signal = sigtype
  io.setsignal(_, signal, types)
end


-- Setup and Binding to state
function io.bind(state_)
  control = State.current.cache.control
end

function io.setup(emitter_, controller_)
  Controller = controller_
  Emitter = emitter_

  ioRegister.setup(io)
  ioChannel.setup(ICStack)
  ioMemory.setup(Emitter, ioRegister, ioChannel)
  ioWire.setup(Emitter, ioRegister, ioChannel)
end

return io
