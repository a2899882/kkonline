fetch_url_to_file() {
    local url="$1"
    local out="$2"
    local expect_tar="$3"
    local mirrors=(
        ""
        "https://gh-proxy.com/"
        "https://ghfast.top/"
        "https://ghproxy.net/"
        "https://mirror.ghproxy.com/"
    )
    for prefix in "${mirrors[@]}"; do
        local try_url="${prefix}${url}"
        rm -f "$out"
        if _wget -t 2 -T 15 -q "$try_url" -O "$out" && [[ -s "$out" ]]; then
            if [[ $expect_tar ]]; then
                tar tzf "$out" &>/dev/null && return 0
            else
                return 0
            fi
        fi
        rm -f "$out"
        if [[ $(type -P curl) ]]; then
            if curl -fsSLk --connect-timeout 10 --max-time 60 "$try_url" -o "$out" 2>/dev/null && [[ -s "$out" ]]; then
                if [[ $expect_tar ]]; then
                    tar tzf "$out" &>/dev/null && return 0
                else
                    return 0
                fi
            fi
        fi
    done
    rm -f "$out"
    return 1
}

get_latest_version() {
    case $1 in
    core)
        name=$is_core_name
        url="https://api.github.com/repos/${is_core_repo}/releases/latest?v=$RANDOM"
        latest_ver=$(_wget -qO- -T 8 $url 2>/dev/null | grep tag_name | grep -E -o 'v([0-9.]+)' | head -n1)
        if [[ ! $latest_ver && $(type -P curl) ]]; then
            latest_ver=$(curl -fsSLk --connect-timeout 5 --max-time 10 -o /dev/null -w '%{url_effective}' "https://github.com/${is_core_repo}/releases/latest" 2>/dev/null | grep -E -o 'v[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)
        fi
        if [[ ! $latest_ver ]]; then
            latest_ver=$(_wget -qO- -T 8 "https://gh-proxy.com/${url}" 2>/dev/null | grep tag_name | grep -E -o 'v([0-9.]+)' | head -n1)
        fi
        ;;
    sh)
        name="$is_core_name 脚本 (kkonline)"
        url="https://api.github.com/repos/$is_sh_repo/releases/latest?v=$RANDOM"
        latest_ver=$(_wget -qO- -T 8 $url 2>/dev/null | grep tag_name | grep -E -o 'v([0-9.]+)' | head -n1)
        # Fallback to main branch latest version if no release tag published yet
        if [[ ! $latest_ver ]]; then
            latest_ver=$(_wget -qO- -T 8 "https://raw.githubusercontent.com/${is_sh_repo}/main/kk.sh?v=$RANDOM" 2>/dev/null | grep '^is_sh_ver=' | head -n1 | cut -d= -f2)
            [[ ! $latest_ver ]] && latest_ver="main"
        fi
        ;;
    caddy)
        name="Caddy"
        url="https://api.github.com/repos/$is_caddy_repo/releases/latest?v=$RANDOM"
        latest_ver=$(_wget -qO- -T 8 $url 2>/dev/null | grep tag_name | grep -E -o 'v([0-9.]+)' | head -n1)
        if [[ ! $latest_ver && $(type -P curl) ]]; then
            latest_ver=$(curl -fsSLk --connect-timeout 5 --max-time 10 -o /dev/null -w '%{url_effective}' "https://github.com/${is_caddy_repo}/releases/latest" 2>/dev/null | grep -E -o 'v[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)
        fi
        ;;
    esac
    [[ ! $latest_ver ]] && {
        err "获取 ${name} 最新版本失败."
    }
    unset name url
}

download() {
    latest_ver=$2
    [[ ! $latest_ver ]] && get_latest_version $1
    # tmp dir
    tmpdir=$(mktemp -u)
    [[ ! $tmpdir ]] && {
        tmpdir=/tmp/tmp-$RANDOM
    }
    mkdir -p $tmpdir
    case $1 in
    core)
        name=$is_core_name
        tmpfile=$tmpdir/$is_core.tar.gz
        link="https://github.com/${is_core_repo}/releases/download/${latest_ver}/${is_core}-${latest_ver:1}-linux-${is_arch}.tar.gz"
        download_file
        tar zxf $tmpfile --strip-components 1 -C $is_core_dir/bin
        rm -f $is_core_dir/bin/LICENSE $is_core_dir/bin/README.md 2>/dev/null
        chmod +x $is_core_bin
        ;;
    sh)
        name="$is_core_name 脚本"
        tmpfile=$tmpdir/sh.tar.gz
        if [[ $latest_ver == "main" ]]; then
            link="https://github.com/${is_sh_repo}/archive/refs/heads/main.tar.gz"
        else
            link="https://github.com/${is_sh_repo}/releases/download/${latest_ver}/code.tar.gz"
        fi
        if ! fetch_url_to_file "$link" "$tmpfile" 1; then
            link="https://github.com/${is_sh_repo}/archive/refs/heads/main.tar.gz"
            download_file
        fi
        mkdir -p $tmpdir/sh_extract
        tar zxf $tmpfile -C $tmpdir/sh_extract
        if [[ -f $tmpdir/sh_extract/src/core.sh ]]; then
            cp -rf $tmpdir/sh_extract/* $is_sh_dir/
        else
            cp -rf $tmpdir/sh_extract/*/* $is_sh_dir/
        fi
        [[ -f $is_sh_dir/kk.sh && ! -f $is_sh_dir/$is_core.sh ]] && cp -f $is_sh_dir/kk.sh $is_sh_dir/$is_core.sh
        [[ -f $is_sh_dir/$is_core.sh && ! -f $is_sh_dir/kk.sh ]] && cp -f $is_sh_dir/$is_core.sh $is_sh_dir/kk.sh
        ln -sf $is_sh_dir/kk.sh /usr/local/bin/kk
        ln -sf $is_sh_dir/kk.sh /usr/local/bin/$is_core
        ln -sf $is_sh_dir/kk.sh /usr/local/bin/sb
        chmod +x $is_sh_dir/kk.sh $is_sh_dir/$is_core.sh /usr/local/bin/kk /usr/local/bin/$is_core /usr/local/bin/sb 2>/dev/null
        ;;
    caddy)
        name="Caddy"
        tmpfile=$tmpdir/caddy.tar.gz
        link="https://github.com/${is_caddy_repo}/releases/download/${latest_ver}/caddy_${latest_ver:1}_linux_${is_arch}.tar.gz"
        download_file
        tar zxf $tmpfile -C $tmpdir
        cp -f $tmpdir/caddy $is_caddy_bin
        chmod +x $is_caddy_bin
        ;;
    esac
    rm -rf $tmpdir
    unset latest_ver
}

download_file() {
    if ! fetch_url_to_file "$link" "$tmpfile" 1; then
        rm -rf $tmpdir
        err "\n下载 ${name} 失败.\n"
    fi
}
