--[[
    Modified by KonStg <konstg.dev@gmail.com> in 2020 for rendering Factorio Rich Text
    and ingame wiki for mod (https://mods.factorio.com/mod/fcpu).
    Original code written by `Calvin Rose` (see below).

    Permission is hereby granted, free of charge, to any person obtaining a copy of
    this software and associated documentation files (the "Software"), to deal in
    the Software without restriction, including without limitation the rights to
    use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
    the Software, and to permit persons to whom the Software is furnished to do so,
    subject to the following conditions:
    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.
]]
--[[
Copyright (c) 2016 Calvin Rose <calsrose@gmail.com>
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

local concat = table.concat
local sub = string.sub
local match = string.match
local format = string.format
local gmatch = string.gmatch
local byte = string.byte
local find = string.find
local lower = string.lower
local tonumber = tonumber -- luacheck: no unused
local type = type
local pcall = pcall

--------------------------------------------------------------------------------
-- Stream Utils
--------------------------------------------------------------------------------

local function iff(c, a, b)
    if c then
        return a
    end
    return b
end

local function stringLineStream(str)
    return gmatch(str, "([^\n\r]*)\r?\n?")
end

local function tableLineStream(t)
    local index = 0
    return function()
        index = index + 1
        return t[index]
    end
end

local function bufferStream(linestream)
    local bufferedLine
    local getline = function()
        bufferedLine = linestream()
        if bufferedLine and find(bufferedLine, 'md2frt%-skip%-section%-begin') then
            repeat
                bufferedLine = linestream()
            until not bufferedLine or find(bufferedLine, 'md2frt%-skip%-section%-end')
            bufferedLine = linestream()
        end
        return bufferedLine
    end
    bufferedLine = getline()
    return getline, function() return bufferedLine end
end

--------------------------------------------------------------------------------
-- Line Level Operations
--------------------------------------------------------------------------------

local lineDelimiters = {'`', '__', '**', '_', '*', '~~'}
local function findDelim(str, start, max)
    local delim = nil
    local min = 1/0
    local finish = 1/0
    max = max or #str
    for i = 1, #lineDelimiters do
        local pos, fin = find(str, lineDelimiters[i], start, true)
        if pos and pos < min and pos <= max then
            if string.sub(str, pos - 1, pos - 1) == '\\' then
                start = pos + 2
            else
                min = pos
                finish = fin
                delim = lineDelimiters[i]
            end
        end
    end
    return delim, min, finish
end

local function findDelimEnd(str, delim, start)
    while start <= #str do
        local pos, fin = find(str, delim, start, true)
        if pos then
            if string.sub(str, pos - 1, pos - 1) == '\\' then
                start = pos + 2
            else
                return pos, fin
            end
        else
            break
        end
    end
end

local function externalLinkEscape(str, t)
    local nomatches = true
    for m1, m2, m3 in gmatch(str, '(!?)%[([^%]]*)%]%s*%[(%d+)%]') do
        if nomatches then t[#t + 1] = match(m1, '^(.-)!?$'); nomatches = false end
        if byte(m1, #m1) == byte '!' then
            t[#t + 1] = {type = 'img', attributes = {alt = m2}}
        else
            t[#t + 1] = {m2, type = 'a'}
        end
        t[#t + 1] = m3
    end
    if nomatches then t[#t + 1] = str end
end

local function linkEscape(str, t)
    local nomatches = true
    for m0, m1, m2, m3, m4 in gmatch(str, '([^!%[]*)(!?)%[([^%]]+)%]%(([^%)]*)%)([^!%[]*)') do
        if m0 and 0 < #m0 then
            t[#t + 1] = {m0}
        end
        if nomatches then externalLinkEscape(match(m1, '^(.-)!?$'), t); nomatches = false end
        if byte(m1, #m1) == byte '!' then
            t[#t + 1] = {type = 'img', attributes = {
                src = m3,
                alt = m2
            }, noclose = true}
        else
            t[#t + 1] = {m2, type = 'a', attributes = {href = m3}}
        end
        externalLinkEscape(m4, t)
    end
    if nomatches then externalLinkEscape(str, t) end
end

local lineDeimiterNames = {
    ['`'] = { type='font', attrs='fcpu-mono-small' }, --'code',
    ['__'] = { type='font', attrs='default-bold' }, --'strong',
    ['**'] = { type='font', attrs='default-bold' }, --'strong',
    ['_'] = { type='font', attrs='default-small' }, --'em',
    ['*'] = { type='font', attrs='default-small' }, --'em',
    ['~~'] = { type='font', attrs='default-tiny-bold' }, --'strike'
}
local function lineRead(str, start, finish)
    local factorio_escape_str = function(s, color)
        local r = s--string.gsub(s, '%[', '[color=default][[/color]')
        return {
            type = 'color',
            attributes = (color or 'default'),
            [1] = r
        }
    end

    start, finish = start or 1, finish or #str
    local searchIndex = start
    local tree = {}
    while true do
        local delim, dstart, dfinish = findDelim(str, searchIndex, finish)
        if not delim then
            local substr = sub(str, searchIndex, finish)
            substr = string.gsub(substr, '\\([`_%*~])', '%1')
            linkEscape(substr, tree)
            break
        end
        if dstart > searchIndex then
            linkEscape(sub(str, searchIndex, dstart - 1), tree)
        end
        local nextdstart, nextdfinish = findDelimEnd(str, delim, dfinish + 1)
        if nextdstart then
            local subtree
            if delim == '`' then
                subtree = { factorio_escape_str(sub(str, dfinish + 1, nextdstart - 1)) }
            else
                subtree = lineRead(str, dfinish + 1, nextdstart - 1)
            end

            local args = lineDeimiterNames[delim]
            if type(args) == 'table' then
                subtree.type = args.type
                subtree.attributes = args.attrs
            else
                subtree.type = args
            end
            tree[#tree + 1] = subtree

            searchIndex = nextdfinish + 1
        else
            tree[#tree + 1]  = {
                delim,
            }
            searchIndex = dfinish + 1
        end
    end
    return tree
end

local function getIndentLevel(line)
    local level = 0
    for i = 1, #line do
        local b = byte(line, i)
        if b == byte(' ') or b == byte('>') then
            level = level + 1
        elseif b == byte('\t') then
            level = level + 4
        else
            break
        end
    end
    return level
end

local function stripIndent(line, level, ignorepattern) -- luacheck: no unused args
    local currentLevel = -1
    for i = 1, #line do
        if byte(line, i) == byte("\t") then
            currentLevel = currentLevel + 4
        elseif byte(line, i) == byte(" ") or byte(line, i) == byte(">") then
            currentLevel = currentLevel + 1
        else
            return sub(line, i, -1)
        end
        if currentLevel == level then
            return sub(line, i, -1)
        elseif currentLevel > level then
            local front = ""
            for j = 1, currentLevel - level do front = front .. " " end -- luacheck: no unused args
            return front .. sub(line, i, -1)
        end
    end
    return ''
end

--------------------------------------------------------------------------------
-- Useful variables
--------------------------------------------------------------------------------
local NEWLINE = '\n'

--------------------------------------------------------------------------------
-- Patterns
--------------------------------------------------------------------------------

local PATTERN_EMPTY = "^%s*$"
local PATTERN_COMMENT = "^%s*<>"
local PATTERN_HEADER = "^%s*(%#+)%s*(.*)%#*$"
local PATTERN_RULE1 = "^%s?%s?%s?(-%s*-%s*-[%s-]*)$"
local PATTERN_RULE2 = "^%s?%s?%s?(*%s**%s**[%s*]*)$"
local PATTERN_RULE3 = "^%s?%s?%s?(_%s*_%s*_[%s_]*)$"
local PATTERN_CODEBLOCK = "^%s*%`%`%`(.*)"
local PATTERN_BLOCKQUOTE = "^%s*> (.*)$"
local PATTERN_ULIST = "^%s*[%*%-] (.+)$"
local PATTERN_OLIST = "^%s*%d+%. (.+)$"
local PATTERN_LINKDEF = "^%s*%[(.*)%]%s*%:%s*(.*)"

-- List of patterns
local PATTERNS = {
    PATTERN_EMPTY,
    PATTERN_COMMENT,
    PATTERN_HEADER,
    PATTERN_RULE1,
    PATTERN_RULE2,
    PATTERN_RULE3,
    PATTERN_CODEBLOCK,
    PATTERN_BLOCKQUOTE,
    PATTERN_ULIST,
    PATTERN_OLIST,
    PATTERN_LINKDEF
}

local function isSpecialLine(line)
    for i = 1, #PATTERNS do
        if match(line, PATTERNS[i]) then return PATTERNS[i] end
    end
end

--------------------------------------------------------------------------------
-- Simple Reading - Non Recursive
--------------------------------------------------------------------------------

local function readSimple(next, peek, tree, links)
    local line = peek()
    if not line then return end

    -- Test for Empty or Comment
    if match(line, PATTERN_EMPTY) or match(line, PATTERN_COMMENT) then
        return next()
    end

    -- Test for Header
    local m, rest = match(line, PATTERN_HEADER)
    if m then
        local replace = {
            ['heading-1'] = 'default-large-bold',
            ['heading-2'] = 'heading-1',
            ['heading-3'] = 'heading-2',
        }
        local heading = "heading-" .. #m
        tree[#tree + 1] = {
            NEWLINE,
            {
                lineRead(rest),
                type = 'font',
                attributes = replace[heading] or heading
            },
            type = { sub = 'h'.. #m }
        }
        tree[#tree + 1] = NEWLINE
        return next()
    end

    -- Test for Horizontal Rule
    if match(line, PATTERN_RULE1) or
       match(line, PATTERN_RULE2) or
       match(line, PATTERN_RULE3) then
        tree[#tree + 1] = { type = "hr", noclose = true }
        tree[#tree + 1] = NEWLINE
        return next()
    end

    -- Test for Code Block
    local syntax = match(line, PATTERN_CODEBLOCK)
    if syntax then
        local indent = getIndentLevel(line)
        local code = {
            type = { sub = "code" }
        }
        if #syntax > 0 then
            code.attributes = {
                class = format('language-%s', lower(syntax))
            }
        end
        local pre = {
            type = "font",-- "pre",
            attributes = "fcpu-mono-small",
            [1] = {
                [1] = code,
                type = 'color',
                attributes = 'default',
            },
        }
        tree[#tree + 1] = pre
        while not (match(next(), PATTERN_CODEBLOCK) and getIndentLevel(peek()) == indent) do
            code[#code + 1] = peek()
            code[#code + 1] = NEWLINE
        end
        return next()
    end

    -- Test for link definition
    local linkname, location = match(line, PATTERN_LINKDEF)
    if linkname then
        links[lower(linkname)] = location
        return next()
    end

    -- Test for header type two
    local nextLine = next()
    if nextLine and match(nextLine, "^%s*%=+$") then
        tree[#tree + 1] = {
            NEWLINE,
            lineRead(line),
            type = 'font', -- h1
            attributes = "heading-1"
        }
        return next()
    elseif nextLine and match(nextLine, "^%s*%-+$") then
        tree[#tree + 1] = {
            NEWLINE,
            lineRead(line),
            type = 'font', -- h2
            attributes = "heading-2"
        }
        return next()
    end

    -- Do Paragraph
    local p = {
        lineRead(line),
        NEWLINE,
        type = { sub = "p" }
    }
    tree[#tree + 1] = p
    while nextLine and not isSpecialLine(nextLine) do
        p[#p + 1] = lineRead(nextLine)
        p[#p + 1] = NEWLINE
        nextLine = next()
    end
    p[#p] = nil
    tree[#tree + 1] = NEWLINE
    return peek()

end

--------------------------------------------------------------------------------
-- Main Reading - Potentially Recursive
--------------------------------------------------------------------------------

local readLineStream

local function readFragment(next, peek, links, recurse_level, indentstr, stop, ...)
    local accum2 = {}
    local line = peek()
    local indent = getIndentLevel(line)
    while true do
        accum2[#accum2 + 1] = indentstr.. stripIndent(line, indent)
        line = next()
        if not line then break end
        if stop(line, ...) then break end
    end
    local tree = {}
    readLineStream(tableLineStream(accum2), tree, links, recurse_level)
    return tree
end

local function readList(next, peek, tree, links, expectedIndent)
    local line = peek()
    if not line then return end

    local indent = getIndentLevel(line)
    --if expectedIndent and indent ~= expectedIndent then return end
    local recurse_level = expectedIndent or 0

    local listPattern = (match(line, PATTERN_ULIST) and PATTERN_ULIST) or
                        (match(line, PATTERN_OLIST) and PATTERN_OLIST)
    if not listPattern then return end

    local list = {
        type = { sub = (listPattern == PATTERN_OLIST and "ol" or "ul") }
    }
    tree[#tree + 1] = list

    local items_number = 0
    local lineType = listPattern
    while lineType == listPattern do
        items_number = items_number + 1
        local indentstr = string.rep(' ', indent)

        list[#list + 1] = {
            indentstr.. iff(listPattern == PATTERN_OLIST, format('%2i ', items_number), '[virtual-signal=signal-dot] '),
            lineRead(match(line, lineType)),
            type = { sub = "li" }
        }

        line = next()
        if not line then break end
        lineType = isSpecialLine(line)

        if lineType ~= PATTERN_EMPTY then
            list[#list + 1] = NEWLINE
            local i = getIndentLevel(line)
            if i < indent then break end
            if i > indent then
                local subtree = readFragment(next, peek, links, recurse_level + 1, string.rep(' ', i+6), function(l)
                    if not l then return true end
                    local tp = isSpecialLine(l)
                    return tp ~= PATTERN_EMPTY and getIndentLevel(l) < i
                end)
                list[#list + 1] = subtree

                line = peek()
                if not line then break end
                lineType = isSpecialLine(line)
            end
        end
    end

    if line and isSpecialLine(line) == PATTERN_EMPTY or recurse_level == 0 then
        list[#list + 1] = NEWLINE
        tree[#tree + 1] = NEWLINE
    end

    return peek()
end

local function readBlockQuote(next, peek, tree, links, recurse_level)
    local line = peek()
    if match(line, PATTERN_BLOCKQUOTE) then
        local bq = readFragment(next, peek, links, recurse_level, nil, function(l)
            local tp = isSpecialLine(l)
            return tp and tp ~= PATTERN_BLOCKQUOTE
        end)
        bq.type = 'font' -- 'blockquote'
        bq.attributes = 'locale-pick'
        tree[#tree + 1] = bq
        return peek()
    end
end

function readLineStream(stream, tree, links, recurse_level)
    local next, peek = bufferStream(stream)
    tree = tree or {}
    links = links or {}
    while peek() do
        if not readBlockQuote(next, peek, tree, links, recurse_level) then
            if not readList(next, peek, tree, links, recurse_level) then
                readSimple(next, peek, tree, links)
            end
        end
    end
    return tree, links
end

local function read(str) -- luacheck: no unused
    return readLineStream(stringLineStream(str))
end

--------------------------------------------------------------------------------
-- Rendering
--------------------------------------------------------------------------------

local function renderAttributes(attributes)
    local accum = {}
    for k, v in pairs(attributes) do
        accum[#accum + 1] = format("%s=%s", k, v)
    end
    return concat(accum, ' ')
end

local function renderTree(tree, links, accum)
    local open = tree.type
    local close = tree.type

    if type(tree.type) == 'table' then
        open = tree.type.open
        close = tree.type.close
    end

    if tree.type then
        local attribs = tree.attributes or {}

        if open == 'a' and not attribs.href then attribs.href = links[lower(tree[1] or '')] or '' end
        if open == 'img' and not attribs.src then attribs.src = links[lower(attribs.alt or '')] or '' end

        local is_table = type(attribs) == 'table'

        if open == 'a' and is_table and attribs.href then
            open = nil
            close = nil
            attribs = {}
            -- open = 'url'
            -- close = 'url'
            -- attribs = attribs.href
            -- is_table = false
        end

        local attribstr
        if 0 < (is_table and table_size(attribs) or #attribs) then
            if is_table then
                attribstr = ' '.. renderAttributes(attribs)
            else
                attribstr = '='.. attribs
            end
        end
        if attribstr and #attribstr > 0 then
            accum[#accum + 1] = format("[%s%s]", open, attribstr)
        elseif open then
            accum[#accum + 1] = format("[%s]", open)
        end
    end
    for i = 1, #tree do
        local line = tree[i]

        if type(line) == "string" then
            accum[#accum + 1] = line
        elseif type(line) == "table" then
            if line.type and line.type.sub == 'p' then
                if tree[i - 1] == NEWLINE and tree[i - 2] and tree[i - 2].type and tree[i - 2].type.sub == 'p' then
                    accum[#accum + 1] = NEWLINE
                end
            end
            renderTree(line, links, accum)
        else
            error "Unexpected node while rendering tree."
        end
    end
    if not tree.noclose and close then
        accum[#accum + 1] = format("[/%s]", close)
    end
end

local function renderTreeRaw(tree, links, options)
    local accum = {}
    local head, tail, insertHead, insertTail, prependHead, appendTail = nil, nil, nil, nil, nil, nil
    if options then
        assert(type(options) == 'table', "Options argument should be a table.")
        if options.tag then
            tail = format('[/%s]', options.tag)
            if options.attributes then
                head = format('[%s %s]', options.tag, renderAttributes(options.attributes))
            else
                head = format('[%s]', options.tag)
            end
        end
        insertHead = options.insertHead
        insertTail = options.insertTail
        prependHead = options.prependHead
        appendTail = options.appendTail
    end
    accum[#accum + 1] = prependHead
    accum[#accum + 1] = head
    accum[#accum + 1] = insertHead
    renderTree(tree, links, accum)
    if accum[#accum] == NEWLINE then accum[#accum] = nil end
    accum[#accum + 1] = insertTail
    accum[#accum + 1] = tail
    accum[#accum + 1] = appendTail
    return concat(accum), { tree = tree, links = links }
end

local function renderLines(stream, options)
    local tree, links = readLineStream(stream)
    return renderTreeRaw(tree, links, options)
end

--------------------------------------------------------------------------------
-- Module
--------------------------------------------------------------------------------

local function pwrap(...)
    local status, value, state = pcall(...)
    if status then
        return value, state
    else
        return nil, value
    end
end

local function renderLineIterator(stream, options)
    return pwrap(renderLines, stream, options)
end

local function renderTable(t, options)
    return pwrap(renderLines, tableLineStream(t), options)
end

local function renderString(str, options)
    return pwrap(renderLines, stringLineStream(str), options)
end

local function renderSections(mdstate)
    local wiki_pages = {}
    local header = ''
    local list = {}

    local push = function(v)
        if header == '' then
            header = v
        else
            list[#list + 1] = v
        end
    end

    local emit = function(mdstate)
        if list and 0 < #list then
            wiki_pages[#wiki_pages + 1] = {
                header = header[2][1][1],
                level = string.match(header.type.sub, 'h(%d+)'),
                content = renderTreeRaw(list, mdstate.links)
            }
        end
        header = ''
        list = {}
    end

    for k,v in ipairs(mdstate.tree) do
      if type(v) == 'table' and type(v.type) == 'table' and string.find(v.type.sub, 'h%d+') then
        emit(mdstate)
      end
      push(v)
    end
    emit(mdstate)

    return wiki_pages
end

local renderers = {
    ['string'] = renderString,
    ['table'] = renderTable,
    ['function'] = renderLineIterator
}

local function render(source, options)
    local renderer = renderers[type(source)]
    if not renderer then return nil, "Source must be a string, table, or function." end
    return renderer(source, options)
end

return setmetatable({
    render = render,
    renderString = renderString,
    renderLineIterator = renderLineIterator,
    renderTable = renderTable,
    renderSections = renderSections
}, {
    __call = function(self, ...) -- luacheck: no unused args
        return render(...)
    end
})
