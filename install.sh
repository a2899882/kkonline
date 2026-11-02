#!/bin/bash

author=a2899882
# github=https://github.com/a2899882/kkonline

# bash fonts colors
red='\e[31m'
yellow='\e[33m'
gray='\e[90m'
green='\e[92m'
blue='\e[94m'
magenta='\e[95m'
cyan='\e[96m'
none='\e[0m'
_red() { echo -e ${red}$@${none}; }
_blue() { echo -e ${blue}$@${none}; }
_cyan() { echo -e ${cyan}$@${none}; }
_green() { echo -e ${green}$@${none}; }
_yellow() { echo -e ${yellow}$@${none}; }
_magenta() { echo -e ${magenta}$@${none}; }
_red_bg() { echo -e "\e[41m$@${none}"; }

is_err=$(_red_bg 错误!)
is_warn=$(_red_bg 警告!)

err() {
    echo -e "\n$is_err $@\n" && exit 1
}

warn() {
    echo -e "\n$is_warn $@\n"
}

# root
[[ $EUID != 0 ]] && err "当前非 ${yellow}ROOT用户.${none} 请使用 root 权限运行脚本."

# Adaptive package manager detection: Debian/Ubuntu (apt-get), Alpine (apk), CentOS/RHEL (dnf/yum), SUSE (zypper)
cmd=$(type -P apt-get || type -P apk || type -P dnf || type -P yum || type -P zypper)
[[ ! $cmd ]] && err "此脚本仅支持 ${yellow}(Debian / Ubuntu / Alpine / CentOS / SUSE)${none}."

# systemd or openrc
is_systemd=$(type -P systemctl)
is_openrc=$(type -P rc-service)
[[ ! $is_systemd && ! $is_openrc ]] && {
    err "此系统缺少 ${yellow}(systemctl 或 rc-service)${none}, 请安装 systemd 或确认 Alpine OpenRC 已启用."
}

# wget installed or none
is_wget=$(type -P wget)

# x64 / arm64
case $(uname -m) in
amd64 | x86_64)
    is_arch=amd64
    ;;
*aarch64* | *armv8*)
    is_arch=arm64
    ;;
*)
    err "此脚本仅支持 64 位系统 (amd64 / arm64)..."
    ;;
esac

is_core=sing-box
is_core_name=sing-box
is_core_dir=/etc/$is_core
is_core_bin=$is_core_dir/bin/$is_core
is_core_repo=SagerNet/$is_core
is_conf_dir=$is_core_dir/conf
is_log_dir=/var/log/$is_core
is_sh_bin=/usr/local/bin/kk
is_sb_bin=/usr/local/bin/$is_core
is_sh_dir=$is_core_dir/sh
is_sh_repo=$author/kkonline
is_pkg="wget tar bash openssl ca-certificates"
# Alpine: gcompat provides glibc compatibility for prebuilt binaries; iproute2 provides ss for port checking
if [[ $cmd =~ apk ]]; then
    is_pkg="$is_pkg gcompat jq iproute2 coreutils procps"
elif [[ $cmd =~ apt-get ]]; then
    is_pkg="$is_pkg iproute2 procps"
fi
is_config_json=$is_core_dir/config.json
tmp_var_lists=(
    tmpcore
    tmpsh
    tmpjq
    is_core_ok
    is_sh_ok
    is_jq_ok
    is_pkg_ok
)

# tmp dir
tmpdir=$(mktemp -u)
[[ ! $tmpdir ]] && {
    tmpdir=/tmp/tmp-$RANDOM
}

# set up var
for i in ${tmp_var_lists[*]}; do
    export $i=$tmpdir/$i
done

# load bash script.
load() {
    . $is_sh_dir/src/$1
}

# wget add --no-check-certificate
_wget() {
    [[ $proxy ]] && export https_proxy=$proxy
    wget --no-check-certificate $*
}

# print a message
msg() {
    case $1 in
    warn)
        local color=$yellow
        ;;
    err)
        local color=$red
        ;;
    ok)
        local color=$green
        ;;
    esac

    echo -e "${color}$(date +'%T')${none}) ${2}"
}

# show help msg
show_help() {
    echo -e "Usage: $0 [-f xxx | -l | -p xxx | -v xxx | -h]"
    echo -e "  -f, --core-file <path>          自定义 $is_core_name 文件路径, e.g., -f /root/$is_core-linux-amd64.tar.gz"
    echo -e "  -l, --local-install             本地获取安装脚本, 使用当前目录"
    echo -e "  -p, --proxy <addr>              使用代理下载, e.g., -p http://127.0.0.1:2333"
    echo -e "  -v, --core-version <ver>        自定义 $is_core_name 版本, e.g., -v v1.12.0"
    echo -e "  -h, --help                      显示此帮助界面\n"

    exit 0
}

# install dependent pkg (lightweight, cleans package cache to save disk space)
install_pkg() {
    cmd_not_found=
    for i in $*; do
        [[ ! $(type -P $i) ]] && cmd_not_found="$cmd_not_found,$i"
    done
    if [[ $cmd_not_found ]]; then
        pkg=$(echo $cmd_not_found | sed 's/,/ /g')
        msg warn "安装系统依赖包 >${pkg}"
        if [[ $cmd =~ apk ]]; then
            apk add --no-cache $pkg &>/dev/null || {
                apk update &>/dev/null
                apk add --no-cache $pkg &>/dev/null
            }
        elif [[ $cmd =~ apt-get ]]; then
            export DEBIAN_FRONTEND=noninteractive
            $cmd install -y --no-install-recommends $pkg &>/dev/null
            if [[ $? != 0 ]]; then
                $cmd update -y &>/dev/null
                $cmd install -y --no-install-recommends $pkg &>/dev/null
            fi
        else
            $cmd install -y $pkg &>/dev/null
            if [[ $? != 0 ]]; then
                [[ $cmd =~ yum ]] && yum install epel-release -y &>/dev/null
                if [[ $cmd =~ zypper ]]; then
                    $cmd --non-interactive refresh &>/dev/null
                else
                    $cmd update -y &>/dev/null
                fi
                $cmd install -y $pkg &>/dev/null
            fi
        fi
        [[ $? == 0 ]] && >$is_pkg_ok
    else
        >$is_pkg_ok
    fi
}

# download file
download() {
    case $1 in
    core)
        [[ ! $is_core_ver ]] && is_core_ver=$(_wget -qO- "https://api.github.com/repos/${is_core_repo}/releases/latest?v=$RANDOM" | grep tag_name | grep -E -o 'v([0-9.]+)')
        [[ $is_core_ver ]] && link="https://github.com/${is_core_repo}/releases/download/${is_core_ver}/${is_core}-${is_core_ver:1}-linux-${is_arch}.tar.gz"
        name=$is_core_name
        tmpfile=$tmpcore
        is_ok=$is_core_ok
        [[ $link ]] && {
            msg warn "下载 ${name} > ${link}"
            if _wget -t 3 -q -c $link -O $tmpfile; then
                mv -f $tmpfile $is_ok
            fi
        }
        ;;
    sh)
        # Support both GitHub main branch archive directly (no Release needed) and Releases code.tar.gz
        link_main="https://github.com/${is_sh_repo}/archive/refs/heads/main.tar.gz"
        link_rel="https://github.com/${is_sh_repo}/releases/latest/download/code.tar.gz"
        name="$is_core_name 脚本 (kkonline)"
        tmpfile=$tmpsh
        is_ok=$is_sh_ok
        msg warn "下载 ${name} > ${link_main}"
        if _wget -t 3 -q -c $link_main -O $tmpfile; then
            mv -f $tmpfile $is_ok
        elif _wget -t 3 -q -c $link_rel -O $tmpfile; then
            mv -f $tmpfile $is_ok
        fi
        ;;
    jq)
        link=https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-$is_arch
        name="jq"
        tmpfile=$tmpjq
        is_ok=$is_jq_ok
        [[ $link ]] && {
            msg warn "下载 ${name} > ${link}"
            if _wget -t 3 -q -c $link -O $tmpfile; then
                mv -f $tmpfile $is_ok
            fi
        }
        ;;
    esac
}

# get server ip
get_ip() {
    export "$(_wget -4 -qO- https://one.one.one.one/cdn-cgi/trace | grep ip=)" &>/dev/null
    [[ -z $ip ]] && export "$(_wget -6 -qO- https://one.one.one.one/cdn-cgi/trace | grep ip=)" &>/dev/null
    [[ -z $ip ]] && ip=$(_wget -4 -qO- https://api.ipify.org 2>/dev/null)
    [[ -z $ip ]] && ip=$(_wget -6 -qO- https://api64.ipify.org 2>/dev/null)
}

# check background tasks status
check_status() {
    # dependent pkg install fail
    [[ ! -f $is_pkg_ok ]] && {
        msg err "安装依赖包失败"
        if [[ $cmd =~ apk ]]; then
            msg err "请尝试手动安装依赖包: apk update; apk add $is_pkg"
        else
            msg err "请尝试手动安装依赖包: $cmd update -y; $cmd install -y $is_pkg"
        fi
        is_fail=1
    }

    # download file status
    if [[ $is_wget ]]; then
        [[ ! -f $is_core_ok ]] && {
            msg err "下载 ${is_core_name} 失败"
            is_fail=1
        }
        [[ ! -f $is_sh_ok ]] && {
            msg err "下载 ${is_core_name} 脚本失败"
            is_fail=1
        }
        [[ ! -f $is_jq_ok ]] && {
            msg err "下载 jq 失败"
            is_fail=1
        }
    else
        [[ ! $is_fail ]] && {
            is_wget=1
            [[ ! $is_core_file ]] && download core &
            [[ ! $local_install ]] && download sh &
            [[ $jq_not_found ]] && download jq &
            get_ip
            wait
            check_status
        }
    fi

    # found fail status, remove tmp dir and exit.
    [[ $is_fail ]] && {
        exit_and_del_tmpdir
    }
}

# parameters check
pass_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
        -f | --core-file)
            [[ -z $2 ]] && {
                err "($1) 缺少必需参数, 正确使用示例: [$1 /root/$is_core-linux-amd64.tar.gz]"
            } || [[ ! -f $2 ]] && {
                err "($2) 不是一个常规的文件."
            }
            is_core_file=$2
            shift 2
            ;;
        -l | --local-install)
            [[ ! -f ${PWD}/src/core.sh ]] && {
                err "当前目录 (${PWD}) 非完整的脚本目录."
            }
            local_install=1
            shift 1
            ;;
        -p | --proxy)
            [[ -z $2 ]] && {
                err "($1) 缺少必需参数, 正确使用示例: [$1 http://127.0.0.1:2333 or -p socks5://127.0.0.1:2333]"
            }
            proxy=$2
            shift 2
            ;;
        -v | --core-version)
            [[ -z $2 ]] && {
                err "($1) 缺少必需参数, 正确使用示例: [$1 v1.12.0]"
            }
            is_core_ver=v${2//v/}
            shift 2
            ;;
        -h | --help)
            show_help
            ;;
        *)
            echo -e "\n${is_err} ($@) 为未知参数...\n"
            show_help
            ;;
        esac
    done
    [[ $is_core_ver && $is_core_file ]] && {
        err "无法同时自定义 ${is_core_name} 版本和 ${is_core_name} 文件."
    }
}

# exit and remove tmpdir
exit_and_del_tmpdir() {
    rm -rf $tmpdir
    [[ ! $1 ]] && {
        msg err "安装过程出现错误..."
        echo -e "反馈问题) https://github.com/${is_sh_repo}/issues"
        echo
        exit 1
    }
    exit
}

# main
main() {

    # check old version
    [[ -f $is_sh_bin && -d $is_core_dir/bin && -d $is_sh_dir && -d $is_conf_dir ]] && {
        err "检测到脚本已安装, 如需管理请直接输入 ${green}kk${none} 命令, 如需重装请使用 ${green}kk reinstall${none} 命令."
    }

    # check parameters
    [[ $# -gt 0 ]] && pass_args $@

    # show welcome msg
    clear
    echo
    echo "=========================================================="
    echo "       KK Sing-box 轻量一键安装脚本 by $author"
    echo "   支持 Debian / Ubuntu / Alpine | 默认开启 BBR+FQ & Hy2加速"
    echo "=========================================================="
    echo

    # start installing...
    msg warn "开始自适应环境安装..."
    [[ $is_core_ver ]] && msg warn "${is_core_name} 版本: ${yellow}$is_core_ver${none}"
    [[ $proxy ]] && msg warn "使用代理: ${yellow}$proxy${none}"
    # create tmpdir
    mkdir -p $tmpdir
    # if is_core_file, copy file
    [[ $is_core_file ]] && {
        cp -f $is_core_file $is_core_ok
        msg warn "${yellow}${is_core_name} 文件使用 > $is_core_file${none}"
    }
    # local dir install sh script
    [[ $local_install ]] && {
        >$is_sh_ok
        msg warn "${yellow}本地获取安装脚本 > $PWD ${none}"
    }

    if [[ $is_systemd ]]; then
        timedatectl set-ntp true &>/dev/null
        [[ $? != 0 ]] && {
            is_ntp_on=1
        }
    fi

    # install dependent pkg
    if [[ $cmd =~ apk ]]; then
        # Alpine: install full utilities with --no-cache to save disk space
        apk add --no-cache $is_pkg &>/dev/null || {
            apk update &>/dev/null
            apk add --no-cache $is_pkg &>/dev/null
        }
        [[ $? == 0 ]] && >$is_pkg_ok
    else
        install_pkg $is_pkg &
    fi

    # jq
    if [[ $(type -P jq) ]]; then
        >$is_jq_ok
    else
        jq_not_found=1
    fi
    # if wget installed. download core, sh, jq, get ip
    [[ $is_wget ]] && {
        [[ ! $is_core_file ]] && download core &
        [[ ! $local_install ]] && download sh &
        [[ $jq_not_found ]] && download jq &
        get_ip
    }

    # waiting for background tasks is done
    wait

    # check background tasks status
    check_status

    # test $is_core_file
    if [[ $is_core_file ]]; then
        mkdir -p $tmpdir/testzip
        tar zxf $is_core_ok --strip-components 1 -C $tmpdir/testzip &>/dev/null
        [[ $? != 0 ]] && {
            msg err "${is_core_name} 文件无法通过测试."
            exit_and_del_tmpdir
        }
        [[ ! -f $tmpdir/testzip/$is_core ]] && {
            msg err "${is_core_name} 文件无法通过测试."
            exit_and_del_tmpdir
        }
    fi

    # get server ip.
    [[ ! $ip ]] && {
        msg err "获取服务器 IP 失败."
        exit_and_del_tmpdir
    }

    # create sh dir...
    mkdir -p $is_sh_dir

    # copy sh file or unzip sh zip file (handles both main.tar.gz with top-level dir and code.tar.gz)
    if [[ $local_install ]]; then
        cp -rf $PWD/* $is_sh_dir
    else
        mkdir -p $tmpdir/sh_extract
        tar zxf $is_sh_ok -C $tmpdir/sh_extract
        if [[ -f $tmpdir/sh_extract/src/core.sh ]]; then
            cp -rf $tmpdir/sh_extract/* $is_sh_dir/
        else
            cp -rf $tmpdir/sh_extract/*/* $is_sh_dir/
        fi
    fi

    # create core bin dir (only keep binary to minimize disk footprint)
    mkdir -p $is_core_dir/bin
    if [[ $is_core_file ]]; then
        cp -rf $tmpdir/testzip/$is_core $is_core_dir/bin/$is_core
    else
        tar zxf $is_core_ok --strip-components 1 -C $is_core_dir/bin
        rm -f $is_core_dir/bin/LICENSE $is_core_dir/bin/README.md 2>/dev/null
    fi

    # ensure both kk.sh and sing-box.sh exist in $is_sh_dir
    [[ -f $is_sh_dir/kk.sh && ! -f $is_sh_dir/$is_core.sh ]] && cp -f $is_sh_dir/kk.sh $is_sh_dir/$is_core.sh
    [[ -f $is_sh_dir/$is_core.sh && ! -f $is_sh_dir/kk.sh ]] && cp -f $is_sh_dir/$is_core.sh $is_sh_dir/kk.sh

    # add alias & symlinks for kk (primary), sb, and sing-box
    sed -i "/alias kk=/d" /root/.bashrc 2>/dev/null
    sed -i "/alias sb=/d" /root/.bashrc 2>/dev/null
    sed -i "/alias $is_core=/d" /root/.bashrc 2>/dev/null
    echo "alias kk=$is_sh_bin" >>/root/.bashrc
    echo "alias sb=$is_sh_bin" >>/root/.bashrc
    echo "alias $is_core=$is_sh_bin" >>/root/.bashrc

    ln -sf $is_sh_dir/kk.sh $is_sh_bin
    ln -sf $is_sh_dir/kk.sh $is_sb_bin
    ln -sf $is_sh_dir/kk.sh /usr/local/bin/sb

    # jq
    [[ $jq_not_found ]] && mv -f $is_jq_ok /usr/bin/jq

    # chmod
    chmod +x $is_core_bin $is_sh_bin $is_sb_bin /usr/local/bin/sb $is_sh_dir/kk.sh $is_sh_dir/$is_core.sh /usr/bin/jq 2>/dev/null

    # create log dir
    mkdir -p $is_log_dir

    # Enable BBR + FQ + Hysteria2 kernel optimizations automatically by default
    msg ok "开启 BBR+FQ 与 Hysteria2 高并发网络加速优化..."
    load bbr.sh
    _auto_enable_bbr_hy2

    # show a tips msg
    msg ok "生成配置文件并创建默认 Shadowsocks (aes-128-gcm) 节点..."

    # create service
    load systemd.sh
    is_new_install=1
    install_service $is_core &>/dev/null

    # create conf dir
    mkdir -p $is_conf_dir

    load core.sh
    # Default node: random port + high-strength random password + Shadowsocks aes-128-gcm
    add ss auto auto aes-128-gcm
    # wait for background tasks (e.g., OpenRC service start)
    wait
    # remove tmp dir and exit.
    exit_and_del_tmpdir ok
}

# start.
main $@
