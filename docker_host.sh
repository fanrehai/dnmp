#!/bin/bash
set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# 加载 .env
if [ -f ".env" ]; then
    . .env
else
    echo -e "\033[1;31m❌ .env 文件不存在，请确保在 Dnmp 项目根目录执行脚本\033[0m"
    exit 1
fi

dnmp_path=${DNMP_PATH}
php_project_path=${PHP_PROJECT_PATH}

# ---- 颜色定义 ----
C_RESET=$'\033[0m'
C_TITLE=$'\033[1;96m'       # 亮青 标题
C_ACCENT=$'\033[1;95m'      # 亮品红 强调
C_CYAN=$'\033[38;5;45m'     # 青 边框/标签
C_GREEN=$'\033[1;92m'       # 绿 成功
C_YELLOW=$'\033[1;93m'      # 黄 警告
C_DIM=$'\033[38;5;240m'     # 暗灰 次要
C_MAGENTA=$'\033[38;5;177m' # 紫 特殊
C_LABEL=$'\033[38;5;117m'   # 浅蓝 字段名
C_VALUE=$'\033[1;97m'       # 白 字段值

# ---- 辅助函数 ----
section() { printf '\n  %s▰▰▰  %s  ▰▰▰%s\n  %s%s%s\n' "$C_TITLE" "$1" "$C_RESET" "$C_DIM" "────────────────────────────" "$C_RESET"; }
ask()  { printf '%s%s%s\n' "$C_CYAN" "$1" "$C_RESET"; }
err()  { printf '%s❌ %s%s\n' "$C_ACCENT" "$1" "$C_RESET"; }
ok()   { printf '%s✅ %s%s\n' "$C_GREEN" "$1" "$C_RESET"; }
warn() { printf '%s⚠️  %s%s\n' "$C_YELLOW" "$1" "$C_RESET"; }
info() { printf '%s%s%s\n' "$C_DIM" "$1" "$C_RESET"; }

# 跨平台 sed -i
run_sed() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i "" "$1" "$2"
    else
        sed -i "$1" "$2"
    fi
}

# ---- 渲染两列 key-value 方框卡片（CJK 宽度对齐）----
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

# ---- 通用交互选择菜单 ----
select_menu() {
    local prompt="$1"
    shift
    local items=("$@")
    local count=${#items[@]}
    local current=0

    render_menu() {
        local idx
        for ((idx = 0; idx < count; idx++)); do
            if [ $idx -eq $current ]; then
                printf '  %s>%s %s%s%s\n' "$C_GREEN" "$C_RESET" "$C_VALUE" "${items[$idx]}" "$C_RESET"
            else
                printf '   %s%s\n' "${items[$idx]}" "$C_RESET"
            fi
        done
        echo
        printf '  %s↑↓ 选择  %sEnter 确认%s\n' "$C_DIM" "$C_CYAN" "$C_RESET"
    }

    printf '\033[?25l'
    render_menu

    while true; do
        IFS= read -rsn1 key
        if [[ $key == $'\e' ]]; then
            IFS= read -rsn1 -t 1 key
            if [[ $key == '[' ]]; then
                IFS= read -rsn1 -t 1 key
                case $key in
                    'A')
                        [ $current -gt 0 ] && ((current--))
                        ;;
                    'B')
                        [ $current -lt $((count - 1)) ] && ((current++))
                        ;;
                esac
                printf '\033[%dA' $((count + 2))
                printf '\033[J'
                render_menu
            fi
        elif [[ $key == "" ]]; then
            break
        fi
    done

    printf '\033[?25h'
    selected_index=$current
    echo
}

# ---- Nginx 配置解析函数 ----
pick_directive() {
    local file="$1" directive="$2"
    awk -v d="$directive" '
        {
            line=$0
            sub(/^[[:space:]]+/, "", line)
            if (line ~ /^#/) next
            if (substr(line,1,length(d))==d) {
                tail=substr(line,length(d)+1,1)
                if (tail=="" || tail ~ /[[:space:];]/) { print line; exit }
            }
        }
    ' "$file"
}

pick_directives_all() {
    local file="$1" directive="$2"
    awk -v d="$directive" '
        {
            line=$0
            sub(/^[[:space:]]+/, "", line)
            if (line ~ /^#/) next
            if (substr(line,1,length(d))==d) {
                tail=substr(line,length(d)+1,1)
                if (tail=="" || tail ~ /[[:space:];]/) print line
            }
        }
    ' "$file"
}

# ---- 子命令函数 ----

cmd_add() {
    section "网站信息录入"
    error_count=0

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
    php_nginx_config_path="$dnmp_path/services/nginx/conf.d/php"
    php_containers=$(docker ps --format "{{.Names}}" --filter name=php)
    available_php_versions=()
    index=0

    for container in $php_containers; do
        if [[ $container =~ php ]] && [ -f "$php_nginx_config_path/$container.conf" ]; then
            available_php_versions+=("$container")
            index=$((index + 1))
        fi
    done

    # 按版本号升序排序
    sorted_versions=($(printf '%s\n' "${available_php_versions[@]}" | \
        perl -e 'print sort { ($a =~ /(\d+)/)[0] <=> ($b =~ /(\d+)/)[0] } <STDIN>'))

    # ----------------------------------- PHP版本选择 ------------------------------------
    section "选择 PHP 版本"

    if [ $index -eq 0 ]; then
        err "未找到可用的 PHP 版本容器（需正在运行且存在对应 conf）"
        exit 1
    fi

    if [ $index -eq 1 ]; then
        selected_php_version="${sorted_versions[0]}"
        printf '  %s>%s %s%s%s\n' "$C_GREEN" "$C_RESET" "$C_VALUE" "$selected_php_version" "$C_RESET"
        ok "已选择唯一版本: $selected_php_version"
    else
        select_menu "" "${sorted_versions[@]}"
        selected_php_version="${sorted_versions[$selected_index]}"
        ok "已选择: $selected_php_version"
    fi

    # ----------------------------------- 获取可用的框架配置 -----------------------------------
    frame_config_path="$dnmp_path/services/nginx/conf.d/rewrite"
    available_frameworks=()

    while IFS= read -r file; do
        [ -n "$file" ] && available_frameworks+=("$file")
    done < <(find "$frame_config_path" -maxdepth 1 -type f -name "*.conf" | sort)

    if [ ${#available_frameworks[@]} -eq 0 ]; then
        err "PHP 框架配置目录错误!!!"
        exit 1
    fi

    section "框架入口文件配置"
    framework_items=("无需配置")
    for file in "${available_frameworks[@]}"; do
        framework_items+=("$(basename "$file")")
    done

    select_menu "" "${framework_items[@]}"
    frame_choice=$selected_index
    ok "已选择: ${framework_items[$frame_choice]}"

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
        ask "继续创建? [${C_CYAN}Y/n$C_RESET]（直接回车默认 Y）:"
        read -r confirm_create
        case "${confirm_create:-Y}" in
            [Yy]|"") break ;;
            [Nn]) warn "已取消，未做任何修改。" && exit 0 ;;
            *) err "输入无效，请输入 Y 或 N" ;;
        esac
    done

    # ----------------------------------- 创建网站目录 ------------------------------------
    section "创建网站目录"
    site_folder="$php_project_path/$folder_name"
    if [ ! -d "$site_folder" ]; then
        mkdir -p "$site_folder"
        ok "文件夹创建成功: $site_folder"
    else
        warn "文件夹已存在: $site_folder"
        while true; do
            ask "是否直接使用? [${C_CYAN}Y/n$C_RESET]（直接回车默认 Y）:"
            read -r use_existing_folder
            case "${use_existing_folder:-Y}" in
                [Yy]|"") break ;;
                [Nn]) warn "已取消。" && exit 0 ;;
                *) err "输入无效，请输入 Y 或 N" ;;
            esac
        done
    fi

    # ----------------------------------- 创建 Nginx 配置 ------------------------------------
    section "生成 Nginx 配置"
    nginx_conf_dir="$dnmp_path/services/nginx/conf.d"
    nginx_conf_file="$nginx_conf_dir/$domain_name.conf"

    if [ ! -f "$nginx_conf_dir/default.conf.sample" ]; then
        err "模板文件 default.conf.sample 不存在！"
        exit 1
    fi
    cp "$nginx_conf_dir/default.conf.sample" "$nginx_conf_file"

    if [[ $frame_choice -ge 1 ]]; then
        selected_framework_path=${available_frameworks[$((frame_choice - 1))]}
        selected_framework=$(basename "$selected_framework_path")
        full_name="conf.d/rewrite/${selected_framework}"

        if [[ "$selected_framework" == "laravel.conf" ]]; then
            target_root="$folder_name/public"
        else
            target_root="$folder_name"
        fi

        run_sed "s|default.host|$domain_name|g; s|default.error|$domain_name.error|g; s|php.version|$selected_php_version|g; s|frame.config|$full_name|g; s|default.file|$target_root|g" "$nginx_conf_file"
        info "已写入框架配置: $selected_framework"
    else
        run_sed "s|default.host|$domain_name|g; s|default.error|$domain_name.error|g; s|php.version|$selected_php_version|g; s|include frame\.config;||g; s|default.file|$folder_name|g" "$nginx_conf_file"
        info "未配置框架入口"
    fi
    ok "已生成配置文件: $(basename "$nginx_conf_file")"

    # ----------------------------------- 写入Host文件 ------------------------------------
    section "写入 hosts"
    domain_regex=$(echo "$domain_name" | sed 's/\./\\./g')
    if grep -qE "(^|[[:space:]])${domain_regex}([[:space:]]|#|$)" /etc/hosts 2>/dev/null; then
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
}

cmd_del() {
    nginx_conf_dir="$dnmp_path/services/nginx/conf.d"
    available_domains=()

    for f in "$nginx_conf_dir"/*.conf; do
        [ -e "$f" ] || continue
        basename_f=$(basename "$f")
        [[ "$basename_f" == "default.conf" || "$basename_f" == "default.conf.sample" ]] && continue
        domain="${basename_f%.conf}"
        available_domains+=("$domain")
    done

    if [ ${#available_domains[@]} -eq 0 ]; then
        err "未找到可删除的网站配置"
        exit 1
    fi

    IFS=$'\n' available_domains=($(sort <<<"${available_domains[*]}")); unset IFS

    section "选择要删除的网站"
    select_menu "" "${available_domains[@]}"
    selected_domain="${available_domains[$selected_index]}"

    printf '\n'
    section "站点: $selected_domain"

    nginx_file="$nginx_conf_dir/$selected_domain.conf"
    project_folder=""

    if [ -f "$nginx_file" ]; then
        # 提取 Nginx 里的容器 root 配置
        tmp_root=$(pick_directive "$nginx_file" 'root')
        root_line=$(printf '%s' "$tmp_root" | sed -E 's/^[[:space:]]*root[[:space:]]+([^;]+);.*/\1/' | tr -d '[:space:]')

        # 【核心修复】：通过 Bash 正则完美匹配容器内的 /www/项目名称 段，并隔离后面的 /public 或斜杠
        if [[ "$root_line" =~ /www/([^/]+) ]]; then
            project_folder="${BASH_REMATCH[1]}"
            info "Nginx 内 root: $root_line  →  🚀 映射出宿主机项目目录名: $project_folder"
        else
            # 健壮性兜底：万一容器内映射目录不是 /www/ 开头
            project_folder=$(echo "$root_line" | sed -E 's|/(public|web)/?$||' | xargs basename 2>/dev/null || echo "")
            if [ -z "$project_folder" ]; then
                project_folder="$selected_domain"
            fi
            info "Nginx 内 root: $root_line  →  ⚠️ 触发兜底目录名: $project_folder"
        fi
    else
        project_folder="$selected_domain"
    fi

    # ---- 1. Hosts 文件检测与精准删除 ----
    domain_regex=$(echo "$selected_domain" | sed 's/\./\\./g')
    if grep -qE "(^|[[:space:]])${domain_regex}([[:space:]]|#|$)" /etc/hosts 2>/dev/null; then
        warn "Hosts 文件中存在该域名"
        while true; do
            ask "是否从 Hosts 文件中删除? [${C_CYAN}Y/n$C_RESET]（直接回车默认 Y）:"
            read -r input
            case "${input:-Y}" in
                [Yy]|"")
                    if [[ "$OSTYPE" == "darwin"* ]]; then
                        sudo sed -i "" -E "/(^|[[:space:]]#*)[[:space:]]*[0-9.]+[[:space:]]+${domain_regex}([[:space:]]|$)/d" /etc/hosts
                    else
                        sudo sed -i -E "/(^|[[:space:]]#*)[[:space:]]*[0-9.]+[[:space:]]+${domain_regex}([[:space:]]|$)/d" /etc/hosts
                    fi
                    ok "hosts 条目已精确删除"
                    break
                    ;;
                [Nn])
                    info "跳过 hosts 删除"
                    break
                    ;;
                *) err "输入无效，请输入 Y 或 N" ;;
            esac
        done
    else
        info "Hosts 文件中未找到该域名，跳过"
    fi

    # ---- 2. Nginx 配置文件检测 ----
    if [ -f "$nginx_file" ]; then
        warn "Nginx 配置文件存在: $selected_domain.conf"
        while true; do
            ask "是否删除 Nginx 配置文件? [${C_CYAN}Y/n$C_RESET]（直接回车默认 Y）:"
            read -r input
            case "${input:-Y}" in
                [Yy]|"")
                    rm -f "$nginx_file"
                    ok "Nginx 配置文件已删除"
                    break
                    ;;
                [Nn])
                    info "跳过 Nginx 配置文件删除"
                    break
                    ;;
                *) err "输入无效，请输入 Y 或 N" ;;
            esac
        done
    else
        info "Nginx 配置文件不存在，跳过"
    fi

    # ---- 3. 项目文件夹检测 ----
    project_dir="$php_project_path/$project_folder"
    if [ -d "$project_dir" ]; then
        warn "宿主机项目文件夹存在: $project_dir"
        while true; do
            ask "是否删除宿主机上的项目文件夹? [${C_CYAN}Y/n$C_RESET]（直接回车默认 Y）:"
            read -r input
            case "${input:-Y}" in
                [Yy]|"")
                    rm -rf "$project_dir"
                    ok "宿主机项目文件夹已成功彻底删除！"
                    break
                    ;;
                [Nn])
                    info "跳过项目文件夹删除"
                    break
                    ;;
                *) err "输入无效，请输入 Y 或 N" ;;
            esac
        done
    else
        info "宿主机项目文件夹不存在 ($project_dir)，跳过删除"
    fi

    echo
    ok "操作完成"
}

cmd_list() {
    nginx_conf_dir="$dnmp_path/services/nginx/conf.d"
    if [ ! -d "$nginx_conf_dir" ]; then
        echo -e "${C_RESET}${C_TITLE}❌ Nginx 配置目录不存在:${C_RESET} $nginx_conf_dir"
        exit 1
    fi

    records=""
    count_total=0
    count_on=0
    count_off=0
    count_none=0
    count_proxy=0

    for nginx_conf_file in "$nginx_conf_dir"/*.conf; do
        [ -f "$nginx_conf_file" ] || continue
        basename_f=$(basename "$nginx_conf_file")
        [[ "$basename_f" == "default.conf" || "$basename_f" == "default.conf.sample" ]] && continue

        tmp_server_name=$(pick_directive "$nginx_conf_file" 'server_name')
        server_name=$(printf '%s' "$tmp_server_name" | sed -E 's/^[[:space:]]*server_name[[:space:]]+([^;]+);.*/\1/' | tr -d '[:space:]')

        tmp_root=$(pick_directive "$nginx_conf_file" 'root')
        root_line=$(printf '%s' "$tmp_root" | sed -E 's/^[[:space:]]*root[[:space:]]+([^;]+);.*/\1/' | tr -d '[:space:]')

        tmp_php=$(pick_directives_all "$nginx_conf_file" 'include')
        version_name=""
        while IFS= read -r inc; do
            [ -z "$inc" ] && continue
            if printf '%s' "$inc" | grep -q 'conf.d/php/'; then
                version_name=$(printf '%s' "$inc" | sed -E 's|.*conf\.d/php/([^/]+)\.conf.*|\1|')
                break
            fi
        done <<< "$(printf '%s\n' "$tmp_php")"

        is_proxy=0
        if [ -z "$root_line" ] && [ -z "$version_name" ]; then
            is_proxy=1
        fi

        if [ "$is_proxy" -eq 1 ]; then
            real_path="—"
        else
            # 【同步修复】：列表查询也采用统一的正则方案，确保宿主机路径显示完全正确
            if [[ "$root_line" =~ /www/([^/]+) ]]; then
                project_name="${BASH_REMATCH[1]}"
            else
                project_name=$(printf '%s' "$root_line" | sed -E 's|^.*/([^/]+)/?$|\1|')
            fi
            real_path="$php_project_path/$project_name"
        fi

        if [ "$is_proxy" -eq 1 ]; then
            version_label="代理"
            status_label="代理"
            count_proxy=$((count_proxy+1))
        else
            version_label="${version_name:-—}"

            if [ -z "$server_name" ]; then
                status_label="不存在"
                count_none=$((count_none+1))
            else
                domain_regex=$(echo "$server_name" | sed 's/\./\\./g')
                if grep -qE "^[[:space:]]*[^#]*([[:space:]]|$)${domain_regex}([[:space:]]|$)" /etc/hosts 2>/dev/null; then
                    status_label="启用"
                    count_on=$((count_on+1))
                elif grep -qE "^[[:space:]]*#[[:space:]]*[0-9.]+[[:space:]]+${domain_regex}([[:space:]]|$)" /etc/hosts 2>/dev/null; then
                    status_label="禁用"
                    count_off=$((count_off+1))
                else
                    status_label="不存在"
                    count_none=$((count_none+1))
                fi
            fi
        fi

        [ -z "$server_name" ] && server_name="(未命名)"

        records+="${server_name}"$'\t'"${real_path}"$'\t'"${version_label}"$'\t'"${status_label}"$'\n'
        count_total=$((count_total+1))
    done

    # ---- 绘制（单次 perl 完成宽度计算 + 卡片渲染） ----
    export C_RESET C_TITLE C_ACCENT C_CYAN C_GREEN C_YELLOW C_DIM C_MAGENTA C_LABEL C_VALUE
    export count_total count_on count_off count_none count_proxy

    printf '%s' "$records" | perl -Mutf8 -CA -e '
        use utf8;
        binmode(STDIN,  ":utf8"); binmode(STDOUT, ":utf8");

        my %C = map { $_ => $ENV{$_} } qw(C_RESET C_TITLE C_ACCENT C_CYAN C_GREEN C_YELLOW C_DIM C_MAGENTA C_LABEL C_VALUE);
        my ($total,$on,$off,$none,$proxy) = @ENV{qw(count_total count_on count_off count_none count_proxy)};

        sub w {
            my $s = shift; $s =~ s/\e\[[0-9;]*m//g; my $w = 0;
            for my $c (split //, $s) {
                my $cp = ord $c;
                if ($cp >= 0x1100 && ($cp <= 0x115F || ($cp >= 0x2E80 && $cp <= 0xA4CF) ||
                    ($cp >= 0xAC00 && $cp <= 0xD7A3) || ($cp >= 0xF900 && $cp <= 0xFAFF) ||
                    ($cp >= 0xFE30 && $cp <= 0xFE4F) || ($cp >= 0xFF00 && $cp <= 0xFF60) ||
                    ($cp >= 0xFFE0 && $cp <= 0xFFE6))) { $w += 2 } else { $w += 1 }
            }
            return $w;
        }
        sub status_color {
            my $s = shift;
            return $C{C_GREEN}    if $s eq "启用";
            return $C{C_YELLOW}   if $s eq "禁用";
            return $C{C_DIM}      if $s eq "不存在";
            return $C{C_MAGENTA}  if $s eq "代理";
            return $C{C_VALUE};
        }

        my @recs;
        while (my $line = <STDIN>) {
            chomp $line; next if $line eq "";
            my ($sname, $rpath, $ver, $stat) = split /\t/, $line, 4;
            push @recs, [$sname, $rpath, $ver, $stat];
        }

        my @cols = (
            ["#",      sub { shift->{idx} }],
            ["域名",   sub { shift->{sname} }],
            ["项目地址", sub { shift->{rpath} }],
            ["PHP版本", sub { shift->{ver} }],
            ["状态",   sub { shift->{stat} }],
        );

        my @colw;
        for my $c (@cols) { $colw[$#colw + 1] = w($c->[0]); }
        for my $r (@recs) {
            my %h = (sname => $r->[0], rpath => $r->[1], ver => $r->[2], stat => $r->[3]);
            for my $ci (0 .. $#cols) {
                my $val = $cols[$ci][1]->(\%h);
                my $vw = w($val); $colw[$ci] = $vw if $vw > $colw[$ci];
            }
        }
        $colw[0] = 2 if $colw[0] < 2;

        my $top    = "┌" . join("┬", map { "─" x ($_ + 2) } @colw) . "┐\n";
        my $mid    = "├" . join("┼", map { "─" x ($_ + 2) } @colw) . "┤\n";
        my $bottom = "└" . join("┴", map { "─" x ($_ + 2) } @colw) . "┘\n";

        print "\n  $C{C_TITLE}▰▰▰  DNMP HOST LIST  ▰▰▰$C{C_RESET}\n";
        print "  $C{C_DIM}" . ("─" x 28) . "$C{C_RESET}\n";
        printf  "  $C{C_CYAN}站点总数$C{C_RESET} $C{C_VALUE}%d$C{C_RESET}   ", $total;
        printf  "$C{C_GREEN}● 启用 %d$C{C_RESET}  ", $on;
        printf  "$C{C_YELLOW}● 禁用 %d$C{C_RESET}  ", $off;
        printf  "$C{C_DIM}● 不存在 %d$C{C_RESET}  ", $none;
        printf  "$C{C_MAGENTA}● 代理 %d$C{C_RESET}\n", $proxy;
        print "\n";

        print $top;
        my $hdr_row = "│";
        for my $ci (0 .. $#cols) {
            my $val = $cols[$ci][0];
            $hdr_row .= " " . pad("$C{C_CYAN}$val", $colw[$ci]) . "$C{C_RESET} │";
        }
        print $hdr_row . "\n";
        print $mid;

        my $i = 0;
        for my $r (@recs) {
            $i++;
            my %h = (idx => $i, sname => $r->[0], rpath => $r->[1], ver => $r->[2], stat => $r->[3]);
            my @cells; push @cells, $cols[$_][1]->(\%h) for (0 .. $#cols);
            my $row = "│";
            for my $ci (0 .. $#cols) {
                my $val = $cells[$ci]; my $color = "";
                if    ($ci == 0) { $color = $C{C_VALUE}; }
                elsif ($ci == 1) { $color = $C{C_VALUE}; }
                elsif ($ci == 2) { $color = $C{C_VALUE}; }
                elsif ($ci == 3) { $color = $C{C_LABEL}; }
                elsif ($ci == 4) { $color = status_color($val); }
                $row .= " " . pad("$color$val", $colw[$ci]) . "$C{C_RESET} │";
            }
            print $row . "\n";
        }
        print $bottom;
        sub pad { my ($s, $target) = @_; my $p = $target - w($s); $p = 0 if $p < 0; return $s . (" " x $p); }
    '
}

# ---- 入口 ----
case "${1:-}" in
    add)  cmd_add ;;
    del)  cmd_del ;;
    list) cmd_list ;;
    *)
        echo "用法: $(basename "$0") add|del|list"
        echo "  add  - 新增网站"
        echo "  del  - 删除网站"
        echo "  list - 列出所有网站"
        exit 1
        ;;
esac