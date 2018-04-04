local M = {}

local function query(node, path_list, i)
  local path = path_list[i]
  for _, v in ipairs(node) do
    if v.tag == path then
      if i == # path_list then
        return v
      else
        return query(v, path_list, i + 1)
      end
    end
  end
end

function M.query_node(node, path)
  assert(type(node) == 'table')

  local path_list = {}
  for v in path:gmatch('([^/]+)/*') do table.insert(path_list, v) end
  assert(# path_list > 0)
  if path_list[1] == node.tag then
    return query(node, path_list, 2)
  end
end


function M.map(list, f)
  local r = {}
  for i, v in ipairs(list) do r[i] = f(v) end
  return r
end

function io.read_file(filename)
  local file, err = io.open(filename, 'rb')
  if file then
    local r = file:read 'a'
    file:close()
    return r
  else
    return nil, err
  end
end

function io.write_file(filename, ...)
  local file, err = io.open(filename, 'wb')
  if file then
    file:write(...):close()
    return true
  else
    return nil, err
  end
end

function M.clear_metatable (tb)
  setmetatable(tb, nil)
  for k, v in pairs(tb) do if type(v) == 'table' then clear_metatable(v) end end
  return tb
end

return M
