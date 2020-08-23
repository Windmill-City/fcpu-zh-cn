
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
    cat=1,
    dog=1,
    bird={
      penguin = 1,
      corvid = {
        crow=1,
        raven=1,
        jay=1
      },
    }
  }
end

function fcpu_page_content(page_name, player_index, element)
  if page_name == "fcpu" then
    element.add{type="label", name="text_1", caption={"fcpu.page_fcpu_text_1"}}
    element.add{type="button", name="image_1", style="fcpu_image_1"}
  end

  if page_name == "cat" then
    element.add{type="label", name="text_1", caption={"fcpu.page_cat_text_1"}}
  end

  if page_name == "dog" then
    element.add{type="label", name="text_1", caption={"fcpu.page_dog_text_1"}}
  end

  if page_name == "bird" then
    element.add{type="label", name="text_1", caption={"fcpu.page_bird_text_1"}}
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
