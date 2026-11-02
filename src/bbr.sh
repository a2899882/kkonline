#!/bin/bash

# BBR + FQ & Hysteria2 / QUIC / High-Concurrency Network Optimization

_apply_sysctl_optimizations() {
    # Try loading tcp_bbr kernel module if available
    modprobe tcp_bbr &>/dev/null || true

    # Ensure /etc/sysctl.conf exists
    touch /etc/sysctl.conf 2>/dev/null

    # Clean up old keys from /etc/sysctl.conf
    local keys=(
        "net.core.default_qdisc"
        "net.ipv4.tcp_congestion_control"
        "net.core.rmem_max"
        "net.core.wmem_max"
        "net.core.rmem_default"
        "net.core.wmem_default"
        "net.core.optmem_max"
        "net.core.netdev_max_backlog"
        "net.ipv4.udp_rmem_min"
        "net.ipv4.udp_wmem_min"
        "net.ipv4.tcp_rmem"
        "net.ipv4.tcp_wmem"
        "net.ipv4.tcp_fastopen"
        "net.ipv4.tcp_tw_reuse"
        "net.ipv4.tcp_fin_timeout"
        "net.ipv4.tcp_keepalive_time"
        "net.ipv4.ip_local_port_range"
        "fs.file-max"
    )
    for k in "${keys[@]}"; do
        sed -i "/^${k}/d" /etc/sysctl.conf 2>/dev/null
        sed -i "/^${k}[[:space:]]*=/d" /etc/sysctl.conf 2>/dev/null
    done

    local sysctl_block="# === KK Sing-box BBR+FQ & Hysteria2 Acceleration ===
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 26214400
net.core.wmem_max = 26214400
net.core.rmem_default = 1048576
net.core.wmem_default = 1048576
net.core.optmem_max = 65536
net.core.netdev_max_backlog = 16384
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192
net.ipv4.tcp_rmem = 4096 87380 26214400
net.ipv4.tcp_wmem = 4096 65536 26214400
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 600
net.ipv4.ip_local_port_range = 10240 65535
fs.file-max = 1048576"

    sed -i '/# === KK Sing-box BBR+FQ & Hysteria2 Acceleration ===/d' /etc/sysctl.conf 2>/dev/null
    echo "$sysctl_block" >>/etc/sysctl.conf 2>/dev/null

    if [[ -d /etc/sysctl.d ]]; then
        echo "$sysctl_block" >/etc/sysctl.d/99-kk-optimize.conf 2>/dev/null
    fi

    # Apply sysctl settings (ignore errors on read-only container procfs)
    sysctl -p &>/dev/null || true
    sysctl --system &>/dev/null || true
}

_open_bbr() {
    _apply_sysctl_optimizations
    local cur_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
    local cur_qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "unknown")
    local cur_rmem=$(sysctl -n net.core.rmem_max 2>/dev/null || echo "unknown")
    echo
    _green "✓ 已启用 BBR + FQ 及 Hysteria2 (UDP/QUIC) 内核加速优化!"
    echo -e "  当前拥塞控制算法 : ${cyan}${cur_cc}${none}"
    echo -e "  当前队列调度算法 : ${cyan}${cur_qdisc}${none}"
    echo -e "  UDP 最大接收缓存 : ${cyan}${cur_rmem} bytes${none}"
    echo
}

_try_enable_bbr() {
    local _test1=$(uname -r | cut -d\. -f1)
    local _test2=$(uname -r | cut -d\. -f2)
    if [[ $_test1 -eq 4 && $_test2 -ge 9 ]] || [[ $_test1 -ge 5 ]]; then
        _open_bbr
    else
        _apply_sysctl_optimizations
        warn "当前内核版本 ($(uname -r)) 较低，已应用 Hysteria2 UDP 缓冲区优化，但可能不支持原生 BBR."
    fi
}

_auto_enable_bbr_hy2() {
    _apply_sysctl_optimizations
}
