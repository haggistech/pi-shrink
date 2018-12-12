#!/bin/bash

function cleanup() {
  if losetup $loopback &>/dev/null; then
	losetup -d "$loopback"
  fi
}

usage() { echo "Usage: $0 [-s] [-r] imagefile.img [newimagefile.img]"; exit -1; }

should_skip_autoexpand=false

while getopts ":s:r" opt; do
  case "${opt}" in
    s) should_skip_autoexpand=true ;;
	r) enable_ssh=true ;;
    *) usage ;;
  esac
done
shift $((OPTIND-1))

#Args
img="$1"

#Usage checks
if [[ -z "$img" ]]; then
  usage
fi
if [[ ! -f "$img" ]]; then
  echo "ERROR: $img is not a file..."
  exit -2
fi
if (( EUID != 0 )); then
  echo "ERROR: You need to be running as root."
  exit -3
fi

#Check that what we need is installed
for command in parted losetup tune2fs md5sum e2fsck resize2fs; do
  which $command 2>&1 >/dev/null
  if (( $? != 0 )); then
    echo "ERROR: $command is not installed."
    exit -4
  fi
done

#Copy to new file if requested
if [ -n "$2" ]; then
  echo "Copying $1 to $2..."
  cp --reflink=auto --sparse=always "$1" "$2"
  if (( $? != 0 )); then
    echo "ERROR: Could not copy file..."
    exit -5
  fi
  old_owner=$(stat -c %u:%g "$1")
  chown $old_owner "$2"
  img="$2"
fi

# cleanup at script exit
trap cleanup ERR EXIT

#Gather info
beforesize=$(ls -lh "$img" | cut -d ' ' -f 5)
parted_output=$(parted -ms "$img" unit B print | tail -n 1)
boot_parted_output=$(parted -ms "$img" unit B print | head -n 3 | tail -n 1)
partnum=$(echo "$parted_output" | cut -d ':' -f 1)
boot_partnum=$(echo "$boot_parted_output" | cut -d ':' -f 1)
partstart=$(echo "$parted_output" | cut -d ':' -f 2 | tr -d 'B')
boot_partstart=$(echo "$boot_parted_output" | cut -d ':' -f 2 | tr -d 'B')
loopback=$(losetup -f --show -o $partstart "$img")
boot_loopback=$(losetup -f --show -o $boot_partstart "$img")
tune2fs_output=$(tune2fs -l "$loopback")
currentsize=$(echo "$tune2fs_output" | grep '^Block count:' | tr -d ' ' | cut -d ':' -f 2)
blocksize=$(echo "$tune2fs_output" | grep '^Block size:' | tr -d ' ' | cut -d ':' -f 2)



#Make sure filesystem is ok
e2fsck -p -f "$loopback"
minsize=$(resize2fs -P "$loopback" | cut -d ':' -f 2 | tr -d ' ')
if [[ $currentsize -eq $minsize ]]; then
  echo "ERROR: Image already shrunk to smallest size"
  exit -6
fi

#Add some free space to the end of the filesystem
extra_space=$(($currentsize - $minsize))
for space in 5000 1000 100; do
  if [[ $extra_space -gt $space ]]; then
    minsize=$(($minsize + $space))
    break
  fi
done

#Shrink filesystem
resize2fs -p "$loopback" $minsize
if [[ $? != 0 ]]; then
  echo "ERROR: resize2fs failed..."
  mount "$loopback" "$mountdir"
  #mv "$mountdir/etc/rc.local.bak" "$mountdir/etc/rc.local"
  umount "$mountdir"
  losetup -d "$loopback"
  exit -7
fi
sleep 1

#Shrink partition
partnewsize=$(($minsize * $blocksize))
newpartend=$(($partstart + $partnewsize))
parted -s -a minimal "$img" rm $partnum >/dev/null
parted -s "$img" unit B mkpart primary $partstart $newpartend >/dev/null

#Truncate the file
endresult=$(parted -ms "$img" unit B print free | tail -1 | cut -d ':' -f 2 | tr -d 'B')
truncate -s $endresult "$img"
aftersize=$(ls -lh "$img" | cut -d ' ' -f 5)

#Check if we should make pi expand rootfs on next boot
# This will add a line to the cmdline.txt to use the init_resize.sh file built into raspbian
if [ "$should_skip_autoexpand" = false ]; then
  #Make pi expand rootfs on next boot
  mountdir=$(mktemp -d)
  mount -t vfat -o loop,offset=$boot_partstart "$img" "$mountdir"
  echo "$(cat $mountdir/cmdline.txt) init=/usr/lib/raspi-config/init_resize.sh" > "$mountdir/cmdline.txt"
  chmod 777 "$mountdir/cmdline.txt"
  echo "Added config to resize Root Partition on first boot"
  echo ""
  umount "$mountdir"
else
  echo "Skipping autoexpanding process..."
fi

# If the -r (remote) flag is set this will add the SSH file to enable SSH on first boot
if [ "$enable_ssh" = true ]; then
  mountdir=$(mktemp -d)
  mount -t vfat "$boot_loopback" "$mountdir" -o rw
  touch "$mountdir/ssh"
  echo "Enabled SSH on Boot"
  echo ""
  umount "$mountdir"
fi


echo "Shrunk $img"
echo ""
echo "Start Size: $beforesize"
echo "Final Size: $aftersize"
echo ""