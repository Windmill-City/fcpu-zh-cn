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
local jump_op = function(addr)
  assert.type(addr, {'label', 'value', 'register'})
  if addr.type == 'label' then
    return { type = 'jump', label = addr.label }
  else
    return { type = 'jump', val = io.getcount(addr) }
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
    assert.three(_)
    assert.type(_[1], {'value', 'input', 'register'})
    assert.type(_[2], {'value', 'input', 'register'})
    if condition(_[1], _[2]) then
      return jump_op(_[3])
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

local memory_clear = function(channel)
  local deffer = { type = 'deffer', ops = {} }
  io.ics_each(function(ics)
    deffer.ops[#deffer.ops + 1] = {action='enable', ic=ics.fix, delay = 0}
    deffer.ops[#deffer.ops + 1] = {action='disable', ic=ics.fix, delay = 1}
  end, channel)
  return deffer
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
    if 0 < #_ then
      for i, expr in ipairs(_) do
        if expr then
          assert.type(expr, {'register', 'memory', 'output'})
          if expr.color == 'out' then
            if expr.addr == nil then
              io.output_clear()
            else
              io.wire_set(_[i], nil)
            end
          elseif expr.type == 'register' then
            io.setsignal(_[i], NULL_SIGNAL, {'register', 'wire'})
          elseif expr.type == 'memory' then
            return memory_clear(expr.index and (expr.location .. expr.index))
          end
        end
      end
    else
      for i = 1, io.register_last_index() do
        io.register_setraw(i, table.deep_copy(NULL_SIGNAL))
      end
      io.control_set(table.deep_copy(NULL_SIGNAL))
      io.output_clear()
      return memory_clear()
    end
  end,

  mov = function(_) -- mov dst...[R/O] src[V/T/S/R/I]
    assert.two_or_more(_)
    local sig = io.getsignal(_[#_], {'value', 'type', 'signal', 'register', 'input'})
    for i = 1, #_ - 1 do
      io.setsignal(_[i], sig, {'register', 'wire'})
    end
  end,
  emit = function(_) -- emit src[V/T/S/R/I]
    assert.one(_)
    local sig = io.getsignal(_[1], {'value', 'type', 'signal', 'register', 'input'})
    io.wire_set({type='wire', color='out', addr=1, pointer=false}, sig)
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
    assert.one(_)
    return jump_op(_[1])
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
    end
  end,
  bkg = function(_)
    assert.one(_)
    assert.type(_[1], {'value', 'register'})
    local count = io.getcount(_[1])
    if io.wire_count('green') < count then
      return {type = 'block'}
    end
  end,
  bkm = function(_)
    assert.one(_)
    assert.type(_[1], {'value', 'register'})
    local count = io.getcount(_[1])
    if io.wire_count('green') < count then
      return {type = 'block'}
    end
  end,

  btr = function(_)
    assert.one(_)
    local type = io.gettype(_[1], {'type', 'register'})
    if io.wire_find_signal('red', type) == NULL_SIGNAL then
      return {type = 'block'}
    end
  end,
  btg = function(_)
    assert.one(_)
    local type = io.gettype(_[1], {'type', 'register'})
    if io.wire_find_signal('green', type) == NULL_SIGNAL then
      return {type = 'block'}
    end
  end,
}


function opcodes.bind(assert_, io_)
  assert = assert_
  io = io_
end
return opcodes
