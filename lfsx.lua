-- author: DavidFeng <davidxifeng at gmail.com>
-- 为lfs库提供两个utils函数


local lfs = require 'lfs'

--- 递归处理文件夹下所有文件
-- @string dir 目录
-- @function file_cb 文件处理函数
-- @function dir_cb 文件夹处理函数
local function walk_dir(dir, file_cb, dir_cb, level)
  level = level or 1
  for file, dir_obj in lfs.dir(dir) do
    if file ~= '.' and file ~= '..' then
      local ip = dir .. '/' .. file
      local attr = lfs.attributes(ip)
      if attr.mode == 'directory' then
        if dir_cb then
          if dir_cb(file, ip, level, attr) then
            walk_dir(ip, file_cb, dir_cb, level + 1)
          end
        else
          walk_dir(ip, file_cb, dir_cb, level + 1)
        end
      elseif attr.mode == 'file' then
        file_cb(file, ip, level, attr)
      end
    end
  end
end

--- 处理文件夹下所有文件
-- @string dir 目录
-- @function ff 文件名过滤函数
-- @function cb 处理函数
local function process_dir(dir, ff, cb)
  for file, dir_obj in lfs.dir(dir) do
    if file ~= '.' and file ~= '..' and ff(file) then
      local ip = dir .. '/' .. file
      local attr = lfs.attributes(ip)
      if attr.mode == 'file' then
        cb(ip, attr)
      end
    end
  end
end

lfs.walk_dir = walk_dir
lfs.process_dir = process_dir

return lfs
