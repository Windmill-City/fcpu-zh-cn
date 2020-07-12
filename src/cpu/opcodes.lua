local assert
local io


local standard_op = function(_)
  assert.two(_)
  local _dst = _[1]
  assert.is_register(_dst)
  local _src = _[2]
  assert.is_input_or_reg_or_val(_src)
  return _src, _dst
end
local test_op = function(_)
  assert.two(_)
  local _in = _[1]
  assert.reg_or_val(_in)
  local _out = _[2]
  assert.out_mem_or_val(_out)
  return _in, _out
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
        io.regsset(_[i], NULL_SIGNAL)
      end
    else
      for i = 1, io.regssize() do
        io.register_set(i, NULL_SIGNAL)
      end
      io.wire_set({type='output'}, NULL_SIGNAL)
    end
  end,

  mov = function(_) -- mov dst...[R/O] src[S/R/I]
    assert.two_or_more(_)
    local sig = io.getsignal(_[#_], {'signal', 'register', 'wire'})
    for i = 1, #_ - 1 do
      io.setsignal(_[i], sig, {'register', 'wire'})
    end
  end,

  add = function(_)
    local _src, _dst = standard_op(_)
    io.regsset_count(_dst, io.getcount(_dst) + io.getcount(_src))
  end,
  sub = function(_)
    local _src, _dst = standard_op(_)
    io.regsset_count(_dst, io.getcount(_dst) - io.getcount(_src))
  end,
  mul = function(_)
    local _src, _dst = standard_op(_)
    io.regsset_count(_dst, io.getcount(_dst) * io.getcount(_src))
  end,
  div = function(_)
    local _src, _dst = standard_op(_)
    io.regsset_count(_dst, io.getcount(_dst) / io.getcount(_src))
  end,
  mod = function(_)
    local _src, _dst = standard_op(_)
    io.regsset_count(_dst, io.getcount(_dst) % io.getcount(_src))
  end,
  pow = function(_)
    local _src, _dst = standard_op(_)
    io.regsset_count(_dst, io.getcount(_dst) ^ io.getcount(_src))
  end,

  set = function(_)
    assert.two(_)
    local _in = _[1]
    assert.reg_or_val(_in)
    local _out = _[2]
    assert.out_register(_out)
    if _in.type == 'register' then
      io.setregister_count(_out, io.getregister(_in).count)
    elseif _in.type == 'value' then
      io.setregister_count(_out, io.num(_in))
    end
  end,
  fir = function(_)
    assert.one(_)
    local _in = _[1]
    assert.in_register(_in)
    local signal = io.getregister(_in)
    local wire_signal = io.wire_find_signal('red', signal)
    io.regsset(io.make_value(1), wire_signal)
  end,
  fig = function(_)
    assert.one(_)
    local _in = _[1]
    assert.in_register(_in)
    local signal = io.getregister(_in)
    local wire_signal = io.wire_find_signal('green', signal)
    io.regsset(io.make_value(1), wire_signal)
  end,
  swp = function(_)
    assert.two(_)
    local _in = _[1]
    assert.in_register(_in)
    local _out = _[2]
    assert.out_register(_out)
    local inSignal = io.getregister(_in)
    local outSignal = io.getregister(_out)
    io.setregister(_in, outSignal)
    io.setregister(_out, inSignal)
  end,
  bnd = function(_)
    local _in, _out = standard_op(_)
    local result = bit32.band(io.getcount(_in), io.getcount(_out))
    io.regsset_count(io.make_value(1), result)
  end,
  bor = function(_)
    local _in, _out = standard_op(_)
    local result = bit32.bor(io.getcount(_in), io.getcount(_out))
    io.regsset_count(io.make_value(1), result)
  end,
  bxr = function(_)
    local _in, _out = standard_op(_)
    local result = bit32.bxor(io.getcount(_in), io.getcount(_out))
    io.regsset_count(io.make_value(1), result)
  end,
  bls = function(_)
    local _in, _out = standard_op(_)
    local result = bit32.lshift(io.getcount(_in), io.getcount(_out))
    io.regsset_count(io.make_value(1), result)
  end,
  brs = function(_)
    local _in, _out = standard_op(_)
    local result = bit32.rshift(io.getcount(_in), io.getcount(_out))
    io.regsset_count(io.make_value(1), result)
  end,
  blr = function(_)
    local _in, _out = standard_op(_)
    local result = bit32.lrotate(io.getcount(_in), io.getcount(_out))
    io.regsset_count(io.make_value(1), result)
  end,
  brr = function(_)
    local _in, _out = standard_op(_)
    local result = bit32.rrotate(io.getcount(_in), io.getcount(_out))
    io.regsset_count(io.make_value(1), result)
  end,
  bno = function(_)
    assert.one(_)
    local _in = _[1]
    assert.reg_or_val(_in)
    local result = bit32.bnot(io.getcount(_in))
    io.regsset_count(io.make_value(1), result)
  end,
  slp = function(_)
    assert.one(_)
    local _in = _[1]
    assert.reg_or_val(_in)
    return { type = 'sleep', val = io.getcount(_in) }
  end,
  jmp = function(_)
    assert.one(_)
    local _in = _[1]
    assert.in_mem_or_val_or_label(_in)
    if _in.type == 'label' then
      return { type = 'jump', label = _in.label }
    else
      return { type = 'jump', val = io.getcount(_in) }
    end
  end,
  hlt = function(_)
    return { type = 'halt' }
  end,
  tgt = function(_)
    local _in, _out = test_op(_)
    if io.getcount(_in) > io.getcount(_out) then
      return { type = 'skip' }
    end
  end,
  tlt = function(_)
    local _in, _out = test_op(_)
    if io.getcount(_in) < io.getcount(_out) then
      return { type = 'skip' }
    end
  end,
  teq = function(_)
    local _in, _out = test_op(_)
    if io.getcount(_in) == io.getcount(_out) then
      return { type = 'skip' }
    end
  end,
  tnq = function(_)
    local _in, _out = test_op(_)
    if io.getcount(_in) ~= io.getcount(_out) then
      return { type = 'skip' }
    end
  end,
  tte = function(_)
    assert.two(_)
    local _in = _[1]
    assert.in_mem(_in)
    local _out = _[2]
    assert.out_mem(_out)
    if io.regsget(_in).signal.name == io.regsget(_out).signal.name then
      return { type = 'skip' }
    end
  end,
  ttn = function(_)
    assert.two(_)
    local _in = _[1]
    assert.in_mem(_in)
    local _out = _[2]
    assert.out_mem(_out)
    if io.regsget(_in).signal.name ~= io.regsget(_out).signal.name then
      return { type = 'skip' }
    end
  end,
  dig = function(_)
    assert.one(_)
    local _in = _[1]
    assert.reg_or_val(_in)
    local i = io.getcount(_in)
    local value = io.regsget(io.make_value(1)).count
    local digit = tonumber(string.sub(tostring(value), -i, -i))
    io.regsset_count(io.make_value(1), digit)
  end,
  dis = function(_)
    assert.two(_)
    local _in = _[1]
    assert.reg_or_val(_in)
    local _out = _[2]
    assert.out_mem_or_val(_out)
    local str_value = tostring(io.regsget(io.make_value(1)).count)
    local selector = string.len(str_value) - io.getcount(_in) + 1
    local digit = io.getcount(_out)
    local p1 = string.sub(str_value, 1, selector-1)
    local p2 = string.sub(str_value, selector, selector)
    local p3 = string.sub(str_value, selector+1, -1)
    p2 = string.sub(tostring(digit), -1)
    io.regsset_count(io.make_value(1), tonumber(p1..p2..p3))
  end,
  bkr = function(_)
    assert.one(_)
    local _in = _[1]
    assert.reg_or_val(_in)
    local count = io.getcount(_in)
    if wires.red.signals == nil or #wires.red.signals < count then
      return {type = 'block'}
    end
  end,
  bkg = function(_)
    assert.one(_)
    local _in = _[1]
    assert.reg_or_val(_in)
    local count = io.getcount(_in)
    if wires.green.signals == nil or #wires.green.signals < count then
      return {type = 'block'}
    end
  end,
}

function opcodes.bind(assert_, io_)
  assert = assert_
  io = io_
end
return opcodes
