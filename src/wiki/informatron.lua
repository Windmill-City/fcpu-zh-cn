local Text_readme = nil
local Source_readme = require('src/wiki/readme.src.lua')
local md2frt = require('src/wiki/md2frt')
local wiki_menu
local wiki_pages

local font_map = function(section)
  local m = {
    '',
    '',
    '',
  }
  local level = math.max(1, math.min(section.level - 0, #m))
  return m[level] .. section.header
end

-- TODO: optimize odd manipulations
local function fcpu_load_docs(force)
  if wiki_menu == nil or wiki_pages == nil or force then
    local mdstate

    Text_readme, mdstate = md2frt.render(Source_readme)
    local sections = md2frt.renderSections(mdstate)

    wiki_menu = {}
    wiki_pages = {}

    local number = 0
    local stack = {}

    for _, v in ipairs(sections) do
      number = number + 1
      local id = string.gsub(string.lower(v.header), '[^%w]+', '-')
      if id ~= 'fcpu' then
        local top = stack[#stack]
        if not top then
          stack[#stack + 1] = { id = id, l = v.level }
        elseif top.l == v.level then
          stack[#stack + 1] = { id = id, l = v.level }
        elseif top.l < v.level then
          top[#top + 1] = { id = id, l = v.level }
        else
          stack[#stack] = nil
        end
      end
      wiki_pages[id] = {
        title = font_map(v),
        content = v.content
      }
    end

    local unmap
    unmap = function(stack)
      if 0 < #stack then
        local m = {}
        for _, v in ipairs(stack) do
          m[v.id] = unmap(v)
        end
        return m
      end
      return 1
    end

    wiki_menu = unmap(stack)
  end
end

function fcpu_menu(player_index)
  return wiki_menu
end

function fcpu_menu_caption_override(page_name, player_index)
  return wiki_pages[page_name] and wiki_pages[page_name].title or nil
end

function fcpu_title_caption_override(page_name, player_index)
  return wiki_pages[page_name] and wiki_pages[page_name].title or nil
end

function fcpu_page_content(page_name, player_index, element)
  if wiki_pages[page_name] then
    local content = wiki_pages[page_name].content

    element.add{type="button", name="image_1", style="fcpu_image_1"}

    if page_name == "fcpu" then
        element.add{type="label", name="text_2", caption=Text_readme}
    elseif content then
      element.add{type="label", name="text_content", caption=content}
    end
  end

  if page_name == "penguin" then
    element.add{type="label", name="text_1", caption={"fcpu.page_penguin_text_1"}}
    local image_container = element.add{type="frame", name="image_1", style="informatron_image_container", direction="vertical"}
    image_container.add{type="button", name="image_1", style="fcpu_image_1"}
  end
end

fcpu_load_docs()

remote.add_interface("fcpu", {
  informatron_menu = function(data)
    return fcpu_menu(data.player_index)
  end,
  informatron_menu_caption_override = function(data)
    return fcpu_menu_caption_override(data.page_name, data.player_index)
  end,
  informatron_title_caption_override = function(data)
    return fcpu_title_caption_override(data.page_name, data.player_index)
  end,
  informatron_page_content = function(data)
    return fcpu_page_content(data.page_name, data.player_index, data.element)
  end,
})
