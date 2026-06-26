#!/bin/bash

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# 切换到脚本所在目录，避免依赖终端当前工作目录
cd "$SCRIPT_DIR"

######################## Main #########################
# 从.env文件中加载环境变量，这样后续可以使用其中定义的路径等信息
if [ -f ".env" ]; then
    . .env
else
    echo -e "\033[1;31m❌ .env 文件不存在，请确保在 Dnmp 项目根目录执行脚本\033[0m"
    exit 1
fi
# Dnmp项目目录
dnmpPath=${DNMP_PATH}
# PHP项目目录
phpProjectPath=${PHP_PROJECT_PATH}

read -p "🌐网站域名:" hostName

# 删除域名Host
if grep -q "127.0.0.1 $hostName" "/etc/hosts"; then
  printf "\n\033[1;33m域名存在于Hosts文件, 是否删除(0或1):\033[0m\n"
  read -p "是否删除(0或1):" checkHost

  if [[ $checkHost -eq '1' ]]; then
    sudo sed -i "" "/127.0.0.1 $hostName/d" /etc/hosts
  fi
fi

# 删除Nginx配置文件
if [ -f "$dnmpPath/services/nginx/conf.d/$hostName.conf" ]; then
  printf "\n\033[1;33mNginx配置文件存在, 是否删除(0或1):\033[0m\n"
  read -p "是否删除(0或1):" checkNginx
  if [[ $checkNginx -eq '1' ]]; then
    sudo rm -rf "$dnmpPath/services/nginx/conf.d/$hostName.conf"
 fi
fi

if [ -d "$phpProjectPath/$hostName" ]; then
  printf "\n\033[1;33m项目文件夹存在, 是否删除(0或1):\033[0m\n"
  read -p "是否删除(0或1):" checkProject
  if [[ $checkProject -eq '1' ]]; then
    sudo rm -rf "$phpProjectPath/$hostName"
  fi
fi