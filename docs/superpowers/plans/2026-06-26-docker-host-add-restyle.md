# docker_host_add.sh 风格统一重构 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 按 `docker_host_list.sh` 的配色与方框卡片风格，对交互式脚本 `docker_host_add.sh` 做完整翻新，统一视觉、优化交互呈现并加固健壮性，功能行为保持不变（仅放宽备注校验 + 明确的健壮性修复）。

**Architecture:** 方案 C 混合实现——交互提示/分段标题/状态提示用纯 Bash 辅助函数；需要精确对齐的方框卡片（选择列表、确认卡片、结果摘要卡片）复用 `list.sh` 的 perl 宽度计算渲染。最终流程调整为：采集全部输入 → 确认卡片 → 执行写操作 → 结果摘要卡片。

**Tech Stack:** Bash、perl（CJK 宽度对齐，环境已有，`list.sh` 已用）、sed（macOS/Linux 兼容）、docker compose。

---

## File Structure

- Modify: `docker_host_add.sh`（整文件翻新，单文件，保持单文件结构）

无需新增文件。所有辅助函数与 perl 渲染器内联在该脚本顶部，符合现有项目"每个操作一个脚本"的约定。

## 验证方式说明

Bash 脚本无传统单测，本计划每个改动后的验证步骤为：

1. 语法检查：`bash -n docker_host_add.sh`，期望无输出、退出码 0。
2. 必要时用 `shellcheck docker_host_add.sh`（若环境有），关注 error 级别。
3. 关键分支人工走查（最终任务统一执行）。

---

### Task 1: 顶部加入配色调色板与纯 Bash 辅助函数

**Files:**
- Modify: `docker_host_add.sh`（在 `.env` 加载后、业务逻辑前插入）

- [ ] **Step 1: 在 php_project_path 定义之后插入配色与辅助函数**

在 `php_project_path=${PHP_PROJECT_PATH}` 这一行之后插入：

```bash
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
```

- [ ] **Step 2: 同步把开头 .env 不存在的报错改用红色风格（仍在函数定义前，故保留原始 echo）**

`.env` 检查发生在颜色变量定义之前，保留其原有写法：

```bash
echo -e "\033[1;31m❌ .env 文件不存在，请确保在 Dnmp 项目根目录执行脚本\033[0m"
```
（仅把提示文案与 `list.sh` 对齐为"请确保在 Dnmp 项目根目录执行脚本"。）

- [ ] **Step 3: 语法检查**

Run: `bash -n docker_host_add.sh`
Expected: 无输出，退出码 0

- [ ] **Step 4: Commit**

```bash
git add docker_host_add.sh
git commit -m "feat: docker_host_add 加入统一配色与提示辅助函数"
```

---

### Task 2: 加入 perl 方框卡片渲染器（两列 key-value 卡片 + 序号选择表）

**Files:**
- Modify: `docker_host_add.sh`（紧接 Task 1 的辅助函数之后插入两个渲染函数）

- [ ] **Step 1: 插入 key-value 卡片渲染函数 `render_kv_card`**

用于确认卡片与结果摘要卡片。输入：标题（环境变量 `CARD_TITLE`）、stdin 每行 `字段\t值`。

```bash
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
        sub pad { my ($s,$t)=@_; my $p=$t-w($s); $p=0 if $p<0; return $s.(" " x $p); }
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
```

- [ ] **Step 2: 插入序号选择表渲染函数 `render_choice_list`**

用于 PHP 版本 / 框架选择展示。输入：标题（`CARD_TITLE`），stdin 每行 `序号\t名称`。

```bash
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
        sub pad { my ($s,$t)=@_; my $p=$t-w($s); $p=0 if $p<0; return $s.(" " x $p); }
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
```

- [ ] **Step 3: 语法检查**

Run: `bash -n docker_host_add.sh`
Expected: 无输出，退出码 0

- [ ] **Step 4: Commit**

```bash
git add docker_host_add.sh
git commit -m "feat: docker_host_add 加入 perl 方框卡片渲染器"
```

---

### Task 3: 重构输入采集（文件夹/域名/备注），放宽备注校验

**Files:**
- Modify: `docker_host_add.sh:22-69`（原三个 while 校验块）

- [ ] **Step 1: 在三个输入块前加分段标题，并替换提示样式**

将原 `error_count=0` 起到第三个备注 while 结束替换为：

```bash
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
```

- [ ] **Step 2: 语法检查**

Run: `bash -n docker_host_add.sh`
Expected: 无输出，退出码 0

- [ ] **Step 3: Commit**

```bash
git add docker_host_add.sh
git commit -m "feat: docker_host_add 重构输入采集并放宽备注校验"
```

---

### Task 4: PHP 版本选择改用方框列表

**Files:**
- Modify: `docker_host_add.sh:101-125`（PHP 版本提示与选择块）

- [ ] **Step 1: 替换 PHP 版本展示与选择逻辑**

将原"输出可用 PHP 版本 + 选择"块替换为（保留 `available_php_versions`、`index` 的采集逻辑不变）：

```bash
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
```

- [ ] **Step 2: 语法检查**

Run: `bash -n docker_host_add.sh`
Expected: 无输出，退出码 0

- [ ] **Step 3: Commit**

```bash
git add docker_host_add.sh
git commit -m "feat: docker_host_add PHP 版本选择改用方框列表"
```

---

### Task 5: 框架选择改用方框列表

**Files:**
- Modify: `docker_host_add.sh:145-172`（框架选择展示与选择块）

- [ ] **Step 1: 替换框架展示与选择逻辑**

保留 `available_frameworks` 采集与空目录报错（报错改用 `err`），将展示+选择替换为：

```bash
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
```

并把空目录检查处的报错改为：

```bash
if [ ${#available_frameworks[@]} -eq 0 ]; then
    err "PHP 框架配置目录错误!!!"
    exit 1
fi
```

- [ ] **Step 2: 语法检查**

Run: `bash -n docker_host_add.sh`
Expected: 无输出，退出码 0

- [ ] **Step 3: Commit**

```bash
git add docker_host_add.sh
git commit -m "feat: docker_host_add 框架选择改用方框列表"
```

---

### Task 6: 在写操作前插入"创建前确认卡片"

**Files:**
- Modify: `docker_host_add.sh`（在框架选择之后、原"创建网站目录"之前插入）

- [ ] **Step 1: 计算待展示字段并渲染确认卡片**

在框架选择完成后插入。先算出展示用的框架名与项目路径：

```bash
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
```

注意：`printf '%s\t%s\n'` 配合多组参数会按每两个参数循环输出一行，得到 6 行 `字段\t值`。

- [ ] **Step 2: 语法检查**

Run: `bash -n docker_host_add.sh`
Expected: 无输出，退出码 0

- [ ] **Step 3: Commit**

```bash
git add docker_host_add.sh
git commit -m "feat: docker_host_add 写操作前加入确认卡片"
```

---

### Task 7: 重构写操作段（目录/nginx/hosts）的提示与健壮性

**Files:**
- Modify: `docker_host_add.sh`（原"创建网站目录""创建 Nginx 配置""框架写入""写入 Host"段）

- [ ] **Step 1: 重构创建网站目录段**

```bash
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
```

- [ ] **Step 2: 重构 Nginx 配置生成段（保留 run_sed 兼容函数）**

```bash
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

run_sed "s/default.host/$domain_name/g" "$nginx_conf_file"
run_sed "s/default.error/$domain_name.error/g" "$nginx_conf_file"
run_sed "s/php.version/$selected_php_version/g" "$nginx_conf_file"
ok "已生成配置文件: $nginx_conf_file"
```

（健壮性：将原先未加引号的 `$domain_name.conf` 统一改为 `"$nginx_conf_file"`。）

- [ ] **Step 3: 重构框架写入段**

```bash
if [[ $frame_choice -ge 1 ]]; then
    selected_framework_path=${available_frameworks[$((frame_choice - 1))]}
    selected_framework=$(basename "$selected_framework_path")
    full_name="conf.d\/rewrite\/${selected_framework}"
    run_sed "s/frame.config/${full_name}/g" "$nginx_conf_file"
    case $selected_framework in
        "laravel.conf")
            run_sed "s/default.file/$folder_name\/public/g" "$nginx_conf_file"
            ;;
        *)
            run_sed "s/default.file/$folder_name/g" "$nginx_conf_file"
            ;;
    esac
    info "已写入框架配置: $selected_framework"
else
    run_sed "s/include frame\.config;//g" "$nginx_conf_file"
    info "未配置框架入口"
fi
```

- [ ] **Step 4: 重构写入 hosts 段，并加固重复判断**

用更精确的整词匹配替代子串 `grep -q`，避免 `a.com` 误匹配 `aa.com`：

```bash
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
```

- [ ] **Step 5: 重构重启 nginx 段**

```bash
section "重启 Nginx"
cd "$dnmp_path"
docker compose restart nginx
```

- [ ] **Step 6: 语法检查**

Run: `bash -n docker_host_add.sh`
Expected: 无输出，退出码 0

- [ ] **Step 7: Commit**

```bash
git add docker_host_add.sh
git commit -m "feat: docker_host_add 重构写操作段提示并加固 hosts/sed"
```

---

### Task 8: 结尾结果摘要卡片

**Files:**
- Modify: `docker_host_add.sh`（替换原结尾的 `echo -e "...网站创建成功..."`）

- [ ] **Step 1: 替换结尾提示为绿色摘要卡片**

```bash
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
```

- [ ] **Step 2: 语法检查**

Run: `bash -n docker_host_add.sh`
Expected: 无输出，退出码 0

- [ ] **Step 3: Commit**

```bash
git add docker_host_add.sh
git commit -m "feat: docker_host_add 结尾改用绿色结果摘要卡片"
```

---

### Task 9: 整体走查与收尾

**Files:**
- Modify: `docker_host_add.sh`（仅在发现问题时修补）

- [ ] **Step 1: 语法 + shellcheck**

Run:
```bash
bash -n docker_host_add.sh
command -v shellcheck >/dev/null && shellcheck docker_host_add.sh || echo "shellcheck 未安装，跳过"
```
Expected: `bash -n` 无输出；shellcheck 无 error 级别问题（warning 视情况）

- [ ] **Step 2: 人工走查清单（逐项确认输出与对齐）**

- 正常创建（新文件夹 + 选框架）→ 确认卡片、摘要卡片中文对齐正确
- 文件夹已存在 → 取消分支正常退出
- 框架选 `0`（无需配置）→ 删除 include 行
- 确认卡片选 `0` → 取消且不写任何文件
- hosts 已存在域名 → 显示"已存在"，且 `aa.com` 不会误判 `a.com`

- [ ] **Step 3: 最终 commit（如有修补）**

```bash
git add docker_host_add.sh
git commit -m "fix: docker_host_add 走查问题修补"
```

---

## Self-Review

**1. Spec coverage:**
- 配色规范（spec §1）→ Task 1 ✅
- 辅助函数（spec §2）→ Task 1 ✅
- 交互流程 + 加固（spec §3）→ Task 3/4/5/7 ✅（备注放宽 Task 3；sed/hosts 加固 Task 7）
- 创建前确认卡片（spec §4）→ Task 6 ✅
- 选择列表卡片（spec §5）→ Task 2（渲染器）+ Task 4/5（应用）✅
- 结果摘要卡片（spec §6）→ Task 2（渲染器）+ Task 8 ✅

**2. Placeholder scan:** 无 TBD/TODO；每个代码步骤均含完整代码。Task 2 Step 1 故意留的笔误由 Step 2 显式修正，已说明。

**3. Type consistency:** 渲染函数名 `render_kv_card`、`render_choice_list` 全程一致；变量 `confirm_framework`、`confirm_project_path`、`hosts_status` 在 Task 6/7 定义、Task 8 使用，命名一致。
