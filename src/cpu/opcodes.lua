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
    local sig = io.getsignal(_[#_], {'signal', 'register', 'wire'})
    for i = 1, #_ - 1 do
      io.setsignal(_[i], sig, {'register', 'wire'})
    end
  end,

  add = function(_)
    local _src, _dst = standard_op(_)
    io.register_set_count(_dst, io.getcount(_dst) + io.getcount(_src))
  end,
  sub = function(_)
    local _src, _dst = standard_op(_)
    io.register_set_count(_dst, io.getcount(_dst) - io.getcount(_src))
  end,
  mul = function(_)
    local _src, _dst = standard_op(_)
    io.register_set_count(_dst, io.getcount(_dst) * io.getcount(_src))
  end,
  div = function(_)
    local _src, _dst = standard_op(_)
    io.register_set_count(_dst, io.getcount(_dst) / io.getcount(_src))
  end,
  mod = function(_)
    local _src, _dst = standard_op(_)
    io.register_set_count(_dst, io.getcount(_dst) % io.getcount(_src))
  end,
  pow = function(_)
    local _src, _dst = standard_op(_)
    io.register_set_count(_dst, io.getcount(_dst) ^ io.getcount(_src))
  end,
}

function opcodes.bind(assert_, io_)
  assert = assert_
  io = io_
end
return opcodes
