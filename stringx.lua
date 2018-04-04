

--- xxd style string hex dump
function string:xxd()

  local non_print_pattern = '%c' -- or use '%G'

  local max_width = 8
  local width = 1
  local address = 0

  local line = {}

  local s = (self:gsub('(..)', function (c)
    if width == max_width then

      line[max_width] = c

      address = address + max_width * 2
      width = 1

      local b1, b2 = c:byte(1, 2)
      return ('%02x%02x  %s\n'):format(b1, b2,
        table.concat(line):gsub(non_print_pattern, '.'))

    elseif width == 1 then

      line[1] = c

      width = 2

      return ('%08x: %02x%02x '):format(address, c:byte(1, 2))

    else

      line[width] = c

      width = width + 1

      return ('%02x%02x '):format(c:byte(1, 2))
    end

  end))

  if #self % 2 ~= 0 then
    s = s:gsub('(.)$', function (c)
      return ('%02x'):format(c:byte())
    end)
  end

  if #self == 1 then
    s = ('%08x: %02x'):format(0, self:byte())
  end

  local rm = #self % (max_width * 2)
  if rm ~= 0 then
    local start_index = 10 + 5 * 8 + 1
    local line_width = start_index + 16 + 1
    local rc = #s % line_width
    rc = start_index - rc
    s = s .. (' '):rep(rc)
      .. self:sub(-rm, -1):gsub(non_print_pattern, '.') .. '\n'
  end

  return s
end

function string:from_hex()
  return (self:gsub('%X', ''):gsub('(..)', function (bs)
    return string.char(tonumber(bs, 16))
  end))
end

return string
