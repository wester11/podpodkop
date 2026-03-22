#!/bin/sh
# shellcheck shell=dash

set -eu

# ==============================
# Podkop fork installer
# ==============================
# 1) Install podkop/luci-app-podkop from YOUR fork releases
# 2) Attach YOUR remote lists to podkop main section
# 3) Keep attribution to original podkop author

# ---- Ready-to-use values ----
# Podkop packages source (this repository releases)
PODKOP_FORK_REPO="wester11/ru-net-blacklist"
# Your lists repository:
LISTS_BASE_URL="https://raw.githubusercontent.com/wester11/ru-net-blacklist/main/lists"
SERVICES_BASE_URL="https://raw.githubusercontent.com/wester11/ru-net-blacklist/main/services"
# Podkop custom config source (from custom podkop fork sources in this repository):
PODKOP_CONFIG_URL="https://raw.githubusercontent.com/wester11/ru-net-blacklist/main/_podkop_upstream/podkop/files/etc/config/podkop"

REPO_API="https://api.github.com/repos/${PODKOP_FORK_REPO}/releases/latest"
DOWNLOAD_DIR="/tmp/podkop-fork"
COUNT=3
PODKOP_KEY="${PODKOP_KEY:-}"

PKG_IS_APK=0
command -v apk >/dev/null 2>&1 && PKG_IS_APK=1

msg() {
    printf "\033[32;1m%s\033[0m\n" "$1"
}

decode_key_payload() {
    encoded="$1"
    encoded="${encoded#PK1_}"
    encoded="$(echo "$encoded" | tr '_-' '/+')"
    rem=$(( ${#encoded} % 4 ))
    if [ "$rem" -eq 2 ]; then encoded="${encoded}=="; fi
    if [ "$rem" -eq 3 ]; then encoded="${encoded}="; fi

    decoded="$(echo "$encoded" | base64 -d 2>/dev/null || true)"
    if [ -z "$decoded" ] && command -v openssl >/dev/null 2>&1; then
        decoded="$(echo "$encoded" | openssl base64 -d -A 2>/dev/null || true)"
    fi
    echo "$decoded"
}

add_remote_pair() {
    domain_url="$1"
    subnet_url="$2"
    uci -q add_list podkop.main.remote_domain_lists="$domain_url"
    uci -q add_list podkop.main.remote_subnet_lists="$subnet_url"
}

apply_default_lists() {
    add_remote_pair "${LISTS_BASE_URL}/all_services/domains.srs" "${LISTS_BASE_URL}/all_services/subnets.srs"
    add_remote_pair "${LISTS_BASE_URL}/social_messaging/domains.srs" "${LISTS_BASE_URL}/social_messaging/subnets.srs"
    add_remote_pair "${LISTS_BASE_URL}/ai_all/domains.srs" "${LISTS_BASE_URL}/ai_all/subnets.srs"
}

apply_selected_lists_from_key() {
    payload="$(decode_key_payload "$PODKOP_KEY")"
    if [ -z "$payload" ]; then
        warn "Key decode failed, fallback to default lists."
        apply_default_lists
        return
    fi

    lists_csv="$(echo "$payload" | sed -n 's/.*L=\([^;]*\).*/\1/p')"
    services_csv="$(echo "$payload" | sed -n 's/.*S=\([^;]*\).*/\1/p')"
    selected_count=0

    OLD_IFS="$IFS"
    IFS=','
    for item in $lists_csv; do
        [ -n "$item" ] || continue
        if echo "$item" | grep -Eq '^[a-z0-9_]+$'; then
            add_remote_pair "${LISTS_BASE_URL}/${item}/domains.srs" "${LISTS_BASE_URL}/${item}/subnets.srs"
            selected_count=$((selected_count + 1))
        fi
    done
    for item in $services_csv; do
        [ -n "$item" ] || continue
        if echo "$item" | grep -Eq '^[a-z0-9_]+$'; then
            add_remote_pair "${SERVICES_BASE_URL}/${item}/domains.srs" "${SERVICES_BASE_URL}/${item}/subnets.srs"
            selected_count=$((selected_count + 1))
        fi
    done
    IFS="$OLD_IFS"

    if [ "$selected_count" -eq 0 ]; then
        warn "No valid items in key, fallback to default lists."
        apply_default_lists
    else
        msg "Applied selected items from key: $selected_count"
    fi
}

warn() {
    printf "\033[33;1m%s\033[0m\n" "$1"
}

err() {
    printf "\033[31;1m%s\033[0m\n" "$1"
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
                wget -O /etc/config/podkop "$PODKOP_CONFIG_URL"
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
    rm -rf "$DOWNLOAD_DIR"
    mkdir -p "$DOWNLOAD_DIR"

    if command -v curl >/dev/null 2>&1; then
        check_response="$(curl -s "$REPO_API")"
        if echo "$check_response" | grep -q "API rate limit"; then
            err "GitHub API rate limit reached. Retry in a few minutes."
            exit 1
        fi
    fi

    if [ "$PKG_IS_APK" -eq 1 ]; then
        grep_url_pattern='https://[^"[:space:]]*\.apk'
    else
        grep_url_pattern='https://[^"[:space:]]*\.ipk'
    fi

    wget -qO- "$REPO_API" | grep -o "$grep_url_pattern" | while read -r url; do
        filename="$(basename "$url")"
        filepath="$DOWNLOAD_DIR/$filename"
        attempt=0

        while [ "$attempt" -lt "$COUNT" ]; do
            msg "Downloading $filename (attempt $((attempt+1))/$COUNT)..."
            if wget -q -O "$filepath" "$url" && [ -s "$filepath" ]; then
                msg "$filename downloaded"
                break
            fi
            rm -f "$filepath"
            attempt=$((attempt+1))
        done

        if [ "$attempt" -eq "$COUNT" ]; then
            warn "Failed to download $filename"
        fi
    done

    if ! ls "$DOWNLOAD_DIR"/*podkop* >/dev/null 2>&1; then
        err "No podkop packages downloaded."
        exit 1
    fi
}

install_packages() {
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

    # Clean previous remote lists in main, then add yours.
    uci -q delete podkop.main.remote_domain_lists || true
    uci -q delete podkop.main.remote_subnet_lists || true

    if [ -n "$PODKOP_KEY" ]; then
        apply_selected_lists_from_key
    else
        apply_default_lists
    fi

    uci commit podkop
    msg "Custom remote lists applied to podkop.main"
}

cleanup() {
    find "$DOWNLOAD_DIR" -type f -name '*podkop*' -exec rm {} \; 2>/dev/null || true
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
        esac
        shift || true
    done

    check_system
    sing_box
    prepare_ntp
    pkg_list_update || { err "Package list update failed"; exit 1; }
    download_release_packages
    install_packages
    refresh_luci_cache
    reset_old_config_if_needed
    apply_custom_lists
    cleanup
    print_finish
}

main "$@"
