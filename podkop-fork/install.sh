#!/bin/sh
# shellcheck shell=dash

set -eu

# ==============================
# Podkop fork installer
# ==============================
# 1) Install podkop/luci-app-podkop from YOUR fork releases
# 2) Optional: attach YOUR lists from key
# 3) Keep attribution to original podkop author

# ---- Ready-to-use values ----
# Podkop packages source (this repository releases)
PODKOP_FORK_REPO="wester11/podpodkop"
# Your lists repository:
LISTS_BASE_URL="https://raw.githubusercontent.com/wester11/podpodkop/main/lists"
SERVICES_BASE_URL="https://raw.githubusercontent.com/wester11/podpodkop/main/services"
# Podkop custom config source (from custom podkop fork sources in this repository):
PODKOP_CONFIG_URL="https://raw.githubusercontent.com/wester11/podpodkop/main/_podkop_upstream/podkop/files/etc/config/podkop"
PODKOP_BIN_URL="https://raw.githubusercontent.com/wester11/podpodkop/main/_podkop_upstream/podkop/files/usr/bin/podkop"
PODKOP_INIT_URL="https://raw.githubusercontent.com/wester11/podpodkop/main/_podkop_upstream/podkop/files/etc/init.d/podkop"
PODKOP_CONSTANTS_URL="https://raw.githubusercontent.com/wester11/podpodkop/main/_podkop_upstream/podkop/files/usr/lib/constants.sh"
PODKOP_SINGBOX_MGR_URL="https://raw.githubusercontent.com/wester11/podpodkop/main/_podkop_upstream/podkop/files/usr/lib/sing_box_config_manager.sh"
PODKOP_SECTION_JS_URL="https://raw.githubusercontent.com/wester11/podpodkop/main/_podkop_upstream/luci-app-podkop/htdocs/luci-static/resources/view/podkop/section.js"
PODKOP_SETTINGS_JS_URL="https://raw.githubusercontent.com/wester11/podpodkop/main/_podkop_upstream/luci-app-podkop/htdocs/luci-static/resources/view/podkop/settings.js"
PODKOP_SUBSCRIBE_JS_URL="https://raw.githubusercontent.com/wester11/podpodkop/main/_podkop_upstream/luci-app-podkop/htdocs/luci-static/resources/view/podkop/subscribe.js"
PODKOP_SUBSCRIBE_CGI_URL="https://raw.githubusercontent.com/wester11/podpodkop/main/_podkop_upstream/luci-app-podkop/root/www/cgi-bin/podkop-subscribe"
PODKOP_IMPORT_CGI_URL="https://raw.githubusercontent.com/wester11/podpodkop/main/_podkop_upstream/luci-app-podkop/root/www/cgi-bin/podkop-import-subscription"

PODKOP_RELEASE_TAG="${PODKOP_RELEASE_TAG:-}"
DOWNLOAD_DIR="/tmp/podkop-fork"
COUNT=3
FETCH_TIMEOUT=20
FETCH_CONNECT_TIMEOUT=10
PODKOP_KEY="${PODKOP_KEY:-}"
PODKOP_VLESS_URL="${PODKOP_VLESS_URL:-}"

PKG_IS_APK=0
command -v apk >/dev/null 2>&1 && PKG_IS_APK=1
REPO_API=""
REPO_RELEASE_PAGE=""
USE_FEED_INSTALL=0

msg() {
    printf "\033[32;1m%s\033[0m\n" "$1"
}

decode_key_payload() {
    encoded="$1"
    encoded="${encoded#PK1_}"
    encoded="$(printf '%s' "$encoded" | tr '_-' '/+')"
    rem=$(( ${#encoded} % 4 ))
    if [ "$rem" -eq 2 ]; then encoded="${encoded}=="; fi
    if [ "$rem" -eq 3 ]; then encoded="${encoded}="; fi

    decoded="$(printf '%s' "$encoded" | base64 -d 2>/dev/null || true)"
    if [ -z "$decoded" ] && command -v openssl >/dev/null 2>&1; then
        decoded="$(printf '%s' "$encoded" | openssl base64 -d -A 2>/dev/null || true)"
    fi
    printf '%s\n' "$decoded"
}

add_remote_pair() {
    domain_url="$1"
    subnet_url="$2"
    uci -q add_list podkop.main.remote_domain_lists="$domain_url"
    uci -q add_list podkop.main.remote_subnet_lists="$subnet_url"
}

add_community_item() {
    item="$1"
    uci -q add_list podkop.main.community_lists="$item"
}

is_custom_community_item() {
    case "$1" in
        ai_all|gaming|social_networks|messengers_calls|video_audio_streaming|news_media|developer_platforms|cloud_storage)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

is_safe_slug() {
    case "$1" in
        *[!a-z0-9_]*|'')
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

apply_selected_lists_from_key() {
    payload="$(decode_key_payload "$PODKOP_KEY")"
    if [ -z "$payload" ]; then
        warn "Key decode failed, skip custom lists."
        return
    fi

    lists_csv="$(echo "$payload" | sed -n 's/.*L=\([^;]*\).*/\1/p')"
    services_csv="$(echo "$payload" | sed -n 's/.*S=\([^;]*\).*/\1/p')"
    selected_count=0

    OLD_IFS="$IFS"
    IFS=','
    for item in $lists_csv; do
        [ -n "$item" ] || continue
        if is_safe_slug "$item"; then
            if is_custom_community_item "$item"; then
                add_community_item "$item"
            else
                add_remote_pair "${LISTS_BASE_URL}/${item}/domains.srs" "${LISTS_BASE_URL}/${item}/subnets.srs"
            fi
            selected_count=$((selected_count + 1))
        fi
    done
    for item in $services_csv; do
        [ -n "$item" ] || continue
        if is_safe_slug "$item"; then
            add_remote_pair "${SERVICES_BASE_URL}/${item}/domains.srs" "${SERVICES_BASE_URL}/${item}/subnets.srs"
            selected_count=$((selected_count + 1))
        fi
    done
    IFS="$OLD_IFS"

    if [ "$selected_count" -gt 0 ]; then
        msg "Applied selected items from key: $selected_count"
    else
        warn "No valid items in key, no lists were applied."
    fi
}

warn() {
    printf "\033[33;1m%s\033[0m\n" "$1"
}

err() {
    printf "\033[31;1m%s\033[0m\n" "$1"
}

fetch_text() {
    url="$1"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --connect-timeout "$FETCH_CONNECT_TIMEOUT" --max-time "$FETCH_TIMEOUT" "$url"
    else
        wget -qO- --timeout="$FETCH_TIMEOUT" "$url"
    fi
}

fetch_file() {
    url="$1"
    output="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --connect-timeout "$FETCH_CONNECT_TIMEOUT" --max-time "$FETCH_TIMEOUT" -o "$output" "$url"
    else
        wget -q --timeout="$FETCH_TIMEOUT" -O "$output" "$url"
    fi
}

pkg_is_installed() {
    pkg_name="$1"
    if [ "$PKG_IS_APK" -eq 1 ]; then
        apk list --installed | grep -q "$pkg_name"
    else
        opkg list-installed | grep -q "$pkg_name"
    fi
}

pkg_remove() {
    pkg_name="$1"
    if [ "$PKG_IS_APK" -eq 1 ]; then
        apk del "$pkg_name"
    else
        opkg remove --force-depends "$pkg_name"
    fi
}

pkg_list_update() {
    if [ "$PKG_IS_APK" -eq 1 ]; then
        apk update
    else
        opkg update
    fi
}

pkg_install() {
    pkg_file="$1"
    if [ "$PKG_IS_APK" -eq 1 ]; then
        apk add --allow-untrusted --force-overwrite "$pkg_file"
    else
        opkg install --force-reinstall "$pkg_file"
    fi
}

pkg_install_name() {
    pkg_name="$1"
    if [ "$PKG_IS_APK" -eq 1 ]; then
        apk add "$pkg_name"
    else
        opkg install "$pkg_name"
    fi
}

update_config() {
    warn "Detected old podkop version."
    warn "If you continue, podkop config may be reset."
    warn "Backup file: /etc/config/podkop-fork-backup"
    msg "Continue? (yes/no)"

    while true; do
        read -r CONFIG_UPDATE
        case "$CONFIG_UPDATE" in
            yes|y|Y)
                cp /etc/config/podkop /etc/config/podkop-fork-backup 2>/dev/null || true
                fetch_file "$PODKOP_CONFIG_URL" /etc/config/podkop
                msg "Config reset done. Backup: /etc/config/podkop-fork-backup"
                break
                ;;
            *)
                msg "Exit"
                exit 1
                ;;
        esac
    done
}

check_system() {
    model="$(cat /tmp/sysinfo/model 2>/dev/null || true)"
    [ -n "$model" ] && msg "Router model: $model"

    openwrt_major="$(grep DISTRIB_RELEASE /etc/openwrt_release | cut -d"'" -f2 | cut -d'.' -f1)"
    if [ "$openwrt_major" = "23" ]; then
        err "OpenWrt 23.05 is not supported by modern podkop versions."
        err "Use OpenWrt 24.10+."
        exit 1
    fi

    available_space="$(df /overlay | awk 'NR==2 {print $4}')"
    required_space=15360
    if [ "$available_space" -lt "$required_space" ]; then
        err "Insufficient space in flash."
        err "Available: $((available_space/1024))MB, required: $((required_space/1024))MB."
        exit 1
    fi

    if ! nslookup github.com >/dev/null 2>&1; then
        err "DNS check failed (github.com unresolved)."
        exit 1
    fi

    if command -v podkop >/dev/null 2>&1; then
        version="$(/usr/bin/podkop show_version 2>/dev/null || true)"
        if [ -n "$version" ]; then
            version="$(echo "$version" | sed 's/^v//')"
            major="$(echo "$version" | cut -d. -f1)"
            minor="$(echo "$version" | cut -d. -f2)"
            patch="$(echo "$version" | cut -d. -f3)"

            if [ "$major" -gt 0 ] ||
               { [ "$major" -eq 0 ] && [ "$minor" -gt 7 ]; } ||
               { [ "$major" -eq 0 ] && [ "$minor" -eq 7 ] && [ "$patch" -ge 0 ]; }; then
                msg "Podkop version >= 0.7.0"
            else
                warn "Podkop version < 0.7.0"
                update_config
            fi
        else
            warn "Unknown podkop version"
            update_config
        fi
    fi

    if pkg_is_installed https-dns-proxy; then
        warn "Conflicting package detected: https-dns-proxy"
        warn "Removing conflicting packages..."
        pkg_remove luci-app-https-dns-proxy || true
        pkg_remove https-dns-proxy || true
        pkg_remove luci-i18n-https-dns-proxy || true
    fi
}

sing_box() {
    if ! pkg_is_installed "^sing-box"; then
        return
    fi

    sing_box_version="$(sing-box version | head -n 1 | awk '{print $3}')"
    required_version="1.12.4"

    if [ "$(printf '%s\n%s\n' "$sing_box_version" "$required_version" | sort -V | head -n 1)" != "$required_version" ]; then
        warn "sing-box version $sing_box_version is older than required $required_version"
        warn "Removing old sing-box..."
        service podkop stop || true
        pkg_remove sing-box || true
    fi
}

prepare_ntp() {
    /usr/sbin/ntpd -q -p 194.190.168.1 -p 216.239.35.0 -p 216.239.35.4 -p 162.159.200.1 -p 162.159.200.123 || true
}

download_release_packages() {
    local release_json release_html grep_url_pattern rel_url_pattern abs_url_pattern pkg_ext url filename filepath attempt
    local api_rate_limited api_not_found
    api_rate_limited=0
    api_not_found=0

    rm -rf "$DOWNLOAD_DIR"
    mkdir -p "$DOWNLOAD_DIR"

    if [ "$PKG_IS_APK" -eq 1 ]; then
        pkg_ext='apk'
    else
        pkg_ext='ipk'
    fi
    grep_url_pattern="https://[^\"[:space:]]*\\.${pkg_ext}"
    rel_url_pattern="/${PODKOP_FORK_REPO}/releases/download/[^\"[:space:]]*\\.${pkg_ext}"
    abs_url_pattern="https://github.com/${PODKOP_FORK_REPO}/releases/download/[^\"[:space:]]*\\.${pkg_ext}"

    : > "$DOWNLOAD_DIR/.release_urls"

    release_json="$(fetch_text "$REPO_API" 2>/dev/null || true)"
    if [ -n "$release_json" ]; then
        if echo "$release_json" | grep -q "API rate limit"; then
            api_rate_limited=1
        fi
        if echo "$release_json" | grep -q '"Not Found"'; then
            api_not_found=1
        fi
        echo "$release_json" | grep -o "$grep_url_pattern" | sed 's/[?#].*$//' | sort -u > "$DOWNLOAD_DIR/.release_urls" || true
    fi

    if [ ! -s "$DOWNLOAD_DIR/.release_urls" ]; then
        if [ "$api_rate_limited" -eq 1 ]; then
            warn "GitHub API rate limit reached. Falling back to release page parsing..."
        else
            warn "GitHub API unavailable. Falling back to release page parsing..."
        fi

        release_html="$(fetch_text "$REPO_RELEASE_PAGE" 2>/dev/null || true)"
        if [ -n "$release_html" ]; then
            {
                echo "$release_html" | grep -Eo "$abs_url_pattern" || true
                echo "$release_html" | grep -Eo "$rel_url_pattern" | sed 's#^#https://github.com#' || true
            } | sed 's/&amp;/\&/g' | sed 's/[?#].*$//' | sort -u > "$DOWNLOAD_DIR/.release_urls"
        fi
    fi

    if [ ! -s "$DOWNLOAD_DIR/.release_urls" ]; then
        if [ "$api_not_found" -eq 1 ]; then
            err "Requested release was not found: ${PODKOP_RELEASE_TAG:-latest}"
        else
            warn "Failed to fetch release metadata from GitHub API and release page."
            warn "Will install podkop packages from OpenWrt feeds."
            USE_FEED_INSTALL=1
            return 0
        fi
        exit 1
    fi

    while read -r url; do
        filename="$(basename "$url")"
        filepath="$DOWNLOAD_DIR/$filename"
        attempt=0

        while [ "$attempt" -lt "$COUNT" ]; do
            msg "Downloading $filename (attempt $((attempt+1))/$COUNT)..."
            if fetch_file "$url" "$filepath" && [ -s "$filepath" ]; then
                msg "$filename downloaded"
                break
            fi
            rm -f "$filepath"
            attempt=$((attempt+1))
        done

        if [ "$attempt" -eq "$COUNT" ]; then
            warn "Failed to download $filename"
        fi
    done < "$DOWNLOAD_DIR/.release_urls"

    if ! find "$DOWNLOAD_DIR" -maxdepth 1 -type f -name '*podkop*' | grep -q .; then
        warn "No podkop packages downloaded from release assets."
        warn "Will install podkop packages from OpenWrt feeds."
        USE_FEED_INSTALL=1
        return 0
    fi
}

install_packages_from_feeds() {
    msg "Installing podkop from OpenWrt feeds..."
    pkg_remove podkop || true
    pkg_remove luci-app-podkop || true
    pkg_install_name podkop
    pkg_install_name luci-app-podkop
    pkg_remove luci-i18n-podkop-ru || true
    pkg_install_name luci-i18n-podkop-ru || true
}

install_packages() {
    if [ "$USE_FEED_INSTALL" -eq 1 ]; then
        install_packages_from_feeds
        return
    fi

    for pkg in podkop luci-app-podkop; do
        file=""
        for f in "$DOWNLOAD_DIR"/"$pkg"*; do
            [ -f "$f" ] || continue
            file="$f"
            break
        done
        [ -n "$file" ] || continue
        msg "Installing $(basename "$file")..."
        # Make sure old package is replaced with the custom one.
        pkg_remove "$pkg" || true
        pkg_install "$file"
        sleep 2
    done

    ru_file=""
    for f in "$DOWNLOAD_DIR"/luci-i18n-podkop-ru*; do
        [ -f "$f" ] || continue
        ru_file="$f"
        break
    done
    if [ -n "$ru_file" ]; then
        msg "Installing Russian translation..."
        pkg_remove luci-i18n-podkop-ru || true
        pkg_install "$ru_file" || true
    fi
}

refresh_luci_cache() {
    msg "Refreshing LuCI cache..."
    rm -f /tmp/luci-indexcache* || true
    rm -rf /tmp/luci-modulecache || true
    rm -rf /tmp/luci-* || true

    if command -v luci-reload >/dev/null 2>&1; then
        luci-reload || true
    fi

    /etc/init.d/rpcd restart || true
    /etc/init.d/uhttpd restart || true
}

apply_subscribe_ui_patch() {
    local view_dir section_js settings_js subscribe_js cgi_dir cgi_file import_cgi_file
    view_dir="/www/luci-static/resources/view/podkop"
    section_js="$view_dir/section.js"
    settings_js="$view_dir/settings.js"
    subscribe_js="$view_dir/subscribe.js"
    cgi_dir="/www/cgi-bin"
    cgi_file="$cgi_dir/podkop-subscribe"
    import_cgi_file="$cgi_dir/podkop-import-subscription"

    mkdir -p "$view_dir"
    mkdir -p "$cgi_dir"

    msg "Applying Subscribe UI patch..."
    if fetch_file "$PODKOP_SUBSCRIBE_JS_URL" "$subscribe_js"; then
        chmod 0644 "$subscribe_js" || true
    else
        warn "Failed to download subscribe.js"
    fi

    if fetch_file "$PODKOP_SECTION_JS_URL" "$section_js"; then
        chmod 0644 "$section_js" || true
    else
        warn "Failed to download patched section.js"
    fi

    if fetch_file "$PODKOP_SETTINGS_JS_URL" "$settings_js"; then
        chmod 0644 "$settings_js" || true
    else
        warn "Failed to download patched settings.js"
    fi

    if fetch_file "$PODKOP_SUBSCRIBE_CGI_URL" "$cgi_file"; then
        chmod 0755 "$cgi_file" || true
    else
        warn "Failed to download podkop-subscribe CGI endpoint"
    fi

    if fetch_file "$PODKOP_IMPORT_CGI_URL" "$import_cgi_file"; then
        chmod 0755 "$import_cgi_file" || true
    else
        warn "Failed to download podkop-import-subscription CGI endpoint"
    fi
}

reset_old_config_if_needed() {
    if [ -f /etc/config/podkop ] && [ ! -f /etc/config/podkop-fork-backup ]; then
        cp /etc/config/podkop /etc/config/podkop-fork-backup || true
    fi

    # Optional hard reset to your fork defaults:
    # wget -O /etc/config/podkop "$PODKOP_CONFIG_URL"
    # Keep commented by default to avoid overwriting user config silently.
}

apply_custom_lists() {
    if ! command -v uci >/dev/null 2>&1; then
        warn "uci not found, skip list auto-setup."
        return
    fi

    if ! uci -q show podkop.main >/dev/null 2>&1; then
        warn "podkop.main section not found, skip list auto-setup."
        return
    fi

    if [ -n "$PODKOP_KEY" ]; then
        # Key mode: replace current auto-routed lists with key payload.
        uci -q delete podkop.main.remote_domain_lists || true
        uci -q delete podkop.main.remote_subnet_lists || true
        uci -q delete podkop.main.community_lists || true
        apply_selected_lists_from_key
        uci commit podkop
        msg "List setup step completed."
    else
        msg "No key provided: keep existing lists as-is."
    fi
}

apply_core_runtime_patch() {
    msg "Applying fork runtime patch..."

    if fetch_file "$PODKOP_BIN_URL" "/usr/bin/podkop"; then
        chmod 0755 /usr/bin/podkop || true
    else
        warn "Failed to download /usr/bin/podkop override"
    fi

    if fetch_file "$PODKOP_INIT_URL" "/etc/init.d/podkop"; then
        chmod 0755 /etc/init.d/podkop || true
    else
        warn "Failed to download /etc/init.d/podkop override"
    fi

    if fetch_file "$PODKOP_CONSTANTS_URL" "/usr/lib/constants.sh"; then
        chmod 0644 /usr/lib/constants.sh || true
    else
        warn "Failed to download /usr/lib/constants.sh override"
    fi

    if fetch_file "$PODKOP_SINGBOX_MGR_URL" "/usr/lib/sing_box_config_manager.sh"; then
        chmod 0644 /usr/lib/sing_box_config_manager.sh || true
    else
        warn "Failed to download /usr/lib/sing_box_config_manager.sh override"
    fi
}

trim_string() {
    echo "$1" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

is_supported_proxy_url() {
    case "$1" in
        vless://*|ss://*|trojan://*|hy2://*|hysteria2://*|socks4://*|socks4a://*|socks5://*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

configure_proxy_quickstart() {
    local applied_url

    if ! command -v uci >/dev/null 2>&1; then
        warn "uci not found, skip proxy quick setup."
        return
    fi

    if ! uci -q show podkop.main >/dev/null 2>&1; then
        warn "podkop.main section not found, skip proxy quick setup."
        return
    fi

    PODKOP_VLESS_URL="$(trim_string "$PODKOP_VLESS_URL")"

    if [ -n "$PODKOP_VLESS_URL" ] && ! is_supported_proxy_url "$PODKOP_VLESS_URL"; then
        err "Unsupported proxy URL format: $PODKOP_VLESS_URL"
        err "Supported schemes: vless:// ss:// trojan:// hy2:// hysteria2:// socks4:// socks4a:// socks5://"
        exit 1
    fi

    applied_url="$PODKOP_VLESS_URL"

    # Force stable proxy setup defaults.
    uci -q delete podkop.settings.traffic_capture_mode || true
    uci -q set podkop.settings.startup_wait_wan='1'
    uci -q set podkop.settings.startup_wait_timeout='60'
    uci -q set podkop.settings.enable_section_failover='0'
    uci -q delete podkop.settings.failover_secondary_section || true

    uci -q set podkop.main.connection_type='proxy'
    uci -q set podkop.main.proxy_config_type='url'
    if [ -n "$applied_url" ]; then
        uci -q set podkop.main.proxy_string="$applied_url"
    fi
    uci -q delete podkop.main.selector_proxy_links || true
    uci -q delete podkop.main.urltest_proxy_links || true
    uci -q delete podkop.main.outbound_json || true

    uci commit podkop
    if [ -n "$applied_url" ]; then
        msg "Applied quick proxy config with your proxy URL."
    else
        msg "Applied quick proxy config (URL can be added later in LuCI)."
    fi

    /etc/init.d/podkop restart >/dev/null 2>&1 || /etc/init.d/podkop start >/dev/null 2>&1 || true
}

setup_mobile_import() {
    local import_key lan_ip seed

    if ! command -v uci >/dev/null 2>&1; then
        warn "uci not found, skip mobile import setup."
        return
    fi

    import_key="$(uci -q get podkop.settings.mobile_import_key 2>/dev/null || true)"
    if [ -z "$import_key" ]; then
        seed="$(cat /etc/machine-id 2>/dev/null || true)"
        [ -z "$seed" ] && seed="$(cat /tmp/sysinfo/board_name 2>/dev/null || true)"
        [ -z "$seed" ] && seed="$(cat /sys/class/net/br-lan/address 2>/dev/null || true)"
        [ -z "$seed" ] && seed="$(date +%s)"

        if command -v md5sum >/dev/null 2>&1; then
            import_key="$(echo "${seed}-$(date +%s)" | md5sum | awk '{print $1}')"
        else
            import_key="$(echo "${seed}$(date +%s)" | tr -cd '[:alnum:]' | cut -c1-32)"
        fi

        uci -q set podkop.settings.mobile_import_key="$import_key"
        uci commit podkop
    fi

    lan_ip="$(uci -q get network.lan.ipaddr 2>/dev/null || true)"
    [ -z "$lan_ip" ] && lan_ip="192.168.1.1"

    masked_key="$(echo "$import_key" | sed -E 's/^(.{4}).*(.{4})$/\1********\2/')"
    msg "Mobile import key (masked): $masked_key"
    msg "To get full key locally on this router: uci get podkop.settings.mobile_import_key"
    msg "Button URL template:"
    msg "http://${lan_ip}/cgi-bin/podkop-import-subscription?key=<YOUR_ROUTER_KEY>&section=main&mode=urltest&url=<URL_ENCODED_SUBSCRIPTION>"
    msg "Alternative with base64url subscription URL:"
    msg "http://${lan_ip}/cgi-bin/podkop-import-subscription?key=<YOUR_ROUTER_KEY>&section=main&mode=urltest&url_b64=<BASE64URL_SUBSCRIPTION>"
}

cleanup() {
    rm -rf "$DOWNLOAD_DIR" 2>/dev/null || true
}

print_finish() {
    msg "Installation complete."
    msg "Fork repo: ${PODKOP_FORK_REPO}"
    msg "Lists base: ${LISTS_BASE_URL}"
    msg "Thanks to the original Podkop author and project: https://github.com/itdoginfo/podkop"
    msg "Спасибо создателю Podkop: https://github.com/itdoginfo/podkop"
}

main() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --key)
                shift
                PODKOP_KEY="${1:-}"
                ;;
            --release)
                shift
                PODKOP_RELEASE_TAG="${1:-}"
                ;;
            --vless-url)
                shift
                PODKOP_VLESS_URL="${1:-}"
                ;;
        esac
        shift || true
    done

    if [ -n "$PODKOP_RELEASE_TAG" ]; then
        REPO_API="https://api.github.com/repos/${PODKOP_FORK_REPO}/releases/tags/${PODKOP_RELEASE_TAG}"
        REPO_RELEASE_PAGE="https://github.com/${PODKOP_FORK_REPO}/releases/tag/${PODKOP_RELEASE_TAG}"
        msg "Using pinned release: ${PODKOP_RELEASE_TAG}"
    else
        REPO_API="https://api.github.com/repos/${PODKOP_FORK_REPO}/releases/latest"
        REPO_RELEASE_PAGE="https://github.com/${PODKOP_FORK_REPO}/releases/latest"
    fi
    trap cleanup EXIT INT TERM

    check_system
    sing_box
    prepare_ntp
    pkg_list_update || { err "Package list update failed"; exit 1; }
    download_release_packages
    install_packages
    apply_core_runtime_patch
    apply_subscribe_ui_patch
    refresh_luci_cache
    reset_old_config_if_needed
    apply_custom_lists
    configure_proxy_quickstart
    setup_mobile_import
    print_finish
}

main "$@"
