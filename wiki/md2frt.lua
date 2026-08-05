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
        return bufferedLine
    end
    bufferedLine = getline()
    return getline, function() return bufferedLine end
end

local lineDelimiters = {'`', '**', '*'}
local function findDelim(str, start, max)
    local delim = nil
    local min = 1/0
    local finish = 1/0
    for i = 1, #lineDelimiters do
        local pos, fin = find(str, lineDelimiters[i], start, true)
        if pos and pos < min and pos <= max then
            if sub(str, pos - 1, pos - 1) == '\\' then
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
            if sub(str, pos - 1, pos - 1) == '\\' then
                start = pos + 2
            else
                return pos, fin
            end
        else
            break
        end
    end
end

local function linkEscape(str, t)
    local nomatches = true
    for m1, m2, m3, m4 in gmatch(str, '([^%[]*)%[([^%]]+)%]%(([^%)]*)%)([^%[]*)') do
        if nomatches then
            t[#t + 1] = m1
            nomatches = false
        end
        t[#t + 1] = { m2, type = 'a', attributes = { href = m3 } }
        t[#t + 1] = m4
    end
    if nomatches then
        t[#t + 1] = str
    end
end

local lineDeimiterNames = {
    ['`'] = { type = 'font', attrs = 'fcpu-mono-small' },
    ['**'] = { type = 'font', attrs = 'default-bold' },
    ['*'] = { type = 'font', attrs = 'default-small' },
}
local function lineRead(str, start, finish)
    local factorio_escape_str = function(s)
        return {
            type = 'color',
            attributes = 'default',
            [1] = s
        }
    end

    start, finish = start or 1, finish or #str
    local searchIndex = start
    local tree = {}
    while true do
        local delim, dstart, dfinish = findDelim(str, searchIndex, finish)
        if not delim then
            local substr = sub(str, searchIndex, finish)
            substr = string.gsub(substr, '\\([`*])', '%1')
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
            subtree.type = args.type
            subtree.attributes = args.attrs
            tree[#tree + 1] = subtree

            searchIndex = nextdfinish + 1
        else
            tree[#tree + 1] = {
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
        if b == byte(' ') then
            level = level + 1
        elseif b == byte('\t') then
            level = level + 4
        else
            break
        end
    end
    return level
end

local function stripIndent(line, level)
    local currentLevel = -1
    for i = 1, #line do
        if byte(line, i) == byte("\t") then
            currentLevel = currentLevel + 4
        elseif byte(line, i) == byte(" ") then
            currentLevel = currentLevel + 1
        else
            return sub(line, i, -1)
        end
        if currentLevel == level then
            return sub(line, i, -1)
        elseif currentLevel > level then
            local front = ""
            for j = 1, currentLevel - level do front = front .. " " end
            return front .. sub(line, i, -1)
        end
    end
    return ''
end

local NEWLINE = '\n'

local PATTERN_EMPTY = "^%s*$"
local PATTERN_HEADER = "^%s*(%#+)%s*(.*)%#*$"
local PATTERN_CODEBLOCK = "^%s*%`%`%`(.*)"
local PATTERN_ULIST = "^%s*[%*%-] (.+)$"
local PATTERN_OLIST = "^%s*%d+%. (.+)$"

local PATTERNS = {
    PATTERN_EMPTY,
    PATTERN_HEADER,
    PATTERN_CODEBLOCK,
    PATTERN_ULIST,
    PATTERN_OLIST
}

local function isSpecialLine(line)
    for i = 1, #PATTERNS do
        if match(line, PATTERNS[i]) then return PATTERNS[i] end
    end
end

local function readSimple(next, peek, tree)
    local line = peek()
    if not line then return end

    if match(line, PATTERN_EMPTY) then
        return next()
    end

    local m, rest = match(line, PATTERN_HEADER)
    if m then
        local replace = {
            ['heading-1'] = 'default-large-bold',
            ['heading-2'] = 'heading-1',
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

    local syntax = match(line, PATTERN_CODEBLOCK)
    if syntax then
        local indent = getIndentLevel(line)
        local code = {
            type = { sub = "code" }
        }
        local pre = {
            type = "font",
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
        tree[#tree + 1] = NEWLINE
        return next()
    end

    local nextLine = next()
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

local readLineStream

local function readFragment(next, peek, recurse_level, indentstr, stop)
    local accum2 = {}
    local line = peek()
    local indent = getIndentLevel(line)
    while true do
        accum2[#accum2 + 1] = indentstr.. stripIndent(line, indent)
        line = next()
        if not line then break end
        if stop(line) then break end
    end
    local tree = {}
    readLineStream(tableLineStream(accum2), tree, recurse_level)
    return tree
end

local function readList(next, peek, tree, expectedIndent)
    local line = peek()
    if not line then return end

    local indent = getIndentLevel(line)
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
                local subtree = readFragment(next, peek, recurse_level + 1, string.rep(' ', i+6), function(l)
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

function readLineStream(stream, tree, recurse_level)
    local next, peek = bufferStream(stream)
    tree = tree or {}
    while peek() do
        if not readList(next, peek, tree, recurse_level) then
            readSimple(next, peek, tree)
        end
    end
    return tree
end

local function renderAttributes(attributes)
    local accum = {}
    for k, v in pairs(attributes) do
        accum[#accum + 1] = format("%s=%s", k, v)
    end
    return concat(accum, ' ')
end

local function renderTree(tree, accum)
    local open = tree.type
    local close = tree.type

    if type(tree.type) == 'table' then
        open = tree.type.open
        close = tree.type.close
    end

    if tree.type then
        local attribs = tree.attributes or {}

        local is_table = type(attribs) == 'table'

        if open == 'a' and is_table and attribs.href then
            open = nil
            close = nil
            attribs = {}
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
            renderTree(line, accum)
        end
    end
    if close then
        accum[#accum + 1] = format("[/%s]", close)
    end
end

local function renderTreeRaw(tree)
    local accum = {}
    renderTree(tree, accum)
    if accum[#accum] == NEWLINE then accum[#accum] = nil end
    return concat(accum), { tree = tree }
end

local function renderString(str)
    return renderTreeRaw(readLineStream(stringLineStream(str)))
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

    local emit = function()
        if 0 < #list then
            wiki_pages[#wiki_pages + 1] = {
                header = header[2][1][1],
                level = match(header.type.sub, 'h(%d+)'),
                content = renderTreeRaw(list)
            }
        end
        header = ''
        list = {}
    end

    for _, v in ipairs(mdstate.tree) do
        if type(v) == 'table' and type(v.type) == 'table' and find(v.type.sub, 'h%d+') then
            emit()
        end
        push(v)
    end
    emit()

    return wiki_pages
end

local function render(source)
    return renderString(source)
end

return {
    render = render,
    renderSections = renderSections,
}
