local io


local function vector_scalar_op()
  return function(_, ics)
    local src = (#_ == 3 and _[3]) or _[2]

    if ics and ics.out then
      local control = ics.out.get_or_create_control_behavior()
      local params = control.parameters
      params.second_constant = io.getvalue(src, {'value', 'register', 'input'})
      control.parameters = params
    end
  end
end

local function vector_compare_op()
  return function(_, ics)
    local src = (#_ == 3 and _[3]) or _[2]

    if ics and ics.out then
      local control = ics.out.get_or_create_control_behavior()
      local params = control.parameters
      params.constant = io.getvalue(src, {'value', 'register', 'input'})
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

  xmov = function(_, ics)end,
  xuni = function(_, ics)end,
  xflt = function(_, ics)end,

  xadd = vector_scalar_op(),
  xsub = vector_scalar_op(),
  xmul = vector_scalar_op(),
  xdiv = vector_scalar_op(),
  xmod = vector_scalar_op(),
  xpow = vector_scalar_op(),

  xand = vector_scalar_op(),
  xor  = vector_scalar_op(),
  xxor = vector_scalar_op(),
  xsl  = vector_scalar_op(),
  xsr  = vector_scalar_op(),

  xclt = vector_compare_op(),
  xcle = vector_compare_op(),
  xcne = vector_compare_op(),
  xceq = vector_compare_op(),
  xcge = vector_compare_op(),
  xcgt = vector_compare_op(),

  xmin = function(_, ics)
    Assert.two(_)
    Assert.type(_[1], {'register', 'output'})
    Assert.type(_[2], {'memory', 'input'})

    local signals = io.memory_getchannel_signals(_[2])
    Assert.check(signals ~= nil, "Input channel is unavailable")

    local m
    for _,v in ipairs(signals) do
      if v.signal.name and (not m or v.count < m.count) then
        m = v
      end
    end

    io.setsignal(_[1], m or NULL_SIGNAL)
  end,
  xmax = function(_, ics)
    Assert.two(_)
    Assert.type(_[1], {'register', 'output'})
    Assert.type(_[2], {'memory', 'input'})

    local signals = io.memory_getchannel_signals(_[2])
    Assert.check(signals ~= nil, "Input channel is unavailable")

    local m
    for _,v in ipairs(signals) do
      if v.signal.name and (not m or v.count > m.count) then
        m = v
      end
    end

    io.setsignal(_[1], m or NULL_SIGNAL)
  end,
  xavg = function(_, ics)
    Assert.two(_)
    Assert.type(_[1], {'register', 'output'})
    Assert.type(_[2], {'memory', 'input'})

    local signals = io.memory_getchannel_signals(_[2])
    Assert.check(signals ~= nil, "Input channel is unavailable")

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

  xmini = function(_, ics)
    Assert.two(_)
    Assert.type(_[1], {'register', 'output'})
    Assert.type(_[2], {'memory', 'input'})

    local signals = io.memory_getchannel_signals(_[2])
    Assert.check(signals ~= nil, "Input channel is unavailable")

    local m, i
    for k,v in ipairs(signals) do
      if v.signal.name and (not m or v.count < m.count) then
        m = v
        i = k
      end
    end

    io.setcount(_[1], i)
  end,
  xmaxi = function(_, ics)
    Assert.two(_)
    Assert.type(_[1], {'register', 'output'})
    Assert.type(_[2], {'memory', 'input'})

    local signals = io.memory_getchannel_signals(_[2])
    Assert.check(signals ~= nil, "Input channel is unavailable")

    local m, i
    for k,v in ipairs(signals) do
      if v.signal.name and (not m or v.count > m.count) then
        m = v
        i = k
      end
    end

    io.setcount(_[1], i)
  end,
}


function opcodes_vx.setup(io_)
  io = io_
end
return opcodes_vx
