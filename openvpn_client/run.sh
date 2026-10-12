#!/usr/bin/env bash
set -Eeuo pipefail
OPTIONS=/data/options.json
option() { jq -r --arg key "$1" '.[$key] // empty' "$OPTIONS"; }
fail() { echo "错误：$*" >&2; exit 1; }
OVPNFILE="$(option ovpnfile)"
[[ -n "$OVPNFILE" && "$OVPNFILE" != /* && "/$OVPNFILE/" != *"/../"* ]] || fail "ovpnfile 必须是 /share 下的相对路径"
CONFIG="/share/$OVPNFILE"
echo "OpenVPN 配置文件：$CONFIG"
while [[ ! -f "$CONFIG" ]]; do
    echo "等待配置文件，请放到 $CONFIG"
    sleep 5
done
CONFIG="$(realpath "$CONFIG")"
[[ "$CONFIG" == /share/* ]] || fail "配置文件必须位于 /share 内"
[[ -c /dev/net/tun ]] || fail "未找到 /dev/net/tun"
CONFIG_DIR="$(dirname "$CONFIG")"
RUNTIME_CONFIG=""
VPN_PID=""
RULE_ADDED=false
cleanup() {
    trap - EXIT TERM INT
    if [[ -n "$VPN_PID" ]]; then
        kill -TERM "$VPN_PID" 2>/dev/null || true
        wait "$VPN_PID" 2>/dev/null || true
    fi
    if [[ "$RULE_ADDED" == true ]]; then
        ip -4 rule del priority "$PRIORITY" from "$LAN_IP/32" table "$TABLE" 2>/dev/null || true
        ip -4 route flush table "$TABLE" 2>/dev/null || true
    fi
    if [[ -n "$RUNTIME_CONFIG" ]]; then
        rm -f -- "$RUNTIME_CONFIG"
    fi
}
trap cleanup EXIT
trap 'exit 0' TERM INT
if grep -Eq '^route-up .*ip route replace table 177 .*ip rule add priority 17700 ' "$CONFIG"; then
    RUNTIME_CONFIG="$(mktemp /data/openvpn-effective.XXXXXX)"
    chmod 600 "$RUNTIME_CONFIG"
    awk '!(/^route-up / && index($0,"ip route replace table 177 ") && index($0,"ip rule add priority 17700 "))' "$CONFIG" > "$RUNTIME_CONFIG"
    CONFIG="$RUNTIME_CONFIG"
    echo "已忽略旧版临时修复的 route-up 命令，使用应用自身的回程保护；原始配置文件未修改。"
fi
# Change directory before parsing relative certificate and password paths.
ARGS=(--cd "$CONFIG_DIR" --config "$CONFIG")
if [[ "$(jq -r '.protect_lan' "$OPTIONS")" != false ]]; then
    IFACE="$(option lan_interface)"
    DEFAULTS="$(ip -j -4 route show table main default)"
    if [[ -z "$IFACE" ]]; then
        IFACE="$(jq -r '[.[] | select(.dev != null) | select(.dev | test("^(tun|tap|wg|docker|hassio|veth)") | not)] | sort_by(.metric // 0) | .[0].dev // empty' <<< "$DEFAULTS")"
    fi
    [[ -n "$IFACE" ]] || fail "无法自动识别局域网网卡，请填写 lan_interface"
    GATEWAY="$(option lan_gateway)"
    if [[ -z "$GATEWAY" ]]; then
        GATEWAY="$(jq -r --arg dev "$IFACE" '[.[] | select(.dev == $dev and .gateway != null)] | sort_by(.metric // 0) | .[0].gateway // empty' <<< "$DEFAULTS")"
    fi
    LAN_IP="$(ip -j -4 address show dev "$IFACE" | jq -r '[.[].addr_info[] | select(.family == "inet" and .scope == "global")][0].local // empty')"
    SUBNET="$(option lan_subnet)"
    if [[ -z "$SUBNET" ]]; then
        SUBNET="$(ip -j -4 route show table main dev "$IFACE" scope link | jq -r --arg ip "$LAN_IP" '[.[] | select(.prefsrc == $ip and .dst != null)][0].dst // empty')"
    fi
    [[ "$LAN_IP" =~ ^[0-9.]+$ && "$GATEWAY" =~ ^[0-9.]+$ && "$SUBNET" =~ ^[0-9.]+/[0-9]+$ ]] || fail "无法识别 LAN 地址、网关或网段，请填写 LAN 选项"
    TABLE="$(option routing_table)"; TABLE="${TABLE:-17800}"
    PRIORITY="$(option routing_priority)"; PRIORITY="${PRIORITY:-17800}"
    [[ "$TABLE" =~ ^[0-9]+$ && "$PRIORITY" =~ ^[0-9]+$ ]] || fail "路由表和优先级必须为整数"
    (( TABLE >= 1000 && TABLE <= 32000 && PRIORITY >= 1000 && PRIORITY <= 32000 )) || fail "路由表和优先级必须在 1000–32000 范围内"
    [[ -z "$(ip -4 route show table "$TABLE" 2>/dev/null || true)" ]] || fail "路由表 $TABLE 已被使用，请更换 routing_table"
    ! ip -j -4 rule show | jq -e --argjson p "$PRIORITY" '.[] | select(.priority == $p)' >/dev/null || fail "优先级 $PRIORITY 已被使用，请更换 routing_priority"
    RULE_ADDED=true
    ip -4 route add table "$TABLE" "$SUBNET" dev "$IFACE" src "$LAN_IP"
    ip -4 route add table "$TABLE" default via "$GATEWAY" dev "$IFACE"
    ip -4 rule add priority "$PRIORITY" from "$LAN_IP/32" table "$TABLE"
    NETWORK="${SUBNET%/*}"
    ARGS+=(--pull-filter ignore "route $NETWORK ")
    echo "局域网回程保护：$LAN_IP → $GATEWAY（$IFACE），保护网段 $SUBNET"
fi
echo "启动 OpenVPN；证书及密码文件不会写入启动日志。"
openvpn "${ARGS[@]}" &
VPN_PID=$!
wait "$VPN_PID"
