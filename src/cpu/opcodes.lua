local assert
local addr


local standard_op = function(_)
  assert.two(_)
  local _in = _[1]
  assert.in_mem_or_val(_in)
  local _out = _[2]
  assert.out_mem_or_val(_out)
  return _in, _out
end
local test_op = function(_)
  assert.two(_)
  local _in = _[1]
  assert.in_mem_or_val(_in)
  local _out = _[2]
  assert.out_mem_or_val(_out)
  return _in, _out
end


local opcodes = {
  -- W = wire
  -- I = integer constant
  -- M = memory register
  -- O = output register
  -- R = Register (memory or output)
  -- + = zero, one or more parameters
  nop = function(_)
  end,
  mov = function(_) -- MOV W/R R -- Move
    local _in = _[1]
    assert.in_register_or_wire(_in)

    local out_val = nil
    if _in.type == 'wire' then
      out_val = addr.getwire(_in)
    elseif _in.type == 'register' then
      out_val = addr.getregister(_in)
    end

    if #_ > 2 then
      for i = 2, #_ do
        assert.out_register(_[i])
        addr.setregister(_[i], out_val)
      end
    else
      local _out = _[2]
      assert.out_register(_out)
      addr.setregister(_out, out_val)
    end
  end,
  set = function(_) -- SET M/I R -- Set Count
    assert.two(_)
    local _in = _[1]
    assert.in_mem_or_val(_in)
    local _out = _[2]
    assert.out_register(_out)
    if _in.type == 'register' then
      addr.setregister_count(_out, addr.getregister(_in).count)
    elseif _in.type == 'num' then
      addr.setregister_count(_out, address.num(_in))
    end
  end,
  clr = function(_) -- CLR R+ -- Clear
    if #_ > 0 then
      for i, expr in ipairs(_) do
        addr.setregister(_[i], NULL_SIGNAL)
      end
    else
      for i = 1, addr.memsize() do
        addr.setraw(i, NULL_SIGNAL)
      end
      addr.setout(NULL_SIGNAL)
    end
  end,
  fir = function(_) -- FIR R -- Find (from) Red
    assert.one(_)
    local _in = _[1]
    assert.in_register(_in)
    local signal = addr.getregister(_in)
    local wire_signal = addr.find_signal_in_wire(wires.red, signal)
    addr.setmem(addr.const_num(1), wire_signal)
  end,
  fig = function(_) -- FIG R -- Find (from) Green
    assert.one(_)
    local _in = _[1]
    assert.in_register(_in)
    local signal = addr.getregister(_in)
    local wire_signal = addr.find_signal_in_wire(wires.green, signal)
    addr.setmem(addr.const_num(1), wire_signal)
  end,
  swp = function(_) -- SWP R R -- Swap
    assert.two(_)
    local _in = _[1]
    assert.in_register(_in)
    local _out = _[2]
    assert.out_register(_out)
    local inSignal = addr.getregister(_in)
    local outSignal = addr.getregister(_out)
    addr.setregister(_in, outSignal)
    addr.setregister(_out, inSignal)
  end,
  add = function(_) -- ADD M/I M/I -- Add
    local _in, _out = standard_op(_)
    addr.setmem_count(addr.const_num(1), addr.memcount_or_val(_in) + addr.memcount_or_val(_out))
  end,
  sub = function(_) -- SUB M/I M/I -- Subtract
    local _in, _out = standard_op(_)
    addr.setmem_count(addr.const_num(1), addr.memcount_or_val(_in) - addr.memcount_or_val(_out))
  end,
  mul = function(_) -- MUL M/I M/I -- Multiply
    local _in, _out = standard_op(_)
    addr.setmem_count(addr.const_num(1), addr.memcount_or_val(_in) * addr.memcount_or_val(_out))
  end,
  div = function(_) -- DIV M/I M/I -- Divide
    local _in, _out = standard_op(_)
    addr.setmem_count(addr.const_num(1), addr.memcount_or_val(_in) / addr.memcount_or_val(_out))
  end,
  mod = function(_) -- MOD M/I M/I -- Modulo
    local _in, _out = standard_op(_)
    addr.setmem_count(addr.const_num(1), addr.memcount_or_val(_in) % addr.memcount_or_val(_out))
  end,
  pow = function(_) -- POW M/I M/I -- Exponetiation
    local _in, _out = standard_op(_)
    addr.setmem_count(addr.const_num(1), addr.memcount_or_val(_in) ^ addr.memcount_or_val(_out))
  end,
  bnd = function(_) -- BND M/I M/I -- Bitwise AND
    local _in, _out = standard_op(_)
    local result = bit32.band(addr.memcount_or_val(_in), addr.memcount_or_val(_out))
    addr.setmem_count(addr.const_num(1), result)
  end,
  bor = function(_) -- BOR M/I M/I -- Bitwise OR
    local _in, _out = standard_op(_)
    local result = bit32.bor(addr.memcount_or_val(_in), addr.memcount_or_val(_out))
    addr.setmem_count(addr.const_num(1), result)
  end,
  bxr = function(_) -- BXR M/I M/I -- Bitwise XOR
    local _in, _out = standard_op(_)
    local result = bit32.bxor(addr.memcount_or_val(_in), addr.memcount_or_val(_out))
    addr.setmem_count(addr.const_num(1), result)
  end,
  bls = function(_) -- BLS M/I M/I -- Bitwise left shift
    local _in, _out = standard_op(_)
    local result = bit32.lshift(addr.memcount_or_val(_in), addr.memcount_or_val(_out))
    addr.setmem_count(addr.const_num(1), result)
  end,
  brs = function(_) -- BRS M/I M/I -- Bitwise right shift
    local _in, _out = standard_op(_)
    local result = bit32.rshift(addr.memcount_or_val(_in), addr.memcount_or_val(_out))
    addr.setmem_count(addr.const_num(1), result)
  end,
  blr = function(_) -- BLR M/I M/I -- Bitwise left rotate
    local _in, _out = standard_op(_)
    local result = bit32.lrotate(addr.memcount_or_val(_in), addr.memcount_or_val(_out))
    addr.setmem_count(addr.const_num(1), result)
  end,
  brr = function(_) -- BRR M/I M/I -- Bitwise right rotate
    local _in, _out = standard_op(_)
    local result = bit32.rrotate(addr.memcount_or_val(_in), addr.memcount_or_val(_out))
    addr.setmem_count(addr.const_num(1), result)
  end,
  bno = function(_) -- BNO M/I M/I -- Bitwise NOT
    assert.one(_)
    local _in = _[1]
    assert.in_mem_or_val(_in)
    local result = bit32.bnot(addr.memcount_or_val(_in))
    addr.setmem_count(addr.const_num(1), result)
  end,
  slp = function(_) -- SLP M/I -- Sleep
    assert.one(_)
    local _in = _[1]
    assert.in_mem_or_val(_in)
    return { type = "sleep", val = addr.memcount_or_val(_in) }
  end,
  jmp = function(_) -- JMP M/I/L -- Jump
    assert.one(_)
    local _in = _[1]
    assert.in_mem_or_val_or_label(_in)
    if _in.type == 'label' then
      return { type = "jump", label = _in.label }
    else
      return { type = "jump", val = addr.memcount_or_val(_in) }
    end
  end,
  hlt = function(_) -- HLT -- Halt
    return { type = "halt" }
  end,
  tgt = function(_) -- TGT M/I M/I -- Test Greater Than
    local _in, _out = test_op(_)
    if addr.memcount_or_val(_in) > addr.memcount_or_val(_out) then
      return { type = "skip" }
    end
  end,
  tlt = function(_) -- TLT M/I M/I -- Test Less Than
    local _in, _out = test_op(_)
    if addr.memcount_or_val(_in) < addr.memcount_or_val(_out) then
      return { type = "skip" }
    end
  end,
  teq = function(_) -- TEQ M/I M/I -- Test Equal (Signal count)
    local _in, _out = test_op(_)
    if addr.memcount_or_val(_in) == addr.memcount_or_val(_out) then
      return { type = "skip" }
    end
  end,
  tnq = function(_) -- TNG M/I M/I -- Test Not Equal (Signal count)
    local _in, _out = test_op(_)
    if addr.memcount_or_val(_in) ~= addr.memcount_or_val(_out) then
      return { type = "skip" }
    end
  end,
  tte = function(_) -- TTE M M -- Test Equal (Signal type)
    assert.two(_)
    local _in = _[1]
    assert.in_mem(_in)
    local _out = _[2]
    assert.out_mem(_out)
    if addr.getmem(_in).signal.name == addr.getmem(_out).signal.name then
      return { type = "skip" }
    end
  end,
  ttn = function(_) -- TTN M M -- Test Not Equal (Signal type)
    assert.two(_)
    local _in = _[1]
    assert.in_mem(_in)
    local _out = _[2]
    assert.out_mem(_out)
    if addr.getmem(_in).signal.name ~= addr.getmem(_out).signal.name then
      return { type = "skip" }
    end
  end,
  dig = function(_) -- DIG M/I -- Get Digit (from memory1)
    assert.one(_)
    local _in = _[1]
    assert.in_mem_or_val(_in)
    local i = addr.memcount_or_val(_in)
    local value = addr.getmem(addr.const_num(1)).count
    local digit = tonumber(string.sub(tostring(value), -i, -i))
    addr.setmem_count(addr.const_num(1), digit)
  end,
  dis = function(_) -- DIS M/I M/I -- Set Digit (in memory1)
    assert.two(_)
    local _in = _[1]
    assert.in_mem_or_val(_in)
    local _out = _[2]
    assert.out_mem_or_val(_out)
    local str_value = tostring(addr.getmem(addr.const_num(1)).count)
    local selector = string.len(str_value) - addr.memcount_or_val(_in) + 1
    local digit = addr.memcount_or_val(_out)
    local p1 = string.sub(str_value, 1, selector-1)
    local p2 = string.sub(str_value, selector, selector)
    local p3 = string.sub(str_value, selector+1, -1)
    p2 = string.sub(tostring(digit), -1)
    addr.setmem_count(addr.const_num(1), tonumber(p1..p2..p3))
  end,
  bkr = function(_) -- BKR M/I -- Block until there are at least [a] red signals.
    assert.one(_)
    local _in = _[1]
    assert.in_mem_or_val(_in)
    local count = addr.memcount_or_val(_in)
    if wires.red.signals == nil or #wires.red.signals < count then
      return {type = "block"}
    end
  end,
  bkg = function(_) -- BKG M/I -- Block until there are at least [a] green signals.
    assert.one(_)
    local _in = _[1]
    assert.in_mem_or_val(_in)
    local count = addr.memcount_or_val(_in)
    if wires.green.signals == nil or #wires.green.signals < count then
      return {type = "block"}
    end
  end,
}


function opcodes.bind(assert_, addr_)
  assert = assert_
  addr = addr_
end
return opcodes
