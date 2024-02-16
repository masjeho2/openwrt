#!/bin/sh
#==========================================================

# dir path
make_path="$(pwd)"
openwrt_dir="openwrt"
imagebuilder_path="${make_path}/${openwrt_dir}"

# targets
releases="$(cat "${make_path}/openwrt-version.txt")"
targets="armvirt"

# repository
imagebuilder_repo="https://downloads.openwrt.org/releases/${releases}/targets/${targets}/64/openwrt-imagebuilder-${releases}-${targets}-64.Linux-x86_64.tar.xz"

error_msg() {
    echo -e "${ERROR} ${1}"
    exit 1
}

download_imagebuilder () {
    wget ${imagebuilder_repo} || error_msg
    tar -xJf openwrt-imagebuilder-* && rm -f openwrt-imagebuilder-*.tar.xz
    mv -f openwrt-imagebuilder-* ${openwrt_dir}
#    mv -f custom-files/repositories.conf ${imagebuilder_path}
    sed -i "s|CONFIG_TARGET_ROOTFS_PARTSIZE=104|CONFIG_TARGET_ROOTFS_PARTSIZE=800|g" ${imagebuilder_path}/.config || error_msg
    sed -i "s/^option check_signature/#option check_signature/g" ${imagebuilder_path}/repository.conf || error_msg
    echo "src/gz custom_generic https://raw.githubusercontent.com/lrdrdn/my-opkg-repo/21.02/generic" >> ${imagebuilder_path}/repository.conf || error_msg
    echo "src/gz custom_arch https://raw.githubusercontent.com/lrdrdn/my-opkg-repo/21.02/aarch64_cortex-a53" >> ${imagebuilder_path}/repository.conf || error_msg


}

add_custom_file () {
## add walpeper
    mkdir -p ${imagebuilder_path}/files/www/luci-static/alpha/background/
    wget -P ${imagebuilder_path}/files/www/luci-static/alpha/background/ ${make_path}/files/www/luci-static/alpha/background/dashboard.png || error_msg
    wget -P ${imagebuilder_path}/files/www/luci-static/alpha/background/ ${make_path}/files/www/luci-static/alpha/background/login.png || error_msg
## add armvirt64 package
    wget -P ${imagebuilder_path}/packages/ -i ${make_path}/repository/target/armvirt64.txt || error_msg 
## add universal package
    wget -P ${imagebuilder_path}/packages/ -i ${make_path}/repository/target/universal.txt || error_msg
## load custom
    sh ${make_path}/load-custom/armvirt64.sh || error_msg
}

build_rootfs () {
    my_packages="$(cat "${make_path}/universal.txt")"
    cd ${imagebuilder_path}
    make image PROFILE="Default" PACKAGES="${my_packages}" FILES="files" || error_msg
## relocate rootfs
    mkdir -p ${make_path}/amlogic-openwrt/openwrt-armvirt
    mv ${imagebuilder_path}/bin/targets/${targets}/64/*-default-rootfs.tar.gz ${make_path}/amlogic-openwrt/openwrt-armvirt/
}

download_imagebuilder
add_custom_file
build_rootfs
exit 0