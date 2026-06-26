#!/bin/bash

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# 切换到脚本所在目录
cd "$SCRIPT_DIR"

# 从.env文件中加载环境变量，这样后续可以使用其中定义的路径等信息
if [ -f ".env" ]; then
    . .env
else
    echo -e "\033[1;31m❌ .env 文件不存在，请确保在 Dnmp 项目根目录执行脚本\033[0m"
    exit 1
fi

# 定义DNMP项目的路径，从.env文件加载的变量赋值而来
dnmp_path=${DNMP_PATH}
# 定义PHP项目的路径，同样从.env文件加载的变量赋值
php_project_path=${PHP_PROJECT_PATH}

# ---- 颜色定义（与 docker_host_list.sh 保持一致）----
C_RESET=$'\033[0m'
C_TITLE=$'\033[1;96m'       # 亮青 标题
C_ACCENT=$'\033[1;95m'      # 亮品红 强调
C_CYAN=$'\033[38;5;45m'     # 青 边框/标签
C_GREEN=$'\033[1;92m'       # 绿 成功
C_YELLOW=$'\033[1;93m'      # 黄 警告/提示
C_DIM=$'\033[38;5;240m'     # 暗灰 次要
C_MAGENTA=$'\033[38;5;177m' # 紫 特殊
C_LABEL=$'\033[38;5;117m'   # 浅蓝 字段名
C_VALUE=$'\033[1;97m'       # 白 字段值

# ---- 纯 Bash 提示辅助函数 ----
section() { printf '\n  %s▰▰▰  %s  ▰▰▰%s\n  %s%s%s\n' "$C_TITLE" "$1" "$C_RESET" "$C_DIM" "────────────────────────────" "$C_RESET"; }
ask()  { printf '%s%s%s\n' "$C_CYAN" "$1" "$C_RESET"; }
err()  { printf '%s❌ %s%s\n' "$C_ACCENT" "$1" "$C_RESET"; }
ok()   { printf '%s✅ %s%s\n' "$C_GREEN" "$1" "$C_RESET"; }
warn() { printf '%s⚠️  %s%s\n' "$C_YELLOW" "$1" "$C_RESET"; }
info() { printf '%s%s%s\n' "$C_DIM" "$1" "$C_RESET"; }
kv()   { printf '  %s%s%s %s%s%s\n' "$C_LABEL" "$1" "$C_RESET" "$C_VALUE" "$2" "$C_RESET"; }

# 渲染两列 key-value 方框卡片（CJK 宽度对齐）
# 用法: printf '%s\t%s\n' ... | CARD_TITLE="确认创建" CARD_TITLE_COLOR="$C_TITLE" render_kv_card
render_kv_card() {
    export C_RESET C_TITLE C_CYAN C_LABEL C_VALUE C_DIM CARD_TITLE CARD_TITLE_COLOR
    perl -Mutf8 -CA -e '
        use utf8;
        binmode(STDIN, ":utf8"); binmode(STDOUT, ":utf8");
        my %C = map { $_ => $ENV{$_} } qw(C_RESET C_TITLE C_CYAN C_LABEL C_VALUE C_DIM);
        my $title = $ENV{CARD_TITLE} // "";
        my $tcolor = $ENV{CARD_TITLE_COLOR} // $C{C_TITLE};
        sub w { my $s = shift; $s =~ s/\e\[[0-9;]*m//g; my $w=0;
            for my $c (split //, $s) { my $cp=ord $c;
                if ($cp>=0x1100 && ($cp<=0x115F || ($cp>=0x2E80 && $cp<=0xA4CF) ||
                    ($cp>=0xAC00 && $cp<=0xD7A3) || ($cp>=0xF900 && $cp<=0xFAFF) ||
                    ($cp>=0xFE30 && $cp<=0xFE4F) || ($cp>=0xFF00 && $cp<=0xFF60) ||
                    ($cp>=0xFFE0 && $cp<=0xFFE6))) { $w+=2 } else { $w+=1 } }
            return $w; }
        sub pad { my ($s,$t)=@_; my $p=$t - w($s); $p=0 if $p<0; return $s.(" " x $p); }
        my (@k,@v); my ($kw,$vw)=(0,0);
        while (my $l=<STDIN>) { chomp $l; next if $l eq "";
            my ($a,$b)=split /\t/, $l, 2; $b //= "";
            push @k,$a; push @v,$b;
            $kw=w($a) if w($a)>$kw; $vw=w($b) if w($b)>$vw; }
        my $top = "┌".("─"x($kw+2))."┬".("─"x($vw+2))."┐\n";
        my $bot = "└".("─"x($kw+2))."┴".("─"x($vw+2))."┘\n";
        print "\n  $tcolor▰▰▰  $title  ▰▰▰$C{C_RESET}\n\n";
        print "  $top";
        for my $i (0..$#k) {
            printf "  │ %s%s%s │ %s%s%s │\n",
                $C{C_LABEL}, pad($k[$i],$kw), $C{C_RESET},
                $C{C_VALUE}, pad($v[$i],$vw), $C{C_RESET};
        }
        print "  $bot";
    '
}

# 渲染带序号的选择方框表（青色表头）
# 用法: printf '%s\t%s\n' ... | CARD_TITLE="可用的PHP版本" render_choice_list
render_choice_list() {
    export C_RESET C_TITLE C_CYAN C_VALUE CARD_TITLE
    perl -Mutf8 -CA -e '
        use utf8;
        binmode(STDIN, ":utf8"); binmode(STDOUT, ":utf8");
        my %C = map { $_ => $ENV{$_} } qw(C_RESET C_TITLE C_CYAN C_VALUE);
        my $title = $ENV{CARD_TITLE} // "";
        sub w { my $s = shift; $s =~ s/\e\[[0-9;]*m//g; my $w=0;
            for my $c (split //, $s) { my $cp=ord $c;
                if ($cp>=0x1100 && ($cp<=0x115F || ($cp>=0x2E80 && $cp<=0xA4CF) ||
                    ($cp>=0xAC00 && $cp<=0xD7A3) || ($cp>=0xF900 && $cp<=0xFAFF) ||
                    ($cp>=0xFE30 && $cp<=0xFE4F) || ($cp>=0xFF00 && $cp<=0xFF60) ||
                    ($cp>=0xFFE0 && $cp<=0xFFE6))) { $w+=2 } else { $w+=1 } }
            return $w; }
        sub pad { my ($s,$t)=@_; my $p=$t - w($s); $p=0 if $p<0; return $s.(" " x $p); }
        my (@n,@name); my ($nw,$mw)=(w("#"),w("选项"));
        while (my $l=<STDIN>) { chomp $l; next if $l eq "";
            my ($a,$b)=split /\t/, $l, 2; $b //= "";
            push @n,$a; push @name,$b;
            $nw=w($a) if w($a)>$nw; $mw=w($b) if w($b)>$mw; }
        my $top = "┌".("─"x($nw+2))."┬".("─"x($mw+2))."┐\n";
        my $mid = "├".("─"x($nw+2))."┼".("─"x($mw+2))."┤\n";
        my $bot = "└".("─"x($nw+2))."┴".("─"x($mw+2))."┘\n";
        print "\n  $C{C_TITLE}$title$C{C_RESET}\n";
        print "  $top";
        printf "  │ %s%s%s │ %s%s%s │\n",
            $C{C_CYAN}, pad("#",$nw), $C{C_RESET},
            $C{C_CYAN}, pad("选项",$mw), $C{C_RESET};
        print "  $mid";
        for my $i (0..$#n) {
            printf "  │ %s%s%s │ %s%s%s │\n",
                $C{C_VALUE}, pad($n[$i],$nw), $C{C_RESET},
                $C{C_VALUE}, pad($name[$i],$mw), $C{C_RESET};
        }
        print "  $bot";
    '
}

section "网站信息录入"
error_count=0

# 文件夹名称：非空 + 无空格
while true; do
    [ $error_count -ge 5 ] && { err "错误次数超过 5 次，脚本退出。"; exit 1; }
    ask "📂 请输入文件夹名称（不可为空 / 不含空格）:"
    read -r folder_name
    if [[ -n $folder_name && ! $folder_name =~ [[:space:]] ]]; then
        break
    else
        error_count=$((error_count + 1)); err "输入无效！请输入非空且不含空格的内容"
    fi
done

# 网站域名：非空 + 无空格
while true; do
    [ $error_count -ge 5 ] && { err "错误次数超过 5 次，脚本退出。"; exit 1; }
    ask "🌐 请输入网站域名（不可为空 / 不含空格）:"
    read -r domain_name
    if [[ -n $domain_name && ! $domain_name =~ [[:space:]] ]]; then
        break
    else
        error_count=$((error_count + 1)); err "输入无效！请输入非空且不含空格的内容"
    fi
done

# 网站备注：仅非空（允许空格）
while true; do
    [ $error_count -ge 5 ] && { err "错误次数超过 5 次，脚本退出。"; exit 1; }
    ask "📖 请输入网站备注（不可为空，可含空格）:"
    read -r site_remark
    if [[ -n $site_remark ]]; then
        break
    else
        error_count=$((error_count + 1)); err "输入无效！备注不可为空"
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

# ----------------------------------- PHP版本选择 ------------------------------------

section "选择 PHP 版本"

if [ $index -eq 0 ]; then
    err "未找到可用的 PHP 版本容器（需正在运行且存在对应 conf）"
    exit 1
fi

php_list=""
for ((i = 0; i < index; i++)); do
    php_list+="$i"$'\t'"${available_php_versions[$i]}"$'\n'
done
printf '%s' "$php_list" | CARD_TITLE="🐘 可用的 PHP 版本" render_choice_list
echo

while true; do
    ask "请输入版本对应数字 [0-$((index - 1))]:"
    read -r php_version_choice
    if [[ $php_version_choice =~ ^[0-9]+$ && $php_version_choice -ge 0 && $php_version_choice -lt $index ]]; then
        break
    else
        err "版本选择错误，请重新输入。"
    fi
done
selected_php_version=${available_php_versions[$php_version_choice]}

# 获取可用的框架配置

# 定义框架配置的基础目录
frame_config_path="$dnmp_path/services/nginx/conf.d/rewrite"
# 获取框架配置目录下的文件列表，将错误信息重定向到/dev/null
# 使用数组直接存储文件列表
available_frameworks=()
while IFS= read -r -d '' file; do
    available_frameworks+=("$file")
done < <(find "$frame_config_path" -maxdepth 1 -type f -name "*.conf" -print0 | sort)

# 检查框架配置目录下是否有文件
if [ ${#available_frameworks[@]} -eq 0 ]; then
    err "PHP 框架配置目录错误!!!"
    exit 1
fi

section "框架入口文件配置"

frame_list="0"$'\t'"无需配置"$'\n'
frame_index=1
for file in "${available_frameworks[@]}"; do
    frame_list+="$frame_index"$'\t'"$(basename "$file")"$'\n'
    frame_index=$((frame_index + 1))
done
printf '%s' "$frame_list" | CARD_TITLE="🧩 可选框架" render_choice_list
echo

while true; do
    ask "请输入框架对应数字 [0-$((frame_index - 1))]:"
    read -r frame_choice
    if [[ $frame_choice =~ ^[0-9]+$ && $frame_choice -ge 0 && $frame_choice -lt $frame_index ]]; then
        break
    else
        err "输入无效，请重新输入!!!"
    fi
done

# ----------------------------------- 创建前确认 ------------------------------------

section "确认创建"

if [[ $frame_choice -ge 1 ]]; then
    confirm_framework=$(basename "${available_frameworks[$((frame_choice - 1))]}")
else
    confirm_framework="无需配置"
fi
confirm_project_path="$php_project_path/$folder_name"

printf '%s\t%s\n' \
    "文件夹"   "$folder_name" \
    "域名"     "$domain_name" \
    "备注"     "$site_remark" \
    "PHP版本"  "$selected_php_version" \
    "框架"     "$confirm_framework" \
    "项目路径" "$confirm_project_path" \
    | CARD_TITLE="确认创建" CARD_TITLE_COLOR="$C_TITLE" render_kv_card
echo

while true; do
    ask "继续创建? [0. 取消 / 1. 确认]:"
    read -r confirm_create
    if [[ $confirm_create == "0" || $confirm_create == "1" ]]; then
        break
    else
        err "输入无效，请输入 0 或 1"
    fi
done
if [[ $confirm_create == "0" ]]; then
    warn "已取消，未做任何修改。"
    exit 0
fi

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
    echo -e "\n\033[1;33m📂文件夹已经存在:\033[0m"
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

# --- 兼容性修复：处理 macOS 和 Linux 的 sed 差异 ---
# 定义一个简单的替换函数
run_sed() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i "" "$1" "$2"
    else
        sed -i "$1" "$2"
    fi
}

# 替换配置 这里的空双引号是为了避开命令的强制备份逻辑
run_sed "s/default.host/$domain_name/g" $domain_name.conf
run_sed "s/default.error/$domain_name.error/g" "$nginx_conf_file"
run_sed "s/php.version/$selected_php_version/g" "$nginx_conf_file"


# -------------------------------- 框架配置写入Nginx文件 -----------------------------------

# 检查用户是否选择了框架配置
if [[ $frame_choice -ge 1 ]]; then
    # 如果选择了框架配置，根据用户选择的序号从可用框架数组中获取对应的框架配置文件名称
    selected_framework_path=${available_frameworks[$((frame_choice - 1))]}
    selected_framework=$(basename "$selected_framework_path")
    # 拼接框架配置文件的完整路径
    full_name="conf.d\/rewrite\/${selected_framework}"
    # 替换文件名称
    run_sed "s/frame.config/${full_name}/g" $domain_name.conf

    # 根据框架类型修改root路径
    case $selected_framework in
        "laravel.conf")
            # 在替换好的域名后面加上public
            run_sed "s/default.file/$folder_name\/public/g" "$nginx_conf_file"
            ;;
        *)
            # 其他框架：
            run_sed "s/default.file/$folder_name/g" "$nginx_conf_file"
            ;;
    esac
else
    # 如果用户选择无需配置，使用sed命令删除配置文件中包含框架配置的行
    run_sed "s/include frame\.config;//g" "$nginx_conf_file"
fi

# ----------------------------------- 写入Host文件 ------------------------------------

# 检查Host文件中是否已经存在用户输入的域名
if ! grep -q "$domain_name" /etc/hosts; then
    # 如果不存在，将域名和对应的IP地址以及备注信息追加到Host文件中
    echo "127.0.0.1 $domain_name #$site_remark" | sudo tee -a /etc/hosts > /dev/null
    echo "✅ 已成功添加域名到 /etc/hosts"
else
    echo '⚠️ host中已存在相同域名,请注意清理'
fi


# 切换到DNMP项目的根目录
cd "$dnmp_path"
# 使用docker-compose命令重启Nginx容器
docker compose restart nginx

# 输出网站创建成功的提示信息
echo -e "\n\n\n🎉🎉🎉网站创建成功🎉🎉🎉\n\n\n"




