#!/system/bin/sh

ACTION="$1"  # 参数：add 或 del

ZT_IFACE=$(ip link | awk -F': ' '/\bzt[0-9a-f]+\b/ {print $2; exit}')
HOT_IFACE=$(ip link | awk -F': ' '/swlan|ap0|softap/ {print $2; exit}')
HOT_CIDR=$(ip -4 addr show dev "$HOT_IFACE" | awk '/inet /{print $2; exit}')

case "$ACTION" in
  add)
    iptables -t nat -A tetherctrl_nat_POSTROUTING -s $HOT_CIDR -o $ZT_IFACE -j MASQUERADE
    iptables -A tetherctrl_FORWARD -i $HOT_IFACE -o $ZT_IFACE -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
    iptables -A tetherctrl_FORWARD -i $ZT_IFACE -o $HOT_IFACE -m state --state ESTABLISHED,RELATED -j ACCEPT
    echo "[ZT-NAT] Rules applied." >> $ZTROOT/run/daemon.log
    ;;
  del)
    iptables -t nat -D tetherctrl_nat_POSTROUTING -s $HOT_CIDR -o $ZT_IFACE -j MASQUERADE
    iptables -D tetherctrl_FORWARD -i $HOT_IFACE -o $ZT_IFACE -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
    iptables -D tetherctrl_FORWARD -i $ZT_IFACE -o $HOT_IFACE -m state --state ESTABLISHED,RELATED -j ACCEPT
    echo "[ZT-NAT] Rules removed." >> $ZTROOT/run/daemon.log
    ;;
  *)
    echo "Usage: $0 [add|del]"
    exit 1
    ;;
esac
