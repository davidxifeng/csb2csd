local assert, type = assert, type

local string  = require 'stringx'
local inspect = require 'inspect'

string.read   = require 'buffer'.read

local BaseType = {
    None   = 0,
    UType  = 1,
    Bool   = 2,
    Byte   = 3,
    UByte  = 4,
    Short  = 5,
    UShort = 6,
    Int    = 7,
    UInt   = 8,
    Long   = 9,
    ULong  = 10,
    Float  = 11,
    Double = 12,
    String = 13,
    Vector = 14,
    Obj    = 15,
    Union  = 16,
}

local field_reader = {

  ['string'] = '< +%d =$u4 +$1 s4',

  ['bool']   = '< +%d b1',

  ['byte']   = '< +%d i1',
  ['ubyte']  = '< +%d u1',

  ['short']  = '< +%d i2',
  ['ushort'] = '< +%d u2',

  ['int']    = '< +%d i',
  ['uint']   = '< +%d u',

  ['long']   = '< +%d i8',
  ['ulong']  = '< +%d u8',

  ['float']  = '< +%d f',
  ['double'] = '< +%d d',

  [BaseType.Bool  ] = 'b1',
  [BaseType.Byte  ] = 'i1',
  [BaseType.UByte ] = 'u1',
  [BaseType.Short ] = 'i2',
  [BaseType.UShort] = 'u2',
  [BaseType.Int   ] = 'i',
  [BaseType.UInt  ] = 'u',
  [BaseType.Long  ] = 'i8',
  [BaseType.ULong ] = 'u8',
  [BaseType.Float ] = 'f',
  [BaseType.Double] = 'd',
}

local function simple_reader(fb_type)
  return function (buf, offset, field, dv)
    if field ~= 0 then
      return buf:read(field_reader[fb_type]:format(offset + field))
    else
      return dv
    end
  end
end

local read_bool   = simple_reader 'bool'
local read_byte   = simple_reader 'byte'
local read_ubyte  = simple_reader 'ubyte'
local read_short  = simple_reader 'short'
local read_ushort = simple_reader 'ushort'
local read_int    = simple_reader 'int'
local read_uint   = simple_reader 'uint'
local read_long   = simple_reader 'long'
local read_ulong  = simple_reader 'ulong'
local read_float  = simple_reader 'float'
local read_double = simple_reader 'double'
local read_string = simple_reader 'string'

local function subtable_offset(buf, offset)
  return buf:read(('< +%d =$u4 +$1 @'):format(offset)) -- TODO confirm u4 or i4
end


local function read_table_type(buf, offset)
  local r = {}
  if field == 0 then return r end
  local vt_reader = '< +%d =$i4 -$1 $u2 +2 {*[($2 - 4) // 2] u2}'
  local fields = buf:read(vt_reader:format(offset))

  r.base_type = read_byte(buf, offset, fields[1])
  if fields[2] ~= 0 then
    assert(r.base_type == BaseType.Vector)
    r.element = read_byte(buf, offset, fields[2])
  end
  r.index = read_int(buf, offset, fields[3], -1)

  return r
end

local function parse_key_value(buf, offset)
  local r = {}
  local vt_reader = '< +%d =$i4 -$1 $u2 +2 {*[($2 - 4) // 2] u2}'
  local fields = buf:read(vt_reader:format(offset))

  r.key = read_string(buf, offset, fields[1])
  r.value = read_string(buf, offset, fields[2])

  return r
end

local function read_table_array(buf, offset, field, obj_reader)
  if field == 0 then return nil end

  local r = {}

  local size, addr = buf:read(('< +%d =$u4 +$1 u4 @'):format(offset + field))
  for i = 1, size do
    local elem_offset = buf:read(('< +%d =$u4 +$1 @'):format(addr))
    r[i] = obj_reader(buf, elem_offset)

    addr = addr + 4
  end
  return r
end

local function read_table_field(buf, offset)
  local r = {}
  local vt_reader = '< +%d =$i4 -$1 $u2 +2 {*[($2 - 4) // 2] u2}'
  local fields = buf:read(vt_reader:format(offset))

  r.name = read_string(buf, offset, fields[1])
  r.type = read_table_type(buf, subtable_offset(buf, offset + fields[2]))
  r.id = read_ushort(buf, offset, fields[3], 0)
  r.offset = read_ushort(buf, offset, fields[4], 0)

  if fields[5] ~= 0 or fields[6] ~= 0 then
    local bt = r.type.base_type
    if BaseType.Byte <= bt and bt <= BaseType.ULong then
      r.default_value = read_long(buf, offset, fields[5], 0)
    elseif bt == BaseType.Bool then
      r.default_value = read_long(buf, offset, fields[5], 0) ~= 0
    elseif bt == BaseType.Float or bt == BaseType.Double then
      r.default_value = read_double(buf, offset, fields[6], 0.0)
    end
  end

  r.deprecated = read_bool(buf, offset, fields[7], false)
  r.required = read_bool(buf, offset, fields[8], false)
  r.key = read_bool(buf, offset, fields[9], false)
  r.attributes = read_table_array(buf, offset, fields[10], parse_key_value)

  return r
end


local function parse_object(buf, offset)
  local r = {}
  local vt_reader = '< +%d =$i4 -$1 $u2 +2 {*[($2 - 4) // 2] u2}'
  local fields = buf:read(vt_reader:format(offset))
  r.name = read_string(buf, offset, fields[1])
  r.fields = read_table_array(buf, offset, fields[2], read_table_field)

  local fields_array = {}
  for i, v in ipairs(r.fields) do
    fields_array[v.id + 1] = v -- id: 0-based lua array index: 1-based
  end
  r.fields_array = fields_array

  r.is_struct = read_bool(buf, offset, fields[3], false)
  r.minalign = read_int(buf, offset, fields[4], 0)
  r.bytesize = read_int(buf, offset, fields[5], 0)
  r.attributes = read_table_array(buf, offset, fields[6], parse_key_value)

  return r
end

local function parse_enum_val(buf, offset)
  local r = {}
  local vt_reader = '< +%d =$i4 -$1 $u2 +2 {*[($2 - 4) // 2] u2}'
  local fields = buf:read(vt_reader:format(offset))

  r.name = read_string(buf, offset, fields[1])
  r.value = read_long(buf, offset, fields[2], 0)
  if fields[3] ~= 0 then
    r.object = parse_object(buf, subtable_offset(buf, offset + fields[3]))
  end

  return r
end

local function parse_enum(buf, offset)
  local r = {}
  local vt_reader = '< +%d =$i4 -$1 $u2 +2 {*[($2 - 4) // 2] u2}'
  local fields = buf:read(vt_reader:format(offset))

  r.name = read_string(buf, offset, fields[1])
  r.values = read_table_array(buf, offset, fields[2], parse_enum_val)

  local t = {}
  for i, v in ipairs(r.values) do t[v.value] = v end
  r.values_lookup_dict = t

  r.is_union = read_bool(buf, offset, fields[3], false)

  -- required
  r.underlying_type = read_table_type(buf, subtable_offset(buf, offset + fields[4]))
  r.attributes = read_table_array(buf, offset, fields[5], parse_key_value)

  return r
end

-- TODO replace with `decode_table`
local function parse_schema(schema_buf)
  local r = {}
  local schema_reader = '< =&u4 +$1 =$i4 -$2 $u2 +2 {*[($3 - 4) // 2] u2}'
  local of, fields = schema_buf:read(schema_reader)

  r.objects = read_table_array(schema_buf, of, fields[1], parse_object)

  local t = {}
  for _, v in ipairs(r.objects) do t[v.name] = v end
  r.objects_name_dict = t

  r.enums = read_table_array(schema_buf, of, fields[2], parse_enum)
  r.file_ident = read_string(schema_buf, of, fields[3])
  r.file_ext = read_string(schema_buf, of, fields[4])
  if fields[5] ~= 0 then
    r.root_table = parse_object(schema_buf, subtable_offset(schema_buf, of + fields[5]))
  end

  return r
end

local schema_info_cache = setmetatable({}, {__mode = 'kv'})

local function decode_schema_with_cache(schema)
  local schema_info = schema_info_cache[schema]
  if not schema_info then
    schema_info = parse_schema(schema)

    local dict = {}
    for _, v in ipairs(schema_info.objects) do
      dict[v.name] = v
    end
    schema_info.objects_dict = dict

    dict = {}
    for _, v in ipairs(schema_info.enums) do
      dict[v.name] = v
    end
    schema_info.enums_dict = dict


    schema_info_cache[schema] = schema_info
  end
  return schema_info
end

local field_type_reader = {
  [BaseType.Bool]   = read_bool,
  [BaseType.Byte]   = read_byte,
  [BaseType.UByte]  = read_ubyte,
  [BaseType.Short]  = read_short,
  [BaseType.UShort] = read_ushort,
  [BaseType.Int]    = read_int,
  [BaseType.UInt]   = read_uint,
  [BaseType.Long]   = read_long,
  [BaseType.ULong]  = read_ulong,
  [BaseType.Float]  = read_float,
  [BaseType.Double] = read_double,
  [BaseType.String] = read_string,
}

local decode_table, decode_array

local function decode_struct(buf, offset, table_info)
  local init_offset = offset

  local r = {}

  for _, field_info in ipairs(table_info.fields) do
    local field_type = field_info.type
    local basetype = field_type.base_type
    local rd = field_reader[basetype]
    local addr = offset + field_info.offset
    r[field_info.name] = buf:read(('< +%d %s'):format(addr, rd))
  end

  return r
end

-- types may in array: bool-string, table(struct)
-- types may NOT in array: vector, union
function decode_array(schema, field_type, buf, offset, fcb)
  local array_info_reader = '< +%d =$u4 +$1 u4 @'
  --                                 ^      ^  ^
  --                                 |      |  | array element address
  --                                 |      |
  --                                 |      | array size
  --                                 |
  --                                 | array offset
  local size, addr = buf:read(array_info_reader:format(offset))

  -- array的元素类型不能是array,即没有嵌套的数组

  local element_type = field_type.element
  if BaseType.Bool <= element_type and element_type <= BaseType.Double then

    local rd = field_reader[element_type]
    return buf:read(('< +%d {*%d %s }'):format(addr, size, rd))

  elseif element_type == BaseType.String then

    local r = {}
    for i = 1, size do
      r[i] = buf:read(('< +%d =$u4 +$1 s4'):format(addr))
      addr = addr + 4
    end
    return r

  elseif element_type == BaseType.Obj then
    local ti = schema.objects[field_type.index + 1] -- 1-based index
    local r = {}

    if ti.is_struct then
      for i = 1, size do
        r[i] = decode_struct(buf, addr, ti)
        addr = addr + ti.bytesize
      end
    else
      for i = 1, size do
        local elem_offset = buf:read(('< +%d =$u4 +$1 @'):format(addr))
        r[i] = decode_table(schema, buf, elem_offset, ti, fcb)
        addr = addr + 4
      end
    end


    return r
  end
end

function decode_table(schema, buf, offset, table_info, fcb)
  local fields_info = table_info.fields_array

  if table_info.is_struct then return decode_struct(buf, offset, table_info) end

  local vt_reader = '< +%d =$i4 -$1 $u2 +2 {*[($2 - 4) // 2] u2}'
  local fields = buf:read(vt_reader:format(offset))

  local r = {}

  local i, fields_len = 0, # fields

  while i < fields_len do
    i = i + 1
    local v = fields[i]

    local field_info = fields_info[i]
    local field_type = field_info.type
    local basetype = field_type.base_type

    if fcb and fcb(table_info, r, offset, field_info, v) then goto continue end

    if BaseType.Bool <= basetype and basetype <= BaseType.String then

      if v ~= 0 then
        r[field_info.name] = field_type_reader[basetype](buf, offset, v)
      else
        r[field_info.name] = field_info.default_value
      end

    elseif basetype == BaseType.Vector then

      if v ~= 0 then
        r[field_info.name] = decode_array(schema, field_type, buf, offset + v, fcb)
      end


    elseif basetype == BaseType.Obj then

      if v ~= 0 then
        local sub_offset = subtable_offset(buf, offset + v)
        local ti = schema.objects[field_type.index + 1] -- 1-based index
        if ti.is_struct then
          r[field_info.name] = decode_struct(buf, offset + v, ti)
        else
          r[field_info.name] = decode_table(schema, buf, sub_offset, ti, fcb)
        end
      end

    elseif basetype == BaseType.UType then

      i = i + 1 -- skip next field: basetype Union

      -- union only contain table

      if v ~= 0 then
        local union_index = buf:read(('< +%d u1'):format(offset + v))
        local next_field_info = fields_info[i]
        local next_field_type = next_field_info.type
        local next_v = fields[i]
        assert(next_field_type.base_type == BaseType.Union and next_v ~= 0)

        -- 1-based index
        local enum_info = schema.enums[next_field_type.index + 1]
        local ti = enum_info.values_lookup_dict[union_index].object

        local sub_offset = subtable_offset(buf, offset + next_v)

        r[field_info.name] = ti.name
        r[next_field_info.name] = decode_table(schema, buf, sub_offset, ti, fcb)
      end
    end

    ::continue::
  end

  return r
end

local FlatBuffersMethods = { }

function FlatBuffersMethods:decode(buf, offset, ti)
  offset = offset or buf:read '< u4'
  if ti then
    ti = assert(self.objects_name_dict[ti], 'bad type name')
  else
    ti = self.root_table
  end
  return decode_table(self, buf, offset, ti)
end

function FlatBuffersMethods:decode_ex(buf, fcb)
  return decode_table(self, buf, buf:read '< u4', self.root_table, fcb)
end

local FlatBuffers = {}

local fbs_mt = { __index = FlatBuffersMethods }

-- TODO create schema with json, or parse from fbs source file with lpeg
function FlatBuffers.bfbs(schema)
  assert(type(schema) == 'string')
  return setmetatable(decode_schema_with_cache(schema), fbs_mt)
end

return FlatBuffers
