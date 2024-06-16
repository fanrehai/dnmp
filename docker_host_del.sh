#!/bin/sh

######################## Main #########################
# 读取.env文件并加载其中的变量
. .env
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

