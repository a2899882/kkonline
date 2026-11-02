get_latest_version() {
    case $1 in
    core)
        name=$is_core_name
        url="https://api.github.com/repos/${is_core_repo}/releases/latest?v=$RANDOM"
        latest_ver=$(_wget -qO- $url | grep tag_name | grep -E -o 'v([0-9.]+)')
        ;;
    sh)
        name="$is_core_name 脚本 (kkonline)"
        url="https://api.github.com/repos/$is_sh_repo/releases/latest?v=$RANDOM"
        latest_ver=$(_wget -qO- $url | grep tag_name | grep -E -o 'v([0-9.]+)')
        # Fallback to main branch latest version if no release tag published yet
        if [[ ! $latest_ver ]]; then
            latest_ver=$(_wget -qO- "https://raw.githubusercontent.com/${is_sh_repo}/main/kk.sh?v=$RANDOM" | grep '^is_sh_ver=' | head -n1 | cut -d= -f2)
            [[ ! $latest_ver ]] && latest_ver="main"
        fi
        ;;
    caddy)
        name="Caddy"
        url="https://api.github.com/repos/$is_caddy_repo/releases/latest?v=$RANDOM"
        latest_ver=$(_wget -qO- $url | grep tag_name | grep -E -o 'v([0-9.]+)')
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
        if ! _wget -t 3 -c $link -O $tmpfile &>/dev/null; then
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
    if ! _wget -t 5 -c $link -O $tmpfile; then
        rm -rf $tmpdir
        err "\n下载 ${name} 失败.\n"
    fi
}
