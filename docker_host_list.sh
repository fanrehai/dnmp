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

# ---- 颜色定义 ----
C_RESET=$'\033[0m'
C_TITLE=$'\033[1;96m'       # 亮青 标题
C_ACCENT=$'\033[1;95m'      # 亮品红 强调
C_CYAN=$'\033[38;5;45m'     # 青 边框/标签
C_GREEN=$'\033[1;92m'       # 绿 启用
C_YELLOW=$'\033[1;93m'      # 黄 禁用
C_DIM=$'\033[38;5;240m'     # 暗灰 不存在
C_MAGENTA=$'\033[38;5;177m' # 紫 代理
C_LABEL=$'\033[38;5;117m'   # 浅蓝 字段名
C_VALUE=$'\033[1;97m'       # 白 字段值

# 提取 nginx 配置中某指令的第一个有效值（跳过注释行）
# 用法: pick_directive <文件> <指令名>
# 返回: 该指令所在行的完整内容（仅第一个非注释匹配）
pick_directive() {
    local file="$1" directive="$2"
    awk -v d="$directive" '
        {
            line=$0
            sub(/^[[:space:]]+/, "", line)        # 去行首空白
            if (line ~ /^#/) next                 # 跳过整行注释
            if (substr(line,1,length(d))==d) {
                # 确认指令后紧跟空白或分号，避免 server 匹配到 server_name
                tail=substr(line,length(d)+1,1)
                if (tail=="" || tail ~ /[[:space:];]/) { print line; exit }
            }
        }
    ' "$file"
}

# 提取 nginx 配置中某指令的所有有效匹配行（跳过注释行）
# 用法: pick_directives_all <文件> <指令名>
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

# ---- 收集数据 ----
nginxConfDir="$dnmpPath/services/nginx/conf.d"
if [ ! -d "$nginxConfDir" ]; then
    echo -e "${C_RESET}${C_TITLE}❌ Nginx 配置目录不存在:${C_RESET} $nginxConfDir"
    exit 1
fi

confFiles=$(find "$nginxConfDir" -maxdepth 1 -type f -name "*.conf" | sort)
if [ -z "$confFiles" ]; then
    echo -e "${C_RESET}${C_TITLE}⚠️ Nginx 配置目录中没有 .conf 文件:${C_RESET} $nginxConfDir"
    exit 0
fi

# 每行一条记录，字段以 \t 分隔: serverName \t projectName \t realPath \t version \t status
records=""
count_total=0
count_on=0
count_off=0
count_none=0
count_proxy=0

for nginxConfFile in $confFiles; do
    [ -f "$nginxConfFile" ] || continue

    # server_name
    tmpServerName=$(pick_directive "$nginxConfFile" 'server_name')
    serverName=$(printf '%s' "$tmpServerName" | sed -E 's/^[[:space:]]*server_name[[:space:]]+([^;]+);.*/\1/' | tr -d '[:space:]')

    # root
    tmpRoot=$(pick_directive "$nginxConfFile" 'root')
    rootLine=$(printf '%s' "$tmpRoot" | sed -E 's/^[[:space:]]*root[[:space:]]+([^;]+);.*/\1/' | tr -d '[:space:]')

    # php include：扫描所有 include 行，找出含 conf.d/php/ 的那个
    tmpPHP=$(pick_directives_all "$nginxConfFile" 'include')
    versionName=""
    while IFS= read -r inc; do
        [ -z "$inc" ] && continue
        if printf '%s' "$inc" | grep -q 'conf.d/php/'; then
            versionName=$(printf '%s' "$inc" | sed -E 's|.*conf\.d/php/([^/]+)\.conf.*|\1|')
            break
        fi
    done <<< "$(printf '%s\n' "$tmpPHP")"

    # 判断是否纯代理：无 root 且无 php include
    isProxy=0
    if [ -z "$rootLine" ] && [ -z "$versionName" ]; then
        isProxy=1
    fi

    # 项目地址
    if [ "$isProxy" -eq 1 ]; then
        realPath="—"
    else
        # 从 root 中提取 /www/<name> 段
        projectName=$(printf '%s' "$rootLine" | sed -E 's|^.*/www/([^/]+).*|\1|')
        if [ "$projectName" = "$rootLine" ]; then
            # 没匹配到 /www/ 前缀，退而用 root 末段
            projectName=$(printf '%s' "$rootLine" | sed -E 's|^.*/([^/]+)/?$|\1|')
        fi
        realPath="$phpProjectPath/$projectName"
    fi

    if [ "$isProxy" -eq 1 ]; then
        versionLabel="代理"
        statusLabel="代理"
        count_proxy=$((count_proxy+1))
    else
        versionLabel="${versionName:-—}"
        # hosts 状态：固定字符串匹配，避免正则/空串误判
        if [ -z "$serverName" ]; then
            statusLabel="不存在"
            count_none=$((count_none+1))
        elif grep -qF "$serverName" /etc/hosts 2>/dev/null; then
            # 取匹配行判断是否被注释
            matchLine=$(grep -F "$serverName" /etc/hosts 2>/dev/null | head -1)
            if printf '%s' "$matchLine" | grep -qE '^[[:space:]]*#'; then
                statusLabel="禁用"
                count_off=$((count_off+1))
            else
                statusLabel="启用"
                count_on=$((count_on+1))
            fi
        else
            statusLabel="不存在"
            count_none=$((count_none+1))
        fi
    fi

    [ -z "$serverName" ] && serverName="(未命名)"

    records+="${serverName}"$'\t'"${realPath}"$'\t'"${versionLabel}"$'\t'"${statusLabel}"$'\n'
    count_total=$((count_total+1))
done

# ---- 绘制（单次 perl 完成宽度计算 + 卡片渲染，避免多次 fork） ----
# 将颜色码与统计量通过环境变量传入 perl，records 通过 stdin（Tab 分隔 4 列）传入。
export C_RESET C_TITLE C_ACCENT C_CYAN C_GREEN C_YELLOW C_DIM C_MAGENTA C_LABEL C_VALUE
export count_total count_on count_off count_none count_proxy

printf '%s' "$records" | perl -Mutf8 -CA -e '
    use utf8;
    binmode(STDIN,  ":utf8");
    binmode(STDOUT, ":utf8");

    # 取环境变量中的 ANSI 颜色（已是真实 ESC 序列）
    my %C = map { $_ => $ENV{$_} } qw(C_RESET C_TITLE C_ACCENT C_CYAN C_GREEN
                                       C_YELLOW C_DIM C_MAGENTA C_LABEL C_VALUE);
    my ($total,$on,$off,$none,$proxy) = @ENV{qw(count_total count_on count_off count_none count_proxy)};

    # 显示宽度：CJK/全角 2，其余 1（剔除 ANSI 转义后再计）
    sub w {
        my $s = shift;
        $s =~ s/\e\[[0-9;]*m//g;
        my $w = 0;
        for my $c (split //, $s) {
            my $cp = ord $c;
            if ($cp >= 0x1100 && (
                $cp <= 0x115F || ($cp >= 0x2E80 && $cp <= 0xA4CF) ||
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

    # 读取所有记录
    my @recs;
    while (my $line = <STDIN>) {
        chomp $line;
        next if $line eq "";
        my ($sname, $rpath, $ver, $stat) = split /\t/, $line, 4;
        push @recs, [$sname, $rpath, $ver, $stat];
    }

    # 列定义: [表头, 取值回调]
    my @cols = (
        ["#",      sub { shift->{idx} }],
        ["域名",   sub { shift->{sname} }],
        ["项目地址", sub { shift->{rpath} }],
        ["PHP版本", sub { shift->{ver} }],
        ["状态",   sub { shift->{stat} }],
    );

    # 第一遍：算每列最大显示宽度（含表头）
    my @colw;
    for my $c (@cols) { $colw[$#colw + 1] = w($c->[0]); }
    for my $r (@recs) {
        my %h = (sname => $r->[0], rpath => $r->[1], ver => $r->[2], stat => $r->[3]);
        for my $ci (0 .. $#cols) {
            my $val = $cols[$ci][1]->(\%h);
            my $vw = w($val);
            $colw[$ci] = $vw if $vw > $colw[$ci];
        }
    }
    # 序号列固定 2 位宽
    $colw[0] = 2 if $colw[0] < 2;

    # 计算表格总宽（用于顶部横线）：每列宽 + 左右各 1 空格 + 列间 1 分隔
    my $inner = 0; $inner += $_ + 2 for @colw;
    my $total_w = $inner + ($#cols);   # 列间 │ 各占 1

    # 右侧用空格填充到指定列宽
    sub pad { my ($s, $target) = @_; my $p = $target - w($s); $p = 0 if $p < 0; return $s . (" " x $p); }


    # 顶部 / 底部 / 分隔横线
    my $top    = "┌" . join("┬", map { "─" x ($_ + 2) } @colw) . "┐\n";
    my $mid    = "├" . join("┼", map { "─" x ($_ + 2) } @colw) . "┤\n";
    my $bottom = "└" . join("┴", map { "─" x ($_ + 2) } @colw) . "┘\n";

    # ---- 标题 + 摘要 ----
    print "\n";
    print "  $C{C_TITLE}▰▰▰  DNMP HOST LIST  ▰▰▰$C{C_RESET}\n";
    print "  $C{C_DIM}" . ("─" x 28) . "$C{C_RESET}\n";
    printf  "  $C{C_CYAN}站点总数$C{C_RESET} $C{C_VALUE}%d$C{C_RESET}   ", $total;
    printf  "$C{C_GREEN}● 启用 %d$C{C_RESET}  ", $on;
    printf  "$C{C_YELLOW}● 禁用 %d$C{C_RESET}  ", $off;
    printf  "$C{C_DIM}● 不存在 %d$C{C_RESET}  ", $none;
    printf  "$C{C_MAGENTA}● 代理 %d$C{C_RESET}\n", $proxy;
    print "\n";

    # ---- 表头（青色字） ----
    print $top;
    my $hdr_row = "│";
    for my $ci (0 .. $#cols) {
        my $val = $cols[$ci][0];
        $hdr_row .= " " . pad("$C{C_CYAN}$val", $colw[$ci]) . "$C{C_RESET} │";
    }
    print $hdr_row . "\n";
    print $mid;

    # ---- 数据行（带斑马纹） ----
    my $i = 0;
    for my $r (@recs) {
        $i++;
        my %h = (idx => $i, sname => $r->[0], rpath => $r->[1], ver => $r->[2], stat => $r->[3]);
        my @cells;
        for my $ci (0 .. $#cols) {
            push @cells, $cols[$ci][1]->(\%h);
        }
        my $row = "│";
        for my $ci (0 .. $#cols) {
            my $val = $cells[$ci];
            my $color = "";
            if    ($ci == 0) { $color = $C{C_VALUE}; }               # 序号 白
            elsif ($ci == 1) { $color = $C{C_VALUE}; }               # 域名 白
            elsif ($ci == 2) { $color = $C{C_VALUE}; }               # 项目地址 白
            elsif ($ci == 3) { $color = $C{C_LABEL}; }               # PHP版本 浅蓝
            elsif ($ci == 4) { $color = status_color($val); }        # 状态 状态色
            # 单元格: 空格 + (填充后的着色值) + 空格 + 复位 + 分隔
            my $cell = pad("$color$val", $colw[$ci]);
            $row .= " $cell$C{C_RESET} │";
        }
        print $row . "\n";
    }
    print $bottom;
'
