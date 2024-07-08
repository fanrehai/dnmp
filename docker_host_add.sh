#!/bin/sh


######################## Main #########################
# 读取.env文件并加载其中的变量
. .env
# Dnmp项目目录
dnmpPath=${DNMP_PATH}
# PHP项目目录
phpProjectPath=${PHP_PROJECT_PATH}

printf "📂文件夹名称:"
read -r fileName
printf "🌐网站域名:"
read -r hostName
printf "📖网站备注:"
read -r remark

# ----------------------------------- PHP版本 ------------------------------------
# PHP配置基础目录
phpNginxConfigPath="$dnmpPath/services/nginx/conf.d/php"

# 获取运行的PHP容器
containerList=$(docker ps --format "table {{.Names}}" --filter name=php)

# 获取容器名称
index=0
versionStr=''
phpVersion=()
for item in ${containerList[@]}
    do
      # 如果名称中存在 「 php 」,并且存在「 Nginx 」配置文件
      if [[ $item =~ 'php' && -f "$phpNginxConfigPath/$item.conf" ]]; then
        versionStr="${versionStr} ${index}. ${item} \n"
        phpVersion+=($item)
        index=$((index+1))
      fi
    done

printf "\n\033[1;33m🐘PHP版本:\033[0m\n${versionStr}"
printf "请输入版本对应数字 [0-$((index-1))]:"
read -r version

if [[ $version -gt $index || $version -lt '0' ]]; then
  echo '版本错误'
  exit
fi

# ----------------------------------- 框架选择 ------------------------------------
# 配置基础目录
frameConfigPath="$dnmpPath/services/nginx/conf.d/rewrite"
frameFiles=$(ls -1q "$frameConfigPath")

if [ -z "$frameFiles" ]; then
  printf "\033[1;31mPHP框架配置目录错误!!!\033[0m"
fi

frameIndex=1
frameStr=''
frameList=()
# 读取框架配置目录
lastIndex=$(echo "$frameFiles" | wc -l)
while IFS= read -r item; do
    frameStr="${frameStr}$(printf "%2d. %s\n" $frameIndex "$item\n")"
    frameList+=("$item")
    if [ $frameIndex -lt $((lastIndex)) ]; then
        frameIndex=$((frameIndex+1))
    fi
done <<< "$frameFiles"

printf "\n\033[1;33m框架入口文件配置:\033[0m"
printf "%2d. %s\n" 0 "无需配置\n"
printf "$frameStr"

farmeValid=0
while [ $farmeValid -eq 0 ]; do
  printf "请输入框架对应数字[0-${frameIndex}]:"
  read -r frameCheck

  if [ $frameCheck -ge 0 ] && [ $frameCheck -le $frameIndex ]; then
    farmeValid=1
  else
    printf "\033[1;31m输入无效!!!\033[0m"
  fi
done

# ----------------------------------- 创建网站目录 ------------------------------------
if [ ! -d "$phpProjectPath/$fileName" ];then
  mkdir "$phpProjectPath/$fileName"
  echo "📂文件夹创建成功"
else
  printf "\n\033[1;33m📂文件夹已经存在:\033[0m\n0.取消\n1.继续"
  printf "是否直接使用 [0-1]:"
  read -r whether
  if [[ $whether -eq '0' ]]; then
    exit
  fi
fi

# ----------------------------------- 创建 Nginx 配置 ------------------------------------
cd "$dnmpPath/services/nginx/conf.d"
cp ./default.conf.sample ./$hostName.conf
# 替换配置 这里的空双引号是为了避开命令的强制备份逻辑
sed -i "" "s/default.host/$hostName/g" $hostName.conf
sed -i "" "s/default.file/$fileName/g" $hostName.conf
sed -i "" "s/default.error/$hostName.error/g" $hostName.conf
sed -i "" "s/php.version/${phpVersion[version]}/g" $hostName.conf

# ----------------------------------- 框架配置写入Nginx文件 ------------------------------------
if [[ -n "$frameCheck" && "$frameCheck" -ge 1 ]];then
  # 实际需要减1
  frameCheck=$((frameCheck-1))

  fullName="conf.d\/rewrite\/"${frameList[frameCheck]}
  # 替换文件名称
  sed -i "" "s/frame.config/${fullName}/g" $hostName.conf
else
  # 去除导入
  sed -i "" "s/include frame\.config;//g" $hostName.conf
fi

# ----------------------------------- 写入Host文件 ------------------------------------
# 如果hosts中不存在该域名，就将域名追加写入到Hosts文件
if ! cat '/etc/hosts' | grep "$hostName" >> /dev/null
then
  echo "127.0.0.1 $hostName #$remark" >> /etc/hosts
else
  echo 'host中已存在相同域名,请注意清理'
fi
# 重启Docker NGINX 容器
cd $dnmpPath
docker-compose restart nginx

printf "\n\n\n🎉🎉🎉网站创建成功🎉🎉🎉\n\n\n"

