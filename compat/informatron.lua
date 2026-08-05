local LocaleRenderer
local LocaleCache = {}

local font_map = function(section)
  return section.header
end

-- TODO: optimize odd manipulations
local function fcpu_load_docs(locale, sections)
  local cache = LocaleCache[locale]

  cache.wiki_menu = {}
  cache.wiki_pages = {}

  local stack = {}
  local home_id

  for _, v in ipairs(sections) do
    local id = string.lower(v.header)
    local top = stack[#stack]
    if not top then
      stack[#stack + 1] = { id = id, l = v.level }
      if tonumber(v.level) == 1 and not home_id then
        home_id = id
      end
    elseif top.l == v.level then
      stack[#stack + 1] = { id = id, l = v.level }
    elseif top.l < v.level then
      top[#top + 1] = { id = id, l = v.level }
    else
      stack[#stack] = nil
    end
    cache.wiki_pages[id] = {
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

  cache.wiki_menu = unmap(stack)
  cache.wiki_home = home_id
end

local function verify_parsed(locale)
  local cache = LocaleCache[locale] or {}
  LocaleCache[locale] = cache

  local sections, fulltext = LocaleRenderer(locale)
  fcpu_load_docs(locale, sections)
  cache.wiki_readme = fulltext

  return cache
end

local function locale_cache_for_player(player_index)
  return verify_parsed(game.players[player_index].locale)
end

local function fcpu_menu(player_index)
  local cache = locale_cache_for_player(player_index)
  return cache.wiki_menu
end

local function fcpu_menu_caption_override(page_name, player_index)
  local cache = locale_cache_for_player(player_index)
  return cache.wiki_pages[page_name] and cache.wiki_pages[page_name].title or nil
end

local function fcpu_title_caption_override(page_name, player_index)
  local cache = locale_cache_for_player(player_index)
  return cache.wiki_pages[page_name] and cache.wiki_pages[page_name].title or nil
end

local function fcpu_page_content(page_name, player_index, element)
  local cache = locale_cache_for_player(player_index)

  if page_name == "fcpu" then
    local home = cache.wiki_home and cache.wiki_pages[cache.wiki_home]
    element.add{type="picture", name="image_1", sprite="fcpu-zh-cn-thumbnail"}
    element.add{type="label", name="text_2", caption=home and home.content or cache.wiki_readme}
  elseif cache.wiki_pages[page_name] then
    element.add{type="picture", name="image_1", sprite="fcpu-zh-cn-thumbnail"}
    element.add{type="label", name="text_content", caption=cache.wiki_pages[page_name].content}
  end

  if page_name == "penguin" then
    element.add{type="label", name="text_1", caption={"fcpu.page_penguin_text_1"}}
    local image_container = element.add{type="frame", name="image_1", style="informatron_image_container", direction="vertical"}
    image_container.add{type="picture", name="image_1", sprite="fcpu-zh-cn-thumbnail"}
  end
end

local function fcpu_wiki_informatron_register(locale_renderer)
  LocaleRenderer = locale_renderer

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
end

--return remote.interfaces["informatron"]
return {
  wiki_register = fcpu_wiki_informatron_register,
}