local ops = {
  set = function(_)
    assert.two(_)
    local _in = _[1]
    assert.reg_or_val(_in)
    local _out = _[2]
    assert.out_register(_out)
    if _in.type == 'register' then
      io.setcount(_out, io.getsignal(_in).count)
    elseif _in.type == 'value' then
      io.setcount(_out, io.num(_in))
    end
  end,
  fir = function(_)
    assert.one(_)
    local _in = _[1]
    assert.in_register(_in)
    local signal = io.getsignal(_in)
    local wire_signal = io.wire_find_signal('red', signal)
    io.register_set(io.make_value(1), wire_signal)
  end,
  fig = function(_)
    assert.one(_)
    local _in = _[1]
    assert.in_register(_in)
    local signal = io.getsignal(_in)
    local wire_signal = io.wire_find_signal('green', signal)
    io.register_set(io.make_value(1), wire_signal)
  end,
  swp = function(_)
    assert.two(_)
    local _in = _[1]
    assert.in_register(_in)
    local _out = _[2]
    assert.out_register(_out)
    local inSignal = io.getsignal(_in)
    local outSignal = io.getsignal(_out)
    io.setsignal(_in, outSignal)
    io.setsignal(_out, inSignal)
  end,
  bnd = function(_)
    local _in, _out = standard_op(_)
    local result = bit32.band(io.getcount(_in), io.getcount(_out))
    io.register_set_count(io.make_value(1), result)
  end,
  bor = function(_)
    local _in, _out = standard_op(_)
    local result = bit32.bor(io.getcount(_in), io.getcount(_out))
    io.register_set_count(io.make_value(1), result)
  end,
  bxr = function(_)
    local _in, _out = standard_op(_)
    local result = bit32.bxor(io.getcount(_in), io.getcount(_out))
    io.register_set_count(io.make_value(1), result)
  end,
  bls = function(_)
    local _in, _out = standard_op(_)
    local result = bit32.lshift(io.getcount(_in), io.getcount(_out))
    io.register_set_count(io.make_value(1), result)
  end,
  brs = function(_)
    local _in, _out = standard_op(_)
    local result = bit32.rshift(io.getcount(_in), io.getcount(_out))
    io.register_set_count(io.make_value(1), result)
  end,
  blr = function(_)
    local _in, _out = standard_op(_)
    local result = bit32.lrotate(io.getcount(_in), io.getcount(_out))
    io.register_set_count(io.make_value(1), result)
  end,
  brr = function(_)
    local _in, _out = standard_op(_)
    local result = bit32.rrotate(io.getcount(_in), io.getcount(_out))
    io.register_set_count(io.make_value(1), result)
  end,
  bno = function(_)
    assert.one(_)
    local _in = _[1]
    assert.reg_or_val(_in)
    local result = bit32.bnot(io.getcount(_in))
    io.register_set_count(io.make_value(1), result)
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
    if io.register_get(_in).signal.name == io.register_get(_out).signal.name then
      return { type = 'skip' }
    end
  end,
  ttn = function(_)
    assert.two(_)
    local _in = _[1]
    assert.in_mem(_in)
    local _out = _[2]
    assert.out_mem(_out)
    if io.register_get(_in).signal.name ~= io.register_get(_out).signal.name then
      return { type = 'skip' }
    end
  end,
  dig = function(_)
    assert.one(_)
    local _in = _[1]
    assert.reg_or_val(_in)
    local i = io.getcount(_in)
    local value = io.register_get(io.make_value(1)).count
    local digit = tonumber(string.sub(tostring(value), -i, -i))
    io.register_set_count(io.make_value(1), digit)
  end,
  dis = function(_)
    assert.two(_)
    local _in = _[1]
    assert.reg_or_val(_in)
    local _out = _[2]
    assert.out_mem_or_val(_out)
    local str_value = tostring(io.register_get(io.make_value(1)).count)
    local selector = string.len(str_value) - io.getcount(_in) + 1
    local digit = io.getcount(_out)
    local p1 = string.sub(str_value, 1, selector-1)
    local p2 = string.sub(str_value, selector, selector)
    local p3 = string.sub(str_value, selector+1, -1)
    p2 = string.sub(tostring(digit), -1)
    io.register_set_count(io.make_value(1), tonumber(p1..p2..p3))
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
