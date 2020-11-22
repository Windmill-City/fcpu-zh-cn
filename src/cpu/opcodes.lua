local assert
local io


local standard_op = function(_)
  assert.two(_)
  local _dst = _[1]
  assert.is_register(_dst)
  local _src = _[2]
  assert.type(_src, {'register', 'value', 'input'})
  return _dst, _src
end
local jump_op = function(addr, offset)
  assert.type(addr, {'label', 'value', 'register'})
  if offset then
    assert.type(offset, {'value', 'register'})
    offset = io.getcount(offset) or 0
  else
    offset = 0
  end
  if addr.type == 'label' then
    return { type = 'jump', val = offset, label = addr.label }
  else
    return { type = 'jump', val = io.getcount(addr) + offset }
  end
end

local test_mnemonic = function(condition)
  return function(_)
    assert.two(_)
    assert.type(_[1], {'value', 'input', 'register'})
    assert.type(_[2], {'value', 'input', 'register'})
    if not condition(_[1], _[2]) then
      return { type = 'skip' }
    end
  end
end
local branch_mnemonic = function(condition)
  return function(_)
    assert.three_or_four(_)
    assert.type(_[1], {'value', 'input', 'register'})
    assert.type(_[2], {'value', 'input', 'register'})
    if condition(_[1], _[2]) then
      return jump_op(_[3], _[4])
    end
  end
end

local find_in_wire = function(_, color)
  assert.two(_)
  local _dst = _[1]
  assert.type(_dst, {'register', 'output'})
  local _type = io.gettype(_[2], {'type', 'register', 'input'})
  local sig = io.wire_find_signal(color, _type)
  io.setsignal(_dst, sig)
end

local find_in_channel = function(_)
  assert.three(_)
  local _dst = _[1]
  assert.type(_dst, {'register', 'output'})
  local _chan = _[2]
  assert.type(_chan, {'input', 'memory'})
  local _type = io.gettype(_[3], {'type', 'register', 'input'})
  local control = io.memory_getchannel_read(_chan)
  local count = control.get_signal(_type)
  if count and count ~= 0 then
    io.setsignal(_dst, {signal = _type, count = count})
  else
    io.setsignal(_dst, NULL_SIGNAL)
  end
end

local index_in_channel = function(_)
  assert.three(_)
  local _dst = _[1]
  assert.type(_dst, {'register', 'output'})
  local _chan = _[2]
  assert.type(_chan, {'input', 'memory'})
  local _type = io.gettype(_[3], {'type', 'register', 'input'})
  local signals = io.memory_getchannel_signals(_chan)
  if signals then
    for k, v in ipairs(signals) do
      if v.signal and v.signal.name == _type.name and v.signal.type == _type.type then
        io.setsignal(_dst, {signal = _type, count = k})
        return
      end
    end
  end
  io.setsignal(_dst, NULL_SIGNAL)
end

local ics_clear = function(channel)
  local action = { type = 'deffer', deffer = {} }
  local DisableICS = function(ics)
    action.deffer[#action.deffer + 1] = {action='enable', ic=ics.clr, delay = 0}
    action.deffer[#action.deffer + 1] = {action='disable', ic=ics.clr, delay = 1}
  end
  io.ics_each(DisableICS, channel)
  return action
end

local opcodes = {
-- S: Signal
-- T: signal type
-- V: signal value, same as C
-- C: integer constant, same as V
-- M: memory
-- I: input wire (Red, Green)
-- O: output wire
-- A: instruction address
-- L: instruction label

  nop = function(_)
  end,

  clr = function(_)
    local actions = {}
    if 0 < #_ then
      for i, expr in ipairs(_) do
        if expr then
          assert.type(expr, {'register', 'memory', 'output'})
          if expr.type == 'register' then
            if expr.addr then
              io.register_set(expr, NULL_SIGNAL)
            else
              for i = 1, MC_REGS do
                io.register_set({type='register', addr=i, pointer=false}, NULL_SIGNAL)
              end
            end
          elseif expr.color == 'out' then
            if expr.addr == nil then
              actions[#actions + 1] = io.output_clear()
            else
              io.wire_set(expr, nil)
            end
          elseif expr.type == 'memory' then
            io.memory_clear(expr)
            actions[#actions + 1] = ics_clear(expr.index and (expr.location .. expr.index))
          end
        end
      end
    else
      for i = 1, MC_REGS do
        io.register_set({type='register', addr=i, pointer=false}, NULL_SIGNAL)
      end
      io.control_set(table.deep_copy(NULL_SIGNAL))
      io.memory_clear()
      actions[#actions + 1] = io.output_clear()
      actions[#actions + 1] = ics_clear()
    end
    -- TODO: implement return {type='actions', ...}
    if 0 < #actions then
      local d = {type='deffer', deffer={}}
      for _, a in ipairs(actions) do
        if a and a.deffer then
          for _, v in ipairs(a.deffer) do
            table.insert(d.deffer, v)
          end
        end
      end
      return d
    end
  end,

  mov = function(_) -- mov dst...[R/O] src[V/T/S/R/I]
    assert.two_or_more(_)
    local sig = io.getsignal(_[#_], {'value', 'type', 'signal', 'register', 'input'})
    for i = 1, #_ - 1 do
      io.setsignal(_[i], sig, {'register', 'wire'})
    end
  end,
  emit = function(_) -- emit dst[M] src...[V/T/S/R/I]
    assert.two_or_more(_)
    local dst = table.deep_copy(_[1])
    assert.is_memory_writable(dst)
    local signals = io.memory_getchannel_signals(dst)
    dst.addr = signals and #signals or 0
    for i = 2,#_ do
      local sig = io.getsignal(_[i], {'value', 'type', 'signal', 'register', 'input'})
      dst.addr = dst.addr + 1
      io.memory_set(dst, sig)
    end
  end,
  ssv = function(_) -- ssv dst...[R] val[V/S/R/I]
    assert.two_or_more(_)
    local sigcount = io.getcount(_[#_], {'value', 'signal', 'register', 'input'})
    for i = 1, #_ - 1 do
      io.setcount(_[i], sigcount, {'register', 'output'})
    end
  end,
  sst = function(_) -- sst dst...[R] type[T/S/R/I]
    assert.two_or_more(_)
    local sigtype = io.gettype(_[#_], {'type', 'signal', 'register', 'input'})
    for i = 1, #_ - 1 do
      io.settype(_[i], sigtype, {'register', 'output'})
    end
  end,

  fir = function(_) -- fir dst[R/O] type[T/R/I]
    find_in_wire(_, 'red')
  end,
  fig = function(_) -- fig dst[R/O] type[T/R/I]
    find_in_wire(_, 'green')
  end,

  fid = function(_) -- fid dst[R/O] mem[W/M] type[T/R/I]
    find_in_channel(_)
  end,
  idx = function(_) -- idx dst[R/O] mem[W/M] type[T/R/I]
    index_in_channel(_)
  end,

  swp = function(_) -- swp reg1[R] reg2[R]
    assert.two(_)
    assert.is_register(_[1], _[2])
    local a = io.getsignal(_[1], {'register'})
    local b = io.getsignal(_[2], {'register'})
    io.setsignal(_[1], b, {'register'})
    io.setsignal(_[2], a, {'register'})
  end,
  swpt = function(_) -- swpt reg1[R] reg2[R]
    assert.two(_)
    assert.is_register(_[1], _[2])
    local a = io.gettype(_[1], {'register'})
    local b = io.gettype(_[2], {'register'})
    io.settype(_[1], b, {'register'})
    io.settype(_[2], a, {'register'})
  end,
  swpv = function(_) -- swpv reg1[R] reg2[R]
    assert.two(_)
    assert.is_register(_[1], _[2])
    local a = io.getcount(_[1], {'register'})
    local b = io.getcount(_[2], {'register'})
    io.setcount(_[1], b, {'register'})
    io.setcount(_[2], a, {'register'})
  end,

  add = function(_)
    local _dst, _src = standard_op(_)
    io.register_set_count(_dst, io.getcount(_dst) + io.getcount(_src))
  end,
  sub = function(_)
    local _dst, _src = standard_op(_)
    io.register_set_count(_dst, io.getcount(_dst) - io.getcount(_src))
  end,
  mul = function(_)
    local _dst, _src = standard_op(_)
    io.register_set_count(_dst, io.getcount(_dst) * io.getcount(_src))
  end,
  div = function(_)
    local _dst, _src = standard_op(_)
    io.register_set_count(_dst, io.getcount(_dst) / io.getcount(_src))
  end,
  mod = function(_)
    local _dst, _src = standard_op(_)
    io.register_set_count(_dst, io.getcount(_dst) % io.getcount(_src))
  end,
  pow = function(_)
    local _dst, _src = standard_op(_)
    io.register_set_count(_dst, io.getcount(_dst) ^ io.getcount(_src))
  end,

  inc = function(_)
    assert.one(_)
    local _dst = _[1]
    assert.is_register(_dst)
    io.register_set_count(_dst, io.getcount(_dst) + 1)
  end,
  dec = function(_)
    assert.one(_)
    local _dst = _[1]
    assert.is_register(_dst)
    io.register_set_count(_dst, io.getcount(_dst) - 1)
  end,

  subi = function(_)
    local _dst, _src = standard_op(_)
    io.register_set_count(_dst, io.getcount(_src) - io.getcount(_dst))
  end,
  divi = function(_)
    local _dst, _src = standard_op(_)
    io.register_set_count(_dst, io.getcount(_src) / io.getcount(_dst))
  end,
  modi = function(_)
    local _dst, _src = standard_op(_)
    io.register_set_count(_dst, io.getcount(_src) % io.getcount(_dst))
  end,
  powi = function(_)
    local _dst, _src = standard_op(_)
    io.register_set_count(_dst, io.getcount(_src) ^ io.getcount(_dst))
  end,

  fract = function(_)
    assert.one(_)
    local r = io.getcount(_[1], {'register'})
    io.register_set_count(_[1], r - math.floor(r))
  end,
  floor = function(_)
    assert.one(_)
    local r = io.getcount(_[1], {'register'})
    io.register_set_count(_[1], math.floor(r))
  end,
  round = function(_)
    assert.one(_)
    local r = io.getcount(_[1], {'register'})
    io.register_set_count(_[1], math.floor(r + 0.5))
  end,
  ceil = function(_)
    assert.one(_)
    local r = io.getcount(_[1], {'register'})
    io.register_set_count(_[1], math.ceil(r))
  end,

  rnd = function(_) -- rnd dst[R/O] min[C/R/I] max[C/R/I]
    assert.three(_)
    local _dst = _[1]
    assert.is_register(_dst)
    local _min = _[2]
    local _max = _[3]
    assert.type(_min, {'register', 'value', 'input'})
    assert.type(_max, {'register', 'value', 'input'})
    local min = io.getcount(_min)
    local range  = io.getcount(_max) - min + 1
    assert.check(0 <= range, "Minimum limit should be less or queal than the maximum limit")
    local r = min + (math.random() * range)
    io.register_set_count(_dst, r)
  end,

  dig = function(_) -- dig dst[R] num[C/R/I]
    assert.two(_)
    assert.type(_[1], {'register'})
    assert.type(_[2], {'value', 'register', 'input'})
    local d = io.getcount(_[1])
    local n = io.getcount(_[2])
    n = math.max(0, n)-- + 1
    -- TODO: optimize
    local s = tostring(math.floor(math.abs(d))):reverse()
    io.register_set_count(_[1], tonumber(s:sub(n, n)) or 0)
  end,
  dis = function(_) -- dis dst[R] num[C/R/I] val[C/R/I]
    assert.three(_)
    assert.type(_[1], {'register'})
    assert.type(_[2], {'value', 'register', 'input'})
    assert.type(_[3], {'value', 'register', 'input'})
    local d = io.getcount(_[1])
    local n = io.getcount(_[2])
    local v = io.getcount(_[3])
    n = math.max(0, n)-- + 1
    -- TODO: optimize
    local s = tostring(math.floor(math.abs(d)) or 0):reverse()
    local r = tostring(math.min(math.floor(math.abs(v)), 9) or 0)
    s = s:sub(1, n - 1) .. string.rep('0', n-#s-1) ..r.. s:sub(n + 1)
    if d*v < 0 then
      s = s..'-'
    end
    io.register_set_count(_[1], tonumber(s:reverse()))
  end,

  cos = function(_) -- * **cos** dst[R] src[C/R/I]
    local _dst, _src = standard_op(_)
    io.register_set_count(_dst, math.cos(io.getcount(_src)))
  end,
  sin = function(_) -- * **sin** dst[R] src[C/R/I]
    local _dst, _src = standard_op(_)
    io.register_set_count(_dst, math.sin(io.getcount(_src)))
  end,
  tan = function(_) -- * **tan** dst[R] src[C/R/I]
    local _dst, _src = standard_op(_)
    io.register_set_count(_dst, math.tan(io.getcount(_src)))
  end,
  atan2 = function(_) -- * **atan2** dst[R] x[C/R/I] y[C/R/I]
    assert.three(_)
    assert.type(_[1], {'register'})
    assert.type(_[2], {'value', 'register', 'input'})
    assert.type(_[3], {'value', 'register', 'input'})
    local y = io.getcount(_[2])
    local x = io.getcount(_[3])
    io.register_set_count(_[1], math.atan2(y, x))
  end,
  sqrt = function(_) -- * **sqrt** dst[R] src[C/R/I]
    local _dst, _src = standard_op(_)
    io.register_set_count(_dst, math.sqrt(io.getcount(_src)))
  end,
  exp = function(_) -- * **exp** dst[R] src[C/R/I]
    local _dst, _src = standard_op(_)
    io.register_set_count(_dst, math.exp(io.getcount(_src)))
  end,
  ln = function(_) -- * **ln** dst[R] src[C/R/I]
    local _dst, _src = standard_op(_)
    io.register_set_count(_dst, math.ln(io.getcount(_src)))
  end,

  band = function(_)
    local _dst, _src = standard_op(_)
    local r = bit32.band(io.getcount(_dst), io.getcount(_src))
    io.register_set_count(_dst, r)
  end,
  bor = function(_)
    local _dst, _src = standard_op(_)
    local r = bit32.bor(io.getcount(_dst), io.getcount(_src))
    io.register_set_count(_dst, r)
  end,
  bxor = function(_)
    local _dst, _src = standard_op(_)
    local r = bit32.bxor(io.getcount(_dst), io.getcount(_src))
    io.register_set_count(_dst, r)
  end,
  bnot = function(_)
    local _dst = _[1]
    assert.is_register(_dst)
    local result = bit32.bnot(io.getcount(_dst))
    io.register_set_count(io.getcount(_dst), result)
  end,
  bsl = function(_)
    local _dst, _src = standard_op(_)
    local r = bit32.lshift(io.getcount(_dst), io.getcount(_src))
    io.register_set_count(_dst, r)
  end,
  bsr = function(_)
    local _dst, _src = standard_op(_)
    local r = bit32.rshift(io.getcount(_dst), io.getcount(_src))
    io.register_set_count(_dst, r)
  end,
  brl = function(_)
    local _dst, _src = standard_op(_)
    local r = bit32.lrotate(io.getcount(_dst), io.getcount(_src))
    io.register_set_count(_dst, r)
  end,
  brr = function(_)
    local _dst, _src = standard_op(_)
    local r = bit32.rrotate(io.getcount(_dst), io.getcount(_src))
    io.register_set_count(_dst, r)
  end,

  teq = test_mnemonic(function(a, b) return io.getcount(a) == io.getcount(b) end), -- teq a[C/R/I] b[C/R/I]
  tne = test_mnemonic(function(a, b) return io.getcount(a) ~= io.getcount(b) end), -- tne a[C/R/I] b[C/R/I]
  tgt = test_mnemonic(function(a, b) return io.getcount(a) > io.getcount(b) end), -- tgt a[C/R/I] b[C/R/I]
  tlt = test_mnemonic(function(a, b) return io.getcount(a) < io.getcount(b) end), -- tlt a[C/R/I] b[C/R/I]
  tge = test_mnemonic(function(a, b) return io.getcount(a) >= io.getcount(b) end), -- tge a[C/R/I] b[C/R/I]
  tle = test_mnemonic(function(a, b) return io.getcount(a) <= io.getcount(b) end), -- tle a[C/R/I] b[C/R/I]
  tas = function(_) -- tas a[T/R/I] b[T/R/I]
    assert.two(_)
    local as = io.gettype(_[1], {'type', 'input', 'register'})
    local bs = io.gettype(_[2], {'type', 'input', 'register'})
    local av = (as ~= nil)
    local bv = (bs ~= nil)
    if av ~= bv then
      return { type = 'skip' }
    elseif av and bv then
      if not (as.type == bs.type and as.name == bs.name) then
        return { type = 'skip' }
      end
    end
  end,
  tad = function(_) -- tad a[T/R/I] b[T/R/I]
    assert.two(_)
    local as = io.gettype(_[1], {'type', 'input', 'register'})
    local bs = io.gettype(_[2], {'type', 'input', 'register'})
    local av = (as ~= nil)
    local bv = (bs ~= nil)
    if not (av or bv) then
      return { type = 'skip' }
    elseif av and bv then
      if not (as.type ~= bs.type or as.name ~= bs.name) then
        return { type = 'skip' }
      end
    end
  end,

  beq = branch_mnemonic(function(a, b) return io.getcount(a) == io.getcount(b) end), -- beq a[C/R/I] b[C/R/I] addr[L/A/R]
  bne = branch_mnemonic(function(a, b) return io.getcount(a) ~= io.getcount(b) end), -- bne a[C/R/I] b[C/R/I] addr[L/A/R]
  bgt = branch_mnemonic(function(a, b) return io.getcount(a) > io.getcount(b) end), -- bgt a[C/R/I] b[C/R/I]  addr[L/A/R]
  blt = branch_mnemonic(function(a, b) return io.getcount(a) < io.getcount(b) end), -- blt a[C/R/I] b[C/R/I]  addr[L/A/R]
  bge = branch_mnemonic(function(a, b) return io.getcount(a) >= io.getcount(b) end), -- bge a[C/R/I] b[C/R/I] addr[L/A/R]
  ble = branch_mnemonic(function(a, b) return io.getcount(a) <= io.getcount(b) end), -- ble a[C/R/I] b[C/R/I] addr[L/A/R]
  bas = function(_) -- bas a[T/R/I] b[T/R/I] addr[L/A/R]
    assert.three(_)
    local as = io.gettype(_[1], {'type', 'input', 'register'})
    local bs = io.gettype(_[2], {'type', 'input', 'register'})
    local av = (as ~= nil)
    local bv = (bs ~= nil)
    if av ~= bv then
      return
    elseif av and bv then
      if not (as.type == bs.type and as.name == bs.name) then
        return
      end
    end
    return jump_op(_[3])
  end,
  bad = function(_) -- bad a[T/R/I] b[T/R/I] addr[L/A/R]
    assert.three(_)
    local as = io.gettype(_[1], {'type', 'input', 'register'})
    local bs = io.gettype(_[2], {'type', 'input', 'register'})
    local av = (as ~= nil)
    local bv = (bs ~= nil)
    if not (av or bv) then
      return
    elseif av and bv then
      if not (as.type ~= bs.type or as.name ~= bs.name) then
        return
      end
    end
    return jump_op(_[3])
  end,

  jmp = function(_)
    assert.one_or_two(_)
    return jump_op(_[1], _[2])
  end,
  hlt = function(_)
    return { type = 'halt' }
  end,
  slp = function(_)
    assert.one(_)
    assert.type(_[1], {'value', 'register'})
    return { type = 'sleep', val = io.getcount(_[1]) }
  end,

  bkr = function(_)
    assert.one(_)
    assert.type(_[1], {'value', 'register'})
    local count = io.getcount(_[1])
    if io.wire_count('red') < count then
      return {type = 'block'}
    else
      return {type = 'next'}
    end
  end,
  bkg = function(_)
    assert.one(_)
    assert.type(_[1], {'value', 'register'})
    local count = io.getcount(_[1])
    if io.wire_count('green') < count then
      return {type = 'block'}
    else
      return {type = 'next'}
    end
  end,

  btr = function(_)
    assert.one(_)
    local type = io.gettype(_[1], {'type', 'register'})
    if io.wire_find_signal('red', type) == NULL_SIGNAL then
      return {type = 'block'}
    else
      return {type = 'next'}
    end
  end,
  btg = function(_)
    assert.one(_)
    local type = io.gettype(_[1], {'type', 'register'})
    if io.wire_find_signal('green', type) == NULL_SIGNAL then
      return {type = 'block'}
    else
      return {type = 'next'}
    end
  end,
  bti = function(_)
    assert.one(_)
    local type = io.gettype(_[1], {'type', 'register'})
    if io.wire_find_signal('input', type) == NULL_SIGNAL then
      return {type = 'block'}
    else
      return {type = 'next'}
    end
  end,

  btrc = function(_)
    assert.one(_)
    local oldSig = io.register_get(_[1])
    local newSig = io.wire_find_signal('red', oldSig.signal)
    if newSig.count == oldSig.count then
      return {type = 'block'}
    else
      io.register_set(_[1], newSig)
      return {type = 'next'}
    end
  end,
  btgc = function(_)
    assert.one(_)
    local oldSig = io.register_get(_[1])
    local newSig = io.wire_find_signal('green', oldSig.signal)
    if newSig.count == oldSig.count then
      return {type = 'block'}
    else
      io.register_set(_[1], newSig)
      return {type = 'next'}
    end
  end,
  btic = function(_)
    assert.one(_)
    local oldSig = io.register_get(_[1])
    local newSig = io.wire_find_signal('input', oldSig.signal)
    if newSig.count == oldSig.count then
      return {type = 'block'}
    else
      io.register_set(_[1], newSig)
      return {type = 'next'}
    end
  end,

  nmd = function(_) -- Nuclear Meltdown
    assert.one(_)
    assert.type(_[1], {'type'})
    assert.check(_[1].signal.type == 'item' and (_[1].signal.name == 'uranium-fuel-cell' or _[1].signal.name == 'atomic-bomb'), 'Argument is pretty impoverished. Please, use enriched one!')
    return io.for_entity(function(entity)
      return {type='deffer', deffer={
        {action='exec', delay=0,  proc='game.print', args={'[color=red]fCPU core melting down... Better RUN![/color]'}},
        {action='exec', delay=100, proc='game.print', args={'[color=yellow]5[/color]'}},
        {action='exec', delay=160, proc='game.print', args={'[color=yellow]4[/color]'}},
        {action='exec', delay=220, proc='game.print', args={'[color=yellow]3[/color]'}},
        {action='exec', delay=280, proc='game.print', args={'[color=yellow]2[/color]'}},
        {action='exec', delay=340, proc='game.print', args={'[color=red]1[/color]'}},
        {action='exec', delay=400, proc='EasterEgg_nmd', args={
          entity,
          {name='atomic-rocket', amount=1, position={entity.position.x, entity.position.y}, force=game.forces.enemy, target=entity, speed=1}
        }},
      }}
    end)
  end,

  uiss = function(_) -- Utility Item Stack Size
    assert.two(_)
    local signal = io.gettype(_[2], {'type', 'register'})
    if signal.type ~= 'item' then
      io.setsignal(_[1], NULL_SIGNAL)
      --local str
      --if signal.type == 'virtual' then
      --  str = '[virtual-signal='.. signal.name ..']'
      --else
      --  str = '['.. signal.type ..'='.. signal.name ..']'
      --end
      --assert.exception('Expecting `[item=...]` signal type, got \''.. str ..'\'.')
    else
      local proto = game.item_prototypes[signal.name]
      assert.check(proto ~= nil, 'Unknown item name specified.')
      io.setsignal(_[1], { signal=signal, count=proto.stack_size })
    end
  end,

  ugpf = function(_) -- Utility Get Prototype Field
    assert.three(_)
    local signal = io.gettype(_[2], {'type', 'register'})
    local field = io.getstring(_[3])
    if signal.type ~= 'item' then
      io.setsignal(_[1], NULL_SIGNAL)
    else
      local proto = game.item_prototypes[signal.name]
      if proto == nil then
        assert.exception('Unknown prototype '.. signal.name ..' specified.')
      end

      local getValue = function(proto) return tonumber(proto[field]) end
      local success, value = pcall(getValue, proto)
      if not success then
        success, value = pcall(getValue, proto.place_result)
      end

      assert.check(success, 'Unknown prototype field specified.')
      if value then
        io.setsignal(_[1], { signal=signal, count=value })
      else
        io.setsignal(_[1], NULL_SIGNAL)
      end
    end
  end,
}

function EasterEgg_nmd(entity, ...)
  entity.surface.create_entity(...)
end

function opcodes.bind(assert_, io_)
  assert = assert_
  io = io_
end
return opcodes
