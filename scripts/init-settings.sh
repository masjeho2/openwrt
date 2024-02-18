#!/bin/sh

## fix upload php
php_path="/etc/php.ini"
phpfix () {
    sed -i "s|post_max_size = 8M|post_max_size = 2048M|g" ${php_path}
    sed -i "s|upload_max_filesize = 2M|upload_max_filesize = 2048M|g" ${php_path}
}

## fix downlad index.php
phpindexfix () {
	rm -f /tmp/luci-indexcache
	rm -f /tmp/luci-modulecache/*
	chmod -R 755 /usr/lib/lua/luci/controller/*
	chmod -R 755 /usr/lib/lua/luci/view/*
	chmod -R 755 /www/*
	chmod -R 755 /www/tinyfm/*
	chmod -R 755 /www/tinyfm/assets/*
	[ ! -d /www/tinyfm/rootfs ] && ln -s / /www/tinyfm/rootfs
	# Autofix download index.php, index.html
	if ! grep -q ".php=/usr/bin/php-cgi" /etc/config/uhttpd; then
		echo -e "  helmilog : system not using php-cgi, patching php config ..."
		logger "  helmilog : system not using php-cgi, patching php config..."
		uci set uhttpd.main.ubus_prefix='/ubus'
		uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
		uci set uhttpd.main.index_page='cgi-bin/luci'
		uci add_list uhttpd.main.index_page='index.html'
		uci add_list uhttpd.main.index_page='index.php'
		uci commit uhttpd
		echo -e "  helmilog : patching system with php configuration done ..."
		echo -e "  helmilog : restarting some apps ..."
		logger "  helmilog : patching system with php configuration done..."
		logger "  helmilog : restarting some apps..."
		/etc/init.d/uhttpd restart
	fi
	[ -d /usr/lib/php8 ] && [ ! -d /usr/lib/php ] && ln -sf /usr/lib/php8 /usr/lib/php
}

## patch ui openclash
clientui_path="/usr/lib/lua/luci/model/cbi/openclash/client.lua"
patchuiopenclash () {
    sed -i "101s|^|-- |" ${clientui_path}
    sed -i "131s|^|-- |" ${clientui_path}
    sed -i "132s|^|-- |" ${clientui_path}
    sed -i "133s|^|-- |" ${clientui_path}
    sed -i "134s|^|-- |" ${clientui_path}
    sed -i "135s|^|-- |" ${clientui_path}
    sed -i "137s|^|-- |" ${clientui_path}
    sed -i "138s|^|-- |" ${clientui_path}
    sed -i "139s|^|-- |" ${clientui_path}
    sed -i "140s|^|-- |" ${clientui_path}
}

## hide header name
headerpath="/usr/lib/lua/luci/view/admin_status/index.htm"
hideheader () {
    sed -i "9d" ${headerpath}
    sed -i "9i <!-- <h2 name=content><%:Status%></h2> -->" ${path}
}

## set interface
setiface () {
    # iface
    uci set network.wan1=interface
    uci set network.wan1.proto='dhcp'
    uci set network.wan1.device='eth1'
    uci set network.wan2=interface
    uci set network.wan2.proto='dhcp'
    uci set network.wan2.device='wwan0'
    uci set network.wan3=interface
    uci set network.wan3.proto='dhcp'
    uci set network.wan3.device='usb0'
    # Enable WiFi
    uci set wireless.radio0.disabled='0'
    uci set wireless.radio1.disabled='0'
    uci commit network

    #fix ttl 65   
    echo 'WAN3="usb0"' >> /etc/firewall.user
    echo 'WAN2="wwan0"' >> /etc/firewall.user
    echo 'WAN1="eth1"' >> /etc/firewall.user
    echo 'LAN="br-lan"' >> /etc/firewall.user
    echo 'iptables -t mangle -I POSTROUTING -o $WAN3 -j TTL --ttl-set 65' >> /etc/firewall.user
    echo 'iptables -t mangle -I POSTROUTING -o $WAN2 -j TTL --ttl-set 65' >> /etc/firewall.user
    echo 'iptables -t mangle -I POSTROUTING -o $WAN1 -j TTL --ttl-set 65' >> /etc/firewall.user
    echo 'iptables -t mangle -I POSTROUTING -o $LAN -j TTL --ttl-set 65' >> /etc/firewall.user
    echo 'iptables -t mangle -I PREROUTING -i $WAN3 -j TTL --ttl-set 65' >> /etc/firewall.user
    echo 'iptables -t mangle -I PREROUTING -i $WAN2 -j TTL --ttl-set 65' >> /etc/firewall.user
    echo 'iptables -t mangle -I PREROUTING -i $WAN1 -j TTL --ttl-set 65' >> /etc/firewall.user
    echo 'iptables -t mangle -I PREROUTING -i $LAN -j TTL --ttl-set 65' >> /etc/firewall.user
    echo 'net.ipv4.ip_default_ttl=65' >> /etc/sysctl.conf
    echo 'net.ipv6.ip_default_ttl=65' >> /etc/sysctl.conf

    # firewall
    uci add_list firewall.@zone[1].network='wan1'
    uci add_list firewall.@zone[1].network='wan2'
    uci add_list firewall.@zone[1].network='wan3'
    uci commit firewall
}

## other config
otherconfig () {
    uci set system.@system[0].timezone='WIB-7'
    uci set system.@system[0].zonename='Asia/Jakarta'

    # Set argon as default theme
    uci set argon.@global[0].mode='light'
    uci set luci.main.mediaurlbase='/luci-static/alpha'

    # Set Hostname to VincherWrt
    uci set system.@system[0].hostname='Mas-Jeho'
    uci commit system

    # Fix luci-app-atinout-mod
    chmod +x /usr/bin/luci-app-atinout
    chmod +x /sbin/set_at_port.sh

    # Fix neofetch Permissions
    chmod +x /bin/neofetch

    # Add auto clearcache crontabs
    chmod +x /sbin/clearcache.sh
    echo "0 * * * * /sbin/clearcache.sh" >> /etc/crontabs/root
    
    # Fix cloudflared permissions
    chmod +x /usr/bin/cloudflared
    # remove huawei me909s usb-modeswitch
    sed -i -e '/12d1:15c1/,+5d' /etc/usb-mode.json

    # remove dw5821e usb-modeswitch
    sed -i -e '/413c:81d7/,+5d' /etc/usb-mode.json

    # fix vnstat 
    mkdir -p /etc/vnstat/
    sed -i 's|DatabaseDir "/var/lib/vnstat"|DatabaseDir "/etc/vnstat"|g' /etc/vnstat.conf

    # fix ttyd
    sed -i "s|option command '/bin/login'|option command '/bin/login -f root'|g" /etc/config/ttyd
    /etc/init.d/ttyd restart

    # add cron job for modem rakitan
    echo '#auto renew ip lease for modem rakitan' >> /etc/crontabs/root
    echo '#30 3 * * * echo AT+CFUN=4 | atinout - /dev/ttyUSB1 - && ifdown mm && sleep 3 && ifup mm' >> /etc/crontabs/root
    echo '#30 3 * * * ifdown fibocom && sleep 3 && ifup fibocom' >> /etc/crontabs/root
    /etc/init.d/cron restart
    # costume repo
    sed -i 's/option check_signature/# option check_signature/g' /etc/opkg.conf
    echo "#src/gz custom_generic https://raw.githubusercontent.com/lrdrdn/my-opkg-repo/21.02/generic" >> /etc/opkg/customfeeds.conf
    echo "#src/gz custom_arch https://raw.githubusercontent.com/lrdrdn/my-opkg-repo/21.02/$(cat /etc/os-release | grep OPENWRT_ARCH | awk -F '"' '{print $2}')" >> /etc/opkg/customfeeds.conf


}

phpfix
phpindexfix
patchuiopenclash
hideheader
setiface
otherconfig

exit 0
