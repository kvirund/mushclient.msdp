module (..., package.seeall)

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