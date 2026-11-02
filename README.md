# kkonline - 轻量级 Sing-box 一键安装与管理脚本 (KK面板)

基于 233boy 架构深度定制与精简优化的 **Sing-box 轻量一键脚本**，主打**极低内存与硬盘占用、高稳定性、全系统自适应（Debian / Ubuntu / Alpine）**，快捷管理命令为 **`kk`**。

## 一键安装命令

**方式一（wget，推荐）：**

```
bash <(wget -qO- https://raw.githubusercontent.com/a2899882/kkonline/main/install.sh)

```

**方式二（curl）：**

```
bash <(curl -fsSL https://raw.githubusercontent.com/a2899882/kkonline/main/install.sh)

```

> **提示**：如果是极简 Alpine / Debian 系统未预装 `wget` 或 `curl`，可先执行：
>
> * Debian / Ubuntu: `apt update -y && apt install -y wget`
>
> * Alpine Linux: `apk update && apk add wget bash`

## 核心特性

1. **极致轻量 & 稳定省资源**

   * 内置 `GOGC=50` 内存回收优化，常驻内存占用极低（小内存 VPS 无压力）。

   * 默认关闭冗余访问日志写入（防止日志撑爆小硬盘），可随时通过 `kk log` 开启调试。

   * 自动清理安装包缓存与无用文件。

2. **全系统自适应安装**

   * 自动识别 **Debian / Ubuntu (`apt-get` + `systemd`)** 与 **Alpine Linux (`apk` + `OpenRC`)**（同时兼容 CentOS/RHEL/SUSE）。

3. **安装即默认开启 BBR+FQ 与 Hysteria2 加速优化**

   * 安装过程自动写入并激活 `BBR + FQ` 拥塞控制算法。

   * 自动调优内核 UDP/QUIC 收发缓冲区（`rmem_max` / `wmem_max` = 25MB）、`tcp_fastopen`、高并发连接队列等 Hysteria2 加速参数。

4. **默认自动生成 Shadowsocks (`aes-128-gcm`) 节点**

   * 安装完成后默认自动创建一个 **随机可用端口 + 22位高强度随机密码** 的 `Shadowsocks (aes-128-gcm)` 节点并输出分享链接。

5. **`kk` 快捷交互菜单与主流协议全支持**

   * **Shadowsocks 全系主流加密**：支持一键选择 `aes-128-gcm`、`aes-256-gcm`、`2022-blake3-aes-128-gcm`、`2022-blake3-aes-256-gcm`、`2022-blake3-chacha20-poly1305`、`chacha20-ietf-poly1305`、`xchacha20-ietf-poly1305`，选择后自动分配随机端口与高强度随机密码。

   * **VLESS-REALITY-Vision**：默认开启 `xtls-rprx-vision` 流控，自动随机主流大厂偷取域名（`www.tesla.com`、`www.amazon.com`、`aws.amazon.com`、`www.intel.com`、`www.nvidia.com`、`www.apple.com`、`itunes.apple.com`、`www.amd.com`、`www.sony.com`、`www.paypal.com`、`www.ebay.com`、`www.yahoo.com`，已剔除微软与 Cloudflare 域名）。

   * **Hysteria2 (Hy2)**：默认采用 `www.bing.com` 作为伪装 SNI 并自动生成匹配证书与 `pinSHA256` 指纹，支持随时通过 `kk` 更改 SNI、端口、密码。

   * **AnyTLS / TUIC / Trojan / VMess / VLESS-WS-TLS**：全协议支持，支持多节点同时运行。

## 快捷命令 (`kk`) 使用指南

在终端任意位置输入 **`kk`** 即可打开交互式管理菜单：

```
=================================================================
        KK Sing-box 轻量管理面板 v1.0.0 by a2899882
=================================================================
  内核状态 : sing-box (running)
  加速状态 : bbr + fq (Hy2 UDP 缓冲已优化)
  节点数量 : 1 个配置运行中   |   快捷命令: kk
=================================================================
1) 添加配置 (Add)
2) 更改配置 (Change)
3) 查看配置 (Info/URL/QR)
4) 删除配置 (Delete)
5) 运行管理 (Start/Stop/Restart)
6) 加速优化 (BBR+FQ & Hy2优化)
7) 更新管理 (Update)
8) 卸载脚本 (Uninstall)
9) 帮助说明 (Help)
10) 其他工具 (Log/DNS/Reinstall)
11) 关于脚本 (About)

```

### 常用命令行快捷操作

| 功能 | 命令示例 | 
| ----- | ----- | 
| 打开交互主菜单 | `kk` | 
| 快速添加 SS (选择加密方式，自动随机端口+密码) | `kk` -> 选 `1` -> 选 `1` | 
| 一键添加 SS (`aes-128-gcm`) | `kk add ss128` 或 `kk add ss auto auto aes-128-gcm` | 
| 一键添加 SS (`aes-256-gcm`) | `kk add ss256` 或 `kk add ss auto auto aes-256-gcm` | 
| 一键添加 SS-2022 (`2022-blake3-aes-128-gcm`) | `kk add ss2022-128` | 
| 一键添加 SS-2022 (`2022-blake3-aes-256-gcm`) | `kk add ss2022-256` | 
| 一键添加 VLESS-REALITY-Vision (随机主流大厂SNI) | `kk add reality` | 
| 一键添加 Hysteria2 (默认 `www.bing.com` SNI) | `kk add hy2` | 
| 一键添加 AnyTLS | `kk add anytls` | 
| 一键添加 TUIC | `kk add tuic` | 
| 交互式更改配置 (端口/密码/SNI/加密方式等) | `kk c` | 
| 快速更改节点端口 (支持 `auto` 随机端口) | `kk port [节点名] [新端口 | auto]` | 
| 快速更改节点密码 (支持 `auto` 随机高强度密码) | `kk passwd [节点名] [新密码 | auto]` | 
| 快速更改节点 SNI 伪装域名 | `kk sni [节点名] [域名 | auto]` | 
| 快速更改 SS 加密方式 | `kk method [节点名] [加密方式]` | 
| 查看节点信息与连接 URL | `kk i` 或 `kk url` | 
| 查看节点二维码 | `kk qr` | 
| 删除节点配置 | `kk d` | 
| 重新应用 BBR+FQ & Hy2 加速优化 | `kk bbr` | 
| 重启 / 查看运行状态 | `kk restart` / `kk s` | 
| 更新内核 / 更新脚本 | `kk u core` / `kk U` | 
| 卸载脚本 | `kk un` | 
