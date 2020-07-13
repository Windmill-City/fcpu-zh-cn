local assert
local io
local bit32 = require('3rdparty/numberlua')


local standard_op = function(_)
  assert.two(_)
  local _dst = _[1]
  assert.is_register(_dst)
  local _src = _[2]
  assert.type(_src, {'register', 'value'})
  return _dst, _src
end
local test_op = function(_)
  assert.two(_)
  local _in = _[1]
  assert.type(_in, {'register', 'value'})
  local _out = _[2]
  assert.out_mem_or_val(_out)
  return _in, _out
end

local find_in_wire = function(_, color)
  assert.two(_)
  local _dst = _[1]
  assert.type(_dst, {'register', 'output'})
  local _type = _[2]
  assert.type(_type, {'type', 'register', 'input'})
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
        io.register_set(_[i], NULL_SIGNAL)
      end
    else
      for i = 1, io.register_last_index() do
        io.register_setraw(i, table.deepcopy(NULL_SIGNAL))
      end
      io.wire_set({type='output'}, NULL_SIGNAL)
    end
  end,

  mov = function(_) -- mov dst...[R/O] src[V/T/S/R/I]
    assert.two_or_more(_)
    local sig = io.getsignal(_[#_], {'value', 'type', 'signal', 'register', 'input'})
    for i = 1, #_ - 1 do
      io.setsignal(_[i], sig, {'register', 'wire'})
    end
  end,
  ssv = function(_) -- ssv dst...[R] val[V/S/R/I]
    assert.two_or_more(_)
    local sigcount = io.getcount(_[#_], {'value', 'signal', 'register', 'input'})
    for i = 1, #_ - 1 do
      io.setcount(_[i], sigcount, {'register'})
    end
  end,
  sst = function(_) -- sst dst...[R] type[T/S/R/I]
    assert.two_or_more(_)
    local sigtype = io.gettype(_[#_], {'type', 'signal', 'register', 'input'})
    for i = 1, #_ - 1 do
      io.settype(_[i], sigtype, {'register'})
    end
  end,

  fir = function(_) -- fir dst[R/O] type[T/R/I]
    find_in_wire(_, 'red')
  end,
  fig = function(_) -- fig dst[R/O] type[T/R/I]
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

  jmp = function(_)
    assert.one(_)
    local _in = _[1]
    assert.type(_in, {'label', 'value', 'register'})
    if _in.type == 'label' then
      return { type = 'jump', label = _in.label }
    else
      return { type = 'jump', val = io.getcount(_in) }
    end
  end,
  hlt = function(_)
    return { type = 'halt' }
  end,
  slp = function(_)
    assert.one(_)
    assert.type(_[1], {'value', 'register'})
    return { type = 'sleep', val = io.getcount(_[1]) }
  end,
}


function opcodes.bind(assert_, io_)
  assert = assert_
  io = io_
end
return opcodes
