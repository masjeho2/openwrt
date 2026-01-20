#!/bin/sh

# ==============================================================================
# USER CONFIGURATION
# ==============================================================================
# Wifi & Security
WLAN_SSID="OpenWrt"
WLAN_PASS="12345678"
ROOT_PASS="123456"
LAN_IP="192.168.2.1"

# System Settings
HOSTNAME="Mas-Jeho"
TIMEZONE="WIB-7"
ZONENAME="Asia/Jakarta"

# Hardware Specific Paths (JANGAN UBAH JIKA TIDAK YAKIN)
DEV_WAN2="/sys/devices/platform/soc/ffe09000.usb/ff500000.usb/xhci-hcd.3.auto/usb1/1-1/1-1.2"

# Log setup
exec >/tmp/setup.log 2>&1

# ==============================================================================
# 1. SYSTEM & SECURITY SETUP
# ==============================================================================
setup_security() {
    # Set Root Password
    if [ -n "$ROOT_PASS" ]; then
        (echo "$ROOT_PASS"; sleep 1; echo "$ROOT_PASS") | passwd > /dev/null
    fi

    # Set Hostname & Timezone
    uci set system.@system[0].hostname="$HOSTNAME"
    uci set system.@system[0].timezone="$TIMEZONE"
    uci set system.@system[0].zonename="$ZONENAME"
    uci commit system

    # Fix TTYD login (Auto login root)
    sed -i "s|option command '/bin/login'|option command '/bin/login -f root'|g" /etc/config/ttyd
    /etc/init.d/ttyd restart
}

# ==============================================================================
# 2. NETWORK & WIFI SETUP
# ==============================================================================
setup_network() {
    # Configure LAN IP
    if [ -n "$LAN_IP" ]; then
        uci set network.lan.ipaddr="$LAN_IP"
        uci commit network
    fi

    # Configure WiFi
    if [ -n "$WLAN_SSID" ] && [ -n "$WLAN_PASS" ]; then
        # Radio 0 (2.4GHz)
        uci set wireless.@wifi-device[0].disabled='0'
        uci set wireless.@wifi-iface[0].encryption='psk2'
        uci set wireless.@wifi-iface[0].ssid="$WLAN_SSID"
        uci set wireless.@wifi-iface[0].key="$WLAN_PASS"

        # Radio 1 (5GHz) - Check existence first
        if grep -q 'radio1' /etc/config/wireless; then
            uci set wireless.@wifi-device[1].disabled='0'
            uci set wireless.@wifi-iface[1].encryption='psk2'
            uci set wireless.@wifi-iface[1].ssid="$WLAN_SSID 5G"
            uci set wireless.@wifi-iface[1].key="$WLAN_PASS"
        fi
        uci commit wireless
    fi

    # Configure Interfaces (WAN1, WAN2, WAN3)
    # WAN 1 (USB1 / ETH1)
    uci set network.wan1=interface
    uci set network.wan1.proto='dhcp'
    uci set network.wan1.device='usb1'
    uci set network.wan1.metric='10'
    uci set network.wan1.dns_metric='1'

    # WAN 2 (Modem Manager)
    uci set network.wan2=interface
    uci set network.wan2.proto='modemmanager'
    uci set network.wan2.device="$DEV_WAN2"
    uci set network.wan2.apn='internet'
    uci set network.wan2.auth='none'
    uci set network.wan2.iptype='ipv4'
    uci set network.wan2.metric='30'
    uci set network.wan2.dns_metric='1'

    # WAN 3 (USB0)
    uci set network.wan3=interface
    uci set network.wan3.proto='dhcp'
    uci set network.wan3.device='usb0'
    uci set network.wan3.metric='20'
    uci set network.wan3.dns_metric='1'
    
    uci commit network
}

# ==============================================================================
# 3. FIREWALL & TTL FIX
# ==============================================================================
setup_firewall() {
    # Add WANs to Firewall Zone
    uci add_list firewall.@zone[1].network='wan1'
    uci add_list firewall.@zone[1].network='wan2'
    uci add_list firewall.@zone[1].network='wan3'
    uci commit firewall

    # Fix TTL 65 (Using Here Document for cleaner code)
    cat << 'EOF' > /etc/firewall.user
WAN3="usb0"
WAN2="wwan0"
WAN1="eth1"
LAN="br-lan"

# POSTROUTING Rules
iptables -t mangle -I POSTROUTING -o $WAN3 -j TTL --ttl-set 65
iptables -t mangle -I POSTROUTING -o $WAN2 -j TTL --ttl-set 65
iptables -t mangle -I POSTROUTING -o $WAN1 -j TTL --ttl-set 65
iptables -t mangle -I POSTROUTING -o $LAN -j TTL --ttl-set 65

# PREROUTING Rules
iptables -t mangle -I PREROUTING -i $WAN3 -j TTL --ttl-set 65
iptables -t mangle -I PREROUTING -i $WAN2 -j TTL --ttl-set 65
iptables -t mangle -I PREROUTING -i $WAN1 -j TTL --ttl-set 65
iptables -t mangle -I PREROUTING -i $LAN -j TTL --ttl-set 65
EOF

    # Sysctl defaults
    echo 'net.ipv4.ip_default_ttl=65' >> /etc/sysctl.conf
    echo 'net.ipv6.ip_default_ttl=65' >> /etc/sysctl.conf
}

# ==============================================================================
# 4. PHP & LUCI FIXES
# ==============================================================================
setup_php() {
    local php_ini="/etc/php.ini"
    
    # Increase upload limits
    sed -i "s|post_max_size = 8M|post_max_size = 2048M|g" "$php_ini"
    sed -i "s|upload_max_filesize = 2M|upload_max_filesize = 2048M|g" "$php_ini"

    # Fix permissions
    rm -f /tmp/luci-indexcache
    rm -f /tmp/luci-modulecache/*
    chmod -R 755 /usr/lib/lua/luci/controller/*
    chmod -R 755 /usr/lib/lua/luci/view/*
    chmod -R 755 /www/*
    [ -d /www/tinyfm ] && chmod -R 755 /www/tinyfm/*
    [ ! -d /www/tinyfm/rootfs ] && ln -s / /www/tinyfm/rootfs

    # Auto-fix uhttpd for PHP-CGI
    if ! grep -q ".php=/usr/bin/php-cgi" /etc/config/uhttpd; then
        logger "helmilog: Patching uhttpd for php-cgi..."
        uci set uhttpd.main.ubus_prefix='/ubus'
        uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
        uci set uhttpd.main.index_page='cgi-bin/luci'
        uci add_list uhttpd.main.index_page='index.html'
        uci add_list uhttpd.main.index_page='index.php'
        uci commit uhttpd
        /etc/init.d/uhttpd restart
    fi

    # Symlink PHP8
    [ -d /usr/lib/php8 ] && [ ! -d /usr/lib/php ] && ln -sf /usr/lib/php8 /usr/lib/php
}

setup_ui() {
    # Hide Header Name (Fixing variable error from original script)
    local headerpath="/usr/lib/lua/luci/view/admin_status/index.htm"
    if [ -f "$headerpath" ]; then
        sed -i "9d" "$headerpath"
        sed -i "9i " "$headerpath"
    fi

    # Set Argon Theme
    uci set argon.@global[0].mode='light'
    uci set luci.main.mediaurlbase='/luci-static/alpha'
    uci commit luci
}

# ==============================================================================
# 5. TOOLS, MODEM & CRON
# ==============================================================================
setup_tools() {
    # Fix Permissions
    [ -f /usr/bin/luci-app-atinout ] && chmod +x /usr/bin/luci-app-atinout
    [ -f /sbin/set_at_port.sh ] && chmod +x /sbin/set_at_port.sh
    [ -f /bin/neofetch ] && chmod +x /bin/neofetch
    [ -f /usr/bin/cloudflared ] && chmod +x /usr/bin/cloudflared

    # Clearcache script
    if [ -f /sbin/clearcache.sh ]; then
        chmod +x /sbin/clearcache.sh
        echo "0 * * * * /sbin/clearcache.sh" >> /etc/crontabs/root
    fi

    # Fix ModemManager
    rm -f /usr/lib/ModemManager/connection.d/10-report-down

    # Remove USB Modeswitch for specific modems
    sed -i -e '/12d1:15c1/,+5d' /etc/usb-mode.json # Huawei
    sed -i -e '/413c:81d7/,+5d' /etc/usb-mode.json # Dell/DW5821e

    # Fix Vnstat
    mkdir -p /etc/vnstat/
    sed -i 's|DatabaseDir "/var/lib/vnstat"|DatabaseDir "/etc/vnstat"|g' /etc/vnstat.conf

    # Custom Repo
    sed -i 's/option check_signature/# option check_signature/g' /etc/opkg.conf
    
    # AT Commands User List
    cat << 'EOF' > /etc/config/atcommands.user
Ati;AT
Debug Info;AT^DEBUG?
Temperature;AT+TEMP
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
Lock Band 1, 3 & 8;AT^SLBAND=LTE,2,1,3,8,40
Reset Selected Band;AT^SLBAND
Enable CA;AT^CA_ENABLE=0
Disable CA;AT^CA_ENABLE=1
Lock LTE Only;AT^SLMODE=1,30
LTE CAT Info;AT^GETLTECAT?
Restart Modem;AT^RESET
Scann Cell;AT+VZWRSRP?
EOF

    # Cron for Modem Rakitan
    cat << 'EOF' >> /etc/crontabs/root
# auto renew ip lease for modem rakitan
#30 3 * * * echo AT+CFUN=4 | atinout - /dev/ttyUSB1 - && ifdown mm && sleep 3 && ifup mm
#30 3 * * * ifdown fibocom && sleep 3 && ifup fibocom
EOF
    /etc/init.d/cron restart
}

# ==============================================================================
# EXECUTION
# ==============================================================================
setup_security
setup_network
setup_firewall
setup_php
setup_ui
setup_tools

exit 0
