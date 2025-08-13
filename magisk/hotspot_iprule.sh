#!/system/bin/sh

ACTION="$1"  # 参数：add 或 del

ZT_IFACE=$(ip link | awk -F': ' '/ zt[[:alnum:]]+/ {print $2; exit}')
HOT_IFACE=$(ip link | awk -F': ' '/(^| )(swlan[[:alnum:]_]*|softap[[:alnum:]_]*|ap[[:alnum:]_]*)\:/ {print $2; exit}' | cut -d'@' -f1)
HOT_CIDR=$(ip -4 addr show dev "$HOT_IFACE" | awk '/inet /{print $2; exit}')

#!/system/bin/sh

ACTION="$1"  # 参数：add 或 del

ZT_IFACE=$(ip link | awk -F': ' '/ zt[[:alnum:]]+/ {print $2; exit}')
HOT_IFACE=$(ip link | awk -F': ' '/(^| )(swlan[[:alnum:]_]*|softap[[:alnum:]_]*|ap[[:alnum:]_]*)\:/ {print $2; exit}' | cut -d'@' -f1)
HOT_CIDR=$(ip -4 addr show dev "$HOT_IFACE" | awk '/inet /{print $2; exit}')

add_chains_and_jumps() {
  # 创建自定义链（如果不存在）
  iptables -t nat -N ZT_NAT 2>/dev/null
  iptables -N ZT_FWD 2>/dev/null

  # 确保主链首条规则跳转到自定义链
  iptables -t nat -C POSTROUTING -j ZT_NAT 2>/dev/null || \
    iptables -t nat -I POSTROUTING 1 -j ZT_NAT

  iptables -C FORWARD -j ZT_FWD 2>/dev/null || \
    iptables -I FORWARD 1 -j ZT_FWD
}

case "$ACTION" in
  add)
    add_chains_and_jumps
    # 添加 NAT 规则到 ZT_NAT 链
    iptables -t nat -A ZT_NAT -s "$HOT_CIDR" -o "$ZT_IFACE" -j MASQUERADE
    # 添加转发规则到 ZT_FWD 链
    iptables -A ZT_FWD -i "$HOT_IFACE" -o "$ZT_IFACE" -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
    iptables -A ZT_FWD -i "$ZT_IFACE" -o "$HOT_IFACE" -m state --state ESTABLISHED,RELATED -j ACCEPT
    echo "[ZT-NAT] Custom chains + jumps applied." >> "$ZTROOT/run/daemon.log"
    ;;
  del)
    # 删除规则（只清空自定义链，保留跳转结构）
    iptables -t nat -F ZT_NAT 2>/dev/null
    iptables -F ZT_FWD 2>/dev/null
    echo "[ZT-NAT] Custom chains flushed." >> "$ZTROOT/run/daemon.log"
    ;;
  *)
    echo "Usage: $0 [add|del]"
    exit 1
    ;;
esac
