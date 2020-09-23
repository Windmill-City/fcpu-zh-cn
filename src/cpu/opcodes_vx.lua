local hdlbuilder
local assert
local io


local function vector_scalar_op(operand)
  return function(_, ics)
    if ics and ics.out then
      local src = operand or io.getcount(_[2])

      local control = ics.out.get_or_create_control_behavior()
      local params = control.parameters
      params.parameters.second_constant = src
      control.parameters = params
    end
  end
end

local opcodes_vx = {
-- S: Signal
-- T: signal type
-- V: signal value, same as C
-- C: integer constant, same as V
-- M: memory
-- I: input wire (Red, Green)
-- O: output wire
-- A: instruction address
-- L: instruction label

  xwait = function(_, ics)
    return {type='xwait'}
  end,

  xmov = function(_, ics)
    assert.two(_)
    return 'deffer'
  end,

  xadd = vector_scalar_op(),
  xsub = vector_scalar_op(),
  xmul = vector_scalar_op(),
  xdiv = vector_scalar_op(),
  xmod = vector_scalar_op(),
  xpow = vector_scalar_op(),
  xinc = vector_scalar_op(1),
  xdec = vector_scalar_op(1),

  xand = vector_scalar_op(),
  xor  = vector_scalar_op(),
  xxor = vector_scalar_op(),
  xsl  = vector_scalar_op(),
  xsr  = vector_scalar_op(),
}


function opcodes_vx.bind(assert_, io_, hdlbuilder_)
  hdlbuilder = hdlbuilder_
  assert = assert_
  io = io_
end
return opcodes_vx
