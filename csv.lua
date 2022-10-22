Csv = {}
Csv.__index = Csv

function Csv:new(path, key, hasHeader, separator)
   local obj = {}                       -- our new object
   setmetatable(obj,Csv)                -- make Csv handle lookup
   obj.path = path                      -- path to csv file
   obj.key = key or nil                 -- column name to use as key in dict.
   obj.hasHeader = hasHeader or false   -- use first line as header
   obj.separator = separator or ","     -- character to use as separator

   obj.header = {}                      -- array of column names
   obj.keyColumn = 1                    -- column index of key
   obj.lines = {}                       -- string array of lines in csv file
   obj.table = {}                       -- dictionary of csv content

   return obj
end

function Csv:load()
    local file = io.open(self.path, "r")
    if file == nil then
        error("File not found")
    end

    local arr = {}
    for line in file:lines() do
       table.insert (arr, line);
    end
    self.lines = arr

    return
end

function Csv:parse()
    if #self.lines > 0 then
        self:parseHeader()

        self.table = {}
        for lineIdx, line in ipairs(self.lines) do
            local rowValues = self:parseLine(line)
            local key = rowValues[self.keyColumn]
            local valueDict = {}
            for valueIdx, value in ipairs(rowValues) do
                if #rowValues ~= #self.header then
                    local msg = string.format(
                        "Unexpected number of columns found in line:\n%s",line
                    )
                    error(msg)
                end
                local colName = self.header[valueIdx]
                valueDict[colName] = value
            end
            self.table[key] = valueDict
        end
    else
        error("No lines in file")
    end

    return
end

function Csv:parseHeader()
    if self.hasHeader then
        -- Use first line as header
        local headerLine = table.remove(self.lines,1)
        self.header = self:parseLine(headerLine)
    else
        -- Create header
        local columns = self:parseLine(self.lines[1])
        for idx,_ in ipairs(columns) do
            self.header[idx] = "Var" .. idx
        end
    end

    -- Find the index of the specified key
    if self.key ~= nil then
        if self.key:match("^%d+$") then
            -- numeric
            if self.key <= #self.header then
                self.keyColumn = self.key
            else
                error("Specified key index out of bounds")
            end
        else
            self.keyColumn = Csv:indexOf(self.header,self.key)
        end

        if self.keyColumn == nil then
            local msg = string.format("Key '%s' not found in header",self.key)
            error(msg)
        end
    end
end

function Csv:parseLine(line)
    -- Modified version of ParseCSVLine from http://lua-users.org/wiki/LuaCsv
    local res = {}
    local pos = 1
    local sep = self.separator
    while true do
        local c = string.sub(line,pos,pos)
        if (c == "") then
            if pos > 1 then
                if string.sub(line,pos-1,pos-1) == sep then
                    table.insert(res,"")
                end
            end
            break
        end
        local txt = ""
        if (c == " ") then
            -- ignore leading spaces
            pos = pos + 1
        elseif (c == '"') then
            -- quoted value (ignore separator within)
            repeat
                local startp,endp = string.find(line,'^%b""',pos)
                txt = txt..string.sub(line,startp+1,endp-1)
                pos = endp + 1
                c = string.sub(line,pos,pos)
                if (c == '"') then txt = txt..'"' end
                -- check first char AFTER quoted string, if it is another
                -- quoted string without separator, then append it
                -- this is the way to "escape" the quote char in a quote.
                -- example:
                --   value1,"blub""blip""boing",value3  will result in
                --   blub"blip"boing  for the middle
            until (c ~= '"')
            txt = Csv:trim(txt)
            table.insert(res,txt)
            assert(c == sep or c == "")
            pos = pos + 1
        else
            -- no quotes used, just look for the first separator
            local startp,endp = string.find(line,sep,pos)
            if (startp) then
                txt = string.sub(line,pos,startp-1)
                txt = Csv:trim(txt)
                table.insert(res,txt)
                pos = endp + 1
            else
                -- no separator found -> use rest of string and terminate
                txt = string.sub(line,pos)
                txt = Csv:trim(txt)
                table.insert(res,txt)
                break
            end
        end
    end
    return res
end

-- Return the first index with the given value (or nil if not found).
function Csv:indexOf(array, value)
    for i, v in ipairs(array) do
        if v == value then
            return i
        end
    end
    return nil
end

function Csv:toString(tbl)
    tbl = tbl or self.table
    local s = ""
    if type(tbl) == 'table' then
        s = '{ '
        for k,v in pairs(tbl) do
            if type(k) ~= 'number' then k = '"'..k..'"' end
            s = s .. '['..k..'] = ' .. Csv:toString(v) .. ','
        end
        s = s .. '} '
    else
        s = tostring(tbl)
    end
    return s
 end

function Csv:tprint (tbl, indent)
    -- Modified version of https://gist.github.com/hashmal/874792
    tbl = tbl or self.table
    if not indent then indent = 0 end
    for k, v in pairs(tbl) do
        formatting = string.rep("  ", indent) .. k .. ": "
        if type(v) == "table" then
            print(formatting)
            Csv:tprint(v, indent+1)
        else
            print(formatting .. v)
        end
    end
end

 function Csv:trim(s)
    local n = s:find"%S"
    return n and s:match(".*%S", n) or ""
 end