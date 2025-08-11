#!/system/bin/sh

MODDIR=${0%/*}

# load variables
. $MODDIR/lib.sh

# wait_until_login from yc9559/uperf at uperf/magisk/script/libcommon.sh
wait_until_login() {
    # in case of /data encryption is disabled
    while [ "$(getprop sys.boot_completed)" != "1" ]; do
        sleep 1
    done

    # we doesn't have the permission to rw "/sdcard" before the user unlocks the screen
    local test_file="/sdcard/Android/.PERMISSION_TEST"
    true >"$test_file"
    while [ ! -f "$test_file" ]; do
        true >"$test_file"
        sleep 1
    done
    rm "$test_file"
}

# ----------------------------------------------
#             clean before start
# ----------------------------------------------

rm -rf   $ZTROOT/run
mkdir -p $ZTROOT/run

# ----------------------------------------------
#             start zerotier
# ----------------------------------------------

__start

# ----------------------------------------------
#             CLI before login
# ----------------------------------------------

touch $PIPE_CLI
inotifyd $MODDIR/handle.sh $PIPE_CLI:w &>/dev/null &  # toybox inotifyd bug: needs an extra character after colon

# ----------------------------------------------
#             APP after login
# ----------------------------------------------

wait_until_login


ZT_IFACE=$(ip link | awk -F': ' '/\bzt[0-9a-f]+\b/ {print $2; exit}')  # 也可根据设备具体接口写死
HOT_IFACE=$(ip link | awk -F': ' '/swlan|ap0|softap/ {print $2; exit}')
ZT_SCRIPT=$MODDIR/hotspot_iprule.sh

# 判断是否启用热点（检测接口是否有 IP）
HOT_IP=$(ip -4 addr show "$HOT_IFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)

if [ -n "$HOT_IP" ]; then
  echo "[ZT-NAT] Hotspot detected ($HOT_IFACE: $HOT_IP), applying rules..." >> $ZTROOT/run/daemon.log
  "$ZT_SCRIPT" add
else
  echo "[ZT-NAT] Hotspot not active, skipping rule insertion." >> $ZTROOT/run/daemon.log
fi



if [[ -d "$APPROOT" ]]; then
  rm -rf $APPROOT/run
  mkdir -p $APPROOT/run

  cp $ZTROOT/home/authtoken.secret $APPROOT/run/authtoken
  touch $PIPE_APP
  chmod 666 $APPROOT/run/authtoken $PIPE_APP
  inotifyd $MODDIR/handle.sh $PIPE_APP:w &>/dev/null &
fi
