-- fCPU 简体中文维基覆盖
-- 本模组在 fCPU 之后加载，重新注册 fCPU 的 "fcpu" remote interface，
-- 使 Informatron 渲染简体中文维基，而非 fCPU 自带的英文内容。

local active_mods = script.active_mods

local have_informatron = active_mods['informatron']

if have_informatron then
  local md2frt = require('wiki/md2frt')
  local ReadmeZh = require('wiki/readme_zh')

  local function locale_renderer(locale)
    local fulltext, mdstate = md2frt.render(ReadmeZh)
    local sections = md2frt.renderSections(mdstate)

    return sections, fulltext
  end

  -- Informatron：覆盖 fCPU 注册的 "fcpu" 接口
  require('compat/informatron').wiki_register(locale_renderer)
end
