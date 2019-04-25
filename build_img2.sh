#!/bin/bash
## This script is to automate the pack/repack operation of an ONIE installer image.
##
## USAGE:
##   ./build_img2 {round} {path to old img} [new img name] [path to tmp dir]
##
##   put build_img2.sh and onie-mk-demo2.sh to the sonic-buildimage/

## Include common functions
. functions.sh

## Enable debug output for script
set -x -e

## round 1 - extract the squashfs in the old image
## round 2 - install needed packages to the squashfs (or you can do this manually)
## round 3 - pack the new squashfs and other extracted data to a new image

ROUND=$1
OLD_IMG=$2
NEW_IMG_NAME=$3
OLD_TMPROOT=$4

# set to 1 to modify the version of new image
MOD_VER=1

[ -n "$ROUND" ] || {
    echo "Failed to get round info"
    exit 1
}

[ -n "$NEW_IMG_NAME" ] || {
    NEW_IMG_NAME="sonic-test.bin"
}

[ -n "$OLD_TMPROOT" ] || {
    OLD_TMPROOT="old_root"
}

PATH_OLD_IMG="$(pwd)/$OLD_IMG"

if [ ! -f $PATH_OLD_IMG ]; then
    echo "file: $PATH_OLD_IMG not exist !!!"
    exit 1
fi

## Read ONIE image related config file
. ./onie-image.conf

## Working directory to prepare the file system
FILESYSTEM_ROOT="squashfs-root"
PLATFORM_DIR=platform

if [ $ROUND == 1 ]; then
    sudo mkdir -p $OLD_TMPROOT

    pushd $OLD_TMPROOT

    sudo sed -e '1,/^exit_marker$/d' $PATH_OLD_IMG | tar xf - || exit 1
    sudo unzip installer/fs.zip -d rootfs
    sudo unsquashfs rootfs/fs.squashfs

    sudo cp -ax ./rootfs/boot squashfs-root/
    sudo cp -ax ./rootfs/platform squashfs-root/

    popd 
    exit 0
fi ## ROUND == 1

if [ $ROUND == 2 ]; then

    pushd $OLD_TMPROOT

    if [ $MOD_VER == 1 ]; then

        ## give a new version to the new image
        NEW_VER="HEAD.$(date -u +%Y%m%d-%H%M%S)"

        sed -i s/image_version=\".*\"/image_version=\"$NEW_VER\"/g installer/install.sh
        sed -ie "s/build_version: '.*'/build_version: '$NEW_VER'/g" $FILESYSTEM_ROOT/etc/sonic/sonic_version.yml
    fi

    trap_push 'sudo umount $FILESYSTEM_ROOT/proc || true'
    sudo LANG=C chroot $FILESYSTEM_ROOT mount proc /proc -t proc

    sudo LANG=C chroot $FILESYSTEM_ROOT pip install protobuf
    sudo LANG=C chroot $FILESYSTEM_ROOT pip install grpcio

    gnmisvr_py2_wheel_path="$OLDPWD/target/python-wheels/gnmi_svr-0.1-py2-none-any.whl"

    GNMISVR_PY2_WHEEL_NAME=$(basename $gnmisvr_py2_wheel_path)
    sudo cp $gnmisvr_py2_wheel_path $FILESYSTEM_ROOT/$GNMISVR_PY2_WHEEL_NAME
    sudo LANG=C chroot $FILESYSTEM_ROOT pip install $GNMISVR_PY2_WHEEL_NAME
    sudo rm -rf $FILESYSTEM_ROOT/$GNMISVR_PY2_WHEEL_NAME

    IMAGE_CONFIGS="$OLDPWD/files/image_config"
    sudo cp $IMAGE_CONFIGS/gnmi_svr/gnmi_svr.service $FILESYSTEM_ROOT/etc/systemd/system/
    sudo LANG=C chroot $FILESYSTEM_ROOT systemctl enable gnmi_svr.service

    ## Clean up apt
    sudo LANG=C chroot $FILESYSTEM_ROOT apt-get autoremove
    sudo LANG=C chroot $FILESYSTEM_ROOT apt-get autoclean
    sudo LANG=C chroot $FILESYSTEM_ROOT apt-get clean
    sudo LANG=C chroot $FILESYSTEM_ROOT bash -c 'rm -rf /usr/share/doc/* /usr/share/locale/* /var/lib/apt/lists/* /tmp/*'

    ## Clean up proxy
    [ -n "$http_proxy" ] && sudo rm -f $FILESYSTEM_ROOT/etc/apt/apt.conf.d/01proxy

    ## Umount all
    echo '[INFO] Umount all'
    ## Display all process details access /proc
    sudo LANG=C chroot $FILESYSTEM_ROOT fuser -vm /proc
    ## Kill the processes
    sudo LANG=C chroot $FILESYSTEM_ROOT fuser -km /proc || true
    ## Wait fuser fully kill the processes
    sleep 15
    sudo umount $FILESYSTEM_ROOT/proc || true

    popd
fi ## ROUND == 2

if [ $ROUND == 3 ]; then

    pushd $OLD_TMPROOT

    ## Compress most file system into squashfs file
    sudo rm -f $ONIE_INSTALLER_PAYLOAD $FILESYSTEM_SQUASHFS

    ## Output the file system total size for diag purpose
    ## Note: -x to skip directories on different file systems, such as /proc
    sudo du -hsx $FILESYSTEM_ROOT
    sudo mksquashfs $FILESYSTEM_ROOT $FILESYSTEM_SQUASHFS -e boot -e var/lib/docker -e $PLATFORM_DIR

    ## Compress together with /boot, /var/lib/docker and $PLATFORM_DIR as an installer payload zip file
    pushd $FILESYSTEM_ROOT && sudo zip $OLDPWD/$ONIE_INSTALLER_PAYLOAD -r boot/ $PLATFORM_DIR/; popd

    cp rootfs/$FILESYSTEM_DOCKERFS .

    ## old docker fs is under $OLD_TMPROOT/rootfs
    sudo zip -g $ONIE_INSTALLER_PAYLOAD $FILESYSTEM_SQUASHFS $FILESYSTEM_DOCKERFS

    cp $ONIE_INSTALLER_PAYLOAD installer/

    ## Generate new image file
     
    popd 

    ./onie-mk-demo2.sh $NEW_IMG_NAME $OLD_TMPROOT installer
fi ## ROUND == 3
