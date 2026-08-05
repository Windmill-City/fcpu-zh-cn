-- fCPU 简体中文维基覆盖
-- 本模组在 fCPU 之后加载，重新注册 fCPU 的 "fcpu" remote interface，
-- 使 Informatron / Booktorio 渲染简体中文维基，而非 fCPU 自带的英文内容。

local active_mods = script.active_mods or {}

local have_informatron = active_mods['informatron']
local have_booktorio = active_mods['booktorio']

if have_informatron or have_booktorio then
  local md2frt = require('wiki/md2frt')
  local ReadmeZh = require('wiki/readme.zh')

  local RenderedCache = {}

  local function locale_renderer(locale)
    locale = locale or 'en'

    if not RenderedCache[locale] then
      local fulltext, mdstate = md2frt.render(ReadmeZh)
      local sections = md2frt.renderSections(mdstate)

      RenderedCache[locale] = {
        ['fulltext'] = fulltext,
        ['sections'] = sections,
      }
    end

    return RenderedCache[locale].sections, RenderedCache[locale].fulltext
  end

  -- Informatron：覆盖 fCPU 注册的 "fcpu" 接口（本模组加载更晚，接口方法以后注册者为准）
  if have_informatron then
    require('compat/informatron').wiki_register(locale_renderer)
  end

  -- Booktorio：额外添加一份简体中文手册
  if have_booktorio then
    local booktorio = require('compat/Booktorio')
    booktorio.wiki_register(locale_renderer)

    script.on_init(function()
      booktorio.on_init()
    end)
    script.on_configuration_changed(function()
      booktorio.on_configuration_changed()
    end)
  end
end
