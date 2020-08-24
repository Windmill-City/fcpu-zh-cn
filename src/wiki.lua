
remote.add_interface("fcpu", {
  informatron_menu = function(data)
    return fcpu_menu(data.player_index)
  end,
  informatron_page_content = function(data)
    return fcpu_page_content(data.page_name, data.player_index, data.element)
  end
})

function fcpu_menu(player_index)
  return {
    ['Docs']={
      ['Specs']=1,
      ['Description']={
        ['Program']=1,
        ['Registers'] = 1,
      },
      ['Arrays\\indirect addressing']=1,
      ['Control signals']=1,
      ['Mnemonics']={
        ['Legend']=1,
        ['Common']=1,
        ['Swap']=1,
        ['Arithmetic']=1,
        ['Trigonometry']=1,
        ['Bitwise']=1,
        ['Testing operands values']=1,
        ['Testing operands types']=1,
        ['Flow control']=1,
      },
    },
    ['Examples']=1,
    ['Community']=1,
    ['TODOs']=1,
    ['Dear supporters']=1,
    ['Support fCPU']=1,
  }
end

local Text_readme = require('src/wiki/readme')

function fcpu_page_content(page_name, player_index, element)
  if page_name == "fcpu" then
    element.add{type="label", name="text_1", caption={"fcpu.page_fcpu_text_1"}}
    element.add{type="button", name="image_1", style="fcpu_image_1"}
    element.add{type="label", name="text_2", caption=Text_readme}
  end

  if page_name == "penguin" then
    element.add{type="label", name="text_1", caption={"fcpu.page_penguin_text_1"}}
    local image_container = element.add{type="frame", name="image_1", style="informatron_image_container", direction="vertical"}
    image_container.add{type="button", name="image_1", style="fcpu_image_1"}
  end

  if page_name == "corvid" or page_name == "crow" or page_name == "raven" or page_name == "jay" then
    element.add{type="label", name="text_1", caption={"fcpu.page_"..page_name.."_text_1"}}
  end

end
