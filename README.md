# Firmware Modding for Western Digital My Cloud DL2100 NAS Systems

This repository contains a number of tools for modifying the firmware of Western
Digital My Cloud DL2100 NAS Systems. The tools allow you to

- create backups of the firmware stored in flash memory (MTD),
- extract the firmware images contained in WD firmware <samp>.bin</samp> files,
- assemble firmware <samp>.bin</samp> files from firmware images,
- extract and (re-)asseble the initial ramdisk image (<samp>uRamdisk</samp>) with
  the root filesystem,
- extract and (re-)assemle the SquashFS container (<samp>image.cfs</samp>) with
  the filesystem mounted to <samp>/usr/local/modules/</samp>, and
- patch editable startup scripts into the original firmware.


## WARNING

Modifications to the firmware of your device may **render your device unusable**.
Moreover, modifications to the firmware may **void the warranty for your device**.

You are using the programs in this repository at your own risk. *We are not
responsible for any damage caused by these programs, their incorrect usage, or
inaccuracies in this manual.*


## GETTING STARTED

All scripts are designed to be run directly on the DL2100 (as root user over SSH).
However, some scripts may be used on other Linux systems as well.


### Create a Backup of the Installed Firmware

You can create backups in the form of whole-disk images of the flash memory (MTD),
in the form of all accessible firmware partitions, or of the files stored on those
partitions with the script <samp>[dl2100_fw_create_backup.sh](tools/dl2100_fw_create_backup.sh)</samp>.
The corresponding command line options are:

- <tt>-d</tt> to create whole-disk images,
- <tt>-p</tt> to create partition images, and
- <tt>-f</tt> to create file system archives.

Use the following command to create a full backup of the installed firmware and
store it on the "Public" share:

    ./dl2100_fw_create_backup.sh -dpf -x /shares/Public/


### Extract Images from WD Firmware <samp>.bin</samp> File

You can extract the images packed into a firmware <samp>.bin</samp> file with the
script <samp>[dl2100_fwimage_extract.sh](tools/dl2100_fwimage_extract.sh)</samp>.
Use the following command to extract from the firmware file
<samp>My_Cloud_DL2100_2.21.119.bin</samp> located on the "Public" share:

    ./dl2100_fwimage_extract.sh -x /shares/Public/My_Cloud_DL2100_2.21.119.bin

This creates the files

- <samp>My_Cloud_DL2100_2.21.119-codename.txt</samp> (codename from the magic value
  of the firmware file),
- <samp>My_Cloud_DL2100_2.21.119-version.txt</samp> (version of the firmware file),
- <samp>My_Cloud_DL2100_2.21.119-uImage</samp> (kernel image),
- <samp>My_Cloud_DL2100_2.21.119-uRamdisk</samp> (initial ramdisk image),
- <samp>My_Cloud_DL2100_2.21.119-image.cfs</samp> (SquashFS container),
- <samp>My_Cloud_DL2100_2.21.119-config_default.tar.gz</samp> (archive with the
  default configuration files),
- <samp>My_Cloud_DL2100_2.21.119-ext_0000.head</samp> (header of the first
  extraction target), and
- <samp>My_Cloud_DL2100_2.21.119-ext_0000.data</samp> (data of the first extraction
  target, <samp>grub.tgz</samp>).


### Assemble Firmware <samp>.bin</samp> File from Images

You can assemble a firmware <samp>.bin</samp> file from image files with the
script <samp>[dl2100_fwimage_build.sh](tools/dl2100_fwimage_build.sh)</samp>.
Use the following command to assemble the files in <samp>/shares/Public/customized_fw/</samp>
to the firmware file <samp>My_Cloud_DL2100_customized.bin</samp> located on the
"Public" share:

    ./dl2100_fwimage_build.sh -x -i /shares/Public/customized_fw/ /shares/Public/My_Cloud_DL2100_customized.bin


### Extract Root Filesystem from uRamdisk

You can extract the root filesystem from the initial ramdisk image
(<samp>uRamdisk</samp>) into a directory with the script
<samp>[dl2100_fw_initrd_unpack.sh](tools/dl2100_fw_initrd_unpack.sh)</samp>.
Use the following command to extract the file <samp>/shares/Public/My_Cloud_DL2100_2.21.119-uRamdisk</samp>
to <samp>/shares/Public/customized_rd/</samp>:

    ./dl2100_fw_initrd_unpack.sh -f -i /shares/Public/My_Cloud_DL2100_2.21.119-uRamdisk /shares/Public/customized_rd

Alternatively, you can directly extract the initial ramdisk of the installed firmware:

    ./dl2100_fw_initrd_unpack.sh -f /shares/Public/customized_rd

Both commands will create the file <samp>/shares/Public/customized_rd/uBoot-header</samp>
and the directory <samp>/shares/Public/customized_rd/initramfs-root/</samp> containing the
file tree of the filesystem.


### Repack Root Filesystem to uRamdisk

You can (re-)assemble the root filesystem of the initial ramdisk into a
<samp>uRamdisk</samp> image with the script
<samp>[dl2100_fw_initrd_pack.sh](tools/dl2100_fw_initrd_pack.sh)</samp>.
Use the following command to pack the files in <samp>/shares/Public/customized_rd/</samp>
into the file <samp>/shares/Public/customized_fw/uRamdisk</samp>. The command expects
the same structure as that created by <samp>dl2100_fw_initrd_unpack.sh</samp>.

    ./dl2100_fw_initrd_pack.sh -o /shares/Public/customized_fw/uRamdisk /shares/Public/customized_rd

Alternatively, you can directly install the packed initial ramdisk to the flash memory:

    ./dl2100_fw_initrd_pack.sh /shares/Public/customized_rd


### Extract SquashFS filesystem from image.cfs Container

You can extract the filesystem from the SquashFS container <samp>image.cfs</samp>
into a directory with the script <samp>[dl2100_fw_cfs_unpack.sh](tools/dl2100_fw_cfs_unpack.sh)</samp>.
Use the following command to extract the file <samp>/shares/Public/My_Cloud_DL2100_2.21.119-image.cfs</samp>
to <samp>/shares/Public/customized_cfs/</samp>:

    ./dl2100_fw_cfs_unpack.sh -f -i /shares/Public/My_Cloud_DL2100_2.21.119-image.cfs /shares/Public/customized_cfs

Alternatively, you can directly extract the SquashFS container of the installed firmware:

    ./dl2100_fw_cfs_unpack.sh -f /shares/Public/customized_cfs

Both commands will create the file <samp>/shares/Public/customized_cfs/image.squashfs</samp>
and the directory <samp>/shares/Public/customized_cfs/squashfs-root/</samp> containing the
file tree of the filesystem.


### Repack SquashFS filesystem to <samp>image.cfs</samp> Container

You can (re-)assemble the SquashFS filesystem into a SquashFS container <samp>image.cfs</samp>
with the script <samp>[dl2100_fw_cfs_pack.sh](tools/dl2100_fw_cfs_pack.sh)</samp>.
Use the following command to pack the files in <samp>/shares/Public/customized_cfs/</samp>
into the file <samp>/shares/Public/customized_fw/image.cfs</samp>. The command expects
the sub-directory <samp>squashfs-root/</samp> in the source directory (as created by
<samp>dl2100_fw_cfs_unpack.sh</samp>).

    ./dl2100_fw_cfs_pack.sh -o /shares/Public/customized_fw/image.cfs /shares/Public/customized_cfs

Alternatively, you can directly install the packed SquashFS container to the flash memory:

    ./dl2100_fw_cfs_pack.sh /shares/Public/customized_cfs


## FILE FORMATS

- [Specification of the format of WD firmware <samp>.bin</samp> files](doc/fwimage_format_specification.md)


## THIRD PARTY TOOLS

This repository includes the following precompiled tools and libraries from the
Debian 8 ("jessie") release:

- <tt>cpio</tt> from the package [<samp>cpio_2.11+dfsg-4.1+deb8u1_amd64.deb</samp>](https://packages.debian.org/jessie/cpio).
  You can get the source package [here](https://packages.debian.org/source/jessie/cpio).
- <tt>liblzma.so.5</tt> from the package [<samp>liblzma5_5.1.1alpha+20120614-2+b3_amd64.deb</samp>](https://packages.debian.org/jessie/liblzma5).
  You can get the source package [here](https://packages.debian.org/source/jessie/xz-utils).
- <tt>mksquashfs</tt> and <tt>unsquashfs</tt> from the package [<samp>squashfs-tools_4.2+20130409-2_amd64.deb</samp>](https://packages.debian.org/jessie/squashfs-tools).
  You can get the source package [here](https://packages.debian.org/source/jessie/squashfs-tools).
- <tt>mkimage</tt> from the package [<samp>u-boot-tools_2014.10+dfsg1-5_amd64.deb</samp>](https://packages.debian.org/jessie/u-boot-tools).
  You can get the source package [here](https://packages.debian.org/source/jessie/u-boot).


## GET LATEST VERSION

Find documentation and grab the latest version on GitHub
<https://github.com/michaelroland/wdnas-firmware-modding>


## COPYRIGHT

- Copyright (c) 2016 Michael Roland <<mi.roland@gmail.com>>


## DISCLAIMER

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.


## LICENSE

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

**License**: [GNU General Public License v3.0](http://www.gnu.org/licenses/gpl-3.0.txt)
