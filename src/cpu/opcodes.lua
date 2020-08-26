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
local test_op = function(_)
  assert.two(_)
  assert.type(_[1], {'value', 'input', 'register'})
  assert.type(_[2], {'value', 'input', 'register'})
  return _[1], _[2]
end

local find_in_wire = function(_, color)
  assert.two(_)
  local _dst = _[1]
  assert.type(_dst, {'register', 'output'})
  local _type = io.gettype(_[2], {'type', 'register', 'input'})
  local sig = io.wire_find_signal(color, _type)
  io.setsignal(_dst, sig)
end

local fp = {
  to_float = function(fp)
    return fp / MC_FIXEDPOINT
  end,
  from_float = function(f)
    return math.round(f * MC_FIXEDPOINT)
  end,
  val_float = function(f)
    return f
  end
}

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
        if expr == 'out' then
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

  _tofp = function(_)
    assert.two(_)
    assert.type(_[1], {'register'})
    assert.type(_[2], {'value'})
    local _dst = io.getcount(_[1])
    local _src = io.getcount(_[2])
    io.register_set_fp(_dst, fp.val_float(io.getcount(_src)))
  end,
  _fromfp = function(_)
    assert.two(_)
    assert.type(_[1], {'register'})
    assert.type(_[2], {'value', 'register', 'input'})
    local _dst = io.getcount(_[1])
    local _src = io.getcount(_[2])
    io.register_set_fp(_dst, fp.val_float(io.getcount(_src)))
  end,

  cos = function(_) -- * **cos** dst[R] src[C/R/I]
    local _dst, _src = standard_op(_)
    io.register_set_fp(_dst, math.cos(fp.val_float(io.getcount(_src))))
  end,
  sin = function(_) -- * **sin** dst[R] src[C/R/I]
    local _dst, _src = standard_op(_)
    io.register_set_fp(_dst, math.sin(fp.val_float(io.getcount(_src))))
  end,
  tan = function(_) -- * **tan** dst[R] src[C/R/I]
    local _dst, _src = standard_op(_)
    io.register_set_fp(_dst, math.tan(fp.val_float(io.getcount(_src))))
  end,
  atan2 = function(_) -- * **atan2** dst[R] x[C/R/I] y[C/R/I]
    assert.three(_)
    assert.type(_[1], {'register'})
    assert.type(_[2], {'value', 'register', 'input'})
    assert.type(_[3], {'value', 'register', 'input'})
    local y = fp.val_float(io.getcount(_[2]))
    local x = fp.val_float(io.getcount(_[3]))
    io.register_set_fp(_[1], math.atan2(y, x))
  end,
  sqrt = function(_) -- * **sqrt** dst[R] src[C/R/I]
    local _dst, _src = standard_op(_)
    io.register_set_fp(_dst, math.sqrt(fp.val_float(io.getcount(_src))))
  end,
  exp = function(_) -- * **exp** dst[R] src[C/R/I]
    local _dst, _src = standard_op(_)
    io.register_set_fp(_dst, math.exp(fp.val_float(io.getcount(_src))))
  end,
  ln = function(_) -- * **ln** dst[R] src[C/R/I]
    local _dst, _src = standard_op(_)
    io.register_set_fp(_dst, math.ln(fp.val_float(io.getcount(_src))))
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

  teq = function(_) -- teq a[C/R/I] b[C/R/I]
    local a, b = test_op(_)
    if not (io.getcount(a) == io.getcount(b)) then
      return { type = 'skip' }
    end
  end,
  tne = function(_) -- tne a[C/R/I] b[C/R/I]
    local a, b = test_op(_)
    if not (io.getcount(a) ~= io.getcount(b)) then
      return { type = 'skip' }
    end
  end,
  tgt = function(_) -- tgt a[C/R/I] b[C/R/I]
    local a, b = test_op(_)
    if not (io.getcount(a) > io.getcount(b)) then
      return { type = 'skip' }
    end
  end,
  tlt = function(_) -- tlt a[C/R/I] b[C/R/I]
    local a, b = test_op(_)
    if not (io.getcount(a) < io.getcount(b)) then
      return { type = 'skip' }
    end
  end,
  tge = function(_) -- tge a[C/R/I] b[C/R/I]
    local a, b = test_op(_)
    if not (io.getcount(a) >= io.getcount(b)) then
      return { type = 'skip' }
    end
  end,
  tle = function(_) -- tle a[C/R/I] b[C/R/I]
    local a, b = test_op(_)
    if not (io.getcount(a) <= io.getcount(b)) then
      return { type = 'skip' }
    end
  end,
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

}


function opcodes.bind(assert_, io_)
  assert = assert_
  io = io_
end
return opcodes
