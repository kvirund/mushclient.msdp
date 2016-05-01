module (..., package.seeall)

local a = "\x01\x52\x4f\x4f\x4d\x02\x03\x01\x56\x4e\x55\x4d\x02\x33\x39\x30\x30" ..
          "\x01\x4e\x41\x4d\x45\x02\xc3\xee\xf1\xf2\xe8\xed\xfb\xe9\x20\xe4\xe2" ..
          "\xee\xf0\x01\x41\x52\x45\x41\x02\xcb\xe5\xf1\xed\xe0\xff\x20\xe4\xe5" ..
          "\xf0\xe5\xe2\xed\xff\x01\x5a\x4f\x4e\x45\x02\x34\x30\x01\x45\x58\x49" ..
          "\x54\x53\x02\x03\x01\x65\x02\x33\x39\x31\x34\x04\x04"

-- returns array of characters
function get_chars(s)
  local result = {}
  local function chars(c) table.insert(result, c) return "" end
  chars((s:gsub(".", chars)))
  return result
end

-- returns array of bytes
function get_codes(s)
  local result = {}
  local function chars(c) local n = c:byte(1, 1) table.insert(result, n) return "" end
  chars((s:gsub(".", chars)))
  return result
end

-- joins array elements into string using specified delimiter
function strjoin(values, delimiter)
  local length = table.getn(values)
  if 0 == length then
    return ""
  end
  
  local result = values[1]
  for i = 2, length do
    result = result .. delimiter .. values[i]
  end
  
  return result
end

-- returns string representation suitable to use as lua string constant
function get_string(s)
  local result = {}
  local function chars(c) local n = c:byte(1, 1) if nil ~= n then table.insert(result, string.format("\\x%02x", n)) end return "" end
  chars((s:gsub(".", chars)))
  return strjoin(result, "")
end

local NUL, IAC, SB, SE, DO = 0x00, 0xFF, 0xFA, 0xF0, 0xFD

local MSDP = 69

local MSDP_VAR = 1
local MSDP_VAL = 2

local MSDP_TABLE_OPEN = 3
local MSDP_TABLE_CLOSE = 4

local MSDP_ARRAY_OPEN = 5
local MSDP_ARRAY_CLOSE = 6

local SPECIAL_CHARS = string.char(NUL) .. string.char(MSDP_VAL) .. string.char(MSDP_VAR) .. string.char(MSDP_TABLE_OPEN) .. string.char(MSDP_TABLE_CLOSE) .. string.char(MSDP_ARRAY_OPEN) .. string.char(MSDP_ARRAY_CLOSE) .. string.char(IAC)

function parse_MSDP_request(data)
  local request = {}
  
  local parse_MSDP_variable
  local parse_MSDP_value
  
  local function ParserError(message)
    print(message)
  end
  
  local function parse_MSDP_array(arg)
    local result = {}
    
    repeat
      local item = parse_MSDP_variable(arg)
      if nil == item then
        return nil
      end
      table.insert(result, item)
    until MSDP_ARRAY_CLOSE == data:byte(arg.from, arg.from)
    
    return result
  end
  
  local function parse_MSDP_table(arg)
    local result = {}
    
    repeat
      local item = parse_MSDP_variable(arg)
      if nil == item then
        return nil
      end
      for k, v in pairs(item) do
        result[k] = v
      end
    until MSDP_TABLE_CLOSE == data:byte(arg.from, arg.from)
    
    return result
  end
  
  function parse_MSDP_value(arg)
    local data = arg.data
    local pos = arg.from

    if pos > data:len() then
      ParserError("MSDP value too small")
      return nil
    end

    if MSDP_TABLE_OPEN == data:byte(pos, pos) then
      local a = {data = data, from = 1 + pos}
      result = parse_MSDP_table(a)
      pos = a.from
    elseif MSDP_ARRAY_OPEN == data:byte(pos, pos) then
      local a = {data = data, from = 1 + pos}
      result = parse_MSDP_array(a)
      pos = a.from
    else
      local s = ""
      while pos <= data:len() do
        local c = data:sub(pos, pos)
        
        if MSDP_ARRAY_CLOSE == data:byte(pos, pos) or MSDP_TABLE_CLOSE == data:byte(pos, pos) or MSDP_VAL == data:byte(pos, pos) or MSDP_VAR == data:byte(pos, pos)then
          break
        elseif nil ~= string.find(SPECIAL_CHARS, c) then
          ParserError("MSDP value contains special characters.")
          return nil
        else
          s = s .. c
        end
        
        pos = pos + 1
      end
      
      if pos > data:len() then
        ParserError("MSDP value too small")
        return nil
      end
      
      result = s
    end
    
    arg.from = pos
    return result
  end
  
  function parse_MSDP_variable(arg)
    local data = arg.data
    local pos = arg.from
    local result = {}
    
    if 1 >= data:len() then
      ParserError("Value too small")
      return nil
    end
    
    if data:byte(pos, pos) ~= MSDP_VAR then
      ParserError("MSDP variable does not start from MSDP_VAR. Current character is " .. string.format("\\x%02x", data:byte(pos, pos)))
      return nil
    end
    
    local name, value = "", nil
    
    pos = 1 + pos
    while pos <= data:len() do
      local c = data:sub(pos, pos)
      if string.char(MSDP_VAL) == c then
        local a = {data = data, from = 1 + pos}
        value = parse_MSDP_value(a)
        pos = a.from
        break
      elseif nil ~= string.find(SPECIAL_CHARS, c) then
        ParserError("MSDP variable name contains special characters.")
        return nil
      else
        name = name .. c
      end
      pos = pos + 1
    end
    
    if nil == name or nil == value then
      ParserError("Variable name and variable value are both nil.")
      return nil
    end
    
    if arg.from == data:len() then
      ParserError("Unexpected end of value")
      return nil
    end
    
    arg.from = pos
    result[name] = value
    return result
  end

  return parse_MSDP_variable({data = data, from = 1})
end