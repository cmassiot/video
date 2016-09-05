#!/bin/bash

if [ ! -e ArchLinuxARM-armv7-latest.tar.gz ] ; then
  echo "Downloading ArchLinuxARM tar image..."
  wget http://archlinuxarm.org/os/ArchLinuxARM-armv7-latest.tar.gz
fi


if [ -z "$3" ] ; then
  echo "Usage: $0 SD_CARD_DEVICE HOSTNAME MAC_ADDR"
  exit
fi

DEV=$1
HN=$2
MC=$3

echo "About to repartition $DEV as a FOSBox, hostname $HN with MAC $MC. Make sure nothing is mounted already! Hit ctrl+c now to cancel, or hit return to continue."
read

echo "Zeroing beginning of card"
dd if=/dev/zero of=$DEV bs=1M count=8

echo "Partitioning..."
sfdisk $DEV < partitions.sfdisk
partprobe

echo "Formatting partitions..."
mkfs.vfat -n FBBoot ${DEV}1
mkfs.ext4 -L FBSettings ${DEV}2
mkfs.ext4 -L FBRoot ${DEV}3

echo "Writing bootloader..."
dd if=u-boot-sunxi-with-spl.bin of=$DEV bs=1024 seek=8

echo "Mounting partitions..."
mkdir -p ./boxmounts/FBBoot
mkdir -p ./boxmounts/FBSettings
mkdir -p ./boxmounts/FBRoot
mount ${DEV}1 ./boxmounts/FBBoot
mount ${DEV}2 ./boxmounts/FBSettings
mount ${DEV}3 ./boxmounts/FBRoot

echo "Copying boot files..."
#No ownership issues here - this is a vfat partition.
cp -vr ./FBBoot/* ./boxmounts/FBBoot/

echo "Copying root files..."
bsdtar -xpf ArchLinuxARM-armv7-latest.tar.gz -C ./boxmounts/FBRoot
cp -var --no-preserve=ownership ./FBRoot/* ./boxmounts/FBRoot/
chmod -R g-rwx ./FBRoot/root
chmod 700 ./boxmounts/FBRoot/root/.ssh
chmod 600 ./boxmounts/FBRoot/root/.ssh/authorized_keys

echo "Setting hostname to $HN"
echo -n $HN > ./boxmounts/FBSettings/hostname
echo "Setting MAC address to $MC"
echo -n $MC > ./boxmounts/FBSettings/mac

echo "Unmounting partitions"
umount ./boxmounts/*

sync
echo "Done. You can unplug the SD card now."

