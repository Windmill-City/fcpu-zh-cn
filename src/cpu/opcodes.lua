local assert
local io


local standard_op = function(_)
  assert.two(_)
  local _dst = _[1]
  assert.is_register(_dst)
  local _src = _[2]
  assert.type(_src, {'register', 'memory', 'value', 'input'})
  return _dst, _src
end
local jump_op = function(addr)
  assert.type(addr, {'label', 'value', 'register', 'memory'})
  if addr.type == 'label' then
    return { type = 'jump', label = addr.label }
  else
    return { type = 'jump', val = io.getcount(addr) }
  end
end

local test_mnemonic = function(condition)
  return function(_)
    assert.two(_)
    assert.type(_[1], {'value', 'input', 'register', 'memory'})
    assert.type(_[2], {'value', 'input', 'register', 'memory'})
    if not condition(_[1], _[2]) then
      return { type = 'skip' }
    end
  end
end
local branch_mnemonic = function(condition)
  return function(_)
    assert.three(_)
    assert.type(_[1], {'value', 'input', 'register', 'memory'})
    assert.type(_[2], {'value', 'input', 'register', 'memory'})
    if condition(_[1], _[2]) then
      return jump_op(_[3])
    end
  end
end

local find_in_wire = function(_, color)
  assert.two(_)
  local _dst = _[1]
  assert.type(_dst, {'register', 'output'})
  local _type = io.gettype(_[2], {'type', 'register', 'memory', 'input'})
  local sig = io.wire_find_signal(color, _type)
  io.setsignal(_dst, sig)
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
        if expr and expr.addr == nil and expr.color == 'out' then
          io.output_clear()
        else
          io.setsignal(_[i], NULL_SIGNAL, {'register', 'wire'})
        end
      end
    else
      for i = 1, io.register_last_index() do
        io.register_setraw(i, table.deepcopy(NULL_SIGNAL))
      end
      io.wire_set({type='wire', color='out', addr=1, pointer=false}, NULL_SIGNAL)
      io.output_clear()
    end
  end,

  mov = function(_) -- mov dst...[R/O] src[V/T/S/R/M/I]
    assert.two_or_more(_)
    local sig = io.getsignal(_[#_], {'value', 'type', 'signal', 'register', 'memory', 'input'})
    for i = 1, #_ - 1 do
      io.setsignal(_[i], sig, {'register', 'wire'})
    end
  end,
  emit = function(_) -- emit src[V/T/S/R/M/I]
    assert.one(_)
    local sig = io.getsignal(_[1], {'value', 'type', 'signal', 'register', 'memory', 'input'})
    io.wire_set({type='wire', color='out', addr=1, pointer=false}, sig)
  end,
  ssv = function(_) -- ssv dst...[R] val[V/S/R/M/I]
    assert.two_or_more(_)
    local sigcount = io.getcount(_[#_], {'value', 'signal', 'register', 'memory', 'input'})
    for i = 1, #_ - 1 do
      io.setcount(_[i], sigcount, {'register', 'output'})
    end
  end,
  sst = function(_) -- sst dst...[R] type[T/S/R/M/I]
    assert.two_or_more(_)
    local sigtype = io.gettype(_[#_], {'type', 'signal', 'register', 'memory', 'input'})
    for i = 1, #_ - 1 do
      io.settype(_[i], sigtype, {'register', 'output'})
    end
  end,

  fir = function(_) -- fir dst[R/O] type[T/R/M/I]
    find_in_wire(_, 'red')
  end,
  fig = function(_) -- fig dst[R/O] type[T/R/M/I]
    find_in_wire(_, 'green')
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

  dig = function(_) -- dig dst[R] num[C/R/M/I]
    assert.two(_)
    assert.type(_[1], {'register'})
    assert.type(_[2], {'value', 'register', 'memory', 'input'})
    local d = io.getcount(_[1])
    local n = io.getcount(_[2])
    n = math.max(0, n)-- + 1
    -- TODO: optimize
    local s = tostring(math.floor(math.abs(d))):reverse()
    io.register_set_count(_[1], tonumber(s:sub(n, n)) or 0)
  end,
  dis = function(_) -- dis dst[R] num[C/R/M/I] val[C/R/M/I]
    assert.three(_)
    assert.type(_[1], {'register'})
    assert.type(_[2], {'value', 'register', 'memory', 'input'})
    assert.type(_[3], {'value', 'register', 'memory', 'input'})
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

  cos = function(_) -- * **cos** dst[R] src[C/R/M/I]
    local _dst, _src = standard_op(_)
    io.register_set_count(_dst, math.cos(io.getcount(_src)))
  end,
  sin = function(_) -- * **sin** dst[R] src[C/R/M/I]
    local _dst, _src = standard_op(_)
    io.register_set_count(_dst, math.sin(io.getcount(_src)))
  end,
  tan = function(_) -- * **tan** dst[R] src[C/R/M/I]
    local _dst, _src = standard_op(_)
    io.register_set_count(_dst, math.tan(io.getcount(_src)))
  end,
  atan2 = function(_) -- * **atan2** dst[R] x[C/R/M/I] y[C/R/M/I]
    assert.three(_)
    assert.type(_[1], {'register'})
    assert.type(_[2], {'value', 'register', 'memory', 'input'})
    assert.type(_[3], {'value', 'register', 'memory', 'input'})
    local y = io.getcount(_[2])
    local x = io.getcount(_[3])
    io.register_set_count(_[1], math.atan2(y, x))
  end,
  sqrt = function(_) -- * **sqrt** dst[R] src[C/R/M/I]
    local _dst, _src = standard_op(_)
    io.register_set_count(_dst, math.sqrt(io.getcount(_src)))
  end,
  exp = function(_) -- * **exp** dst[R] src[C/R/M/I]
    local _dst, _src = standard_op(_)
    io.register_set_count(_dst, math.exp(io.getcount(_src)))
  end,
  ln = function(_) -- * **ln** dst[R] src[C/R/M/I]
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

  teq = test_mnemonic(function(a, b) return io.getcount(a) == io.getcount(b) end), -- teq a[C/R/M/I] b[C/R/M/I]
  tne = test_mnemonic(function(a, b) return io.getcount(a) ~= io.getcount(b) end), -- tne a[C/R/M/I] b[C/R/M/I]
  tgt = test_mnemonic(function(a, b) return io.getcount(a) > io.getcount(b) end), -- tgt a[C/R/M/I] b[C/R/M/I]
  tlt = test_mnemonic(function(a, b) return io.getcount(a) < io.getcount(b) end), -- tlt a[C/R/M/I] b[C/R/M/I]
  tge = test_mnemonic(function(a, b) return io.getcount(a) >= io.getcount(b) end), -- tge a[C/R/M/I] b[C/R/M/I]
  tle = test_mnemonic(function(a, b) return io.getcount(a) <= io.getcount(b) end), -- tle a[C/R/M/I] b[C/R/M/I]
  tas = function(_) -- tas a[T/R/M/I] b[T/R/M/I]
    assert.two(_)
    local as = io.gettype(_[1], {'type', 'input', 'register', 'memory'})
    local bs = io.gettype(_[2], {'type', 'input', 'register', 'memory'})
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
  tad = function(_) -- tad a[T/R/M/I] b[T/R/M/I]
    assert.two(_)
    local as = io.gettype(_[1], {'type', 'input', 'register', 'memory'})
    local bs = io.gettype(_[2], {'type', 'input', 'register', 'memory'})
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

  beq = branch_mnemonic(function(a, b) return io.getcount(a) == io.getcount(b) end), -- beq a[C/R/M/I] b[C/R/M/I] addr[**C**/**A**/**L**/**R**]
  bne = branch_mnemonic(function(a, b) return io.getcount(a) ~= io.getcount(b) end), -- bne a[C/R/M/I] b[C/R/M/I] addr[**C**/**A**/**L**/**R**]
  bgt = branch_mnemonic(function(a, b) return io.getcount(a) > io.getcount(b) end), -- bgt a[C/R/M/I] b[C/R/M/I]  addr[**C**/**A**/**L**/**R**]
  blt = branch_mnemonic(function(a, b) return io.getcount(a) < io.getcount(b) end), -- blt a[C/R/M/I] b[C/R/M/I] addr[**C**/**A**/**L**/**R**]
  bge = branch_mnemonic(function(a, b) return io.getcount(a) >= io.getcount(b) end), -- bge a[C/R/M/I] b[C/R/M/I] addr[**C**/**A**/**L**/**R**]
  ble = branch_mnemonic(function(a, b) return io.getcount(a) <= io.getcount(b) end), -- ble a[C/R/M/I] b[C/R/M/I] addr[**C**/**A**/**L**/**R**]
  bas = function(_) -- bas a[T/R/M/I] b[T/R/M/I]
    assert.three(_)
    local as = io.gettype(_[1], {'type', 'input', 'register', 'memory'})
    local bs = io.gettype(_[2], {'type', 'input', 'register', 'memory'})
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
  bad = function(_) -- bad a[T/R/M/I] b[T/R/M/I]
    assert.three(_)
    local as = io.gettype(_[1], {'type', 'input', 'register', 'memory'})
    local bs = io.gettype(_[2], {'type', 'input', 'register', 'memory'})
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
    assert.type(_[1], {'value', 'register', 'memory'})
    return { type = 'sleep', val = io.getcount(_[1]) }
  end,

  bkr = function(_)
    assert.one(_)
    assert.type(_[1], {'value', 'register', 'memory'})
    local count = io.getcount(_[1])
    if io.wire_count('red') < count then
      return {type = 'block'}
    end
  end,
  bkg = function(_)
    assert.one(_)
    assert.type(_[1], {'value', 'register', 'memory'})
    local count = io.getcount(_[1])
    if io.wire_count('green') < count then
      return {type = 'block'}
    end
  end,
}


function opcodes.bind(assert_, io_)
  assert = assert_
  io = io_
end
return opcodes
