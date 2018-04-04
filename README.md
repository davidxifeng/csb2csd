# csb2csd
把CocosStudio输出的csb文件转换成可以继续编辑的csd源文件


注意：工具用到了Lua的flatbuffers库，链接为：

https://github.com/DavidFeng/lua-flatbuffers

需要编译出buffer.so之后，工具才可以正常运行

# 命令格式参考： 调用TexturePack把pvr.ccz转换成png格式

```lua
local cmd = 'TexturePacker %s --sheet %s --data /tmp/wd/dummy.plist --algorithm Basic --allow-free-size --no-trim'
for _, v in ipairs(arg) do
  local png_file_name = v:gsub("%.pvr.ccz", ".png")
  local s = cmd:format(v, png_file_name)
  --print(s)
  os.execute(s)
end
```
