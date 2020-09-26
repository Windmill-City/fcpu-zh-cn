local hdlbuilder
local assert
local io


local function vector_scalar_op(operand)
  return function(_, ics)
    if operand then
      assert.one(_)
    else
      assert.two(_)
      assert.type(_[2], {'value', 'register', 'input'})
    end

    if ics and ics.out then
      local src = operand or io.getcount(_[2])

      local control = ics.out.get_or_create_control_behavior()
      local params = control.parameters
      params.parameters.second_constant = src
      control.parameters = params
    end
  end
end

local opcodes_vx = {
-- S: Signal
-- T: signal type
-- V: signal value, same as C
-- C: integer constant, same as V
-- M: memory
-- I: input wire (Red, Green)
-- O: output wire
-- A: instruction address
-- L: instruction label

  xwait = function(_, ics)
    return {type='xwait'}
  end,

  xmov = function(_, ics)
  end,

  xadd = vector_scalar_op(),
  xsub = vector_scalar_op(),
  xmul = vector_scalar_op(),
  xdiv = vector_scalar_op(),
  xmod = vector_scalar_op(),
  xpow = vector_scalar_op(),
  xinc = vector_scalar_op(1),
  xdec = vector_scalar_op(1),

  xand = vector_scalar_op(),
  xor  = vector_scalar_op(),
  xxor = vector_scalar_op(),
  xsl  = vector_scalar_op(),
  xsr  = vector_scalar_op(),

  xmin = function(_, ics)
    assert.two(_)
    assert.type(_[1], {'register', 'output'})
    assert.type(_[2], {'memory', 'input'})

    local signals = io.memory_getchannel_signals(_[2])
    assert.check(signals ~= nil, "Input channel is unavailable")

    local m
    for _,v in ipairs(signals) do
      if v.signal.name and (not m or v.count < m.count) then
        m = v
      end
    end

    io.setsignal(_[1], m)
  end,
  xmax = function(_, ics)
    assert.two(_)
    assert.type(_[1], {'register', 'output'})
    assert.type(_[2], {'memory', 'input'})

    local signals = io.memory_getchannel_signals(_[2])
    assert.check(signals ~= nil, "Input channel is unavailable")

    local m
    for _,v in ipairs(signals) do
      if v.signal.name and (not m or v.count > m.count) then
        m = v
      end
    end

    io.setsignal(_[1], m)
  end,
  xavg = function(_, ics)
    assert.two(_)
    assert.type(_[1], {'register', 'output'})
    assert.type(_[2], {'memory', 'input'})

    local signals = io.memory_getchannel_signals(_[2])
    assert.check(signals ~= nil, "Input channel is unavailable")

    local s = 0
    local c = 0
    for _,v in ipairs(signals) do
      if v.signal.name then
        s = s + v.count
        c = c + 1
      end
    end

    if 0 < c then
      io.setcount(_[1], s / c)
    end
  end,
}


function opcodes_vx.bind(assert_, io_, hdlbuilder_)
  hdlbuilder = hdlbuilder_
  assert = assert_
  io = io_
end
return opcodes_vx
