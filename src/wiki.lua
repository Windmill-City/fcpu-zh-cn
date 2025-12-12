local have_informatron = Compatibility['informatron']
local have_booktorio = Compatibility['Booktorio']

if have_informatron or have_booktorio then
  local ReadmeL10n = {
    ['en'] = require('src/wiki/readme.en.src.lua'),
    ['ru'] = require('src/wiki/readme.ru.src.lua'),
  }
  local md2frt = require('src/wiki/md2frt')

  function switch_locale(locale)
    locale = locale or 'en'

    local Source_readme = ReadmeL10n[locale] or ReadmeL10n['en']

    local fulltext
    local mdstate

    fulltext, mdstate = md2frt.render(Source_readme)
    local sections = md2frt.renderSections(mdstate)

    Compatibility.wiki_register(sections, fulltext)
    return locale
  end

  storage.gui_locale = switch_locale(storage.gui_locale)

  ---@param e {player_index:int32, old_locale:string, name:string, tick:int32}
  function on_player_locale_changed(e)
    local player = game.players[e.player_index]
    if storage.gui_locale ~= player.locale then
      storage.gui_locale = switch_locale(player.locale)
    end
  end

  script.on_event(defines.events.on_player_locale_changed, on_player_locale_changed)
end
