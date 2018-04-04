-- 一个简单的比较两份xml文件差异的函数


local xml         = require 'xml'

local base        = require 'base'

local query_node = base.query_node

local function is_different(left_value, right_value)
  local rvt = type(right_value)
  if rvt == 'boolean' then
    right_value = right_value and 'True' or 'False'
    return left_value ~= right_value
  elseif rvt == 'number' then
    return math.abs(tonumber(left_value) - right_value) > 0.1
  else
    return left_value ~= right_value
  end
end

local function split_children(node)
  local sub_attrs = {}
  local sub_nodes = {}
  for _, v in ipairs(node) do
    if v.tag == 'Children' then
      for _, node in ipairs(v) do
        if node:get_attribs().ActionTag == nil then
          node:set_attrib('ActionTag', 0)
        end
        table.insert(sub_nodes, node)
      end
    else
      table.insert(sub_attrs, v)
    end
  end

  table.sort(sub_attrs, function (a, b)
    return a.tag < b.tag
  end)

  table.sort(sub_nodes, function (a, b)
    return tonumber(a:get_attribs().ActionTag) < tonumber(b:get_attribs().ActionTag)
  end)

  return sub_attrs, sub_nodes
end

local function diff_csd_node_tree(left_node, right_node)
  local diff_doc = xml.new(left_node.tag)

  local left_attrs = left_node:get_attribs()
  local right_attrs = right_node:get_attribs()

  -- 1. compare attrs
  for attr_name, right_attr_value in pairs(right_attrs) do

    local left_attr_value = left_attrs[attr_name]
    if left_attr_value then
      if is_different(left_attr_value, right_attr_value) then
        diff_doc:set_attribs {
          ['L-' .. attr_name] = left_attr_value,
          ['R-' .. attr_name] = right_attr_value,
        }
      end
      left_attrs[attr_name] = nil
    else
      diff_doc:set_attrib('R_' .. attr_name, right_attr_value)
    end
  end
  for attr_name, left_attr_value in pairs(left_attrs) do
    diff_doc:set_attrib('L_' .. attr_name, left_attr_value)
  end

  local left_sub_attrs, left_sub_nodes = split_children(left_node)
  local right_sub_attrs, right_sub_nodes = split_children(right_node)

  -- 2. compare sub attrs

  local lai, rai = 1, 1
  while lai <= # left_sub_attrs and rai <= # right_sub_attrs do
    local l_attr, r_attr = left_sub_attrs[lai], right_sub_attrs[rai]
    local l_tag, r_tag = l_attr.tag, r_attr.tag
    if l_tag < r_tag then
      diff_doc:child_with_name('Left', true):add_child(l_attr)
      lai = lai + 1
    elseif l_tag > r_tag then
      diff_doc:child_with_name('Right', true):add_child(r_attr)
      rai = rai + 1
    else
      lai, rai = lai + 1, rai + 1
    end
  end

  -- 3. compare children node: with same action_tag
  local lni, rni = 1, 1
  while lni <= # left_sub_nodes and rni <= # right_sub_nodes do
    local l_node, r_node = left_sub_nodes[lni], right_sub_nodes[rni]
    local lt = tonumber(l_node:get_attribs().ActionTag)
    local rt = r_node:get_attribs().ActionTag
    if lt < rt then
      lni = lni + 1
    elseif lt > rt then
      rni = rni + 1
    else
      local sub_diff_doc = diff_csd_node_tree(l_node, r_node)
      sub_diff_doc:set_attrib('ActionTag', lt)
      diff_doc:add_child(sub_diff_doc)
      lni, rni = lni + 1, rni + 1
    end
  end

  return diff_doc
end

local function diff_csd(left_csd, right_csd)
  local node_path = '/GameFile/Content/Content/ObjectData'
  local left_node = query_node(left_csd, node_path)
  local right_node = query_node(right_csd, node_path)
  if left_node and right_node then
    return diff_csd_node_tree(left_node, right_node)
  end
end

return diff_csd

