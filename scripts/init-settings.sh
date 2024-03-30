#!/bin/sh
#radenku.com

# Set Timezone to Asia/Jakarta
uci -q set system.@system[0].timezone='WIB-7'
uci -q set system.@system[0].zonename='Asia/Jakarta'
uci -q commit system

# Remove watchcat default config
uci -q delete watchcat.@watchcat[0]
uci -q commit watchcat
/etc/init.d/watchcat reload

# Set theme
#uci -q set luci.main.mediaurlbase='/luci-static/bootstrap'
#! grep -q "material" /etc/config/luci ||uci -q set luci.main.mediaurlbase='/luci-static/material'
! grep -q "alpha" /etc/config/luci || uci -q set luci.main.mediaurlbase='/luci-static/alpha'
uci -q commit luci

if [ -f "/etc/config/argon" ]; then
	uci -q set argon.@global[0].mode='light'
	uci -q set argon.@global[0].primary='#40A379' #light green
	uci -q set argon.@global[0].dark_primary='#40A379' #light green
	#uci -q set argon.@global[0].primary='#5688C7' #light blue
	#uci -q set argon.@global[0].dark_primary='#5688C7' #light blue
	chmod 0664 /www/luci-static/argon/background/*
	ls /www/luci-static/argon/background/ | grep -q 'jpg' && uci -q set argon.@global[0].online_wallpaper='none'
	uci -q commit argon
fi 

# remove huawei me909s usb-modeswitch
sed -i -e '/12d1:15c1/,+5d' /etc/usb-mode.json

# remove dw5821e usb-modeswitch
sed -i -e '/413c:81d7/,+5d' /etc/usb-mode.json
# Remove modemmanager tty
if [ -f "/etc/hotplug.d/tty/25-modemmanager-tty" ]; then
    rm /etc/hotplug.d/tty/25-modemmanager-tty
	/etc/init.d/modemmanager stop
    /etc/init.d/modemmanager start
fi

/etc/init.d/modemmanager restart
/etc/init.d/modemmanager reload

# Fix Temp Modeminfo
if [ -f "/etc/config/modeminfo" ]; then
	sed -i "s|AT+TEMP?; AT^TEMP?|AT^TEMP?; AT+TEMP?|" /usr/share/modeminfo/scripts/DELL.at
fi

# Set sms_tool_js
if [ -f "/etc/config/sms_tool_js" ]; then
    uci -q set sms_tool_js.@sms_tool_js[0]=sms_tool_js
    uci -q set sms_tool_js.@sms_tool_js[0].storage='SM'
    uci -q set sms_tool_js.@sms_tool_js[0].prefix='0'
    uci -q set sms_tool_js.@sms_tool_js[0].readport='/dev/ttyUSB1'
    uci -q set sms_tool_js.@sms_tool_js[0].sendport='/dev/ttyUSB1'
	uci -q set sms_tool_js.@sms_tool_js[0].ussdport='/dev/ttyUSB1'
	uci -q set sms_tool_js.@sms_tool_js[0].atport='/dev/ttyUSB1'
	uci -q commit sms_tool_js
fi

# Set Atcommands
if [ -f "/etc/config/atcommands" ]; then
	uci -q set atcommands.@atcommands[0]=atcommands
	uci -q set atcommands.@atcommands[0].set_port='/dev/ttyUSB1'
	uci -q commit atcommands

    cat << 'EOF' > /etc/modem/atcommands.user
AT;AT
ATI;ATI
Debug Info;AT^DEBUG?
Temperature;AT^TEMP?
Voltase;AT+VOLT
CA Info;AT^CA_INFO?
Display Selected Band;AT^SLBAND?
Lock Band 1;AT^SLBAND=LTE,2,1
Lock Band 3;AT^SLBAND=LTE,2,3
Lock Band 8;AT^SLBAND=LTE,2,8
Lock Band 40;AT^SLBAND=LTE,2,40
Lock Band 1 & 3;AT^SLBAND=LTE,2,1,3
Lock Band 3 & 8;AT^SLBAND=LTE,2,3,8
Lock Band 3 & 40;AT^SLBAND=LTE,2,3,40
Lock Band 1, 3 & 8;AT^SLBAND=LTE,2,1,3,8
Reset Selected Band;AT^SLBAND
Lock LTE Only;AT^SLMODE=1,30
LTE CAT Info;AT^GETLTECAT?
Restart Modem;AT^RESET
EOF
fi

# Set 3ginfo-lite
if [ -f "/etc/config/3ginfo" ]; then
	[ ! -f "/usr/share/3ginfo-lite/modem/2cb70007" ] && cp /usr/share/3ginfo-lite/modem/8087095a /usr/share/3ginfo-lite/modem/2cb70007
	uci -q set 3ginfo.@3ginfo[0].network='@mm'
	uci -q set 3ginfo.@3ginfo[0].device='/dev/ttyUSB1'
	uci -q commit 3ginfo
fi

# Adjust Modem
DEB="/sys/kernel/debug/usb/devices"

# lt4220
if grep -qE "1bc7 ProdID=1900|1bc7 ProdID=1901|03f0 ProdID=0a57|03f0 ProdID=0857" $DEB ; then 
	sed -i 's|2,||g' /etc/modem/atcommands.user
	
# l850
elif grep -qE "2cb7 ProdID=0007|8087 ProdID=095a" $DEB ; then
	sed -i 's|/dev/ttyUSB1|/dev/ttyACM2|g' /etc/config/sms_tool_js
	sed -i 's|/dev/ttyUSB1|/dev/ttyACM2|g' /etc/config/atcommands
	sed -i 's|/dev/ttyUSB1|/dev/ttyACM2|g' /etc/config/3ginfo
	cat << 'EOF' > /etc/modem/atcommands.user
AT;AT
ATI;ATI
AT+CIMI;AT+CIMI
AT+COPS;AT+COPS?
AT+CEREG;AT+CEREG?
CA Info;AT+XLEC?
Selected Band;AT+XACT?
Restart Modem;AT+CFUN=1,1
EOF
	sms_tool -d /dev/ttyACM2 at "at+gmm" > /tmp/detectmodem
	if grep 'L850' /tmp/detectmodem ; then
	sed -i '8i Mode MBIM;AT+GTUSBMODE=7' /etc/modem/atcommands.user
	sed -i '9i Mode NCM;AT+GTUSBMODE=0' /etc/modem/atcommands.user
	fi
	
# rm520
elif grep -q "2c7c ProdID=0801" $DEB ; then
	sed -i 's|/dev/ttyUSB1|/dev/ttyUSB3|g' /etc/config/sms_tool_js
	sed -i 's|/dev/ttyUSB1|/dev/ttyUSB3|g' /etc/config/atcommands
	sed -i 's|/dev/ttyUSB1|/dev/ttyUSB3|g' /etc/config/3ginfo
	cat << 'EOF' > /etc/modem/atcommands.user
AT;AT
ATI;ATI
QNWINFO;AT+QNWINFO
Servingcell info;AT+QENG="servingcell"
Neighbourcell info;AT+QENG="neighbourcell"
QCAINFO;AT+QCAINFO
Temperature;AT+QTEMP
Mode QMI/PPP/Default;AT+QCFG="usbnet",0
Mode ECM;AT+QCFG="usbnet",1
Mode MBIM;AT+QCFG="usbnet",2
Restart Modem;AT+CFUN=1,1
EOF

# em7430
elif grep -qE "1199 ProdID=9071|1199 ProdID=9091" $DEB ; then
	sed -i 's|/dev/ttyUSB1|/dev/ttyUSB2|g' /etc/config/sms_tool_js
	sed -i 's|/dev/ttyUSB1|/dev/ttyUSB2|g' /etc/config/atcommands
	sed -i 's|/dev/ttyUSB1|/dev/ttyUSB2|g' /etc/config/3ginfo	
	cat << 'EOF' > /etc/modem/atcommands.user
AT;AT
ATI;ATI
AT!GSTATUS?;AT!GSTATUS?
Restart Modem;AT+CFUN=1,1
EOF
fi

# TTL 65
cat << 'EOF' > /etc/nftables.d/11-ttl-65.nft
chain mangle_postrouting_ttl65 {
      type filter hook postrouting priority 300; policy accept;
 	counter ip ttl set 65 
}

chain mangle_prerouting_ttl65 {
      type filter hook prerouting priority 300; policy accept;
 	counter ip ttl set 65 
}
EOF

# Set minicom port
if [ -f "/usr/sbin/minicom" ]; then
	cat << 'EOF' > /etc/minirc.0
# Machine-generated file - use "minicom -s" to change parameters.
pu port             /dev/ttyUSB0
EOF
	cat << 'EOF' > /etc/minirc.1
# Machine-generated file - use "minicom -s" to change parameters.
pu port             /dev/ttyUSB1
EOF
	cat << 'EOF' > /etc/minirc.2
# Machine-generated file - use "minicom -s" to change parameters.
pu port             /dev/ttyUSB2
EOF
	cat << 'EOF' > /etc/minirc.3
# Machine-generated file - use "minicom -s" to change parameters.
pu port             /dev/ttyUSB3
EOF
	cat << 'EOF' > /etc/minirc.a0
# Machine-generated file - use "minicom -s" to change parameters.
pu port             /dev/ttyACM0
EOF
	cat << 'EOF' > /etc/minirc.a1
# Machine-generated file - use "minicom -s" to change parameters.
pu port             /dev/ttyACM1
EOF
	cat << 'EOF' > /etc/minirc.a2
# Machine-generated file - use "minicom -s" to change parameters.
pu port             /dev/ttyACM2
EOF
fi

# Set Netdata
if [ -f "/etc/config/netdata" ]; then
	uci -q set netdata.@netdata[0].enabled='1'
	uci -q commit nedata
fi

# Set Vnstat2
if [ -f "/etc/config/vnstat" ]; then
	uci -q set vnstat.@vnstat[0].interface='br-lan'
	uci -q add_list vnstat.@vnstat[0].interface='wwan0'
	uci -q commit vnstat
fi

# Fix Temp
if [ -f "/usr/libexec/rpcd/luci.temp-status" ]; then
	INCLUDE="/www/luci-static/resources/view/status/include"
	mv $INCLUDE/*temp.js $INCLUDE/11_temp.js
fi

# Move luci zerotier
if [ -f "/usr/lib/lua/luci/controller/zerotier.lua" ]; then
	sed -i '/entry({"admin", "vpn"}, firstchild(), "VPN", 45).dependent = false/d' /usr/lib/lua/luci/controller/zerotier.lua
	sed -i 's|"vpn"|"services"|g' /usr/lib/lua/luci/controller/zerotier.lua
fi

# Move tiny file manager
#if [ -f "/usr/share/luci/menu.d/luci-app-tinyfilemanager.json" ]; then
#	sed -i -e '/"admin\/nas": {/,+7d' /usr/share/luci/menu.d/luci-app-tinyfilemanager.json
#	sed -i 's|/nas/|/system/|g' /usr/share/luci/menu.d/luci-app-tinyfilemanager.json
#	uci -q add_list tinyfilemanager.@main[0].auth_users='root:$2y$10$TLasyNswvi/Y1v7tz8C8N.a6LKnM4gMDn70A9w76nWICzVoaS0B1G'
#	uci -q commit tinyfilemanager
#fi

# Fix Openclash
sed -i "s|option ifname 'utun'|option device 'utun'|" /etc/config/network

#STATUS="/usr/lib/lua/luci/view/openclash/status.htm"
DEV="/usr/lib/lua/luci/view/openclash/developer.htm"
MYIP="/usr/lib/lua/luci/view/openclash/myip.htm"
#IMG="/luci-static/resources/openclash/img"
CLIENT="/usr/lib/lua/luci/model/cbi/openclash/client.lua"
CONT="/usr/lib/lua/luci/controller/openclash.lua"

if ! grep -qE "\-\- s:section|\-\-s:section" $CLIENT
then
	sed -i "s#s:section#-- s:section#g" $CLIENT
	mv $MYIP $MYIP.bak
	cat << 'EOF' > $MYIP
<!DOCTYPE html>
<html>
</html>
EOF
fi

if grep -q 'githubusercontent.com' $DEV
then
	sed -i 's#translate("Credits")#translate("")#g' $CLIENT
	mv $DEV $DEV.bak
	cat << 'EOF' > $DEV
<style>
.developer_ {
  text-align: justify;
  text-align-last: justify;
}
</style>
<fieldset class="cbi-section">
    <div class="developer_">
        <table width="100%"><tr><td>
        <span id="_Dreamacro"><%:Dreamacro%></span>
        <span id="_vernesong"><%:Vernesong%></span>
        <span id="_frainzy1477"><%:Frainzy1477%></span>
        <span id="_SukkaW"><%:SukkaW%></span>
        <span id="_lhie1_dev"><%:lhie1_dev%></span>
        <span id="_ConnersHua_dev"><%:ConnersHua_dev%></span>
        <span id="_haishanh"><%:Haishanh%></span>
        <span id="_MaxMind"><%:MaxMind%></span>
        <span id="_FQrabbit"><%:FQrabbit%></span>
        <span id="_Alecthw"><%:Alecthw%></span>
        <span id="_Tindy_X"><%:Tindy_X%></span>
        <span id="_lmc999"><%:lmc999%></span>
        <span id="_dlercloud"><%:Dlercloud%></span>
        <span id="_immortalwrt"><%:Immortalwrt%></span>
        <span id="_MetaCubeX"><%:MetaCubeX%></span>
        </td></tr></table>
    </div>
</fieldset>
EOF
fi

if ! grep -q "Config Editor" $CONT && [ -f "/www/tinyfilemanager/index.php" ]; then
    sed -i '87 i\	entry({"admin", "services", "openclash", "editor"}, template("openclash/editor"),_("Config Editor"), 90).leaf = true' $CONT
    cat << EOF > /usr/lib/lua/luci/view/openclash/editor.htm
<%+header%>
<div class="cbi-map">
<iframe id="editor" style="width: 100%; min-height: 100vh; border: none; border-radius: 2px;"></iframe>
</div>
<script type="text/javascript">
document.getElementById("editor").src = "http://" + window.location.hostname + "/tinyfilemanager/index.php?p=etc/openclash";
</script>
<%+footer%>
EOF
elif grep -q "Config Editor" $CONT && [ ! -f "/www/tinyfilemanager/index.php" ]; then
	sed -i '/Config Editor/d' $CONT
fi
# fix modemmanager
rm -f /usr/lib/ModemManager/connection.d/10-report-down
# fix vnstat 
mkdir -p /etc/vnstat/
sed -i 's|DatabaseDir "/var/lib/vnstat"|DatabaseDir "/etc/vnstat"|g' /etc/vnstat.conf
# fix ttyd
sed -i "s|option command '/bin/login'|option command '/bin/login -f root'|g" /etc/config/ttyd
/etc/init.d/ttyd restart
#Add interface & firewall MM
uci -q set network.mm=interface
uci -q set network.mm.proto='modemmanager'
uci -q set network.mm.device="$(readlink -f /sys/class/usbmisc/cdc-wdm0/device | sed "s|/$(readlink -f /sys/class/usbmisc/cdc-wdm0/device/ | awk -F '/' '{print $(NF)}')||g")"
uci -q set network.mm.apn='internet'
uci -q set network.mm.auth='none'
uci -q set network.mm.iptype='ipv4'
uci -q set network.mm.signalrate='10'

if ! grep -q "eth1" /etc/config/network; then
	uci -q set network.wan1=interface
	uci -q set network.wan1.proto='dhcp'
	uci -q set network.wan1.device='eth1'
else
	uci -q set network.wan1=interface
	uci -q set network.wan1.proto='dhcp'
	uci -q set network.wan1.device='eth2'
fi

uci -q set network.wan2=interface
uci -q set network.wan2.proto='dhcp'
uci -q set network.wan2.device='usb0'

uci -q commit network

uci -q set firewall.@zone[1].network="$(uci -q get firewall.@zone[1].network) wan1 wan2 mm"
uci -q commit firewall

# Overview credit
DIS=$(grep "PRETTY_NAME" /etc/os-release | awk -F '"' '{print $2}')
sed -i "s/.*DISTRIB_DESCRIPTION.*/DISTRIB_DESCRIPTION='$DIS build by Radenku.com'/" /etc/openwrt_release
sed -i "s/\/ ':'')+(luciversion||'')/ ':'')/" /www/luci-static/resources/view/status/include/10_system.js

# My opkg repo
ARCH="$(grep "OPENWRT_ARCH" /etc/os-release | awk -F '"' '{print $2}')"
MYREPO="https://raw.githubusercontent.com/lrdrdn/my-opkg-repo/main"
MYKMOD="https://raw.githubusercontent.com/lrdrdn/kmod/main"
BOARD="$(grep "OPENWRT_BOARD" /etc/os-release | awk -F '"' '{print $2}')"
DIST="/etc/opkg/distfeeds.conf"
MODEL="$(cat /tmp/sysinfo/model | sed 's| |-|')"
OVER="$(cat /etc/openwrt_release |grep 'DISTRIB_RELEASE'| awk -F "'" '{print $2}')"
RDATE="$(awk -F '_' '{print $2}' /etc/codename)"
DATE="$(cat /etc/build-date)"

sed -i 's/.*option check_signature.*/# option check_signature/' /etc/opkg.conf
sed -i '/openwrt_custom/d' $DIST

# Custom Feeds
if ! grep -q "lrdrdn" /etc/opkg/customfeeds.conf; then
	echo "" >> /etc/opkg/customfeeds.conf
	echo "src/gz custom_generic $MYREPO/generic" >> /etc/opkg/customfeeds.conf
	echo "src/gz custom_arch $MYREPO/$ARCH" >> /etc/opkg/customfeeds.conf
	if grep -qE "B1300|Mi Router 4A|Arion" /tmp/sysinfo/model; then
	    echo "src/gz custom_minimal $MYREPO/minimal" >> /etc/opkg/customfeeds.conf
	fi
fi

# KMOD
if [ -f "/packages/Packages.gz" ]; then
	sed -i "s|.*openwrt_core.*|src/gz openwrt_core file:///packages|" $DIST
elif [ -f "/etc/codename" ]; then
	sed -i "s|.*openwrt_core.*|src/gz openwrt_core $MYKMOD/$BOARD/$MODEL-GoldenOrb-$RDATE|" $DIST
elif [ -f "/etc/build-date" ]; then
	sed -i "s|.*openwrt_core.*|src/gz openwrt_core $MYKMOD/$BOARD/$MODEL-$OVER-$DATE|" $DIST
fi

# LED Ruter
BOARD_NAME="$(cat /tmp/sysinfo/board_name)"
case $BOARD_NAME in
zbt,z8102ax)
	uci -q add system led
	uci -q set system.@led[0]=led
	uci -q set system.@led[0].name='modem1'
	uci -q set system.@led[0].sysfs='4g:status'
	uci -q set system.@led[0].trigger='netdev'
	uci -q set system.@led[0].dev='wwan0'
	uci -q set system.@led[0].mode='rx'
	uci -q commit system
	;;
esac

# Device armsr
if grep -q "armsr" /etc/os-release; then
#	kernel 5.4
#	KER="$(uname -r | awk -F '.' '{print $1$2}')"
#	if [ "$KER" = "54" ]; then
#	uci -q set network.mm.device='/sys/devices/platform/soc/soc:usb@c9000000/c9000000.dwc3/xhci-hcd.0.auto/usb1/1-2'
#	else
#	#kernel 5.10 5.15
#	uci -q set network.mm.device='/sys/devices/platform/soc/d0078080.usb/c9000000.usb/xhci-hcd.3.auto/usb1/1-2'
#	fi

	uci -q set network.wan3=interface
	uci -q set network.wan3.proto='dhcp'
	uci -q set network.wan3.device='wwan0'
	uci -q commit network

	uci -q set firewall.@zone[1].network="$(uci -q get firewall.@zone[1].network) wan3"
	uci -q commit firewall
	
	#vnstat
	if grep -q "/var/lib/vnstat" /etc/vnstat.conf; then
	sed -i "s|/var/lib/vnstat|/etc/vnstat|" /etc/vnstat.conf
	fi
	
	# USB Realtek RTL8188EU Wireless LAN Driver
	echo "8188eu" > /etc/modules.d/8188eu
	# Realtek RTL8189FS Wireless LAN Driver
	echo "8189fs" > /etc/modules.d/8189fs
	echo "8189es" > /etc/modules.d/8189es
	echo "8188gu" > /etc/modules.d/8188gu
	echo "8192cu" > /etc/modules.d/8192cu
	echo "8192du" > /etc/modules.d/8192du
	echo "8192ee" > /etc/modules.d/8192ee
	echo "8192eu" > /etc/modules.d/8192eu
	echo "8812au" > /etc/modules.d/8812au
	echo "8814au" > /etc/modules.d/8814au
	echo "8821cu" > /etc/modules.d/8821cu
	echo "rtl8821au" > /etc/modules.d/rtl8821au
	# Realtek RTL8188FU Wireless LAN Driver
	echo "rtl8188fu" > /etc/modules.d/rtl8188fu
	# Realtek RTL8822CS Wireless LAN Driver
	echo "88x2cs" > /etc/modules.d/88x2cs
	echo "88x2bs" > /etc/modules.d/88x2bs
	echo "88x2ce" > /etc/modules.d/88x2ce
	# USB Ralink Wireless LAN Driver
	echo "rt2500usb" > /etc/modules.d/rt2500-usb
	echo "rt2800usb" > /etc/modules.d/rt2800-usb
	echo "rt2x00usb" > /etc/modules.d/rt2x00-usb
	# USB Mediatek Wireless LAN Driver
	echo "mt7601u" > /etc/modules.d/mt7601u
	echo "mt7663u" > /etc/modules.d/mt7663u
	echo "mt76x0u" > /etc/modules.d/mt76x0u
	echo "mt76x2u" > /etc/modules.d/mt76x2u
	# A95X
	echo "ath10k_core" > /etc/modules.d/ath10k_core
	echo "ath10k_sdio" > /etc/modules.d/ath10k_sdio
	echo "ath10k_usb" > /etc/modules.d/ath10k_usb
	# tp-link ue300 v4
	echo "8152" > /etc/modules.d/8152
	echo "r8153" > /etc/modules.d/r8153
	echo "8153" > /etc/modules.d/8153
fi

# Fibocom Modem interface
if grep -q "8087 ProdID=095a" /sys/kernel/debug/usb/devices ; then
	uci -q delete network.mm
	uci -q delete network.wan3
	uci -q set network.wan1.device='wwan0'

	uci -q set network.xmm=interface
	uci -q set network.xmm.proto='xmm'
	uci -q set network.xmm.device='/dev/ttyACM0'
	uci -q set network.xmm.apn='internet'
	uci -q set network.xmm.auth='auto'
	uci -q set network.xmm.pdp='ip'
	uci -q add_list network.xmm.dns='8.8.8.8'
	uci -q add_list network.xmm.dns='8.8.4.4'
	uci -q commit network

	uci -q set firewall.@zone[1].network="$(uci -q get firewall.@zone[1].network) xmm"
	uci -q commit firewall

	if [ -f "/etc/config/3ginfo" ]; then
	uci -q set 3ginfo.@3ginfo[0].network='@xmm'
	uci -q commit 3ginfo
	fi
fi

######################

# Beware! This script will be in /rom/etc/uci-defaults/ as part of the image.
# Uncomment lines to apply:
#
wlan_name="OpenWrt"
wlan_password="12345678"
#
root_password="masjeho26"
lan_ip_address="192.168.2.1"
#
# pppoe_username=""
# pppoe_password=""

# log potential errors
exec >/tmp/setup.log 2>&1

if [ -n "$root_password" ]; then
  (echo "$root_password"; sleep 1; echo "$root_password") | passwd > /dev/null
fi

# Configure LAN
# More options: https://openwrt.org/docs/guide-user/base-system/basic-networking
if [ -n "$lan_ip_address" ]; then
  uci set network.lan.ipaddr="$lan_ip_address"
  uci commit network
fi

# Configure WLAN
# More options: https://openwrt.org/docs/guide-user/network/wifi/basic#wi-fi_interfaces
if [ -n "$wlan_name" -a -n "$wlan_password" -a ${#wlan_password} -ge 8 ]; then
  uci set wireless.@wifi-device[0].disabled='0'
  uci set wireless.@wifi-iface[0].encryption='psk2'
  uci set wireless.@wifi-iface[0].ssid="$wlan_name"
  uci set wireless.@wifi-iface[0].key="$wlan_password"
  if grep -q 'radio1' /etc/config/wireless; then
  uci set wireless.@wifi-device[1].disabled='0'
  uci set wireless.@wifi-iface[1].encryption='psk2'
  uci set wireless.@wifi-iface[1].ssid="$wlan_name 5G"
  uci set wireless.@wifi-iface[1].key="$wlan_password"
  fi
  uci commit wireless
fi

# Configure PPPoE
# More options: https://openwrt.org/docs/guide-user/network/wan/wan_interface_protocols#protocol_pppoe_ppp_over_ethernet
if [ -n "$pppoe_username" -a "$pppoe_password" ]; then
  uci set network.wan.proto=pppoe
  uci set network.wan.username="$pppoe_username"
  uci set network.wan.password="$pppoe_password"
  uci commit network
fi

echo "All done!"

exit 0
