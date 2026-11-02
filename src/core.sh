#!/bin/bash

protocol_list=(
    Shadowsocks
    VLESS-REALITY
    Hysteria2
    AnyTLS
    TUIC
    Trojan
    VLESS-HTTP2-REALITY
    VLESS-WS-TLS
    VLESS-H2-TLS
    VLESS-HTTPUpgrade-TLS
    Trojan-WS-TLS
    Trojan-H2-TLS
    Trojan-HTTPUpgrade-TLS
    VMess-WS
    VMess-TCP
    VMess-HTTP
    VMess-QUIC
    VMess-WS-TLS
    VMess-H2-TLS
    VMess-HTTPUpgrade-TLS
    # Direct
    Socks
)
ss_method_list=(
    aes-128-gcm
    aes-256-gcm
    2022-blake3-aes-128-gcm
    2022-blake3-aes-256-gcm
    2022-blake3-chacha20-poly1305
    chacha20-ietf-poly1305
    xchacha20-ietf-poly1305
)
mainmenu=(
    "添加配置 (Add)"
    "更改配置 (Change)"
    "查看配置 (Info/URL/QR)"
    "删除配置 (Delete)"
    "运行管理 (Start/Stop/Restart)"
    "加速优化 (BBR+FQ & Hy2优化)"
    "更新管理 (Update)"
    "卸载脚本 (Uninstall)"
    "帮助说明 (Help)"
    "其他工具 (Log/DNS/Reinstall)"
    "关于脚本 (About)"
)
info_list=(
    "协议 (protocol)"
    "地址 (address)"
    "端口 (port)"
    "用户ID (id)"
    "传输协议 (network)"
    "伪装类型 (type)"
    "伪装域名 (host)"
    "路径 (path)"
    "传输层安全 (TLS)"
    "应用层协议协商 (Alpn)"
    "密码 (password)"
    "加密方式 (encryption)"
    "链接 (URL)"
    "目标地址 (remote addr)"
    "目标端口 (remote port)"
    "流控 (flow)"
    "SNI (serverName)"
    "指纹 (Fingerprint)"
    "公钥 (Public key)"
    "用户名 (Username)"
    "跳过证书验证 (allowInsecure)"
    "拥塞控制算法 (congestion_control)"
)
change_list=(
    "更改协议"
    "更改端口"
    "更改域名"
    "更改路径"
    "更改密码"
    "更改 UUID"
    "更改加密方式"
    "更改目标地址"
    "更改目标端口"
    "更改密钥"
    "更改 SNI (serverName)"
    "更改伪装网站"
    "更改用户名 (Username)"
)
# 主流大厂 REALITY 伪装偷取域名 (已去除微软 Microsoft/Bing 与 Cloudflare 域名)
servername_list=(
    www.tesla.com
    www.amazon.com
    aws.amazon.com
    www.intel.com
    www.nvidia.com
    www.apple.com
    itunes.apple.com
    www.amd.com
    www.sony.com
    www.paypal.com
    www.ebay.com
    www.yahoo.com
)
is_hy2_default_sni="www.bing.com"

# shuf fallback for systems without shuf (e.g., Alpine BusyBox)
if ! type -P shuf &>/dev/null; then
    shuf() {
        local min max n
        while [[ $# -gt 0 ]]; do
            case $1 in
            -i) IFS=- read min max <<<"$2"; shift 2 ;;
            -n) n=$2; shift 2 ;;
            esac
        done
        echo $(( RANDOM % (max - min + 1) + min ))
    }
fi

get_random_servername() {
    local idx=$(shuf -i 0-$((${#servername_list[@]} - 1)) -n1)
    echo "${servername_list[$idx]}"
}

get_strong_pass() {
    local p
    p=$(head -c 64 /dev/urandom 2>/dev/null | base64 2>/dev/null | tr -dc 'A-Za-z0-9' | head -c 22)
    [[ ${#p} -lt 16 && -x $is_core_bin ]] && p=$($is_core_bin generate rand 16 --base64 2>/dev/null | tr -dc 'A-Za-z0-9' | head -c 22)
    [[ ${#p} -lt 16 ]] && p="$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-')$(shuf -i 1000-9999 -n1)"
    echo "$p"
}

is_random_ss_method=${ss_method_list[0]} # default aes-128-gcm
is_random_servername=$(get_random_servername)

msg() {
    echo -e "$@"
}

msg_ul() {
    echo -e "\e[4m$@\e[0m"
}

# pause
pause() {
    echo
    echo -ne "按 $(_green Enter 回车键) 继续, 或按 $(_red Ctrl + C) 取消."
    read -rs -d $'\n'
    echo
}

get_uuid() {
    tmp_uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null)
    if [[ ! $tmp_uuid && -x $is_core_bin ]]; then
        tmp_uuid=$($is_core_bin generate uuid 2>/dev/null)
    fi
    return 0
}

get_ip() {
    [[ $ip || $is_no_auto_tls || $is_gen || $is_dont_get_ip ]] && return
    export "$(_wget -4 -qO- -T 5 https://one.one.one.one/cdn-cgi/trace | grep ip=)" &>/dev/null
    [[ ! $ip ]] && export "$(_wget -6 -qO- -T 5 https://one.one.one.one/cdn-cgi/trace | grep ip=)" &>/dev/null
    [[ ! $ip ]] && ip=$(_wget -4 -qO- -T 5 https://api.ipify.org 2>/dev/null)
    [[ ! $ip ]] && ip=$(_wget -6 -qO- -T 5 https://api64.ipify.org 2>/dev/null)
    [[ ! $ip ]] && {
        err "获取服务器 IP 失败.."
    }
}

get_port() {
    is_count=0
    while :; do
        ((is_count++))
        if [[ $is_count -ge 233 ]]; then
            err "自动获取可用端口失败次数达到 233 次, 请检查端口占用情况."
        fi
        tmp_port=$(shuf -i 10000-65535 -n 1)
        [[ ! $(is_test port_used $tmp_port) && $tmp_port != $port ]] && break
    done
}

get_pbk() {
    is_tmp_pbk=($($is_core_bin generate reality-keypair | sed 's/.*://'))
    is_public_key=${is_tmp_pbk[1]}
    is_private_key=${is_tmp_pbk[0]}
}

show_list() {
    PS3=''
    COLUMNS=1
    select i in "$@"; do echo; done &
    wait
}

is_test() {
    case $1 in
    number)
        echo $2 | grep -E '^[1-9][0-9]?+$'
        ;;
    port)
        if [[ $(is_test number $2) ]]; then
            [[ $2 -le 65535 ]] && echo ok
        fi
        ;;
    port_used)
        [[ ! $(type -P ss) && ! $(type -P netstat) ]] && is_cant_test_port=1
        [[ ! $is_cant_test_port && $(is_port_used $2) ]] && echo ok
        ;;
    domain)
        echo $2 | grep -E -i '^\w(\w|\-|\.)?+\.\w+$'
        ;;
    path)
        echo $2 | grep -E -i '^\/\w(\w|\-|\/)?+\w$'
        ;;
    uuid)
        echo $2 | grep -E -i '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
        ;;
    esac
}

is_port_used() {
    if [[ $(type -P ss) ]]; then
        [[ ! $is_used_port ]] && is_used_port="$(ss -tunlp 2>/dev/null | sed -n 's/.*:\([0-9]\+\).*/\1/p' | sort -nu)"
        echo $is_used_port | sed 's/ /\n/g' | grep ^${1}$
        return
    fi
    if [[ $(type -P netstat) ]]; then
        [[ ! $is_used_port ]] && is_used_port="$(netstat -tunlp 2>/dev/null | sed -n 's/.*:\([0-9]\+\).*/\1/p' | sort -nu)"
        echo $is_used_port | sed 's/ /\n/g' | grep ^${1}$
        return
    fi
    is_cant_test_port=1
    return 0
}

# ask input a string or pick a option for list.
ask() {
    case $1 in
    set_ss_method)
        is_tmp_list=(${ss_method_list[@]})
        is_default_arg=${ss_method_list[0]}
        is_opt_msg="\n请选择 Shadowsocks 加密方式 (回车默认 ${green}${is_default_arg}${none}):\n"
        is_opt_input_msg="请选择 [\e[91m1-${#is_tmp_list[@]}\e[0m] (默认\e[92m $is_default_arg\e[0m): "
        is_ask_set=ss_method
        ;;
    set_protocol)
        is_tmp_list=(${protocol_list[@]})
        [[ $is_no_auto_tls ]] && {
            unset is_tmp_list
            for v in ${protocol_list[@]}; do
                [[ $(grep -i "\-tls$" <<<$v) ]] && is_tmp_list=(${is_tmp_list[@]} $v)
            done
        }
        is_opt_msg="\n请选择要添加的节点协议:\n"
        is_ask_set=is_new_protocol
        ;;
    set_change_list)
        is_tmp_list=()
        for v in ${is_can_change[@]}; do
            is_tmp_list+=("${change_list[$v]}")
        done
        is_opt_msg="\n请选择要更改的选项:\n"
        is_ask_set=is_change_str
        is_opt_input_msg=$3
        ;;
    string)
        is_ask_set=$2
        is_opt_input_msg=$3
        ;;
    list)
        is_ask_set=$2
        [[ ! $is_tmp_list ]] && is_tmp_list=($3)
        is_opt_msg=$4
        is_opt_input_msg=$5
        ;;
    get_config_file)
        is_tmp_list=("${is_all_json[@]}")
        is_opt_msg="\n请选择配置:\n"
        is_ask_set=is_config_file
        ;;
    mainmenu)
        is_tmp_list=("${mainmenu[@]}")
        is_ask_set=is_main_pick
        is_emtpy_exit=1
        ;;
    esac
    msg $is_opt_msg
    [[ ! $is_opt_input_msg ]] && is_opt_input_msg="请选择 [\e[91m1-${#is_tmp_list[@]}\e[0m]: "
    [[ $is_tmp_list ]] && show_list "${is_tmp_list[@]}"
    while :; do
        echo -ne $is_opt_input_msg
        read REPLY
        [[ ! $REPLY && $is_emtpy_exit ]] && exit
        [[ ! $REPLY && $is_default_arg ]] && export $is_ask_set=$is_default_arg && msg "默认使用: ${!is_ask_set}" && break
        if [[ ! $is_tmp_list ]]; then
            [[ $(grep port <<<$is_ask_set) ]] && {
                [[ ! $(is_test port "$REPLY") ]] && {
                    msg "$is_err 请输入正确的端口, 可选(1-65535)"
                    continue
                }
                if [[ $(is_test port_used $REPLY) && $is_ask_set != 'door_port' ]]; then
                    msg "$is_err 无法使用 ($REPLY) 端口."
                    continue
                fi
            }
            [[ $(grep path <<<$is_ask_set) && ! $(is_test path "$REPLY") ]] && {
                [[ ! $tmp_uuid ]] && get_uuid
                msg "$is_err 请输入正确的路径, 例如: /$tmp_uuid"
                continue
            }
            [[ $(grep uuid <<<$is_ask_set) && ! $(is_test uuid "$REPLY") ]] && {
                [[ ! $tmp_uuid ]] && get_uuid
                msg "$is_err 请输入正确的 UUID, 例如: $tmp_uuid"
                continue
            }
            [[ $(grep ^y$ <<<$is_ask_set) ]] && {
                [[ $(grep -i ^y$ <<<"$REPLY") ]] && break
                msg "请输入 (y)"
                continue
            }
            [[ $REPLY ]] && export $is_ask_set=$REPLY && msg "使用: ${!is_ask_set}" && break
        else
            [[ $(is_test number "$REPLY") ]] && is_ask_result=${is_tmp_list[$REPLY - 1]}
            [[ $is_ask_result ]] && export $is_ask_set="$is_ask_result" && msg "选择: ${!is_ask_set}" && break
        fi

        msg "输入${is_err}"
    done
    unset is_opt_msg is_opt_input_msg is_tmp_list is_ask_result is_default_arg is_emtpy_exit
}

# Generate or update self-signed TLS certificate for given SNI
ensure_tls_cert() {
    local cert_sni=${1:-$is_hy2_default_sni}
    is_tls_cer=$is_core_dir/bin/tls.cer
    is_tls_key=$is_core_dir/bin/tls.key
    is_tls_sni_file=$is_core_dir/bin/tls.sni
    if [[ ! -f $is_tls_cer || ! -f $is_tls_key || ! -s $is_tls_cer || ! -s $is_tls_key || $is_force_tls_cert ]]; then
        is_tls_tmp=${is_tls_key/key/tmp}
        $is_core_bin generate tls-keypair "$cert_sni" -m 456 >$is_tls_tmp 2>/dev/null
        awk '/BEGIN PRIVATE KEY/,/END PRIVATE KEY/' $is_tls_tmp >$is_tls_key
        awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/' $is_tls_tmp >$is_tls_cer
        rm -f $is_tls_tmp
        # Fallback to openssl if sing-box tls-keypair output is empty
        if [[ ! -s $is_tls_cer || ! -s $is_tls_key ]]; then
            openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout "$is_tls_key" -out "$is_tls_cer" -subj "/CN=$cert_sni" -days 3650 &>/dev/null
        fi
        echo "$cert_sni" >$is_tls_sni_file
    fi
}

# create file
create() {
    case $1 in
    server)
        is_tls=none
        get new
        # listen
        is_listen='listen: "::"'
        # file name
        if [[ $host ]]; then
            is_config_name=$2-${host}.json
            is_listen='listen: "127.0.0.1"'
        elif [[ $is_anytls_domain ]]; then
            is_config_name=$2-${is_anytls_domain}.json
        else
            is_config_name=$2-${port}.json
        fi
        is_json_file=$is_conf_dir/$is_config_name
        # get json
        [[ $is_change || ! $json_str ]] && get protocol $2
        [[ $net == "reality" ]] && is_add_public_key=",outbounds:[{type:\"direct\"},{tag:\"public_key_$is_public_key\",type:\"direct\"}]"
        is_new_json=$(jq "{inbounds:[{tag:\"$is_config_name\",type:\"$is_protocol\",$is_listen,listen_port:$port,$json_str}]$is_add_public_key}" <<<{})
        [[ $is_test_json ]] && return # tmp test
        # only show json, dont save to file.
        [[ $is_gen ]] && {
            msg
            jq <<<$is_new_json
            msg
            return
        }
        # del old file
        [[ $is_config_file ]] && is_no_del_msg=1 && del $is_config_file
        # save json to file
        cat <<<$is_new_json >$is_json_file
        if [[ $is_new_install ]]; then
            # config.json (lightweight log settings to save disk space)
            create config.json
        fi
        # caddy auto tls
        [[ $is_caddy && $host && ! $is_no_auto_tls ]] && {
            create caddy $net
        }
        # restart core
        manage restart &
        ;;
    client)
        is_tls=tls
        is_client=1
        get info $2
        [[ ! $is_client_id_json ]] && err "($is_config_name) 不支持生成客户端配置."
        is_new_json=$(jq '{outbounds:[{tag:'\"$is_config_name\"',protocol:'\"$is_protocol\"','"$is_client_id_json"','"$is_stream"'}]}' <<<{})
        msg
        jq <<<$is_new_json
        msg
        ;;
    caddy)
        load caddy.sh
        [[ $is_install_caddy ]] && caddy_config new
        [[ ! $(grep "$is_caddy_conf" $is_caddyfile) ]] && {
            msg "import $is_caddy_conf/*.conf" >>$is_caddyfile
        }
        [[ ! -d $is_caddy_conf ]] && mkdir -p $is_caddy_conf
        caddy_config $2
        manage restart caddy &
        ;;
    config.json)
        # Lightweight default: disable verbose access log file growth by default; only warn/error or disabled
        is_log='log:{"disabled":true,"level":"warn","timestamp":true}'
        is_dns='dns:{}'
        is_ntp='ntp:{"enabled":true,"server":"time.apple.com"},'
        if [[ -f $is_config_json ]]; then
            [[ $(jq .ntp.enabled $is_config_json 2>/dev/null) != "true" ]] && is_ntp=
        else
            [[ ! $is_ntp_on ]] && is_ntp=
        fi
        is_outbounds='outbounds:[{tag:"direct",type:"direct"}]'
        is_server_config_json=$(jq "{$is_log,$is_dns,$is_ntp$is_outbounds}" <<<{})
        cat <<<$is_server_config_json >$is_config_json
        manage restart &
        ;;
    esac
}

# change config file
change() {
    is_change=1
    is_dont_show_info=1
    if [[ $2 ]]; then
        case ${2,,} in
        full)
            is_change_id=full
            ;;
        new)
            is_change_id=0
            ;;
        port)
            is_change_id=1
            ;;
        host)
            is_change_id=2
            ;;
        path)
            is_change_id=3
            ;;
        pass | passwd | password)
            is_change_id=4
            ;;
        id | uuid)
            is_change_id=5
            ;;
        ssm | method | ss-method | ss_method)
            is_change_id=6
            ;;
        dda | door-addr | door_addr)
            is_change_id=7
            ;;
        ddp | door-port | door_port)
            is_change_id=8
            ;;
        key | publickey | privatekey)
            is_change_id=9
            ;;
        sni | servername | servernames)
            is_change_id=10
            ;;
        web | proxy-site)
            is_change_id=11
            ;;
        *)
            [[ $is_try_change ]] && return
            err "无法识别 ($2) 更改类型."
            ;;
        esac
    fi
    [[ $is_try_change ]] && return
    [[ $is_dont_auto_exit ]] && {
        get info $1
    } || {
        [[ $is_change_id ]] && {
            is_change_msg=${change_list[$is_change_id]}
            [[ $is_change_id == 'full' ]] && {
                [[ $3 ]] && is_change_msg="更改多个参数" || is_change_msg=
            }
            [[ $is_change_msg ]] && _green "\n快速执行: $is_change_msg"
        }
        info $1
        [[ $is_auto_get_config ]] && msg "\n自动选择: $is_config_file"
    }
    is_old_net=$net
    [[ $is_tcp_http ]] && net=http
    [[ $host ]] && net=$is_protocol-$net-tls
    [[ $is_reality && $net_type =~ 'http' ]] && net=rh2

    [[ $3 == 'auto' ]] && is_auto=1
    # if is_dont_show_info exist, cant show info.
    is_dont_show_info=
    # if not prefer args, show change list and then get change id.
    [[ ! $is_change_id ]] && {
        ask set_change_list
        is_change_id=${is_can_change[$REPLY - 1]}
    }
    case $is_change_id in
    full)
        add $net ${@:3}
        ;;
    0)
        # new protocol
        is_set_new_protocol=1
        add ${@:3}
        ;;
    1)
        # new port
        is_new_port=$3
        [[ $host && ! $is_caddy || $is_no_auto_tls ]] && err "($is_config_file) 不支持更改端口, 因为没啥意义."
        if [[ $is_new_port && ! $is_auto ]]; then
            [[ ! $(is_test port $is_new_port) ]] && err "请输入正确的端口, 可选(1-65535)"
            [[ $is_new_port != 443 && $(is_test port_used $is_new_port) ]] && err "无法使用 ($is_new_port) 端口"
        fi
        [[ $is_auto ]] && get_port && is_new_port=$tmp_port
        if [[ ! $is_new_port ]]; then
            get_port
            is_default_arg=$tmp_port
            ask string is_new_port "请输入新端口 (直接回车随机使用 ${green}${tmp_port}${none}): "
        fi
        if [[ $is_caddy && $host ]]; then
            net=$is_old_net
            is_https_port=$is_new_port
            load caddy.sh
            caddy_config $net
            manage restart caddy &
            info
        else
            add $net $is_new_port
        fi
        ;;
    2)
        # new host
        is_new_host=$3
        [[ ! $host ]] && err "($is_config_file) 不支持更改域名."
        [[ ! $is_new_host ]] && ask string is_new_host "请输入新域名: "
        old_host=$host # del old host
        add $net $is_new_host
        ;;
    3)
        # new path
        is_new_path=$3
        [[ ! $path ]] && err "($is_config_file) 不支持更改路径."
        [[ $is_auto ]] && get_uuid && is_new_path=/$tmp_uuid
        [[ ! $is_new_path ]] && ask string is_new_path "请输入新路径: "
        add $net auto auto $is_new_path
        ;;
    4)
        # new password
        is_new_pass=$3
        if [[ $ss_password || $password ]]; then
            if [[ $is_auto ]]; then
                if [[ $ss_password && $(grep 2022 <<<$ss_method) ]]; then
                    is_new_pass=$(get ss2022)
                else
                    is_new_pass=$(get_strong_pass)
                fi
            fi
        else
            err "($is_config_file) 不支持更改密码."
        fi
        if [[ ! $is_new_pass ]]; then
            if [[ $ss_password && $(grep 2022 <<<$ss_method) ]]; then
                is_default_arg=$(get ss2022)
            else
                is_default_arg=$(get_strong_pass)
            fi
            ask string is_new_pass "请输入新密码 (直接回车使用高强度随机密码 ${green}${is_default_arg}${none}): "
        fi
        password=$is_new_pass
        ss_password=$is_new_pass
        is_socks_pass=$is_new_pass
        add $net
        ;;
    5)
        # new uuid
        is_new_uuid=$3
        [[ ! $uuid ]] && err "($is_config_file) 不支持更改 UUID."
        [[ $is_auto ]] && get_uuid && is_new_uuid=$tmp_uuid
        if [[ ! $is_new_uuid ]]; then
            get_uuid
            is_default_arg=$tmp_uuid
            ask string is_new_uuid "请输入新 UUID (直接回车随机使用 ${green}${tmp_uuid}${none}): "
        fi
        add $net auto $is_new_uuid
        ;;
    6)
        # new method
        is_new_method=$3
        [[ $net != 'ss' ]] && err "($is_config_file) 不支持更改加密方式."
        old_ss_method=$ss_method
        [[ $is_auto ]] && is_new_method=$is_random_ss_method
        if [[ $is_new_method ]]; then
            is_new_method=$(normalize_ss_method "$is_new_method")
        else
            ask set_ss_method
            is_new_method=$ss_method
        fi
        # Regenerate compatible high-strength key when switching to/from SS-2022
        if [[ $(grep 2022 <<<$is_new_method) ]]; then
            ss_method=$is_new_method
            ss_password=$(get ss2022)
        elif [[ $(grep 2022 <<<$old_ss_method) ]]; then
            ss_method=$is_new_method
            ss_password=$(get_strong_pass)
        fi
        add $net auto "$ss_password" $is_new_method
        ;;
    7)
        # new remote addr
        is_new_door_addr=$3
        [[ $net != 'direct' ]] && err "($is_config_file) 不支持更改目标地址."
        [[ ! $is_new_door_addr ]] && ask string is_new_door_addr "请输入新的目标地址: "
        door_addr=$is_new_door_addr
        add $net
        ;;
    8)
        # new remote port
        is_new_door_port=$3
        [[ $net != 'direct' ]] && err "($is_config_file) 不支持更改目标端口."
        [[ ! $is_new_door_port ]] && {
            ask string door_port "请输入新的目标端口: "
            is_new_door_port=$door_port
        }
        add $net auto auto $is_new_door_port
        ;;
    9)
        # new is_private_key is_public_key
        is_new_private_key=$3
        is_new_public_key=$4
        [[ ! $is_reality ]] && err "($is_config_file) 不支持更改密钥."
        if [[ $is_auto ]]; then
            get_pbk
            add $net
        else
            [[ $is_new_private_key && ! $is_new_public_key ]] && {
                err "无法找到 Public key."
            }
            [[ ! $is_new_private_key ]] && ask string is_new_private_key "请输入新 Private key: "
            [[ ! $is_new_public_key ]] && ask string is_new_public_key "请输入新 Public key: "
            if [[ $is_new_private_key == $is_new_public_key ]]; then
                err "Private key 和 Public key 不能一样."
            fi
            is_tmp_json=$is_conf_dir/$is_config_file-$uuid
            cp -f $is_conf_dir/$is_config_file $is_tmp_json
            sed -i s#$is_private_key#$is_new_private_key# $is_tmp_json
            $is_core_bin check -c $is_tmp_json &>/dev/null
            if [[ $? != 0 ]]; then
                is_key_err=1
                is_key_err_msg="Private key 无法通过测试."
            fi
            sed -i s#$is_new_private_key#$is_new_public_key# $is_tmp_json
            $is_core_bin check -c $is_tmp_json &>/dev/null
            if [[ $? != 0 ]]; then
                is_key_err=1
                is_key_err_msg+="Public key 无法通过测试."
            fi
            rm $is_tmp_json
            [[ $is_key_err ]] && err $is_key_err_msg
            is_private_key=$is_new_private_key
            is_public_key=$is_new_public_key
            is_test_json=
            add $net
        fi
        ;;
    10)
        # new serverName (supports REALITY, Hysteria2, TUIC, Trojan, AnyTLS)
        is_new_servername=$3
        if [[ ! $is_reality && ! $is_protocol =~ ^(hysteria2|tuic|trojan|anytls)$ ]]; then
            err "($is_config_file) 不支持更改 serverName (SNI)."
        fi
        if [[ $is_auto ]]; then
            if [[ $is_protocol == "hysteria2" ]]; then
                is_new_servername=$is_hy2_default_sni
            else
                is_new_servername=$(get_random_servername)
            fi
        fi
        if [[ ! $is_new_servername ]]; then
            if [[ $is_protocol == "hysteria2" ]]; then
                is_sni_menu_list=("$is_hy2_default_sni" "${servername_list[@]}" "随机主流域名 (Random)" "手动输入自定义域名 (Custom)")
                is_default_arg=$is_hy2_default_sni
            else
                is_sni_menu_list=("${servername_list[@]}" "随机主流域名 (Random)" "手动输入自定义域名 (Custom)")
                is_default_arg=$(get_random_servername)
            fi
            is_tmp_list=("${is_sni_menu_list[@]}")
            ask list is_sni_pick null "\n请选择主流 SNI 伪装域名 (回车默认 ${green}${is_default_arg}${none}):\n" "请选择 [\e[91m1-${#is_sni_menu_list[@]}\e[0m] (默认\e[92m $is_default_arg\e[0m): "
            if [[ "$is_sni_pick" == "随机主流域名 (Random)" ]]; then
                is_new_servername=$(get_random_servername)
            elif [[ "$is_sni_pick" == "手动输入自定义域名 (Custom)" ]]; then
                ask string is_new_servername "请输入自定义 SNI 域名 (如 www.apple.com): "
            else
                is_new_servername=$is_sni_pick
            fi
        fi
        is_servername=$is_new_servername
        if [[ $is_protocol =~ ^(hysteria2|tuic|trojan|anytls)$ && ! $is_anytls_domain ]]; then
            is_force_tls_cert=1
            ensure_tls_cert "$is_servername"
            unset is_force_tls_cert
        fi
        add $net
        ;;
    11)
        # new proxy site
        is_new_proxy_site=$3
        [[ ! $is_caddy && ! $host ]] && {
            err "($is_config_file) 不支持更改伪装网站."
        }
        [[ ! -f $is_caddy_conf/${host}.conf.add ]] && err "无法配置伪装网站."
        [[ ! $is_new_proxy_site ]] && ask string is_new_proxy_site "请输入新的伪装网站 (例如 example.com): "
        proxy_site=$(sed 's#^.*//##;s#/$##' <<<$is_new_proxy_site)
        load caddy.sh
        caddy_config proxy
        manage restart caddy &
        msg "\n已更新伪装网站为: $(_green $proxy_site) \n"
        ;;
    12)
        # new socks user
        [[ ! $is_socks_user ]] && err "($is_config_file) 不支持更改用户名 (Username)."
        ask string is_socks_user "请输入新用户名 (Username): "
        add $net
        ;;
    esac
}

# delete config.
del() {
    # dont get ip
    is_dont_get_ip=1
    [[ $is_conf_dir_empty ]] && return # not found any json file.
    # get a config file
    [[ ! $is_config_file ]] && get info $1
    if [[ $is_config_file ]]; then
        if [[ $is_main_start && ! $is_no_del_msg ]]; then
            msg "\n是否删除配置文件?: $is_config_file"
            pause
        fi
        rm -rf $is_conf_dir/"$is_config_file"
        [[ ! $is_new_json ]] && manage restart &
        [[ ! $is_no_del_msg ]] && _green "\n已删除: $is_config_file\n"

        [[ $is_caddy ]] && {
            is_del_host=$host
            [[ $is_change ]] && {
                [[ ! $old_host ]] && return # no host exist or not set new host;
                is_del_host=$old_host
            }
            [[ $is_del_host && $host != $old_host && -f $is_caddy_conf/$is_del_host.conf ]] && {
                rm -rf $is_caddy_conf/$is_del_host.conf $is_caddy_conf/$is_del_host.conf.add
                [[ ! $is_new_json ]] && manage restart caddy &
            }
        }
    fi
    if [[ ! $(ls $is_conf_dir 2>/dev/null | grep .json) && ! $is_change ]]; then
        warn "当前配置目录为空! 因为你刚刚删除了最后一个配置文件."
        is_conf_dir_empty=1
    fi
    unset is_dont_get_ip
    [[ $is_dont_auto_exit ]] && unset is_config_file
}

# uninstall
uninstall() {
    if [[ $is_caddy ]]; then
        is_tmp_list=("卸载 $is_core_name (kk)" "卸载 ${is_core_name} (kk) & Caddy")
        ask list is_do_uninstall
    else
        ask string y "是否确认卸载 ${is_core_name} (kk)? [y]: "
    fi
    manage stop &>/dev/null
    manage disable &>/dev/null
    rm -rf $is_core_dir $is_log_dir $is_sh_bin /usr/local/bin/$is_core /usr/local/bin/sb /etc/sysctl.d/99-kk-optimize.conf
    if [[ $is_systemd ]]; then
        rm -f /lib/systemd/system/$is_core.service
        systemctl daemon-reload &>/dev/null
    elif [[ $is_openrc ]]; then
        rm -f /etc/init.d/$is_core
    fi
    sed -i "/$is_core/d" /root/.bashrc 2>/dev/null
    sed -i "/alias kk=/d" /root/.bashrc 2>/dev/null
    # uninstall caddy; 2 is ask result
    if [[ $REPLY == '2' ]]; then
        manage stop caddy &>/dev/null
        manage disable caddy &>/dev/null
        if [[ $is_systemd ]]; then
            rm -rf $is_caddy_dir $is_caddy_bin /lib/systemd/system/caddy.service
        elif [[ $is_openrc ]]; then
            rm -rf $is_caddy_dir $is_caddy_bin /etc/init.d/caddy
        fi
    fi
    [[ $is_install_sh ]] && return # reinstall
    _green "\n✓ 卸载完成!"
    msg "项目仓库: $(msg_ul https://github.com/${is_sh_repo})\n"
}

# manage run status
manage() {
    [[ $is_dont_auto_exit ]] && return
    case $1 in
    1 | start)
        is_do=start
        is_do_msg=启动
        is_test_run=1
        ;;
    2 | stop)
        is_do=stop
        is_do_msg=停止
        ;;
    3 | r | restart)
        is_do=restart
        is_do_msg=重启
        is_test_run=1
        ;;
    *)
        is_do=$1
        is_do_msg=$1
        ;;
    esac
    case $2 in
    caddy)
        is_do_name=$2
        is_run_bin=$is_caddy_bin
        is_do_name_msg=Caddy
        ;;
    *)
        is_do_name=$is_core
        is_run_bin=$is_core_bin
        is_do_name_msg=$is_core_name
        ;;
    esac
    if [[ $is_systemd ]]; then
        systemctl $is_do $is_do_name 2>/dev/null
    elif [[ $is_openrc ]]; then
        case $is_do in
        enable)
            rc-update add $is_do_name default 2>/dev/null
            ;;
        disable)
            rc-update del $is_do_name default 2>/dev/null
            ;;
        *)
            rc-service $is_do_name $is_do 2>/dev/null
            ;;
        esac
    fi
    [[ $is_test_run && ! $is_new_install ]] && {
        sleep 2
        if [[ ! $(pgrep -f $is_run_bin) ]]; then
            is_run_fail=${is_do_name_msg,,}
            [[ ! $is_no_manage_msg ]] && {
                msg
                warn "($is_do_msg) $is_do_name_msg 失败"
                _yellow "检测到运行失败, 自动执行测试运行."
                get test-run
                _yellow "测试结束, 请按 Enter 退出."
            }
        fi
    }
}

# Map shorthand SS method aliases
normalize_ss_method() {
    case ${1,,} in
    128 | aes128 | ace128 | aes-128 | aes-128-gcm)
        echo "aes-128-gcm"
        ;;
    256 | aes256 | ace256 | aes-256 | aes-256-gcm)
        echo "aes-256-gcm"
        ;;
    2022 | 2022-128 | ss2022-128 | 2022-blake3-aes-128-gcm)
        echo "2022-blake3-aes-128-gcm"
        ;;
    2022-256 | 2022-258 | ss2022-256 | 2022-blake3-aes-256-gcm)
        echo "2022-blake3-aes-256-gcm"
        ;;
    2022-chacha20 | 2022-blake3-chacha20-poly1305)
        echo "2022-blake3-chacha20-poly1305"
        ;;
    chacha20 | chacha20-ietf-poly1305)
        echo "chacha20-ietf-poly1305"
        ;;
    xchacha20 | xchacha20-ietf-poly1305)
        echo "xchacha20-ietf-poly1305"
        ;;
    *)
        echo "$1"
        ;;
    esac
}

# add a config
add() {
    is_lower=${1,,}
    if [[ $is_lower ]]; then
        case $is_lower in
        ws | tcp | quic | http)
            is_new_protocol=VMess-${is_lower^^}
            ;;
        wss | h2 | hu | vws | vh2 | vhu | tws | th2 | thu)
            is_new_protocol=$(sed -E "s/^V/VLESS-/;s/^T/Trojan-/;/^(W|H)/{s/^/VMess-/};s/WSS/WS/;s/HU/HTTPUpgrade/" <<<${is_lower^^})-TLS
            ;;
        r | reality | vless-reality | vision)
            is_new_protocol=VLESS-REALITY
            ;;
        rh2)
            is_new_protocol=VLESS-HTTP2-REALITY
            ;;
        ss)
            is_new_protocol=Shadowsocks
            # Support `kk add ss 256` or `kk add ss 2022-128` shorthand when $2 is a cipher name rather than port
            if [[ $2 && ! $3 && $2 != "auto" && ! $(is_test port "$2") ]]; then
                set -- "$1" "auto" "auto" "$2"
            fi
            ;;
        ss128 | ace128 | aes128)
            is_new_protocol=Shadowsocks
            set -- "$1" "${2:-auto}" "${3:-auto}" "aes-128-gcm"
            ;;
        ss256 | ace256 | aes256)
            is_new_protocol=Shadowsocks
            set -- "$1" "${2:-auto}" "${3:-auto}" "aes-256-gcm"
            ;;
        ss2022 | ss2022-128)
            is_new_protocol=Shadowsocks
            set -- "$1" "${2:-auto}" "${3:-auto}" "2022-blake3-aes-128-gcm"
            ;;
        ss2022-256 | ss2022-258)
            is_new_protocol=Shadowsocks
            set -- "$1" "${2:-auto}" "${3:-auto}" "2022-blake3-aes-256-gcm"
            ;;
        ss2022-chacha20)
            is_new_protocol=Shadowsocks
            set -- "$1" "${2:-auto}" "${3:-auto}" "2022-blake3-chacha20-poly1305"
            ;;
        door | direct)
            is_new_protocol=Direct
            ;;
        tuic)
            is_new_protocol=TUIC
            ;;
        hy | hy2 | hysteria*)
            is_new_protocol=Hysteria2
            ;;
        trojan)
            is_new_protocol=Trojan
            ;;
        anytls)
            is_new_protocol=AnyTLS
            ;;
        socks)
            is_new_protocol=Socks
            ;;
        *)
            for v in ${protocol_list[@]}; do
                [[ $(grep -E -i "^$is_lower$" <<<$v) ]] && is_new_protocol=$v && break
            done

            [[ ! $is_new_protocol ]] && err "无法识别 ($1), 请使用: kk add [protocol] [args... | auto]"
            ;;
        esac
    fi

    # no prefer protocol
    [[ ! $is_new_protocol ]] && ask set_protocol

    if [[ ${is_new_protocol,,} == 'anytls' ]]; then
        is_core_major=$(echo "$is_core_ver" | cut -d. -f1)
        is_core_minor=$(echo "$is_core_ver" | cut -d. -f2)
        if [[ ${is_core_major:-0} -lt 1 || ${is_core_major:-0} -eq 1 && ${is_core_minor:-0} -lt 12 ]]; then
            err "当前 sing-box 版本 ($is_core_ver) 不支持 AnyTLS，请先使用 kk u core 升级 sing-box 到 1.12.0 或更高版本。"
        fi
    fi

    case ${is_new_protocol,,} in
    *-tls)
        is_use_tls=1
        is_use_host=$2
        is_use_uuid=$3
        is_use_path=$4
        is_add_opts="[host] [uuid] [/path]"
        ;;
    vmess* | tuic*)
        is_use_port=$2
        is_use_uuid=$3
        is_add_opts="[port] [uuid]"
        ;;
    trojan* | hysteria*)
        is_use_port=$2
        is_use_pass=$3
        is_use_servername=$4
        is_add_opts="[port] [password] [sni]"
        ;;
    *reality*)
        is_reality=1
        is_use_port=$2
        is_use_uuid=$3
        is_use_servername=$4
        is_add_opts="[port] [uuid] [sni]"
        ;;
    shadowsocks)
        is_use_port=$2
        is_use_pass=$3
        is_use_method=$4
        is_add_opts="[port] [password] [method]"
        ;;
    direct)
        is_use_port=$2
        is_use_door_addr=$3
        is_use_door_port=$4
        is_add_opts="[port] [remote_addr] [remote_port]"
        ;;
    anytls*)
        is_use_port=$2
        is_use_pass=$3
        [[ $4 ]] && is_anytls_domain=$4
        is_add_opts="[port] [password] [domain]"
        ;;
    socks)
        is_socks=1
        is_use_port=$2
        is_use_socks_user=$3
        is_use_socks_pass=$4
        is_add_opts="[port] [username] [password]"
        ;;
    esac

    [[ $1 && ! $is_change ]] && {
        msg "\n使用协议: $is_new_protocol"
        # err msg tips
        is_err_tips="\n\n请使用: $(_green kk add $1 $is_add_opts) 来添加 $is_new_protocol 配置"
    }

    # remove old protocol args when switching protocols
    if [[ $is_set_new_protocol ]]; then
        case $is_old_net in
        h2 | ws | httpupgrade)
            old_host=$host
            [[ ! $is_use_tls ]] && unset host is_no_auto_tls
            ;;
        reality)
            net_type=
            [[ ! $(grep -i reality <<<$is_new_protocol) ]] && is_reality=
            ;;
        ss)
            [[ $(is_test uuid $ss_password) ]] && uuid=$ss_password
            ;;
        esac
        [[ ! $(is_test uuid $uuid) ]] && uuid=
        [[ $(is_test uuid $password) ]] && uuid=$password
        unset ss_password password ss_method is_servername is_anytls_domain
    fi

    # no-auto-tls only use h2,ws,grpc
    if [[ $is_no_auto_tls && ! $is_use_tls ]]; then
        err "$is_new_protocol 不支持手动配置 tls."
    fi

    # prefer args.
    if [[ $2 ]]; then
        for v in is_use_port is_use_uuid is_use_host is_use_path is_use_pass is_use_method is_use_door_addr is_use_door_port is_use_servername; do
            [[ ${!v} == 'auto' ]] && unset $v
        done

        if [[ $is_use_port ]]; then
            [[ ! $(is_test port ${is_use_port}) ]] && {
                err "($is_use_port) 不是一个有效的端口. $is_err_tips"
            }
            [[ $(is_test port_used $is_use_port) && ! $is_gen ]] && {
                err "无法使用 ($is_use_port) 端口. $is_err_tips"
            }
            port=$is_use_port
        fi
        if [[ $is_use_door_port ]]; then
            [[ ! $(is_test port ${is_use_door_port}) ]] && {
                err "(${is_use_door_port}) 不是一个有效的目标端口. $is_err_tips"
            }
            door_port=$is_use_door_port
        fi
        if [[ $is_use_uuid ]]; then
            [[ ! $(is_test uuid $is_use_uuid) ]] && {
                err "($is_use_uuid) 不是一个有效的 UUID. $is_err_tips"
            }
            uuid=$is_use_uuid
        fi
        if [[ $is_use_path ]]; then
            [[ ! $(is_test path $is_use_path) ]] && {
                err "($is_use_path) 不是有效的路径. $is_err_tips"
            }
            path=$is_use_path
        fi
        if [[ $is_use_method ]]; then
            is_use_method=$(normalize_ss_method "$is_use_method")
            is_tmp_use_name=加密方式
            is_tmp_list=${ss_method_list[@]}
            for v in ${is_tmp_list[@]}; do
                [[ $(grep -E -i "^${is_use_method}$" <<<$v) ]] && is_tmp_use_type=$v && break
            done
            [[ ! ${is_tmp_use_type} ]] && {
                warn "(${is_use_method}) 不是一个可用的${is_tmp_use_name}."
                msg "${is_tmp_use_name}可用如下: "
                for v in ${is_tmp_list[@]}; do
                    msg "\t\t$v"
                done
                msg "$is_err_tips\n"
                exit 1
            }
            ss_method=$is_tmp_use_type
        fi
        [[ $is_use_pass ]] && ss_password=$is_use_pass && password=$is_use_pass
        [[ $is_use_host ]] && host=$is_use_host
        [[ $is_use_door_addr ]] && door_addr=$is_use_door_addr
        [[ $is_use_servername ]] && is_servername=$is_use_servername
        [[ $is_use_socks_user ]] && is_socks_user=$is_use_socks_user
        [[ $is_use_socks_pass ]] && is_socks_pass=$is_use_socks_pass
    fi

    # anytls with domain (ACME TLS)
    if [[ $is_anytls_domain && ! $is_change && ! $is_gen ]]; then
        get_ip
        host=$is_anytls_domain
        get host-test
        host=
    fi

    if [[ $is_use_tls ]]; then
        if [[ ! $is_no_auto_tls && ! $is_caddy && ! $is_gen && ! $is_dont_test_host ]]; then
            # test auto tls
            [[ $(is_test port_used 80) || $(is_test port_used 443) ]] && {
                get_port
                is_http_port=$tmp_port
                get_port
                is_https_port=$tmp_port
                warn "端口 (80 或 443) 已经被占用, 你也可以考虑使用 no-auto-tls"
                msg "\n Caddy 将使用非标准端口实现自动配置 TLS, HTTP:$is_http_port HTTPS:$is_https_port\n"
                msg "请确定是否继续???"
                pause
            }
            is_install_caddy=1
        fi
        # set host
        [[ ! $host ]] && ask string host "请输入域名: "
        # test host dns
        get host-test
    else
        # Interactive menu flow:
        # For Shadowsocks, user selects which SS cipher (128/256/2022 etc.), and port + high-strength password are auto-generated!
        if [[ $is_main_start ]]; then
            case ${is_new_protocol,,} in
            shadowsocks)
                [[ ! $ss_method ]] && ask set_ss_method
                ;;
            socks)
                [[ ! $port ]] && {
                    get_port
                    is_default_arg=$tmp_port
                    ask string port "请输入端口 (直接回车随机端口 ${green}${tmp_port}${none}): "
                }
                [[ ! $is_socks_user ]] && {
                    is_default_arg="kkuser"
                    ask string is_socks_user "请设置用户名 (直接回车默认 ${green}kkuser${none}): "
                }
                [[ ! $is_socks_pass ]] && {
                    is_default_arg=$(get_strong_pass)
                    ask string is_socks_pass "请设置密码 (直接回车使用高强度随机密码): "
                }
                ;;
            esac
        fi
    fi

    # Dokodemo-Door
    if [[ $is_new_protocol == 'Direct' ]]; then
        [[ ! $port ]] && ask string port "请输入本地监听端口: "
        [[ ! $door_addr ]] && ask string door_addr "请输入目标地址: "
        [[ ! $door_port ]] && ask string door_port "请输入目标端口: "
    fi

    # Shadowsocks 2022 validation
    if [[ $(grep 2022 <<<$ss_method) ]]; then
        [[ $ss_password ]] && {
            is_test_json=1
            create server Shadowsocks
            [[ ! $tmp_uuid ]] && get_uuid
            is_test_json_save=$is_conf_dir/tmp-test-$tmp_uuid
            cat <<<"$is_new_json" >$is_test_json_save
            $is_core_bin check -c $is_test_json_save &>/dev/null
            if [[ $? != 0 ]]; then
                warn "Shadowsocks 协议 ($ss_method) 不支持当前密码格式, 脚本将自动生成高强度合规密钥 :)"
                ss_password=
                json_str=
            fi
            is_test_json=
            rm -f $is_test_json_save
        }
    fi

    # install caddy
    if [[ $is_install_caddy ]]; then
        get install-caddy
    fi

    # create json
    create server $is_new_protocol

    # show config info.
    info
}

# get config info
# or somes required args
get() {
    case $1 in
    addr)
        is_addr=$host
        [[ ! $is_addr ]] && {
            get_ip
            is_addr=$ip
            [[ $(grep ":" <<<$ip) ]] && is_addr="[$ip]"
        }
        ;;
    new)
        [[ ! $host ]] && get_ip
        [[ ! $port ]] && get_port && port=$tmp_port
        [[ ! $uuid ]] && get_uuid && uuid=$tmp_uuid
        ;;
    file)
        is_file_str=$2
        [[ ! $is_file_str ]] && is_file_str='.json$'
        readarray -t is_all_json <<<"$(ls $is_conf_dir 2>/dev/null | grep -E -i "$is_file_str" | sed '/dynamic-port-.*-link/d' | head -233)"
        [[ ! $is_all_json ]] && err "无法找到相关的配置文件: $2"
        [[ ${#is_all_json[@]} -eq 1 ]] && is_config_file=$is_all_json && is_auto_get_config=1
        [[ ! $is_config_file ]] && {
            [[ $is_dont_auto_exit ]] && return
            ask get_config_file
        }
        ;;
    info)
        get file $2
        if [[ $is_config_file ]]; then
            is_json_str=$(cat $is_conf_dir/"$is_config_file" | sed s#//.*##)
            is_json_data=$(jq '(.inbounds[0]|.type,.listen_port,(.users[0]|.uuid,.password,.username),.method,.password,.override_port,.override_address,(.transport|.type,.path,.headers.host),(.tls|.server_name,.reality.private_key)),(.outbounds[1].tag)' <<<$is_json_str)
            [[ $? != 0 ]] && err "无法读取此文件: $is_config_file"
            is_up_var_set=(null is_protocol port uuid password username ss_method ss_password door_port door_addr net_type path host is_servername is_private_key is_public_key)
            [[ $is_debug ]] && msg "\n------------- debug: $is_config_file -------------"
            i=0
            for v in $(sed 's/""/null/g;s/"//g' <<<"$is_json_data"); do
                ((i++))
                [[ $is_debug ]] && msg "$i-${is_up_var_set[$i]}: $v"
                export ${is_up_var_set[$i]}="${v}"
            done
            for v in ${is_up_var_set[@]}; do
                [[ ${!v} == 'null' ]] && unset $v
            done

            if [[ $is_private_key ]]; then
                is_reality=1
                net_type+=reality
                is_public_key=${is_public_key/public_key_/}
            else
                is_reality=
            fi
            is_socks_user=$username
            is_socks_pass=$password

            # extract anytls ACME domain
            [[ $is_protocol == 'anytls' ]] && {
                is_anytls_domain=$(jq -r '(.inbounds[0].tls.certificate_provider.domain[0] // .inbounds[0].tls.acme.domain[0]) // empty' <<<$is_json_str 2>/dev/null)
            }

            is_config_name=$is_config_file

            if [[ $is_caddy && $host && -f $is_caddy_conf/$host.conf ]]; then
                is_tmp_https_port=$(grep -E -o "$host:[1-9][0-9]?+" $is_caddy_conf/$host.conf | sed s/.*://)
            fi
            if [[ $host && ! -f $is_caddy_conf/$host.conf ]]; then
                is_no_auto_tls=1
            fi
            [[ $is_tmp_https_port ]] && is_https_port=$is_tmp_https_port
            [[ $is_client && $host ]] && port=$is_https_port
            get protocol $is_protocol-$net_type
        fi
        ;;
    protocol)
        get addr # get host or server ip
        is_lower=${2,,}
        net=
        is_users="users:[{uuid:\"$uuid\"}]"
        # Default SNI for self-signed TLS protocols (Hysteria2 / TUIC / Trojan / AnyTLS)
        local tls_sni=${is_servername:-$is_hy2_default_sni}
        ensure_tls_cert "$tls_sni"
        is_tls_json='tls:{enabled:true,server_name:"'$tls_sni'",alpn:["h3"],key_path:"'$is_tls_key'",certificate_path:"'$is_tls_cer'"}'
        case $is_lower in
        vmess*)
            is_protocol=vmess
            [[ $is_lower =~ "tcp" || ! $net_type && $is_up_var_set ]] && net=tcp && json_str=$is_users
            ;;
        vless*)
            is_protocol=vless
            ;;
        tuic*)
            net=tuic
            is_protocol=$net
            [[ ! $is_servername ]] && is_servername=$is_hy2_default_sni
            [[ ! $password ]] && password=$(get_strong_pass)
            is_users="users:[{uuid:\"$uuid\",password:\"$password\"}]"
            json_str="$is_users,congestion_control:\"bbr\",$is_tls_json"
            ;;
        trojan*)
            is_protocol=trojan
            [[ ! $password ]] && password=$(get_strong_pass)
            is_users="users:[{password:\"$password\"}]"
            [[ ! $host ]] && {
                net=trojan
                [[ ! $is_servername ]] && is_servername=$is_hy2_default_sni
                json_str="$is_users,${is_tls_json/alpn\:\[\"h3\"\],/}"
            }
            ;;
        hysteria2*)
            net=hysteria2
            is_protocol=$net
            [[ ! $is_servername ]] && is_servername=$is_hy2_default_sni
            [[ ! $password ]] && password=$(get_strong_pass)
            json_str="users:[{password:\"$password\"}],$is_tls_json"
            ;;
        shadowsocks*)
            net=ss
            is_protocol=shadowsocks
            [[ ! $ss_method ]] && ss_method=${ss_method_list[0]}
            [[ ! $ss_password ]] && {
                if [[ $(grep 2022 <<<$ss_method) ]]; then
                    ss_password=$(get ss2022)
                else
                    ss_password=$(get_strong_pass)
                fi
            }
            json_str="method:\"$ss_method\",password:\"$ss_password\""
            ;;
        direct*)
            net=direct
            is_protocol=$net
            json_str="override_port:$door_port,override_address:\"$door_addr\""
            ;;
        anytls*)
            net=anytls
            is_protocol=$net
            [[ ! $password ]] && password=$(get_strong_pass)
            is_users="users:[{password:\"$password\"}]"
            if [[ $is_anytls_domain ]]; then
                is_core_minor=$(echo "$is_core_ver" | cut -d. -f2)
                if [[ ${is_core_minor:-0} -ge 14 ]]; then
                    is_anytls_tls="tls:{enabled:true,server_name:\"$is_anytls_domain\",certificate_provider:{type:\"acme\",domain:[\"$is_anytls_domain\"]}}"
                else
                    is_anytls_tls="tls:{enabled:true,server_name:\"$is_anytls_domain\",acme:{domain:[\"$is_anytls_domain\"]}}"
                fi
            else
                [[ ! $is_servername ]] && is_servername=$is_hy2_default_sni
                is_anytls_tls="${is_tls_json/alpn\:\[\"h3\"\],/}"
            fi
            json_str="$is_users,$is_anytls_tls"
            ;;
        socks*)
            net=socks
            is_protocol=$net
            [[ ! $is_socks_user ]] && is_socks_user=kkuser
            [[ ! $is_socks_pass ]] && is_socks_pass=$(get_strong_pass)
            json_str="users:[{username: \"$is_socks_user\", password: \"$is_socks_pass\"}]"
            ;;
        *)
            err "无法识别协议: $is_config_file"
            ;;
        esac
        [[ $net ]] && return # if net exist, dont need more json args
        [[ $host && $is_lower =~ "tls" ]] && {
            [[ ! $path ]] && path="/$uuid"
            is_path_host_json=",path:\"$path\",headers:{host:\"$host\"}"
        }
        case $is_lower in
        *quic*)
            net=quic
            is_json_add="$is_tls_json,transport:{type:\"$net\"}"
            ;;
        *ws*)
            net=ws
            is_json_add="transport:{type:\"$net\"$is_path_host_json,early_data_header_name:\"Sec-WebSocket-Protocol\"}"
            ;;
        *reality*)
            net=reality
            [[ ! $is_servername ]] && is_servername=$(get_random_servername)
            [[ ! $is_private_key ]] && get_pbk
            is_json_add="tls:{enabled:true,server_name:\"$is_servername\",reality:{enabled:true,handshake:{server:\"$is_servername\",server_port:443},private_key:\"$is_private_key\",short_id:[\"\"]}}"
            [[ $is_lower =~ "http" ]] && {
                is_json_add="$is_json_add,transport:{type:\"http\"}"
            } || {
                is_users=${is_users/uuid/flow:\"xtls-rprx-vision\",uuid}
            }
            ;;
        *http* | *h2*)
            net=http
            [[ $is_lower =~ "up" ]] && net=httpupgrade
            is_json_add="transport:{type:\"$net\"$is_path_host_json}"
            [[ $is_lower =~ "h2" || ! $is_lower =~ "httpupgrade" && $host ]] && {
                net=h2
                is_json_add="${is_tls_json/alpn\:\[\"h3\"\],/},$is_json_add"
            }
            ;;
        *)
            err "无法识别传输协议: $is_config_file"
            ;;
        esac
        json_str="$is_users,$is_json_add"
        ;;
    host-test) # test host dns record; for auto *tls required.
        [[ $is_no_auto_tls || $is_gen || $is_dont_test_host ]] && return
        get_ip
        get ping
        if [[ ! $(grep $ip <<<$is_host_dns) ]]; then
            msg "\n请将 ($(_red_bg $host)) 解析到 ($(_red_bg $ip))"
            msg "\n如果使用 Cloudflare, 在 DNS 那; 关闭 (Proxy status / 代理状态), 即是 (DNS only / 仅限 DNS)"
            ask string y "我已经确定解析 [y]: "
            get ping
            if [[ ! $(grep $ip <<<$is_host_dns) ]]; then
                _cyan "\n测试结果: $is_host_dns"
                err "域名 ($host) 没有解析到 ($ip)"
            fi
        fi
        ;;
    ssss | ss2022)
        if [[ $(grep 128 <<<$ss_method) ]]; then
            $is_core_bin generate rand 16 --base64
        else
            $is_core_bin generate rand 32 --base64
        fi
        ;;
    ping)
        is_dns_type="a"
        [[ $(grep ":" <<<$ip) ]] && is_dns_type="aaaa"
        is_host_dns=$(_wget -qO- --header="accept: application/dns-json" "https://one.one.one.one/dns-query?name=$host&type=$is_dns_type")
        ;;
    install-caddy)
        _green "\n安装 Caddy 实现自动配置 TLS.\n"
        load download.sh
        download caddy
        load systemd.sh
        install_service caddy &>/dev/null
        is_caddy=1
        _green "安装 Caddy 成功.\n"
        ;;
    reinstall)
        is_install_sh=$(cat $is_sh_dir/install.sh)
        uninstall
        bash <<<$is_install_sh
        ;;
    test-run)
        if [[ $is_systemd ]]; then
            systemctl list-units --full -all &>/dev/null
            [[ $? != 0 ]] && {
                _yellow "\n无法执行测试, 请检查 systemctl 状态.\n"
                return
            }
        fi
        is_no_manage_msg=1
        if [[ ! $(pgrep -f $is_core_bin) ]]; then
            _yellow "\n测试运行 $is_core_name ..\n"
            manage start &>/dev/null
            if [[ $is_run_fail == $is_core ]]; then
                _red "$is_core_name 运行失败信息:"
                $is_core_bin run -c $is_config_json -C $is_conf_dir
            else
                _green "\n测试通过, 已启动 $is_core_name ..\n"
            fi
        else
            _green "\n$is_core_name 正在运行, 跳过测试\n"
        fi
        if [[ $is_caddy ]]; then
            if [[ ! $(pgrep -f $is_caddy_bin) ]]; then
                _yellow "\n测试运行 Caddy ..\n"
                manage start caddy &>/dev/null
                if [[ $is_run_fail == 'caddy' ]]; then
                    _red "Caddy 运行失败信息:"
                    $is_caddy_bin run --config $is_caddyfile
                else
                    _green "\n测试通过, 已启动 Caddy ..\n"
                fi
            else
                _green "\nCaddy 正在运行, 跳过测试\n"
            fi
        fi
        ;;
    esac
}

# show info
info() {
    if [[ ! $is_protocol ]]; then
        get info $1
    fi
    is_color=44
    case $net in
    ws | tcp | h2 | quic | http*)
        if [[ $host ]]; then
            is_color=45
            is_can_change=(0 1 2 3 5)
            is_info_show=(0 1 2 3 4 6 7 8)
            [[ $is_protocol == 'vmess' ]] && {
                is_vmess_url=$(jq -c '{v:2,ps:'\"kk-$net-$host\"',add:'\"$is_addr\"',port:'\"$is_https_port\"',id:'\"$uuid\"',aid:"0",net:'\"$net\"',host:'\"$host\"',path:'\"$path\"',tls:'\"tls\"'}' <<<{})
                is_url=vmess://$(echo -n $is_vmess_url | base64 | tr -d '\n')
            } || {
                [[ $is_protocol == "trojan" ]] && {
                    uuid=$password
                    is_can_change=(0 1 2 3 4)
                    is_info_show=(0 1 2 10 4 6 7 8)
                }
                is_url="$is_protocol://$uuid@$host:$is_https_port?encryption=none&security=tls&type=$net&host=$host&path=$path#kk-$net-$host"
            }
            [[ $is_caddy ]] && is_can_change+=(11)
            is_info_str=($is_protocol $is_addr $is_https_port $uuid $net $host $path 'tls')
        else
            is_type=none
            is_can_change=(0 1 5)
            is_info_show=(0 1 2 3 4)
            is_info_str=($is_protocol $is_addr $port $uuid $net)
            [[ $net == "http" ]] && {
                net=tcp
                is_type=http
                is_tcp_http=1
                is_info_show+=(5)
                is_info_str=(${is_info_str[@]/http/tcp http})
            }
            [[ $net == "quic" ]] && {
                is_insecure=1
                is_info_show+=(8 9 20)
                is_info_str+=(tls h3 true)
                is_quic_add=",tls:\"tls\",alpn:\"h3\""
            }
            is_vmess_url=$(jq -c "{v:2,ps:\"kk-${net}-$is_addr\",add:\"$is_addr\",port:\"$port\",id:\"$uuid\",aid:\"0\",net:\"$net\",type:\"$is_type\"$is_quic_add}" <<<{})
            is_url=vmess://$(echo -n $is_vmess_url | base64 | tr -d '\n')
        fi
        ;;
    ss)
        is_can_change=(0 1 4 6)
        is_info_show=(0 1 2 10 11)
        is_url="ss://$(echo -n ${ss_method}:${ss_password} | base64 | tr -d '\n')@${is_addr}:${port}#kk-$net-${is_addr}"
        is_info_str=($is_protocol $is_addr $port $ss_password $ss_method)
        ;;
    trojan)
        is_insecure=1
        [[ ! $is_servername ]] && is_servername=$is_hy2_default_sni
        is_can_change=(0 1 4 10)
        is_info_show=(0 1 2 10 4 8 16 20)
        is_url="$is_protocol://$password@$is_addr:$port?type=tcp&security=tls&sni=$is_servername&insecure=1&allowInsecure=1#kk-$net-$is_addr"
        is_info_str=($is_protocol $is_addr $port $password tcp tls $is_servername true)
        ;;
    hy*)
        [[ ! $is_servername ]] && is_servername=$is_hy2_default_sni
        is_can_change=(0 1 4 10)
        is_info_show=(0 1 2 10 8 16 9 20)
        is_sha256=$(openssl x509 -noout -fingerprint -sha256 -in $is_core_dir/bin/tls.cer 2>/dev/null | sed 's/.*=//;s/://g')
        is_url="$is_protocol://$password@$is_addr:$port?sni=$is_servername&alpn=h3&insecure=1&allowInsecure=1&pinSHA256=$is_sha256#kk-$net-$is_addr"
        is_info_str=($is_protocol $is_addr $port $password tls $is_servername h3 "true (SHA256指纹: $is_sha256)")
        ;;
    tuic)
        is_insecure=1
        [[ ! $is_servername ]] && is_servername=$is_hy2_default_sni
        is_can_change=(0 1 4 5 10)
        is_info_show=(0 1 2 3 10 8 16 9 20 21)
        is_url="$is_protocol://$uuid:$password@$is_addr:$port?sni=$is_servername&alpn=h3&insecure=1&allowInsecure=1&congestion_control=bbr#kk-$net-$is_addr"
        is_info_str=($is_protocol $is_addr $port $uuid $password tls $is_servername h3 true bbr)
        ;;
    reality)
        is_color=41
        is_can_change=(0 1 5 9 10)
        is_info_show=(0 1 2 3 15 4 8 16 17 18)
        is_flow=xtls-rprx-vision
        is_net_type=tcp
        [[ $net_type =~ "http" || ${is_new_protocol,,} =~ "http" ]] && {
            is_flow=
            is_net_type=h2
            is_info_show=(${is_info_show[@]/15/})
        }
        is_info_str=($is_protocol $is_addr $port $uuid $is_flow $is_net_type reality $is_servername chrome $is_public_key)
        is_url="$is_protocol://$uuid@$is_addr:$port?encryption=none&security=reality&flow=$is_flow&type=$is_net_type&sni=$is_servername&pbk=$is_public_key&fp=chrome#kk-$net-$is_addr"
        ;;
    anytls)
        if [[ $is_anytls_domain ]]; then
            is_can_change=(0 1 4)
            is_info_show=(0 1 2 10 8 16)
            is_info_str=($is_protocol $is_anytls_domain $port $password tls $is_anytls_domain)
            is_url="anytls://$password@$is_anytls_domain:$port?sni=$is_anytls_domain#kk-$net-$is_anytls_domain"
        else
            is_insecure=1
            [[ ! $is_servername ]] && is_servername=$is_hy2_default_sni
            is_can_change=(0 1 4 10)
            is_info_show=(0 1 2 10 8 16 20)
            is_info_str=($is_protocol $is_addr $port $password tls $is_servername true)
            is_url="anytls://$password@$is_addr:$port?sni=$is_servername&insecure=1&allowInsecure=1#kk-$net-$is_addr"
        fi
        ;;
    direct)
        is_can_change=(0 1 7 8)
        is_info_show=(0 1 2 13 14)
        is_info_str=($is_protocol $is_addr $port $door_addr $door_port)
        ;;
    socks)
        is_can_change=(0 1 12 4)
        is_info_show=(0 1 2 19 10)
        is_info_str=($is_protocol $is_addr $port $is_socks_user $is_socks_pass)
        is_url="socks://$(echo -n ${is_socks_user}:${is_socks_pass} | base64 | tr -d '\n')@${is_addr}:${port}#kk-$net-${is_addr}"
        ;;
    esac
    [[ $is_dont_show_info || $is_gen || $is_dont_auto_exit ]] && return # dont show info
    msg "================ $is_config_name ================"
    for ((i = 0; i < ${#is_info_show[@]}; i++)); do
        a=${info_list[${is_info_show[$i]}]}
        if [[ ${#a} -eq 11 || ${#a} -ge 13 ]]; then
            tt='\t'
        else
            tt='\t\t'
        fi
        msg "$a $tt= \e[${is_color}m${is_info_str[$i]}\e[0m"
    done
    if [[ $is_new_install ]]; then
        msg "-------------------------------------------------"
        msg "快捷管理命令: 输入 $(_green kk) 即可随时打开节点管理与协议切换菜单!"
    fi
    if [[ $is_url ]]; then
        msg "================= ${info_list[12]} ================="
        msg "\e[4;${is_color}m${is_url}\e[0m"
        [[ $is_insecure ]] && {
            warn "客户端如 (v2rayN / NekoBox / Shadowrocket) 导入时请确认开启: 跳过证书验证 (allowInsecure=true)"
        }
    fi
    if [[ $is_no_auto_tls ]]; then
        msg "------------- no-auto-tls INFO -------------"
        msg "端口(port): $port"
        msg "路径(path): $path"
    fi
    footer_msg
}

# footer msg
footer_msg() {
    [[ $is_core_stop && ! $is_new_json ]] && warn "$is_core_name 当前处于停止状态."
    [[ $is_caddy_stop && $host ]] && warn "Caddy 当前处于停止状态."
    msg "==================== END ===================="
    msg "快捷菜单命令: $(_green kk)   |   项目地址: $(msg_ul https://github.com/${is_sh_repo})\n"
}

# URL or qrcode
url_qr() {
    is_dont_show_info=1
    info $2
    if [[ $is_url ]]; then
        [[ $1 == 'url' ]] && {
            msg "\n============= $is_config_name & URL 链接 ============="
            msg "\n\e[${is_color}m${is_url}\e[0m\n"
            footer_msg
        } || {
            link="https://233boy.github.io/tools/qr.html#${is_url}"
            msg "\n============= $is_config_name & QR code 二维码 ============="
            msg
            if [[ $(type -P qrencode) ]]; then
                qrencode -t ANSI "${is_url}"
            else
                msg "请安装 qrencode: $(_green "$cmd update -y; $cmd install qrencode -y")"
            fi
            msg
            msg "如果无法正常显示或识别, 请使用下面的链接来生成二维码:"
            msg "\n\e[4;${is_color}m${link}\e[0m\n"
            footer_msg
        }
    else
        [[ $1 == 'url' ]] && {
            err "($is_config_name) 无法生成 URL 链接."
        } || {
            err "($is_config_name) 无法生成 QR code 二维码."
        }
    fi
}

# update core, sh, caddy
update() {
    case $1 in
    1 | core | $is_core)
        is_update_name=core
        is_show_name=$is_core_name
        is_run_ver=v${is_core_ver##* }
        is_update_repo=$is_core_repo
        ;;
    2 | sh)
        is_update_name=sh
        is_show_name="$is_core_name 脚本 (kk)"
        is_run_ver=$is_sh_ver
        is_update_repo=$is_sh_repo
        ;;
    3 | caddy)
        [[ ! $is_caddy ]] && err "不支持更新 Caddy."
        is_update_name=caddy
        is_show_name="Caddy"
        is_run_ver=$is_caddy_ver
        is_update_repo=$is_caddy_repo
        ;;
    *)
        err "无法识别 ($1), 请使用: kk update [core | sh | caddy] [ver]"
        ;;
    esac
    [[ $2 ]] && is_new_ver=v${2#v}
    [[ $is_run_ver == $is_new_ver && $is_update_name != 'sh' ]] && {
        msg "\n自定义版本和当前 $is_show_name 版本一样, 无需更新.\n"
        exit
    }
    load download.sh
    if [[ $is_new_ver ]]; then
        msg "\n使用自定义版本更新 $is_show_name: $(_green $is_new_ver)\n"
    else
        get_latest_version $is_update_name
        [[ $is_run_ver == $latest_ver && $is_update_name != 'sh' ]] && {
            msg "\n$is_show_name 当前已经是最新版本了.\n"
            exit
        }
        msg "\n获取 $is_show_name 最新版本: $(_green $latest_ver)\n"
        is_new_ver=$latest_ver
    fi
    download $is_update_name $is_new_ver
    msg "✓ 更新成功, 当前 $is_show_name 版本: $(_green $is_new_ver)\n"
    [[ $is_update_name != 'sh' ]] && manage restart $is_update_name &
}

# main menu; if no prefer args.
is_main_menu() {
    local bbr_status=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
    local qdisc_status=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "unknown")
    local node_count=$(ls $is_conf_dir 2>/dev/null | grep -c '.json$')
    msg "\n================================================================="
    msg "        KK Sing-box 轻量管理面板 $is_sh_ver by $author"
    msg "================================================================="
    msg "  内核状态 : $is_core_name $is_core_ver ($is_core_status)"
    msg "  加速状态 : $(_cyan "${bbr_status} + ${qdisc_status}") (Hy2 UDP 缓冲已优化)"
    msg "  节点数量 : $(_yellow "${node_count}") 个配置运行中   |   快捷命令: $(_green kk)"
    msg "================================================================="
    is_main_start=1
    ask mainmenu
    case $REPLY in
    1)
        add
        ;;
    2)
        change
        ;;
    3)
        info
        ;;
    4)
        del
        ;;
    5)
        ask list is_do_manage "启动 停止 重启"
        manage $REPLY &
        msg "\n管理状态执行: $(_green $is_do_manage)\n"
        ;;
    6)
        load bbr.sh
        _try_enable_bbr
        ;;
    7)
        is_tmp_list=("更新 $is_core_name 内核" "更新 kk 脚本")
        [[ $is_caddy ]] && is_tmp_list+=("更新 Caddy")
        ask list is_do_update null "\n请选择更新:\n"
        update $REPLY
        ;;
    8)
        uninstall
        ;;
    9)
        msg
        load help.sh
        show_help
        ;;
    10)
        ask list is_do_other "查看/设置日志 测试运行 重装脚本 设置DNS 导入配置"
        case $REPLY in
        1)
            load log.sh
            log_set
            ;;
        2)
            get test-run
            ;;
        3)
            get reinstall
            ;;
        4)
            load dns.sh
            dns_set
            ;;
        5)
            load import.sh
            ;;
        esac
        ;;
    11)
        load help.sh
        about
        ;;
    esac
}

# check prefer args, if not exist prefer args and show main menu
main() {
    case $1 in
    a | add | gen | no-auto-tls)
        [[ $1 == 'gen' ]] && is_gen=1
        [[ $1 == 'no-auto-tls' ]] && is_no_auto_tls=1
        add ${@:2}
        ;;
    bin | pbk | check | completion | format | generate | geoip | geosite | merge | rule-set | run | tools)
        is_run_command=$1
        if [[ $1 == 'bin' ]]; then
            $is_core_bin ${@:2}
        else
            [[ $is_run_command == 'pbk' ]] && is_run_command="generate reality-keypair"
            $is_core_bin $is_run_command ${@:2}
        fi
        ;;
    bbr)
        load bbr.sh
        _try_enable_bbr
        ;;
    c | config | change)
        change ${@:2}
        ;;
    d | del | rm)
        del $2
        ;;
    dd | ddel | fix | fix-all)
        case $1 in
        fix)
            [[ $2 ]] && {
                change $2 full
            } || {
                is_change_id=full && change
            }
            return
            ;;
        fix-all)
            is_dont_auto_exit=1
            msg
            for v in $(ls $is_conf_dir | grep .json$ | sed '/dynamic-port-.*-link/d'); do
                msg "fix: $v"
                change $v full
            done
            _green "\nfix 完成.\n"
            ;;
        *)
            is_dont_auto_exit=1
            [[ ! $2 ]] && {
                err "无法找到需要删除的参数"
            } || {
                for v in ${@:2}; do
                    del $v
                done
            }
            ;;
        esac
        is_dont_auto_exit=
        manage restart &
        [[ $is_del_host ]] && manage restart caddy &
        ;;
    dns)
        load dns.sh
        dns_set ${@:2}
        ;;
    debug)
        is_debug=1
        get info $2
        warn "如果需要复制; 请把 *uuid, *password, *host, *key 的值改写, 以避免泄露."
        ;;
    fix-config.json)
        create config.json
        ;;
    fix-caddyfile)
        if [[ $is_caddy ]]; then
            load caddy.sh
            caddy_config new
            manage restart caddy &
            _green "\nfix 完成.\n"
        else
            err "无法执行此操作"
        fi
        ;;
    i | info)
        info $2
        ;;
    ip)
        get_ip
        msg $ip
        ;;
    in | import)
        load import.sh
        ;;
    log)
        load log.sh
        log_set $2
        ;;
    url | qr)
        url_qr $@
        ;;
    un | uninstall)
        uninstall
        ;;
    u | up | update | U | update.sh)
        is_update_name=$2
        is_update_ver=$3
        [[ ! $is_update_name ]] && is_update_name=core
        [[ $1 == 'U' || $1 == 'update.sh' ]] && {
            is_update_name=sh
            is_update_ver=
        }
        update $is_update_name $is_update_ver
        ;;
    ssss | ss2022)
        get $@
        ;;
    s | status)
        msg "\n$is_core_name $is_core_ver: $is_core_status\n"
        [[ $is_caddy ]] && msg "Caddy $is_caddy_ver: $is_caddy_status\n"
        ;;
    start | stop | r | restart)
        [[ $2 && $2 != 'caddy' ]] && err "无法识别 ($2), 请使用: kk $1 [caddy]"
        manage $1 $2 &
        ;;
    t | test)
        get test-run
        ;;
    reinstall)
        get $1
        ;;
    get-port)
        get_port
        msg $tmp_port
        ;;
    main)
        is_main_menu
        ;;
    v | ver | version)
        [[ $is_caddy_ver ]] && is_caddy_ver="/ $(_blue Caddy $is_caddy_ver)"
        msg "\n$(_green $is_core_name $is_core_ver) / $(_cyan KK script $is_sh_ver) $is_caddy_ver\n"
        ;;
    h | help | --help)
        load help.sh
        show_help ${@:2}
        ;;
    *)
        is_try_change=1
        change test $1
        if [[ $is_change_id ]]; then
            unset is_try_change
            if [[ $2 ]]; then
                # If $2 matches an existing config file, pass $2 as config name; otherwise if only 1 config exists, treat $2 as the new value!
                if [[ $(ls $is_conf_dir 2>/dev/null | grep -E -i "$2") ]]; then
                    change $2 $1 ${@:3}
                elif [[ $(ls $is_conf_dir 2>/dev/null | grep -c '\.json$') -eq 1 ]]; then
                    change "" $1 $2 ${@:3}
                else
                    change $2 $1 ${@:3}
                fi
            else
                change
            fi
        else
            err "无法识别 ($1), 获取帮助请使用: kk help"
        fi
        ;;
    esac
}
