show_help() {
    case $1 in
    api | x25519 | tls | run | uuid | version)
        $is_core_bin help $1 ${@:2}
        ;;
    *)
        [[ $1 ]] && warn "未知选项 '$1'"
        msg "================================================================="
        msg "  KK Sing-box 轻量一键管理脚本 $is_sh_ver by $author"
        msg "  Usage: kk [options]... [args]... (兼容 sb / sing-box)"
        msg "================================================================="
        msg
        help_info=(
            "基本命令:"
            "   kk                                              打开 KK 交互式快捷管理菜单"
            "   v, version                                      显示当前内核与脚本版本"
            "   ip                                              返回当前主机的公网 IP"
            "   pbk                                             生成 REALITY 密钥对 (reality-keypair)"
            "   get-port                                        返回一个随机可用的端口"
            "   ss2022                                          返回一个可用于 Shadowsocks 2022 的高强度密钥\n"
            "节点管理:"
            "   a, add [protocol] [args... | auto]              快速添加节点配置 (如: kk a ss / kk a reality / kk a hy2 / kk a anytls)"
            "   c, change [name] [option] [args... | auto]      快速更改节点配置"
            "   d, del [name]                                   删除指定节点配置**"
            "   i, info [name]                                  查看节点完整配置与链接"
            "   qr [name]                                       显示节点二维码信息"
            "   url [name]                                      仅显示节点 URL 链接"
            "   log [level | del | none]                        查看或设置日志级别 (默认轻量模式不占磁盘)\n"
            "参数更改:"
            "   full [name] [...]                               更改多个参数"
            "   id [name] [uuid | auto]                         更改 UUID (auto 为随机生成)"
            "   host [name] [domain]                            更改 TLS 域名"
            "   port [name] [port | auto]                       更改端口 (auto 为随机端口)"
            "   path [name] [path | auto]                       更改路径"
            "   passwd [name] [password | auto]                 更改密码 (auto 为高强度随机密码)"
            "   key [name] [Private key | auto] [Public key]    更改 REALITY 密钥"
            "   method [name] [method | auto]                   更改 Shadowsocks 加密方式 (128/256/2022等)"
            "   sni [name] [domain | auto]                      更改 SNI / 偷取域名 (支持 Reality / Hy2 / AnyTLS / TUIC)"
            "   new [name] [...]                                更换节点协议"
            "   web [name] [domain]                             更改伪装网站\n"
            "进阶与维护:"
            "   bbr                                             一键开启 BBR+FQ 与 Hysteria2 内核加速优化"
            "   dns [...]                                       配置 DNS 分流解析"
            "   dd, ddel [name...]                              批量删除多个配置**"
            "   fix [name]                                      修复单个配置"
            "   fix-all                                         修复全部配置"
            "   fix-caddyfile                                   修复 Caddyfile"
            "   fix-config.json                                 修复主配置文件 config.json"
            "   import                                          导入 xray/v2ray 脚本配置\n"
            "服务管理:"
            "   un, uninstall                                   卸载脚本与内核"
            "   u, update [core | sh | caddy] [ver]             更新内核 / 脚本 / Caddy"
            "   U, update.sh                                    快速更新 kk 脚本"
            "   s, status                                       查看服务运行状态"
            "   start, stop, restart [caddy]                    启动 / 停止 / 重启服务"
            "   t, test                                         测试运行并诊断故障"
            "   reinstall                                       重装脚本\n"
            "其他:"
            "   debug [name]                                    显示配置解析调试信息"
            "   gen [...]                                       仅生成显示 JSON 内容而不写入文件"
            "   no-auto-tls [...]                               添加 TLS 协议但禁用自动申请证书"
            "   bin [...]                                       直接调用 sing-box 原生命令"
            "   h, help                                         显示此帮助界面\n"
        )
        for v in "${help_info[@]}"; do
            msg "$v"
        done
        msg "提示: 谨慎使用 del / ddel, 该命令会直接删除指定配置"
        msg "项目地址: $(msg_ul https://github.com/${is_sh_repo})"
        ;;
    esac
}

about() {
    msg
    msg "================================================================="
    msg "  KK Sing-box 轻量一键脚本 ($is_sh_ver)"
    msg "================================================================="
    msg "  作者 (Author)   : $author"
    msg "  项目仓库 (Repo) : $(msg_ul https://github.com/${is_sh_repo})"
    msg "  快捷命令 (Cmd)  : $(_green kk) (兼容 $(_cyan sb) / $(_cyan sing-box))"
    msg "  支持系统 (OS)   : Debian / Ubuntu / Alpine (自适应 systemd & OpenRC)"
    msg "  默认优化 (Opt)  : BBR + FQ + Hysteria2 高并发 UDP/QUIC 缓冲优化"
    msg "  内核官网 (Core) : $(msg_ul https://sing-box.sagernet.org/)"
    msg "================================================================="
    msg
}
