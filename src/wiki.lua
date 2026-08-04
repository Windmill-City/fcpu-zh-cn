local have_informatron = Compatibility['informatron']
local have_booktorio = Compatibility['Booktorio']

if have_informatron or have_booktorio then
  local ReadmeL10n = {
    ['en'] = require('src/wiki/readme.en.src.lua'),
    ['ru'] = require('src/wiki/readme.ru.src.lua'),
    ['zh-CN'] = require('src/wiki/readme.zh.src.lua'),
  }
  local md2frt = require('src/wiki/md2frt')

  local RenderedCache = {}

  function locale_renderer(locale)
    locale = locale or 'en'

    if not RenderedCache[locale] then
      local Source_readme = ReadmeL10n[locale] or ReadmeL10n['en']

      local fulltext
      local mdstate

      fulltext, mdstate = md2frt.render(Source_readme)
      local sections = md2frt.renderSections(mdstate)

      RenderedCache[locale] = {
        ['fulltext'] = fulltext,
        ['sections'] = sections,
      }
    end

    return RenderedCache[locale].sections, RenderedCache[locale].fulltext
  end

  Compatibility.wiki_register(locale_renderer)
--[[
  ---@param e {player_index:int32, old_locale:string, name:string, tick:int32}
  function on_player_locale_changed(e)
    local player_data, player = get_player_data(e.player_index)
    if player_data.gui_locale ~= player.locale then
      player_data.gui_locale = switch_locale(player.locale)
    end
  end

  script.on_event(defines.events.on_player_locale_changed, on_player_locale_changed)
]]
end
