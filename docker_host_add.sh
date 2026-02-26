#!/bin/sh

# 从.env文件中加载环境变量，这样后续可以使用其中定义的路径等信息
. .env

# 定义DNMP项目的路径，从.env文件加载的变量赋值而来
dnmp_path=${DNMP_PATH}
# 定义PHP项目的路径，同样从.env文件加载的变量赋值
php_project_path=${PHP_PROJECT_PATH}

error_count=0
# 文件夹名称输入校验（非空+无空格）
while true; do
    if [ $error_count -ge 5 ]; then
        echo "错误次数超过 5 次，脚本退出。"
        exit 1
    fi
    echo "📂请输入文件夹名称（不可为空/含空格）:"
    read -r folder_name
    if [[ -n $folder_name && ! $folder_name =~ [[:space:]] ]]; then
        break
    else
        error_count=$((error_count + 1))
        echo "❌ 输入无效！请输入非空且不含空格的内容"
    fi
done

# 网站域名输入校验（非空+无空格）
while true; do
    if [ $error_count -ge 5 ]; then
        echo "错误次数超过 5 次，脚本退出。"
        exit 1
    fi
    echo "🌐请输入网站域名（不可为空/含空格）:"
    read -r domain_name
    if [[ -n $domain_name && ! $domain_name =~ [[:space:]] ]]; then
        break
    else
        error_count=$((error_count + 1))
        echo "❌ 输入无效！请输入非空且不含空格的内容"
    fi
done

# 网站备注输入校验（非空+无空格）
while true; do
    if [ $error_count -ge 5 ]; then
        echo "错误次数超过 5 次，脚本退出。"
        exit 1
    fi
    echo "📖请输入网站备注（不可为空/含空格）:"
    read -r site_remark
    if [[ -n $site_remark && ! $site_remark =~ [[:space:]] ]]; then
        break
    else
        error_count=$((error_count + 1))
        echo "❌ 输入无效！请输入非空且不含空格的内容"
    fi
done

# ----------------------------------- PHP版本 ------------------------------------

# 定义PHP的Nginx配置基础目录
php_nginx_config_path="$dnmp_path/services/nginx/conf.d/php"

# 通过docker命令获取正在运行且名称包含php的容器列表
php_containers=$(docker ps --format "table {{.Names}}" --filter name=php)

# 初始化一个空数组，用于存储可用的PHP版本容器名称
available_php_versions=()

# 初始化索引变量，用于记录可用PHP版本的序号
index=0

# 初始化存储版本选择提示信息的变量
version_choices=""

# 遍历获取到的PHP容器列表
for container in $php_containers; do
    # 检查容器名称是否包含php且对应的Nginx配置文件存在
    if [[ $container =~ php ]] && [ -f "$php_nginx_config_path/$container.conf" ]; then
        # 将符合条件的容器名称添加到可用PHP版本数组中
        available_php_versions+=("$container")
        # 拼接版本选择提示信息，包含序号和容器名称
        version_choices="$version_choices $index. $container \n"
        # 序号加1
        index=$((index + 1))
    fi
done

# ----------------------------------- 框架选择 ------------------------------------

# 输出可用PHP版本的提示信息，使用黄色高亮显示
echo "\n\033[1;33m🐘可用的PHP版本:\033[0m"

# 输出具体的版本选择提示信息
echo "$version_choices"

# 进入无限循环，用于验证用户输入的版本选择是否有效
while true; do
    # 提示用户输入版本对应的数字
    echo "请输入版本对应数字 [0-$((index - 1))]:"
    # 读取用户输入的版本选择并存储到php_version_choice变量中
    read php_version_choice
    # 检查用户输入的版本选择是否在有效范围内
    if [[ $php_version_choice -ge 0 && $php_version_choice -lt $index ]]; then
        # 如果有效，跳出循环
        break
    else
        # 如果无效，提示用户重新输入
        echo "版本选择错误，请重新输入。"
    fi
done
# 根据用户选择的序号，从可用PHP版本数组中获取对应的PHP版本容器名称
selected_php_version=${available_php_versions[$php_version_choice]}

# 获取可用的框架配置

# 定义框架配置的基础目录
frame_config_path="$dnmp_path/services/nginx/conf.d/rewrite"
# 获取框架配置目录下的文件列表，将错误信息重定向到/dev/null
frame_files=$(ls -1q "$frame_config_path" 2>/dev/null)
# 检查框架配置目录下是否有文件
if [ -z "$frame_files" ]; then
    # 如果没有文件，输出错误信息并退出脚本
    echo "\033[1;31mPHP框架配置目录错误!!!\033[0m"
    exit 1
fi

# 初始化框架选择的序号
frame_index=1

frame_choices=" 0. 无需配置\n"  # 初始选项换行
while IFS= read -r file; do
    # 使用换行符确保每个选项单独一行，%2d 控制序号宽度（如  1.  2.）
    frame_choices="$frame_choices$(printf " %d. %s\n" $frame_index "$file") \n"
    available_frameworks+=("$file")
    frame_index=$((frame_index + 1))
done <<< "$frame_files"

echo "\n\033[1;33m框架入口文件配置:\033[0m"
echo "$frame_choices"

# 进入无限循环，用于验证用户输入的框架选择是否有效
while true; do
    # 提示用户输入框架对应的数字
    echo "请输入框架对应数字[0-$((frame_index - 1))]:"
    # 读取用户输入的框架选择并存储到frame_choice变量中
    read frame_choice
    # 检查用户输入的框架选择是否在有效范围内
    if [[ $frame_choice -ge 0 && $frame_choice -lt $frame_index ]]; then
        # 如果有效，跳出循环
        break
    else
        # 如果无效，提示用户重新输入
        echo "\033[1;31m输入无效，请重新输入!!!\033[0m"
    fi
done

# ----------------------------------- 创建网站目录 ------------------------------------

# 拼接网站文件夹的完整路径
site_folder="$php_project_path/$folder_name"
# 检查网站文件夹是否存在
if [ ! -d "$site_folder" ]; then
    # 如果不存在，创建该文件夹
    mkdir "$site_folder"
    # 输出文件夹创建成功的提示信息
    echo "📂文件夹创建成功"
else
    # 如果文件夹已存在，输出提示信息
    echo "\n\033[1;33m📂文件夹已经存在:\033[0m"
    # 提示用户选择取消或继续
    echo "0. 取消"
    echo "1. 继续"
    # 进入无限循环，用于验证用户输入的选择是否有效
    while true; do
        # 提示用户输入是否直接使用已存在的文件夹
        echo "是否直接使用 [0-1]:"
        # 读取用户输入的选择并存储到use_existing_folder变量中
        read use_existing_folder
        # 检查用户输入的选择是否为0或1
        if [[ $use_existing_folder -eq 0 || $use_existing_folder -eq 1 ]]; then
            # 如果有效，跳出循环
            break
        else
            echo "输入无效，请重新输入。"
        fi
    done
    # 如果用户选择取消，退出脚本
    if [[ $use_existing_folder -eq 0 ]]; then
        exit
    fi
fi

# ----------------------------------- 创建 Nginx 配置 ------------------------------------

# 定义Nginx配置文件所在的目录
nginx_conf_dir="$dnmp_path/services/nginx/conf.d"
# 切换到Nginx配置文件所在的目录
cd "$nginx_conf_dir"
# 拼接Nginx配置文件的完整名称
nginx_conf_file="$domain_name.conf"
# 从默认配置文件模板复制一个新的配置文件
cp ./default.conf.sample "$nginx_conf_file"
# 替换配置 这里的空双引号是为了避开命令的强制备份逻辑
sed -i "" "s/default.host/$domain_name/g" $domain_name.conf
sed -i "" "s/default.error/$domain_name.error/g" "$nginx_conf_file"
sed -i "" "s/php.version/$selected_php_version/g" "$nginx_conf_file"


# -------------------------------- 框架配置写入Nginx文件 -----------------------------------

# 检查用户是否选择了框架配置
if [[ $frame_choice -ge 1 ]]; then
    # 如果选择了框架配置，根据用户选择的序号从可用框架数组中获取对应的框架配置文件名称
    selected_framework=${available_frameworks[$((frame_choice - 1))]}
    # 拼接框架配置文件的完整路径
    full_name="conf.d\/rewrite\/"${selected_framework}
    # 替换文件名称
    sed -i "" "s/frame.config/${full_name}/g" $domain_name.conf

    # 根据框架类型修改root路径
    case $selected_framework in
        "laravel.conf")
            # 在替换好的域名后面加上public
            sed -i "" "s/default.file/$folder_name\/public/g" "$nginx_conf_file"
            ;;
        *)
            # 其他框架：
            sed -i "" "s/default.file/$folder_name/g" "$nginx_conf_file"
            ;;
    esac
else
    # 如果用户选择无需配置，使用sed命令删除配置文件中包含框架配置的行
    sed -i "" "s/include frame\.config;//g" "$nginx_conf_file"
fi

# ----------------------------------- 写入Host文件 ------------------------------------

# 检查Host文件中是否已经存在用户输入的域名
if ! grep -q "$domain_name" /etc/hosts; then
    # 如果不存在，将域名和对应的IP地址以及备注信息追加到Host文件中
    echo "127.0.0.1 $domain_name #$site_remark" >> /etc/hosts
else
    echo 'host中已存在相同域名,请注意清理'
fi


# 切换到DNMP项目的根目录
cd "$dnmp_path"
# 使用docker-compose命令重启Nginx容器
docker-compose restart nginx

# 输出网站创建成功的提示信息
echo "\n\n\n🎉🎉🎉网站创建成功🎉🎉🎉\n\n\n"




