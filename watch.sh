#!/bin/sh



# Dnmp项目目录
dnmpPath='/Users/fanrehai/Desktop/Code/Dnmp'


# PHP配置基础目录
watchedFiles="$dnmpPath/services/nginx/conf.d/php/*.conf"

获取文件的初始状态
initial_md5sum=$(md5sum watchedFiles)

while true; do
# 暂停脚本执行1秒钟
sleep 1

# 获取当前文件的md5sum值
current_md5sum=$(md5sum $watchedFiles)

# 比较初始状态和当前状态的md5sum值
if [[ "$initial_md5sum" != "$current_md5sum" ]]; then
    echo "文件发生了变动"
    
    # 更新初始状态的md5sum值为当前状态的md5sum值
    initial_md5sum=$current_md5sum
fi
done