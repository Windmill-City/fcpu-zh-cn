local Assert = require('src/cpu/assert')
local io = require('src/cpu/io')

local StandartSourceTypes = {'register', 'value', 'input'}

local standard_op = function(_)
  Assert.two(_)
  local _dst = _[1]
  Assert.is_register(_dst)
  local _src = _[2]
  Assert.type(_src, StandartSourceTypes)
  return _dst, _src
end
local standard_op3 = function(_)
  local three = (Assert.two_or_three(_) == 3)
  local _dst = _[1]
  Assert.is_register(_dst)
  local _a = _[three and 2 or 1]
  local _b = _[three and 3 or 2]
  if three then
    Assert.type(_a, StandartSourceTypes)
  end
  Assert.type(_b, StandartSourceTypes)
  return _dst, _a, _b
end
local jump_op = function(addr, offset)
  Assert.type(addr, {'label', 'value', 'register'})
  if offset then
    Assert.type(offset, {'value', 'register'})
    offset = io.getvalue(offset) or 0
  else
    offset = 0
  end
  if addr.type == 'label' then
    return { type = 'jump', val = offset, label = addr.label }
  else
    return { type = 'jump', val = io.getvalue(addr) + offset }
  end
end

local test_mnemonics = function(condition)
  return function(_)
    Assert.two(_)
    Assert.type(_[1], {'value', 'string', 'input', 'register'})
    Assert.type(_[2], {'value', 'string', 'input', 'register'})
    if not condition(_[1], _[2]) then
      return { type = 'skip' }
    end
  end
end

local branch_mnemonics = function(condition)
  return function(_)
    Assert.three_or_four(_)
    Assert.type(_[1], {'value', 'string', 'input', 'register'})
    Assert.type(_[2], {'value', 'string', 'input', 'register'})
    if condition(_[1], _[2]) then
      return jump_op(_[3], _[4])
    end
  end
end

local bk_mnemonics = function(color)
  return function(_)
    Assert.one(_)
    Assert.type(_[1], {'value', 'register'})
    local count = io.getvalue(_[1])
    if io.wire_count(color) < count then
      return {type = 'block'}
    else
      return {type = 'next'}
    end
  end
end

local bt_mnemonics = function(color)
  return function(_)
    Assert.one(_)
    local type = io.gettype(_[1], {'type', 'register'})
    if (io.wire_find_signal(color, type) or 0) ~= 0 then
      return {type = 'next'}
    else
      return {type = 'block'}
    end
  end
end

local btc_mnemonics = function(color)
  return function(_)
    Assert.one(_)
    local oldSig = io.register_get(_[1])
    local type = oldSig.signal
    Assert.check(type, 'Type should be specified for reference signal')
    local newCnt = io.wire_find_signal(color, type)
    if newCnt == oldSig.count then
      return {type = 'block'}
    else
      io.register_set(_[1], {signal=oldSig.signal, count=newCnt})
      return {type = 'next'}
    end
  end
end

local find_in_wire = function(color)
  return function(_)
    Assert.two(_)
    local _dst = _[1]
    Assert.type(_dst, {'register', 'output'})
    local _type = io.gettype(_[2], {'type', 'register', 'input'})
    local count = io.wire_find_signal(color, _type)
    local signal = (count and count ~= 0) and { signal = _type, count = count }
    io.setsignal(_dst, signal or NULL_SIGNAL)
  end
end

local find_in_channel = function(_)
  Assert.three(_)
  local _dst = _[1]
  Assert.type(_dst, {'register', 'output'})
  local _chan = _[2]
  Assert.type(_chan, {'input', 'memory'})
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
  Assert.three(_)
  local _dst = _[1]
  Assert.type(_dst, {'register', 'output'})
  local _chan = _[2]
  Assert.type(_chan, {'input', 'memory'})
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
  local ClearIC = function(ast)
    if ast.deffer and ast.deffer.clr then
      for _, v in ipairs(ast.deffer.clr) do
        action.deffer[#action.deffer + 1] = v
      end
    end
  end
  io.ics_each_ast(ClearIC, channel)
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
          Assert.type(expr, {'register', 'memory', 'output'})
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
    Assert.two_or_more(_)
    local sig = io.getsignal(_[#_], {'value', 'type', 'signal', 'register', 'input'})
    for i = 1, #_ - 1 do
      io.setsignal(_[i], sig, {'register', 'wire'})
    end
  end,
  emit = function(_) -- emit dst[M] src...[V/T/S/R/I]
    Assert.two_or_more(_)
    local dst = table.deep_copy(_[1])
    Assert.is_memory_writable(dst)
    local signals = io.memory_getchannel_signals(dst)
    dst.addr = signals and #signals or 0
    for i = 2,#_ do
      local sig = io.getsignal(_[i], {'value', 'type', 'signal', 'register', 'input'})
      dst.addr = dst.addr + 1
      io.memory_set(dst, sig)
    end
  end,
  ssv = function(_) -- ssv dst...[R] val[V/S/R/I]
    Assert.two_or_more(_)
    local sigcount = io.getvalue(_[#_], {'value', 'signal', 'register', 'input'})
    for i = 1, #_ - 1 do
      io.setcount(_[i], sigcount, {'register', 'output'})
    end
  end,
  sst = function(_) -- sst dst...[R] type[T/S/R/I]
    Assert.two_or_more(_)
    local sigtype = io.gettype(_[#_], {'type', 'signal', 'register', 'input'})
    for i = 1, #_ - 1 do
      io.settype(_[i], sigtype, {'register', 'output'})
    end
  end,

  fir = find_in_wire('red'), -- fir dst[R/O] type[T/R/I]
  fig = find_in_wire('green'), -- fig dst[R/O] type[T/R/I]

  fid = function(_) -- fid dst[R/O] mem[W/M] type[T/R/I]
    find_in_channel(_)
  end,
  idx = function(_) -- idx dst[R/O] mem[W/M] type[T/R/I]
    index_in_channel(_)
  end,

  swp = function(_) -- swp reg1[R] reg2[R]
    Assert.two(_)
    Assert.is_register(_[1], _[2])
    local a = io.getsignal(_[1], {'register'})
    local b = io.getsignal(_[2], {'register'})
    io.setsignal(_[1], b, {'register'})
    io.setsignal(_[2], a, {'register'})
  end,
  swpt = function(_) -- swpt reg1[R] reg2[R]
    Assert.two(_)
    Assert.is_register(_[1], _[2])
    local a = io.gettype(_[1], {'register'})
    local b = io.gettype(_[2], {'register'})
    io.settype(_[1], b, {'register'})
    io.settype(_[2], a, {'register'})
  end,
  swpv = function(_) -- swpv reg1[R] reg2[R]
    Assert.two(_)
    Assert.is_register(_[1], _[2])
    local a = io.getvalue(_[1], {'register'})
    local b = io.getvalue(_[2], {'register'})
    io.setcount(_[1], b, {'register'})
    io.setcount(_[2], a, {'register'})
  end,

  add = function(_)
    local _dst, _a, _b = standard_op3(_)
    io.register_set_count(_dst, io.getvalue(_a) + io.getvalue(_b))
  end,
  sub = function(_)
    local _dst, _a, _b = standard_op3(_)
    io.register_set_count(_dst, io.getvalue(_a) - io.getvalue(_b))
  end,
  mul = function(_)
    local _dst, _a, _b = standard_op3(_)
    io.register_set_count(_dst, io.getvalue(_a) * io.getvalue(_b))
  end,
  div = function(_)
    local _dst, _a, _b = standard_op3(_)
    io.register_set_count(_dst, io.getvalue(_a) / io.getvalue(_b))
  end,
  mod = function(_)
    local _dst, _a, _b = standard_op3(_)
    io.register_set_count(_dst, io.getvalue(_a) % io.getvalue(_b))
  end,
  pow = function(_)
    local _dst, _a, _b = standard_op3(_)
    io.register_set_count(_dst, io.getvalue(_a) ^ io.getvalue(_b))
  end,

  inc = function(_)
    Assert.one(_)
    local _dst = _[1]
    Assert.is_register(_dst)
    io.register_set_count(_dst, io.getvalue(_dst) + 1)
  end,
  dec = function(_)
    Assert.one(_)
    local _dst = _[1]
    Assert.is_register(_dst)
    io.register_set_count(_dst, io.getvalue(_dst) - 1)
  end,

  subi = function(_)
    local _dst, _src = standard_op(_)
    io.register_set_count(_dst, io.getvalue(_src) - io.getvalue(_dst))
  end,
  divi = function(_)
    local _dst, _src = standard_op(_)
    io.register_set_count(_dst, io.getvalue(_src) / io.getvalue(_dst))
  end,
  modi = function(_)
    local _dst, _src = standard_op(_)
    io.register_set_count(_dst, io.getvalue(_src) % io.getvalue(_dst))
  end,
  powi = function(_)
    local _dst, _src = standard_op(_)
    io.register_set_count(_dst, io.getvalue(_src) ^ io.getvalue(_dst))
  end,

  fract = function(_)
    Assert.one(_)
    local r = io.getvalue(_[1], {'register'})
    io.register_set_count(_[1], r - math.floor(r))
  end,
  floor = function(_)
    Assert.one(_)
    local r = io.getvalue(_[1], {'register'})
    io.register_set_count(_[1], math.floor(r))
  end,
  round = function(_)
    Assert.one(_)
    local r = io.getvalue(_[1], {'register'})
    io.register_set_count(_[1], math.floor(r + 0.5))
  end,
  ceil = function(_)
    Assert.one(_)
    local r = io.getvalue(_[1], {'register'})
    io.register_set_count(_[1], math.ceil(r))
  end,

  rnd = function(_) -- rnd dst[R/O] min[C/R/I] max[C/R/I]
    Assert.three(_)
    local _dst = _[1]
    Assert.is_register(_dst)
    local _min = _[2]
    local _max = _[3]
    Assert.type(_min, {'register', 'value', 'input'})
    Assert.type(_max, {'register', 'value', 'input'})
    local min = io.getvalue(_min)
    local range  = io.getvalue(_max) - min + 1
    Assert.check(0 <= range, "Minimum limit should be less or queal than the maximum limit")
    local r = min + (math.random() * range)
    io.register_set_count(_dst, r)
  end,

  dig = function(_) -- dig dst[R] num[C/R/I]
    Assert.two(_)
    Assert.type(_[1], {'register'})
    Assert.type(_[2], {'value', 'register', 'input'})
    local d = io.getvalue(_[1])
    local n = io.getvalue(_[2])
    n = math.max(0, n)-- + 1
    -- TODO: optimize
    local s = tostring(math.floor(math.abs(d))):reverse()
    io.register_set_count(_[1], tonumber(s:sub(n, n)) or 0)
  end,
  dis = function(_) -- dis dst[R] num[C/R/I] val[C/R/I]
    Assert.three(_)
    Assert.type(_[1], {'register'})
    Assert.type(_[2], {'value', 'register', 'input'})
    Assert.type(_[3], {'value', 'register', 'input'})
    local d = io.getvalue(_[1])
    local n = io.getvalue(_[2])
    local v = io.getvalue(_[3])
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
    io.register_set_count(_dst, math.cos(io.getvalue(_src)))
  end,
  sin = function(_) -- * **sin** dst[R] src[C/R/I]
    local _dst, _src = standard_op(_)
    io.register_set_count(_dst, math.sin(io.getvalue(_src)))
  end,
  tan = function(_) -- * **tan** dst[R] src[C/R/I]
    local _dst, _src = standard_op(_)
    io.register_set_count(_dst, math.tan(io.getvalue(_src)))
  end,
  atan2 = function(_) -- * **atan2** dst[R] x[C/R/I] y[C/R/I]
    Assert.three(_)
    Assert.type(_[1], {'register'})
    Assert.type(_[2], {'value', 'register', 'input'})
    Assert.type(_[3], {'value', 'register', 'input'})
    local y = io.getvalue(_[2])
    local x = io.getvalue(_[3])
    io.register_set_count(_[1], math.atan2(y, x))
  end,
  sqrt = function(_) -- * **sqrt** dst[R] src[C/R/I]
    local _dst, _src = standard_op(_)
    io.register_set_count(_dst, math.sqrt(io.getvalue(_src)))
  end,
  exp = function(_) -- * **exp** dst[R] src[C/R/I]
    local _dst, _src = standard_op(_)
    io.register_set_count(_dst, math.exp(io.getvalue(_src)))
  end,
  ln = function(_) -- * **ln** dst[R] src[C/R/I]
    local _dst, _src = standard_op(_)
    io.register_set_count(_dst, math.log(io.getvalue(_src)))
  end,

  band = function(_)
    local _dst, _a, _b = standard_op3(_)
    local r = bit32.band(io.getvalue(_a), io.getvalue(_b))
    io.register_set_count(_dst, r)
  end,
  bor = function(_)
    local _dst, _a, _b = standard_op3(_)
    local r = bit32.bor(io.getvalue(_a), io.getvalue(_b))
    io.register_set_count(_dst, r)
  end,
  bxor = function(_)
    local _dst, _a, _b = standard_op3(_)
    local r = bit32.bxor(io.getvalue(_a), io.getvalue(_b))
    io.register_set_count(_dst, r)
  end,
  bnot = function(_)
    local two = Assert.one_or_two(_)
    local _dst = _[1]
    local _src = _[two and 2 or 1]
    Assert.is_register(_dst, _src)
    local result = bit32.bnot(io.getvalue(_src))
    io.register_set_count(io.getvalue(_dst), result)
  end,
  bsl = function(_)
    local _dst, _a, _b = standard_op3(_)
    local r = bit32.lshift(io.getvalue(_a), io.getvalue(_b))
    io.register_set_count(_dst, r)
  end,
  bsr = function(_)
    local _dst, _a, _b = standard_op3(_)
    local r = bit32.rshift(io.getvalue(_a), io.getvalue(_b))
    io.register_set_count(_dst, r)
  end,
  brl = function(_)
    local _dst, _a, _b = standard_op3(_)
    local r = bit32.lrotate(io.getvalue(_a), io.getvalue(_b))
    io.register_set_count(_dst, r)
  end,
  brr = function(_)
    local _dst, _a, _b = standard_op3(_)
    local r = bit32.rrotate(io.getvalue(_a), io.getvalue(_b))
    io.register_set_count(_dst, r)
  end,

  teq = test_mnemonics(function(a, b) return io.getvalue(a) == io.getvalue(b) end), -- teq a[C/S/R/I] b[C/S/R/I]
  tne = test_mnemonics(function(a, b) return io.getvalue(a) ~= io.getvalue(b) end), -- tne a[C/S/R/I] b[C/S/R/I]
  tgt = test_mnemonics(function(a, b) return io.getvalue(a) >  io.getvalue(b) end), -- tgt a[C/S/R/I] b[C/S/R/I]
  tlt = test_mnemonics(function(a, b) return io.getvalue(a) <  io.getvalue(b) end), -- tlt a[C/S/R/I] b[C/S/R/I]
  tge = test_mnemonics(function(a, b) return io.getvalue(a) >= io.getvalue(b) end), -- tge a[C/S/R/I] b[C/S/R/I]
  tle = test_mnemonics(function(a, b) return io.getvalue(a) <= io.getvalue(b) end), -- tle a[C/S/R/I] b[C/S/R/I]
  tas = function(_) -- tas a[T/R/I] b[T/R/I]
    Assert.two(_)
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
    Assert.two(_)
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

  beq = branch_mnemonics(function(a, b) return io.getvalue(a) == io.getvalue(b) end), -- beq a[C/S/R/I] b[C/S/R/I] addr[L/A/R]
  bne = branch_mnemonics(function(a, b) return io.getvalue(a) ~= io.getvalue(b) end), -- bne a[C/S/R/I] b[C/S/R/I] addr[L/A/R]
  bgt = branch_mnemonics(function(a, b) return io.getvalue(a) >  io.getvalue(b) end), -- bgt a[C/S/R/I] b[C/S/R/I] addr[L/A/R]
  blt = branch_mnemonics(function(a, b) return io.getvalue(a) <  io.getvalue(b) end), -- blt a[C/S/R/I] b[C/S/R/I] addr[L/A/R]
  bge = branch_mnemonics(function(a, b) return io.getvalue(a) >= io.getvalue(b) end), -- bge a[C/S/R/I] b[C/S/R/I] addr[L/A/R]
  ble = branch_mnemonics(function(a, b) return io.getvalue(a) <= io.getvalue(b) end), -- ble a[C/S/R/I] b[C/S/R/I] addr[L/A/R]
  bas = function(_) -- bas a[T/R/I] b[T/R/I] addr[L/A/R] offset?[C/R]
    Assert.three_or_four(_)
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
    return jump_op(_[3], _[4])
  end,
  bad = function(_) -- bad a[T/R/I] b[T/R/I] addr[L/A/R] offset?[C/R]
    Assert.three_or_four(_)
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
    return jump_op(_[3], _[4])
  end,

  lea = function(_)
    Assert.two(_)
    Assert.is_register(_[1])
    local label = _[2]
    Assert.type(label, {'label'})
    local addr = io.for_entity(function(entity, state)
      for line_num, node in ipairs(state.program_ast) do
        if node and node.type == 'label' and node.label == label.label then
          return line_num + 1
        end
      end
    end)
    Assert.check(addr ~= nil, 'Undefined label')
    io.register_set_count(_[1], addr)
  end,
  jmp = function(_)
    Assert.one_or_two(_)
    return jump_op(_[1], _[2])
  end,
  hlt = function(_)
    return { type = 'halt' }
  end,
  slp = function(_)
    Assert.one(_)
    Assert.type(_[1], {'value', 'register'})
    return { type = 'sleep', val = io.getvalue(_[1]) }
  end,

  bkr = bk_mnemonics('red'),
  bkg = bk_mnemonics('green'),

  btr = bt_mnemonics('red'),
  btg = bt_mnemonics('green'),
  bti = bt_mnemonics('input'),

  btrc = btc_mnemonics('red'),
  btgc = btc_mnemonics('green'),
  btic = btc_mnemonics('input'),

  nmd = function(_) -- Nuclear Meltdown
    Assert.one(_)
    Assert.type(_[1], {'type'})
    Assert.check(_[1].signal.type == 'item' and (_[1].signal.name == 'uranium-fuel-cell' or _[1].signal.name == 'atomic-bomb'), 'Argument is pretty impoverished. Please, use enriched one!')
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
    Assert.two(_)
    local signal = io.gettype(_[2], {'type', 'register'})
    if signal.type ~= 'item' then
      io.setsignal(_[1], NULL_SIGNAL)
      --local str
      --if signal.type == 'virtual' then
      --  str = '[virtual-signal='.. signal.name ..']'
      --else
      --  str = '['.. signal.type ..'='.. signal.name ..']'
      --end
      --Assert.exception('Expecting `[item=...]` signal type, got \''.. str ..'\'.')
    else
      local proto = game.item_prototypes[signal.name]
      Assert.check(proto ~= nil, 'Unknown item name specified.')
      io.setsignal(_[1], { signal=signal, count=proto.stack_size })
    end
  end,

  ugpf = function(_) -- Utility Get Prototype Field
    Assert.three(_)
    local signal = io.gettype(_[2], {'type', 'register'})
    if signal.type ~= 'item' then
      io.setsignal(_[1], NULL_SIGNAL)
    else
      local proto = game.item_prototypes[signal.name]
      if proto == nil then
        Assert.exception('Unknown prototype '.. signal.name ..' specified.')
      end

      local getFieldValue = function(var, field)
        local bak
        for v, b in string.gmatch(field, '([^%.()]+)([()]?)') do
          if type(var[v]) == 'function' and b == '(' then
            bak = var[v]
            var = _G
          else
            var = var[v]
            if b == ')' then
              Assert.check(bak, 'Unmatched brace found')
              var = bak(var)
              bak = nil
            end
          end
        end
        return tonumber(var) or var
      end

      local field = io.getvalue(_[3])

      local success, value = pcall(getFieldValue, proto, field)
      if not success then
        success, value = pcall(getFieldValue, proto.place_result, field)
      end
      Assert.check(success, value)

      local t = type(value)
      if t == 'number' then
        io.setsignal(_[1], { signal=signal, count=value })
      elseif t == 'string' then
        io.setsignal(_[1], { signal=signal, str=value })
      else
        io.setsignal(_[1], NULL_SIGNAL)
      end
    end
  end,
}

function EasterEgg_nmd(entity, ...)
  entity.surface.create_entity(...)
end

function opcodes.setup(io_)
  io = io_
end
return opcodes
