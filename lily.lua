#!/usr/bin/env lua53

local assert, pairs, ipairs = assert, pairs, ipairs

local inspect     = require 'inspect'
local FlatBuffers = require 'lfb'
local xml         = require 'xml'
local base        = require 'base'
local diff_csd    = require 'diff'

local map = base.map
local clear_metatable = base.clear_metatable


-- classname scanned from csb
local classname_type_dict = {
  ArmatureNode = 'CSArmatureNodeOption',
  Button       = 'ButtonOptions',
  CheckBox     = 'CheckBoxOptions',
  ImageView    = 'ImageViewOptions',
  ListView     = 'ListViewOptions',
  LoadingBar   = 'LoadingBarOptions',
  Node         = 'WidgetOptions',
  PageView     = 'PageViewOptions',
  Panel        = 'PanelOptions',
  Particle     = 'ParticleSystemOptions',
  ProjectNode  = 'ProjectNodeOptions',
  ScrollView   = 'ScrollViewOptions',
  Sprite       = 'SpriteOptions',
  Text         = 'TextOptions',
  TextAtlas    = 'TextAtlasOptions',
  TextBMFont   = 'TextBMFontOptions',
  TextField    = 'TextFieldOptions',

  SingleNode   = 'SingleNodeOptions',
}

local function decode_node_tree_options(fbs, buf, info)

  local function go(nodeTree)
    local opt_type = classname_type_dict[nodeTree.classname]
    if opt_type then
      local so = buf:read(('< +%d =$u4 +$1 @'):format(nodeTree.options.data))
      nodeTree.options.data = fbs:decode(buf, so, opt_type)
    else
      print('not found class name:', nodeTree.classname)
    end

    for _, v in ipairs(nodeTree.children) do go(v) end
  end

  go(info.nodeTree)

  return info
end


local fbs = FlatBuffers.bfbs(io.read_file 'app.bfbs')

local function filter_field(table_info, r, offset, field_info, field_offset)
  if field_offset ~= 0 and table_info.name == 'Options' then
    r.data = offset + field_offset
    return true
  end
end

local function read_csb(filepath)
  local buf = io.read_file(filepath)
  return decode_node_tree_options(fbs, buf, fbs:decode_ex(buf, filter_field))
end

local current_id = 0x4f1d6279b700
local function get_uid()
  current_id = current_id + 1
  return ('a2ee0952-26b5-49ae-8bf9-%012x'):format(current_id)
end

local function child_attr(xml_doc, name, attr)
  if attr then
    return xml_doc:add_child(xml.new(name, attr))
  end
end

local colors = {
  { A = 255 , R = 255 , G = 0   , B = 0   , } ,
  { A = 255 , R = 0   , G = 255 , B = 0   , } ,
  { A = 255 , R = 0   , G = 0   , B = 255 , } ,
  { A = 255 , R = 255 , G = 127 , B = 127 , } ,
  { A = 255 , R = 127 , G = 255 , B = 127 , } ,
  { A = 255 , R = 127 , G = 127 , B = 255 , } ,
  { A = 255 , R = 255 , G = 255 , B = 255 , } ,
  { A = 255 , R = 0   , G = 0   , B = 0   , } ,
}

local color_index = 0
local function render_color()
  if color_index == # colors - 1 then
    color_index = 1
  else
    color_index = color_index + 1
  end
  return colors[color_index]
end

local function animation_list(animationList)
  return xml.elem('AnimationList', map(animationList, function (i)
    return xml.new('AnimationInfo', {
      Name       = i.name,
      StartIndex = i.startIndex or 0,
      EndIndex   = i.endIndex or 0,
    }):add_child(xml.new('RenderColor', render_color()))
  end))
end


local frame_to_xml = {}

function frame_to_xml.VisibleForFrame(frame)
  local data = assert(frame.BoolFrame)

  return data, xml.new('BoolFrame', {
    FrameIndex = data.frameIndex or 0,
    Tween      = data.tween,
    Value      = data.value,
  })
end

function frame_to_xml.Position(frame)
  local data = assert(frame.PointFrame)
  return data, xml.new('PointFrame', {
    FrameIndex = data.frameIndex or 0,
    X          = data.position.X,
    Y          = data.position.Y,
  })
end

function frame_to_xml.Scale(frame)
  local data = assert(frame.ScaleFrame)
  return data, xml.new('ScaleFrame', {
    FrameIndex = data.frameIndex or 0,
    Tween      = data.tween,
    X          = data.scale.ScaleX,
    Y          = data.scale.ScaleY,
  })
end

function frame_to_xml.RotationSkew(frame)
  local data = assert(frame.ScaleFrame)
  return data, xml.new('ScaleFrame', {
    FrameIndex = data.frameIndex or 0,
    Tween      = data.tween,
    X          = data.scale.ScaleX,
    Y          = data.scale.ScaleY,
  })
end

function frame_to_xml.CColor(frame)
  local data = assert(frame.ColorFrame)
  return data, xml.new('ColorFrame', {
    FrameIndex = data.frameIndex or 0,
    Tween      = data.tween,
    Alpha      = '255',
  }):add_child(xml.new('Color', {
    A          = '255',
    R          = data.color.R,
    G          = data.color.G,
    B          = data.color.B,
  }))
end

function frame_to_xml.FileData(frame)
  local data = assert(frame.TextureFrame)

  local res = xml.new('TextureFrame', {
    FrameIndex = data.frameIndex or 0,
    Tween      = data.tween,
  })
  if data.textureFile then
    data.textureFile.Type = data.textureFile.Type or 'Normal'
    res:add_child(xml.new('TextureFile', data.textureFile))
  end
  return data, res
end

function frame_to_xml.FrameEvent(frame)
  local data = assert(frame.EventFrame)
  return data, xml.new('EventFrame', {
    FrameIndex = data.frameIndex or 0,
    Tween      = data.tween,
    Value      = data.value,
  })
end

function frame_to_xml.Alpha(frame)
  local data = assert(frame.IntFrame)
  return data, xml.new('IntFrame', {
    FrameIndex = data.frameIndex or 0,
    Tween      = data.tween,
    Value      = data.value,
  })
end

function frame_to_xml.AnchorPoint(frame)
  local data = assert(frame.ScaleFrame)
  return data, xml.new('ScaleFrame', {
    FrameIndex = data.frameIndex or 0,
    Tween      = data.tween,
    X          = data.scale.ScaleX,
    Y          = data.scale.ScaleY,
  })
end

function frame_to_xml.ZOrder(frame)
  local data = assert(frame.IntFrame)
  return data, xml.new('IntFrame', {
    FrameIndex = data.frameIndex or 0,
    Tween      = data.tween,
    Value      = data.value,
  })
end

function frame_to_xml.ActionValue(frame)
  local data = assert(frame.InnerActionFrame)

  local act
  if data.innerActionType == 1 then act = 'NoLoopAction'
  elseif data.innerActionType == 2 then act = 'SingleFrame'
  else act = 'LoopAction' end

  return data, xml.new('InnerActionFrame', {
    FrameIndex           = data.frameIndex or 0,
    Tween                = data.tween,
    InnerActionType      = act,
    CurrentAniamtionName = data.currentAnimationName,
    SingleFrameIndex     = data.singleFrameIndex or 0,
  })
end

function frame_to_xml.BlendFunc(frame)
  local data = assert(frame.BlendFrame)
  return data, xml.new('BlendFuncFrame', {
    FrameIndex = data.frameIndex or 0,
    Tween      = data.tween,
    Src        = data.blendFunc.Src,
    Dst        = data.blendFunc.Dst,
  })
end

local function point_f(point) return xml.new('PointF', point) end

local function frame(property)
  return function (frame)
    local data, frame_doc = frame_to_xml[property](frame)
    data = data.easingData
    if data then
      local easing_doc = xml.new('EasingData'):set_attrib('Type', data.Type)
      if data.Points and # data.Points > 0 then
        easing_doc:add_child(xml.elem('Points', map(data.Points, point_f)))
      end
      return frame_doc:add_child(easing_doc)
    else
      return frame_doc
    end
  end
end

local function timeLine_to_xml(time_line)
  local property = time_line.property
  local attr = { ActionTag= time_line.actionTag, Property = property }
  return xml.doc('Timeline', attr, map(time_line.frames, frame(property)))
end

local function action(nodeAction)
  local attr = {
    Duration = nodeAction.duration or 0,
    Speed    = nodeAction.speed,
  }
  if # nodeAction.timeLines > 0 then
    attr.ActivedAnimationName = nodeAction.currentAnimationName
  end
  return xml.doc('Animation', attr, map(nodeAction.timeLines, timeLine_to_xml))
end

local classname_option_dict = { }

local function set_basic_attr(xml_doc, data)
  local basic_data = assert(data.nodeOptions or data.widgetOptions or data)
  xml_doc:set_attribs(basic_data, {
    'Name', 'ActionTag', 'Tag', 'VisibleForFrame', 'TouchEnable',
  })

  if basic_data.CallBackType ~= '' then
    xml_doc:set_attribs(basic_data, { 'CallBackType' })
  end
  if basic_data.UserData ~= '' then
    xml_doc:set_attribs(basic_data, { 'UserData' })
  end
  if basic_data.FrameEvent ~= '' then
    xml_doc:set_attribs(basic_data, { 'FrameEvent' })
  end
  if basic_data.CallBackName ~= '' then
    xml_doc:set_attribs(basic_data, { 'CallBackName' })
  end

  xml_doc:set_attribs(basic_data.rotationSkew)
  xml_doc:set_attribs(basic_data.layoutComponent, {
    'LeftMargin', 'RightMargin', 'TopMargin', 'BottomMargin'
  })


  child_attr(xml_doc, 'Size',        basic_data.size)
  child_attr(xml_doc, 'AnchorPoint', basic_data.anchorPoint)
  child_attr(xml_doc, 'Position',    basic_data.position)
  child_attr(xml_doc, 'Scale',       basic_data.scale)
  child_attr(xml_doc, 'CColor',      basic_data.color)
end

local function set_resource_data(xml_doc, data, attr_name)
  local tp = data[attr_name].Type
  if tp == 0 or tp == nil then
    data[attr_name].Type = 'Default'
  else
    print('resource type: from 1 -> raw')
  end
  child_attr(xml_doc, attr_name, data[attr_name])
end

-- TODO get sprite size
local function set_scale_9_attr(xml_doc, capInsets, enable)
  if enable ~= nil then
    xml_doc:set_attrib('Scale9Enable', enable)
  end

  for k, v in pairs(capInsets) do
    capInsets[k] = assert(math.tointeger(v))
  end

  xml_doc:set_attrib('LeftEage'  , capInsets.Scale9OriginX)
  xml_doc:set_attrib('RightEage' , capInsets.Scale9OriginX)
  xml_doc:set_attrib('TopEage'   , capInsets.Scale9OriginY)
  xml_doc:set_attrib('BottomEage', capInsets.Scale9OriginY)
  xml_doc:set_attribs(capInsets)
end

local function set_text_outline(xml_doc, data)
  xml_doc:set_attribs(data, {
    "OutlineSize" , "OutlineEnabled",
  })
  child_attr(xml_doc, 'OutlineColor', data.OutlineColor)
end

local function set_text_shadow(xml_doc, data)
  xml_doc:set_attribs(data, {
    "ShadowOffsetX" , "ShadowBlurRadius", "ShadowOffsetY" , 'ShadowEnabled',
  })
  child_attr(xml_doc, 'ShadowColor', data.ShadowColor)
end


function classname_option_dict.ArmatureNode(xml_doc, data)
  set_basic_attr(xml_doc, data)
  xml_doc:set_attrib('ctype', "ArmatureNodeObjectData")

  child_attr(xml_doc, 'FileData', data.FileData)
  xml_doc:set_attribs(data, { 'IsLoop', 'IsAutoPlay', 'CurrentAnimationName' })
end

function classname_option_dict.CheckBox(xml_doc, data)
  set_basic_attr(xml_doc, data)
  xml_doc:set_attrib('ctype', "CheckBoxObjectData")

  xml_doc:set_attribs(data, { 'DisplayState', 'CheckedState' })

  set_resource_data(xml_doc, data, 'NormalBackFileData')
  set_resource_data(xml_doc, data, 'PressedBackFileData')
  set_resource_data(xml_doc, data, 'DisableBackFileData')
  set_resource_data(xml_doc, data, 'NodeNormalFileData')
  set_resource_data(xml_doc, data, 'NodeDisableFileData')
end

function classname_option_dict.ImageView(xml_doc, data)
  set_basic_attr(xml_doc, data)
  xml_doc:set_attrib('ctype', "ImageViewObjectData")

  set_scale_9_attr(xml_doc, data.capInsets, data.Scale9Enabled)
  child_attr(xml_doc, 'FileData',    data.fileNameData)
end

function classname_option_dict.ListView(xml_doc, data)
  xml_doc:set_attrib('ctype', "ListViewObjectData")
  set_basic_attr(xml_doc, data)

  -- 编辑器支持的渐变方向属性 导出时只保留了color vector，没有保存角度数值

  xml_doc:set_attribs(data, {
    'ClipAble', 'ComboBoxIndex', 'IsBounceEnabled',
    'ItemMargin', 'BackColorAlpha',
  })
  if data.DirectionType ~= '' then xml_doc:set_attribs(data, {'DirectionType'}) end
  if data.HorizontalType ~= '' then xml_doc:set_attribs(data, {'HorizontalType'}) end
  if data.VerticalType ~= '' then xml_doc:set_attribs(data, {'VerticalType'}) end

  set_scale_9_attr(xml_doc, data.capInsets, data.Scale9Enable)

  child_attr(xml_doc, 'FileData', data.FileData)
  child_attr(xml_doc, 'ColorVector', data.ColorVector)

  child_attr(xml_doc, 'SingleColor', data.SingleColor)
  child_attr(xml_doc, 'FirstColor', data.FirstColor)
  child_attr(xml_doc, 'EndColor', data.EndColor)
end

function classname_option_dict.LoadingBar(xml_doc, data)
  xml_doc:set_attrib('ctype', "LoadingBarObjectData")
  set_basic_attr(xml_doc, data)

  xml_doc:set_attrib('ProgressInfo', data.ProgressInfo)
  xml_doc:set_attrib('ProgressType', data.direction and 'Right_To_Left')

  child_attr(xml_doc, 'ImageFileData', data.textureData)
end

function classname_option_dict.Node(xml_doc, data)
  -- XXX test
  print('Node detected:')
  set_basic_attr(xml_doc, data)
end

function classname_option_dict.PageView(xml_doc, data)
  xml_doc:set_attrib('ctype', "PageViewObjectData")
  set_basic_attr(xml_doc, data)

  set_scale_9_attr(xml_doc, data.capInsets, data.Scale9Enable)

  xml_doc:set_attribs(data, { 'ClipAble', 'BackColorAlpha', 'ComboBoxIndex', })
  child_attr(xml_doc, 'FileData', data.FileData)

  child_attr(xml_doc, 'ColorVector', data.ColorVector)

  child_attr(xml_doc, 'SingleColor', data.SingleColor)
  child_attr(xml_doc, 'FirstColor',  data.FirstColor)
  child_attr(xml_doc, 'EndColor',    data.EndColor)

end

function classname_option_dict.Panel(xml_doc, data)
  xml_doc:set_attrib('ctype', "PanelObjectData")
  set_basic_attr(xml_doc, data)

  xml_doc:set_attribs(data, { 'ClipAble', 'BackColorAlpha', 'ComboBoxIndex', })

  set_scale_9_attr(xml_doc, data.capInsets, data.Scale9Enable)

  child_attr(xml_doc, 'FileData', data.FileData)
  child_attr(xml_doc, 'ColorVector', data.ColorVector)

  child_attr(xml_doc, 'SingleColor', data.SingleColor)
  child_attr(xml_doc, 'FirstColor',  data.FirstColor)
  child_attr(xml_doc, 'EndColor',    data.EndColor)
end

function classname_option_dict.Particle(xml_doc, data)
  xml_doc:set_attrib('ctype', "ParticleObjectData")
  set_basic_attr(xml_doc, data)
  child_attr(xml_doc, 'FileData', data.FileData)
  child_attr(xml_doc, 'BlendFunc', data.BlendFunc)
end

function classname_option_dict.ProjectNode(xml_doc, data)
  xml_doc:set_attrib('ctype', "ProjectNodeObjectData")
  set_basic_attr(xml_doc, data)
  xml_doc:set_attribs(data, { 'InnerActionSpeed' })

  child_attr(xml_doc, 'FileData', {
    Path= data.fileName:gsub('%.csb', '.csd'),
    Type="Normal", Plist="",
  })
end

function classname_option_dict.ScrollView(xml_doc, data)
  xml_doc:set_attrib('ctype', "ScrollViewObjectData")
  set_basic_attr(xml_doc, data)

  xml_doc:set_attribs(data, {
    'ClipAble', 'ComboBoxIndex', 'IsBounceEnabled',
    'ItemMargin', 'BackColorAlpha',
  })

  set_scale_9_attr(xml_doc, data.capInsets, data.Scale9Enable)


  child_attr(xml_doc, 'InnerNodeSize', data.InnerNodeSize)
  local dir
  if data.direction == 1 then
    dir = 'Vertical'
  elseif data.direction == 2 then
    dir = "Horizontal"
  elseif data.direction == 3 then
    dir = "Vertical_Horizontal"
  end
  xml_doc:set_attrib('ScrollDirectionType', dir)

  -- 我的cocos studio不支持编辑 滚动条侧边栏的 3个属性，所以这三个就不写回了

  child_attr(xml_doc, 'FileData', data.FileData)
  child_attr(xml_doc, 'ColorVector', data.ColorVector)
  child_attr(xml_doc, 'SingleColor', data.SingleColor)
  child_attr(xml_doc, 'FirstColor', data.FirstColor)
  child_attr(xml_doc, 'EndColor', data.EndColor)
end

function classname_option_dict.Sprite(xml_doc, data)
  set_basic_attr(xml_doc, data)
  xml_doc:set_attrib('ctype', "SpriteObjectData")

  child_attr(xml_doc, 'FileData',    data.FileData)
  child_attr(xml_doc, 'BlendFunc',   data.BlendFunc)
end

function classname_option_dict.Text(xml_doc, data)
  set_basic_attr(xml_doc, data)
  xml_doc:set_attrib('ctype', "TextObjectData")

  set_text_shadow(xml_doc, data)
  set_text_outline(xml_doc, data)

  xml_doc:set_attribs(data, {
    "FontSize", "FontName", 'LabelText',
  })
  child_attr(xml_doc, 'FontResource', data.FontResource)

  if data.hAlignment == 1 then
    xml_doc:set_attrib('HorizontalAlignmentType', "HT_Center")
  elseif data.hAlignment == 2 then
    xml_doc:set_attrib('HorizontalAlignmentType', "HT_Right")
  end
  if data.vAlignment == 1 then
    xml_doc:set_attrib('VerticalAlignmentType', "VT_Center")
  elseif data.vAlignment == 2 then
    xml_doc:set_attrib('VerticalAlignmentType', "VT_Bottom")
  end

end

function classname_option_dict.TextAtlas(xml_doc, data)
  xml_doc:set_attrib('ctype', "TextAtlasObjectData")
  set_basic_attr(xml_doc, data)

  child_attr(xml_doc, 'LabelAtlasFileImage_CNB', data.charMapFileData)

  xml_doc:set_attribs(data, {
    "StartChar", "LabelText", 'CharWidth', 'CharHeight',
  })

end

function classname_option_dict.TextBMFont(xml_doc, data)
  xml_doc:set_attrib('ctype', "TextBMFontObjectData")
  set_basic_attr(xml_doc, data)
  child_attr(xml_doc, 'LabelBMFontFile_CNB', data.fileNameData)
  xml_doc:set_attribs(data, { "LabelText" })
end

function classname_option_dict.TextField(xml_doc, data)
  xml_doc:set_attrib('ctype', "TextFieldObjectData")
  set_basic_attr(xml_doc, data)

  child_attr(xml_doc, 'FontResource', data.fontResource)

  if data.FontName and data.FontName ~= '' then
    xml_doc:set_attrib('FontName', data.FontName)
  end

  if data.PasswordEnable then
    xml_doc:set_attrib('PasswordStyleText', data.PasswordStyleText)
  end

  xml_doc:set_attribs(data, {
    "FontSize", 'LabelText', 'IsCustomSize',
    'MaxLengthEnable', 'MaxLengthText', 'PlaceHolderText'
  })
end

function classname_option_dict.SingleNode(xml_doc, data)
  set_basic_attr(xml_doc, data)
  xml_doc:set_attrib('ctype', "SingleNodeObjectData")
  return xml_doc
end

function classname_option_dict.Button(xml_doc, data)

  set_basic_attr(xml_doc, data)
  xml_doc:set_attrib('ctype', "ButtonObjectData")

  xml_doc:set_attribs(data, {
    "ButtonText", "IsLocalized", "FontSize", "FontName",
  })

  set_scale_9_attr(xml_doc, data.capInsets, data.Scale9Enable)
  set_text_shadow(xml_doc, data)

  child_attr(xml_doc, 'TextColor', data.textColor)
  child_attr(xml_doc, 'OutlineColor', data.outlineColor)


  child_attr(xml_doc, 'DisabledFileData', data.disabledData)
  child_attr(xml_doc, 'PressedFileData', data.pressedData)
  child_attr(xml_doc, 'NormalFileData', data.normalData )

  return xml_doc
end

local function node_tree(node)
  local xml_doc = xml.new('AbstractNodeData')
  local option_xml = classname_option_dict[node.classname]
  if option_xml then
    option_xml(xml_doc, node.options.data)
  end

  if node.children and # node.children > 0 then
    xml_doc:add_child(xml.elem('Children', map(node.children, node_tree)))
  end

  return xml_doc
end

local function root_node_tree(node)
  local root_option_data = node.options.data
  local xml_doc = xml.new('ObjectData', {
    ctype = "GameNodeObjectData",
    Name  = root_option_data.name,
    Tag   = root_option_data.tag,
  })

  local size = root_option_data.size or {}
  child_attr(xml_doc, 'Size', { X = size.width or 0, Y = size.height or 0 })

  if node.children and # node.children > 0 then
    local r = map(node.children, node_tree)
    xml_doc:add_child(xml.elem('Children', r))
  end

  return xml_doc
end

local function csb_to_csd(csb_doc)

  local node_root = csb_doc.nodeTree
  local root_name = node_root.options.data.Name

  -- layer scene node
  local function get_root_type(root_node)
    if root_node.classname == 'Node' then
      return 'Node'
    else
      return 'Scene'
    end
  end

  local property_group = xml.new('PropertyGroup', {
    Name    = root_name,
    Type    = get_root_type(node_root),
    ID      = get_uid(),
    Version = "3.10.0.0",
  })

  local content_root = xml.new('Content', {
    ctype = "GameProjectContent",
    Tag   = '-1',
    Name  = root_name,
  })

  content_root:add_child(xml.elem('Content', {
    action(csb_doc.action),
    animation_list(csb_doc.animationList),
    root_node_tree(node_root)
  }))

  return xml.elem('GameFile', {property_group, content_root})
end

local diff_result = false

local function write_csd(rb_csdname, xml_doc)

  local csd_name, rc = rb_csdname:gsub('-rb%.csd$', '.csd')
  if diff_result and rc == 1 then
    local csd_doc = xml.parse(csd_name, 'is_file', 'use_basic')
    if csd_doc then
      local diff = rb_csdname:gsub('-rb%.csd$', '-diff.xml')
      local diff_doc = diff_csd(csd_doc, xml_doc)
      io.write_file(diff, xml.tostring(diff_doc, '', '  '):sub(2, -1), '\n')
    end
  end

  local xml_string = xml.tostring(xml_doc, '', '  '):sub(2, -1)
  local r = io.write_file(rb_csdname, xml_string, '\n')
end

-- 注意： 根据需要修改这里
local function process(filename)
  local csd_dir = 'out/'
  local csb_dir = './'
  local csd_name, rc = filename:gsub('%.csb$', '.csd')
  if rc == 1 then
    local input_csb = csb_dir .. filename
    local csb_content = read_csb(input_csb)
    print('读入csb文件:', input_csb)
    local csd_content = csb_to_csd(csb_content)
    local csd_out_filename = csd_dir .. csd_name
    print('输出csd文件:', csd_out_filename)
    return write_csd(csd_out_filename, csd_content)
  end
end


local function main(arg)
  for _, filename in ipairs(arg) do
    process(filename)
  end
end

main(arg)

return {
  read_csb   = read_csb,
  write_csd  = write_csd,
  csb_to_csd = csb_to_csd,
}
