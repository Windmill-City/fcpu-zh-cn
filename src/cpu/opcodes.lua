local assert
local io


local standard_op = function(_)
  assert.two(_)
  local _dst = _[1]
  assert.is_register(_dst)
  local _src = _[2]
  assert.is_input_or_reg_or_val(_src)
  return _dst, _src
end
local test_op = function(_)
  assert.two(_)
  local _in = _[1]
  assert.reg_or_val(_in)
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

  mov = function(_) -- mov dst...[R/O] src[S/R/I]
    assert.two_or_more(_)
    local sig = io.getsignal(_[#_], {'signal', 'register', 'input'})
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

}

function opcodes.bind(assert_, io_)
  assert = assert_
  io = io_
end
return opcodes
