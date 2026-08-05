-- 本地变量：locale_renderer 回调（由 control.lua 注入，负责把 markdown 渲染成章节）
local LocaleRenderer

-- 按语言缓存渲染结果，避免每次 GUI 刷新都重复渲染维基
local docs_cache = {}

-- 把 markdown 章节列表构建成层级菜单树，并扁平化存入页面表，返回新建的文档结构
local function fcpu_load_docs(sections)
  -- wiki_menu 菜单树、wiki_pages 页面表、wiki_home 首页 id
  local docs = {
    wiki_menu = {},
    wiki_pages = {},
  }
  local stack = {}
  local home_id

  -- 遍历每个章节，按标题层级组织父子关系
  for _, v in ipairs(sections) do
    local id = string.lower(v.header)
    local top = stack[#stack]
    if not top then
      -- 栈空：作为根节点入栈，并记录第一个一级标题为首页
      stack[#stack + 1] = { id = id, l = v.level }
      if tonumber(v.level) == 1 and not home_id then
        home_id = id
      end
    elseif top.l == v.level then
      -- 同级标题：作为兄弟节点入栈
      stack[#stack + 1] = { id = id, l = v.level }
    elseif top.l < v.level then
      -- 更深层级：追加为栈顶的子节点并入栈
      top[#top + 1] = { id = id, l = v.level }
    else
      -- 更浅层级：弹出栈顶，等下一轮循环继续判断
      stack[#stack] = nil
    end
    -- 扁平保存页面，供按 id 直接查找
    docs.wiki_pages[id] = {
      title = v.header,
      content = v.content
    }
  end

  -- 递归把树节点转换成纯 id 映射（叶子为 1），供 Informatron 菜单使用
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

  docs.wiki_menu = unmap(stack)
  docs.wiki_home = home_id

  return docs
end

-- 渲染维基内容并构建文档结构（同一语言只渲染一次）
local function render_docs(locale)
  local docs = docs_cache[locale]
  if not docs then
    local sections, fulltext = LocaleRenderer(locale)
    docs = fcpu_load_docs(sections)
    docs.wiki_readme = fulltext
    docs_cache[locale] = docs
  end
  return docs
end

-- 取玩家语言对应的文档结构
local function docs_for_player(player_index)
  return render_docs(game.players[player_index].locale)
end

-- 页面标题，无此页时返回 nil（菜单项与标题栏共用）
local function caption_override(docs, page_name)
  local page = docs.wiki_pages[page_name]
  return page and page.title
end

-- 渲染页面内容到 Informatron 的 GUI 元素上
local function fcpu_page_content(docs, page_name, element)
  if page_name == "fcpu" then
    -- 首页：显示首页章节内容，缺省时回退到全文
    local home = docs.wiki_home and docs.wiki_pages[docs.wiki_home]
    element.add{type="button", name="image_1", style="fcpu-zh-cn-thumbnail"}
    element.add{type="label", name="text_2", caption=home and home.content or docs.wiki_readme}
  elseif docs.wiki_pages[page_name] then
    -- 普通页面：显示对应章节正文
    element.add{type="button", name="image_1", style="fcpu-zh-cn-thumbnail"}
    element.add{type="label", name="text_content", caption=docs.wiki_pages[page_name].content}
  end

  if page_name == "penguin" then
    -- 企鹅页：附加说明文本和图片容器
    element.add{type="label", name="text_1", caption={"fcpu.page_penguin_text_1"}}
    local image_container = element.add{type="frame", name="image_1", style="informatron_image_container", direction="vertical"}
    image_container.add{type="button", name="image_1", style="fcpu-zh-cn-thumbnail"}
  end
end

-- 标题覆盖回调：菜单项与标题栏共用同一实现
local function caption_handler(data)
  return caption_override(docs_for_player(data.player_index), data.page_name)
end

-- 覆盖 fCPU 已注册的 "fcpu" remote 接口，使 Informatron 使用中文维基。
local function fcpu_wiki_informatron_register(locale_renderer)
  LocaleRenderer = locale_renderer

  remote.remove_interface("fcpu")
  remote.add_interface("fcpu", {
    informatron_menu = function(data)
      return docs_for_player(data.player_index).wiki_menu
    end,
    informatron_menu_caption_override = caption_handler,
    informatron_title_caption_override = caption_handler,
    informatron_page_content = function(data)
      return fcpu_page_content(docs_for_player(data.player_index), data.page_name, data.element)
    end,
  })
end

return {
  wiki_register = fcpu_wiki_informatron_register,
}
