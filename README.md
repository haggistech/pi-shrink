# PiShrink #
PiShrink is a bash script that automatically shrink a pi image that will then resize to the max size of the SD card on boot. This will make putting the image back onto the SD card faster and the shrunk images will compress better.

This version has a flag to set the root partition to auto expand or not and also a flag to enable SSH on boot.

## Usage ##
`sudo pishrink.sh [-s] [-r] imagefile.img [newimagefile.img]`

If the `-s` option is given the script will skip the autoexpanding part of the process this uses the init_resize.sh which comes as part of Raspbian.  If you specify the `newimagefile.img` parameter, the script will make a copy of `imagefile.img` and work off that. You will need enough space to make a full copy of the image to use that option.

If the `-r` option is set a file called `ssh` will be added to the boot partition to enable SSH on boot

## Prerequisites ##
If you are trying to shrink a [NOOBS](https://github.com/raspberrypi/noobs) image it will likely fail. This is due to [NOOBS paritioning](https://github.com/raspberrypi/noobs/wiki/NOOBS-partitioning-explained) being significantly different than Raspian's. Hopefully PiShrink will be able to support NOOBS in the near future.

If using Ubuntu, you will likely see an error about `e2fsck` being out of date and `metadata_csum`. The simplest fix for this is to use Ubuntu 16.10 and up, as it will save you a lot of hassle in the long run.

## Installation ##
```bash
wget https://raw.githubusercontent.com/haggistech/PiShrink/master/pishrink.sh
chmod +x pishrink.sh
sudo mv pishrink.sh /usr/local/bin
```

## Example ##
```bash
[user@localhost PiShrink]$ sudo pishrink.sh pi.img
rootfs: 39691/467280 files (0.1% non-contiguous), 306696/1928192 blocks
resize2fs 1.43.4 (31-Jan-2017)
resize2fs 1.43.4 (31-Jan-2017)
Resizing the filesystem on /dev/loop0 to 362101 (4k) blocks.
Begin pass 2 (max = 1)
Relocating blocks             XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
Begin pass 3 (max = 59)
Scanning inode table          XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
Begin pass 4 (max = 3726)
Updating inode references     XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
The filesystem on /dev/loop0 is now 362101 (4k) blocks long.

Added config to resize Root Partition on first boot

Enabled SSH on Boot

Shrunk miknewimage.img

Start Size: 7.5G
Final Size: 1.5G
```

## Contributing ##
If you find a bug please create an issue for it. If you would like a new feature added, you can create an issue for it but I can't promise that I will get to it.

Pull requests for new features and bug fixes are more than welcome!

## Author ##
Orginally Written by: Drew Bonasera

Forked and Continued by: Mik McLean