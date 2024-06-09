#!/bin/sh


######################## Main #########################

# Dnmp项目目录
dnmpPath='yourPath'
# PHP项目目录
phpProjectPath='yourPath'

# 读取并解析配置文件的某个特定项
function read_nginx_conf_item {
    local item_name="$1"
    while read -r line; do
      if [[ $line == $item_name* ]]; then
        echo $line
        break
      fi
    done < $2
}

printf "|%-22s|%-64s|%-12s|%-10s|\n" "域名" "项目地址" "PHP版本" "域名状态"
printf "|--------------------|------------------------------------------------------------|----------|--------|\n"
# 获取 PHP 项目 Nginx 配置
phpNginxConfigList=$(find "$dnmpPath/services/nginx/conf.d" -type f -maxdepth 1 -name "*.conf")
for nginxConfFile in ${phpNginxConfigList[@]}
  do
    # --------- 获取域名 ---------
    # 读取 NGINX 配置
    tmpServerName=$(read_nginx_conf_item 'server_name' "$nginxConfFile")
    # 取出域名
    serverName=$(echo "$tmpServerName" | sed -e 's/server_name \(.*\);/\1/')
    # --------- 获取项目地址 ---------
    # 读取 NGINX 配置
    tmpPath=$(read_nginx_conf_item 'root' "$nginxConfFile")
    # 取出项目名称
    projectName=$(echo $tmpPath | sed -E 's|^.+ /www/([^/]+).+|\1|')
    # 项目真实地址
    realProjectPath="$phpProjectPath/$projectName"
    # --------- 获取 PHP 版本 ---------
    # 读取 NGINX 配置
    tmpPHPVersion=$(read_nginx_conf_item 'include' "$nginxConfFile")
    # 取出项目版本
    versionName=$(echo $tmpPHPVersion | sed -E 's|^.+/([^/]+)\..+|\1|')
    # --------- 获取域名状态 ---------
    serverHostStatus=""
    grepResult=$(grep -E "$serverName" /etc/hosts)
    if [[ $grepResult ]]; then
      if [[ $grepResult == \#* ]]; then
        serverHostStatus="禁用"
      else
        serverHostStatus="启用"
      fi
    else
      serverHostStatus="不存在"
    fi

    printf "|%-20s|%-60s|%-10s|%-10s|\n" $serverName $realProjectPath $versionName $serverHostStatus
  done







