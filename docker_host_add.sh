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

# 渲染两列 key-value 方框卡片（CJK 宽度对齐）
# 用法: printf '%s\t%s\n' ... | CARD_TITLE="确认创建" CARD_TITLE_COLOR="$C_TITLE" render_kv_card
render_kv_card() {
    export C_RESET C_TITLE C_CYAN C_LABEL C_VALUE C_DIM CARD_TITLE CARD_TITLE_COLOR
    perl -Mutf8 -CA -e '
        use utf8;
        use Encode qw(decode_utf8);
        binmode(STDIN, ":utf8"); binmode(STDOUT, ":utf8");
        my %C = map { $_ => $ENV{$_} } qw(C_RESET C_TITLE C_CYAN C_LABEL C_VALUE C_DIM);
        my $title = decode_utf8($ENV{CARD_TITLE} // "");
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

# 遍历获取到的PHP容器列表
for container in $php_containers; do
    # 检查容器名称是否包含php且对应的Nginx配置文件存在
    if [[ $container =~ php ]] && [ -f "$php_nginx_config_path/$container.conf" ]; then
        # 将符合条件的容器名称添加到可用PHP版本数组中
        available_php_versions+=("$container")
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

for ((i = 0; i < index; i++)); do
    printf '  %s%d.%s %s%s%s\n' "$C_CYAN" "$i" "$C_RESET" "$C_VALUE" "${available_php_versions[$i]}" "$C_RESET"
done
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

printf '  %s0.%s %s无需配置%s\n' "$C_CYAN" "$C_RESET" "$C_VALUE" "$C_RESET"
frame_index=1
for file in "${available_frameworks[@]}"; do
    printf '  %s%d.%s %s%s%s\n' "$C_CYAN" "$frame_index" "$C_RESET" "$C_VALUE" "$(basename "$file")" "$C_RESET"
    frame_index=$((frame_index + 1))
done
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

section "创建网站目录"
site_folder="$php_project_path/$folder_name"
if [ ! -d "$site_folder" ]; then
    mkdir "$site_folder"
    ok "文件夹创建成功: $site_folder"
else
    warn "文件夹已存在: $site_folder"
    while true; do
        ask "是否直接使用 [0. 取消 / 1. 继续]:"
        read -r use_existing_folder
        if [[ $use_existing_folder == "0" || $use_existing_folder == "1" ]]; then
            break
        else
            err "输入无效，请输入 0 或 1"
        fi
    done
    if [[ $use_existing_folder == "0" ]]; then
        warn "已取消。"
        exit 0
    fi
fi

# ----------------------------------- 创建 Nginx 配置 ------------------------------------

section "生成 Nginx 配置"
nginx_conf_dir="$dnmp_path/services/nginx/conf.d"
cd "$nginx_conf_dir"
nginx_conf_file="$domain_name.conf"
cp ./default.conf.sample "$nginx_conf_file"

run_sed() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i "" "$1" "$2"
    else
        sed -i "$1" "$2"
    fi
}

# 转义用于 sed 替换串的特殊字符（\ / &），避免破坏替换
sed_escape() { printf '%s' "$1" | sed -e 's/[\/&\\]/\\&/g'; }

esc_domain=$(sed_escape "$domain_name")
esc_php=$(sed_escape "$selected_php_version")
esc_folder=$(sed_escape "$folder_name")

run_sed "s/default.host/$esc_domain/g" "$nginx_conf_file"
run_sed "s/default.error/$esc_domain.error/g" "$nginx_conf_file"
run_sed "s/php.version/$esc_php/g" "$nginx_conf_file"
ok "已生成配置文件: $nginx_conf_file"


# -------------------------------- 框架配置写入Nginx文件 -----------------------------------

if [[ $frame_choice -ge 1 ]]; then
    selected_framework_path=${available_frameworks[$((frame_choice - 1))]}
    selected_framework=$(basename "$selected_framework_path")
    full_name="conf.d\/rewrite\/${selected_framework}"
    run_sed "s/frame.config/${full_name}/g" "$nginx_conf_file"
    case $selected_framework in
        "laravel.conf")
            run_sed "s/default.file/$esc_folder\/public/g" "$nginx_conf_file"
            ;;
        *)
            run_sed "s/default.file/$esc_folder/g" "$nginx_conf_file"
            ;;
    esac
    info "已写入框架配置: $selected_framework"
else
    run_sed "s/include frame\.config;//g" "$nginx_conf_file"
    info "未配置框架入口"
fi

# ----------------------------------- 写入Host文件 ------------------------------------

section "写入 hosts"
# 整词匹配域名（含行内 # 备注的行也算已存在），避免子串误判
if grep -qE "(^|[[:space:]])${domain_name//./\\.}([[:space:]]|#|$)" /etc/hosts 2>/dev/null; then
    warn "hosts 中已存在相同域名，请注意清理"
    hosts_status="已存在"
else
    echo "127.0.0.1 $domain_name #$site_remark" | sudo tee -a /etc/hosts > /dev/null
    ok "已成功添加域名到 /etc/hosts"
    hosts_status="已添加"
fi

# ----------------------------------- 重启 Nginx ------------------------------------

section "重启 Nginx"
cd "$dnmp_path"
docker compose restart nginx

# ----------------------------------- 结果摘要 ------------------------------------

printf '%s\t%s\n' \
    "文件夹"     "$folder_name" \
    "域名"       "$domain_name" \
    "备注"       "$site_remark" \
    "PHP版本"    "$selected_php_version" \
    "框架"       "$confirm_framework" \
    "项目路径"   "$confirm_project_path" \
    "hosts状态"  "$hosts_status" \
    | CARD_TITLE="🎉 创建成功" CARD_TITLE_COLOR="$C_GREEN" render_kv_card
echo




