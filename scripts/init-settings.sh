#!/bin/sh

# Beware! This script will be in /rom/etc/uci-defaults/ as part of the image.
# Uncomment lines to apply:
#
wlan_name="OpenWrt"
wlan_password="12345678"
#
root_password="123456"
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

## fix upload php
php_path="/etc/php.ini"
phpfix () {
    sed -i "s|post_max_size = 8M|post_max_size = 2048M|g" ${php_path}
    sed -i "s|upload_max_filesize = 2M|upload_max_filesize = 2048M|g" ${php_path}
}

## fix download index.php
phpindexfix () {
	rm -f /tmp/luci-indexcache
	rm -f /tmp/luci-modulecache/*
	chmod -R 755 /usr/lib/lua/luci/controller/*
	chmod -R 755 /usr/lib/lua/luci/view/*
	chmod -R 755 /www/*
	chmod -R 755 /www/tinyfm/*
	chmod -R 755 /www/tinyfm/assets/*
	[ ! -d /www/tinyfm/rootfs ] && ln -s / /www/tinyfm/rootfs
	if ! grep -q ".php=/usr/bin/php-cgi" /etc/config/uhttpd; then
		uci set uhttpd.main.ubus_prefix='/ubus'
		uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
		uci set uhttpd.main.index_page='cgi-bin/luci'
		uci add_list uhttpd.main.index_page='index.html'
		uci add_list uhttpd.main.index_page='index.php'
		uci commit uhttpd
		/etc/init.d/uhttpd restart
	fi
	[ -d /usr/lib/php8 ] && [ ! -d /usr/lib/php ] && ln -sf /usr/lib/php8 /usr/lib/php
}

## patch ui openclash
clientui_path="/usr/lib/lua/luci/model/cbi/openclash/client.lua"
patchuiopenclash () {
 #   sed -i "101s|^|-- |" ${clientui_path}
 #   sed -i "131s|^|-- |" ${clientui_path}
 #   sed -i "132s|^|-- |" ${clientui_path}
 #   sed -i "133s|^|-- |" ${clientui_path}
  #  sed -i "134s|^|-- |" ${clientui_path}
  #  sed -i "135s|^|-- |" ${clientui_path}
  #  sed -i "137s|^|-- |" ${clientui_path}
  #  sed -i "138s|^|-- |" ${clientui_path}
  #  sed -i "139s|^|-- |" ${clientui_path}
  #  sed -i "140s|^|-- |" ${clientui_path}
}

## hide header name
headerpath="/usr/lib/lua/luci/view/admin_status/index.htm"
hideheader () {
    sed -i "9d" ${headerpath}
    sed -i "9i <!-- <h2 name=content><%:Status%></h2> -->" ${headerpath}
}

## set interface
setiface () {
    uci set network.wan1=interface
    uci set network.wan1.proto='dhcp'
    uci set network.wan1.device='eth1'
    uci set network.wan2=interface
    uci set network.wan2.proto='dhcp'
    uci set network.wan2.device='wwan0'
    uci set network.wan3=interface
    uci set network.wan3.proto='dhcp'
    uci set network.wan3.device='usb0'
    uci set wireless.radio0.disabled='0'
    uci set wireless.radio1.disabled='0'
    uci commit network

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

    uci add_list firewall.@zone[1].network='wan1'
    uci add_list firewall.@zone[1].network='wan2'
    uci add_list firewall.@zone[1].network='wan3'
    uci commit firewall
}

## other config
otherconfig () {
    uci set system.@system[0].timezone='WIB-7'
    uci set system.@system[0].zonename='Asia/Jakarta'
    uci set argon.@global[0].mode='light'
    uci set luci.main.mediaurlbase='/luci-static/alpha'
    uci set system.@system[0].hostname='Mas-Jeho'
    uci commit system

    chmod +x /usr/bin/luci-app-atinout
    chmod +x /sbin/set_at_port.sh
    rm -f /usr/lib/ModemManager/connection.d/10-report-down
    chmod +x /bin/neofetch
    chmod +x /sbin/clearcache.sh
    echo "0 * * * * /sbin/clearcache.sh" >> /etc/crontabs/root
    chmod +x /usr/bin/cloudflared
    sed -i -e '/12d1:15c1/,+5d' /etc/usb-mode.json
    sed -i -e '/413c:81d7/,+5d' /etc/usb-mode.json
    mkdir -p /etc/vnstat/
    sed -i 's|DatabaseDir "/var/lib/vnstat"|DatabaseDir "/etc/vnstat"|g' /etc/vnstat.conf
    sed -i "s|option command '/bin/login'|option command '/bin/login -f root'|g" /etc/config/ttyd
    /etc/init.d/ttyd restart
    echo '#auto renew ip lease for modem rakitan' >> /etc/crontabs/root
    echo '#30 3 * * * echo AT+CFUN=4 | atinout - /dev/ttyUSB1 - && ifdown mm && sleep 3 && ifup mm' >> /etc/crontabs/root
    echo '#30 3 * * * ifdown fibocom && sleep 3 && ifup fibocom' >> /etc/crontabs/root
    /etc/init.d/cron restart
    sed -i 's/option check_signature/# option check_signature/g' /etc/opkg.conf
    echo "#src/gz custom_generic https://raw.githubusercontent.com/lrdrdn/my-opkg-repo/main/generic" >> /etc/opkg/customfeeds.conf
    echo "#src/gz custom_arch https://raw.githubusercontent.com/lrdrdn/my-opkg-repo/main/$(cat /etc/os-release | grep OPENWRT_ARCH | awk -F '"' '{print $2}')" >> /etc/opkg/customfeeds.conf

    rm  -r /etc/modem/atcommands.user
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
EOF
    fi
}

phpfix
phpindexfix
patchuiopenclash
hideheader
setiface
otherconfig
