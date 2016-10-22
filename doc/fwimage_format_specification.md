# WD DL2100 Firmware Image Format

This file documents my observations regarding the format of firmware <samp>.bin</samp>
files provided by Western Digital for their My Cloud DL2100 NAS system.


## OVERVIEW

Firmware <samp>.bin</samp> files contain the kernel image (<samp>uImage</samp>), the
initial ramdisk image (<samp>uRamdisk</samp>) with the root filesystem, the SquashFS
container (<samp>image.cfs</samp>) with the filesystem mounted to
<samp>/usr/local/modules/</samp>, an archive (<samp>config_default.tar.gz</samp>) with
the default version of the configuration files, and an archive (<samp>grub.tgz</samp>)
with the files for the boot partition.

The images <samp>uImage</samp>, <samp>uRamdisk</samp>, and <samp>image.cfs</samp> match
the single files stored on the corresponding partitions in flash memory (MTD). The
archives <samp>config_default.tar.gz</samp> and <samp>grub.tgz</samp> contain files to
be extracted into the filesystems of the corresponding flash memory partitions.


### Flash Memory Partitions

The flash memory contains a GPT partition table with protective MBR. The MTD is exposed
as device node <samp>/dev/sdc</samp>. The device has 478.0 MiB (978944 sectors with a
logical sector size of 512 bytes).

**GPT Partition Table:**
<pre>
<b>Number   Start (sector)   End (sector)        Size   Code   Name</b>
     1             2048          73727    35.0 MiB   EF00   EFI System
     2            73728          94207    10.0 MiB   0700   kernel
     3            94208         104447     5.0 MiB   0700   ramdisk
     4           104448         837631   358.0 MiB   0700   image.cfs
     5           837632         899071    30.0 MiB   0700   rescue_fw
     6           899072         940031    20.0 MiB   0700   config
     7           940032         960511    10.0 MiB   0700   reserve1
     8           960512         978910     9.0 MiB   0700   reserve2
</pre>
   
- Partition wdnas_efi (device node: <samp>/dev/sdc1</samp>, filesystem: vfat):<br>
  This partition contains the bootloader configuration filesystem.
- Partition wdnas_kernel (device node: <samp>/dev/sdc2</samp>, filesystem: ext4):<br>
  This partition contains the kernel image as a single file named
  "<samp>/uImage</samp>".
- Partition wdnas_initramfs (device node: <samp>/dev/sdc3</samp>, filesystem: ext4):<br>
  This partition contains the initial ramdisk image as a single file named
  "<samp>/uRamdisk</samp>".
- Partition wdnas_image.cfs (device node: <samp>/dev/sdc4</samp>, filesystem: ext4):<br>
  This partition contains the SquashFS container as a single file named
  "<samp>/image.cfs</samp>".
- Partition wdnas_rescue_fw (device node: <samp>/dev/sdc5</samp>, filesystem: ext4):<br>
  This partition contains the kernel image and the initial ramdisk image of the rescue
  firmware as two files named "<samp>/uImage</samp>" and "<samp>/uRamdisk</samp>".
- Partition wdnas_config (device node: <samp>/dev/sdc6</samp>, filesystem: ext4):<br>
  This partition contains the configuration files. These files are extracted to
  <samp>/usr/local/config/</samp> during boot.
- Partition wdnas_reserve1 (device node: <samp>/dev/sdc7</samp>, filesystem: ext4):<br>
  This partition is empty. The device node is removed during boot.
- Partition wdnas_reserve2 (device node: <samp>/dev/sdc8</samp> filesystem: ext4):<br>
  This partition contains a backup copy of the configuration files from <samp>/dev/sdc6</samp>.


### Firmware File Layout

The firmware <samp>.bin</samp> file consists of a main header, four image data blobs,
and one or more "extraction targets" (i.e. a data blob with instructions regarding the
target path for extraction, access permission configuration, and file execution. Each
extraction target consists of a header and a file data blob.

<pre>
+---------------------------+
|        MAIN_HEADER        |
+---------------------------+
|                           |
|        IMAGE0_DATA        |
|                           |
+---------------------------+
|                           |
|        IMAGE1_DATA        |
|                           |
+---------------------------+
|                           |
|        IMAGE2_DATA        |
|                           |
+---------------------------+
|                           |
|        IMAGE3_DATA        |
|                           |
+---------------------------+
| EXTRACTION_TARGET0_HEADER |
+---------------------------+
|                           |
|  EXTRACTION_TARGET0_DATA  |
|                           |
+---------------------------+
:                           :
: [MORE_EXTRACTION_TARGETS] :
:                           :
+---------------------------+
</pre>


## FILE SECTIONS

### Main Header

This is the main header of the firmware <samp>.bin</samp> file located at the beginning
(offset 0) of the file.

<pre>
Offset    +0   +1   +2   +3   +4   +5   +6   +7   +8   +9  +10  +11  +12  +13  +14  +15
       +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
     0 | IMAGE0_OFFSET     | IMAGE0_LENGTH     | IMAGE1_OFFSET     | IMAGE1_LENGTH     |
       +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
    16 | IMAGE2_OFFSET     | IMAGE2_LENGTH     | IMAGE3_OFFSET     | IMAGE3_LENGTH     |
       +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
    32 | IMAGE0_CHECKSUM   | IMAGE1_CHECKSUM   | IMAGE2_CHECKSUM   | IMAGE3_CHECKSUM   |
       +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
    48 | MAGIC                                                     | 00 | 14 | 06 | 01 |
       +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
    64 | 01 | VERSION_STRING                                                           |
       +----+                                                                          +
    80 |                                                                               |
       +                                                                               +
    96 |                                                                               |
       +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
   112 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | HEADER_CHECKSUM   | NEXT_OFFSET       |
       +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
</pre>

- **<tt>IMAGE0_OFFSET</tt> (offset 0, 4 bytes, 32-bit little-endian integer):**<br>
  Start offset of the first firmware image (the kernel image, <samp>uImage</samp>) data
  blob, counted in bytes from the beginning of the firmware <samp>.bin</samp> file.
- **<tt>IMAGE0_LENGTH</tt> (offset 4, 4 bytes, 32-bit little-endian integer):**<br>
  Length of first firmware image data blob in bytes.
- **<tt>IMAGE0_CHECKSUM</tt> (offset 32, 4 bytes, 32-bit value):**<br>
  XOR checksum over the first firmware image data blob. The 32-bit value is calculated
  by XOR-ing the data in blocks of 4 bytes.
- **<tt>IMAGE1_OFFSET</tt> (offset 8, 4 bytes, 32-bit little-endian integer):**<br>
  Start offset of the second firmware image (the ramdisk image, <samp>uRamdisk</samp>
  data blob, counted in bytes from the beginning of the firmware <samp>.bin</samp> file.
- **<tt>IMAGE1_LENGTH</tt> (offset 12, 4 bytes, 32-bit little-endian integer):**<br>
  Length of the second firmware image data blob in bytes.
- **<tt>IMAGE1_CHECKSUM</tt> (offset 36, 4 bytes, 32-bit value):**<br>
  XOR checksum over the second firmware image data blob. The 32-bit value is calculated
  by XOR-ing the data in blocks of 4 bytes.
- **<tt>IMAGE2_OFFSET</tt> (offset 16, 4 bytes, 32-bit little-endian integer):**<br>
  Start offset of the third firmware image (the SquashFS container,
  <samp>image.cfs</samp>) data blob, counted in bytes from the beginning of the
  firmware <samp>.bin</samp> file.
- **<tt>IMAGE2_LENGTH</tt> (offset 20, 4 bytes, 32-bit little-endian integer):**<br>
  Length of the third firmware image data blob in bytes.
- **<tt>IMAGE2_CHECKSUM</tt> (offset 40, 4 bytes, 32-bit value):**<br>
  XOR checksum over the third firmware image data blob. The 32-bit value is calculated
  by XOR-ing the data in blocks of 4 bytes.
- **<tt>IMAGE3_OFFSET</tt> (offset 24, 4 bytes, 32-bit little-endian integer):**<br>
  Start offset of the fourth firmware image (the default configuration file archive,
  <samp>config_default.tar.gz</samp>) data blob, counted in bytes from the beginning
  of the firmware <samp>.bin</samp> file.
- **<tt>IMAGE3_LENGTH</tt> (offset 28, 4 bytes, 32-bit little-endian integer):**<br>
  Length of the fourth firmware image data blob in bytes.
- **<tt>IMAGE3_CHECKSUM</tt> (offset 44, 4 bytes, 32-bit value):**<br>
  XOR checksum over the fourth firmware image data blob. The 32-bit value is calculated
  by XOR-ing the data in blocks of 4 bytes.
- **<tt>MAGIC</tt> (offset 48, 12 bytes):**<br>
  The magic value identifies the firmware file type. The value starts and ends with
  the sequence `\x55\xAA`. Between those markers the magic value contains the product
  code name of the DL2100 ("Aurora") padded with zeros. Consequently, the complete
  magic value is `\x55\xAAAurora\x00\x00\x55\xAA`.
- ***??? (not yet identified)* (offset 60, 5 bytes):**<br>
  These bytes are set to `\x00\x14\x06\x01\x01` and are the same in all analyzed
  WD DL2100 firmware files. I could not yet identify the purpose of these bytes, though
  they might actually be part of <tt>MAGIC</tt> (turning the magic value into
  `\x55\xAAAurora\x00\x00\x55\xAA\x00\x14\x06\x01\x01`.
- **<tt>VERSION_STRING</tt> (offset 65, 47 bytes, null-terminated ASCII(?) string):**<br>
  Version code of the firmware contained in this firmware <samp>.bin</samp> file. The
  format of the version code seems to follow the format `M.mm.RRR.MMDD.YYYY`, where `M`
  is the major version, `mm` the minor version, `RRR` the revision number, `MM` the
  release month, `DD` the release day, and `YYYY` the release year.
- ***unused (?)* (offset 112, 8 bytes):**<br>
  These bytes seem not to be used and are always set to 0x00 in all analyzed WD DL2100
  firmware files. These bytes might actually be part of the <tt>VERSION_STRING</tt>
  though.
- **<tt>HEADER_CHECKSUM</tt> (offset 120, 4 bytes, 32-bit value):**<br>
  XOR checksum over this header. The 32-bit value is calculated by XOR-ing the data
  (128 bytes starting at offset 0) in blocks of 4 bytes. The <tt>HEADER_CHECKSUM</tt>
  field is set to 0 during checksum computation. Due to the nature of XOR checksums,
  calculating that same XOR checksum over the complete header (including the populated
  <tt>HEADER_CHECKSUM</tt> field) must result in a zero value on verification success.
- **<tt>NEXT_OFFSET</tt> (offset 124, 4 bytes, 32-bit little-endian integer):**<br>
  Start offset of the next extraction target header, counted in bytes from the
  beginning of the firmware <samp>.bin</samp> file.


### Extraction Target Header

An extraction target is a data blob together with a header that specifies the target
path for extraction of the data blob, the configuration of the access permissions (to
be applied with `chmod`), and a flag indicating if the file should be executed after
extraction.

<pre>
Offset    +0   +1   +2   +3   +4   +5   +6   +7   +8   +9  +10  +11  +12  +13  +14  +15
       +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
    +0 | DIRECTORY_NAME                                                                |
       +                                                                               +
   +16 |                                                                               |
       +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
   +32 | FILE_NAME                                                                     |
       +                                                                               +
   +48 |                                                                               |
       +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
   +64 | MODE    |EXEC| 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 |
       +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
   +80 | FILE_OFFSET       | FILE_LENGTH       | FILE_CHECKSUM     | NEXT_OFFSET       |
       +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
</pre>

- **<tt>DIRECTORY_NAME</tt> (offset +0, 32 bytes, null-terminated ASCII(?) string):**<br>
  Name of the extraction target directory. This value is "<samp>/tmp</samp>" in all
  analyzed WD DL2100 firmware files.
- **<tt>FILE_NAME</tt> (offset +32, 32 bytes, null-terminated ASCII(?) string):**<br>
  Name of the extraction target file. This value is "<samp>grub.tgz</samp>" in all
  analyzed WD DL2100 firmware files.
- **<tt>MODE</tt> (offset +64, 2 bytes, 16-bit little-endian integer):**<br>
  Unix permissions to be set on the extraction target file. The integer value represents
  the octal mode digits. This value is 0755 in all analyzed WD DL2100 firmware files.
- **<tt>EXEC</tt> (offset +66, 1 byte, 8-bit integer):**<br>
  Flag indicating if the target file should be executed after extraction. If this value
  is zero, the extracted file is not executed; for all(?) other values, the extracted
  file is executed. This value is <samp>0x00</samp> in all analyzed WD DL2100 firmware
  files.
- ***unused (?)* (offset +67, 13 bytes):**<br>
  These bytes seem not to be used and are always set to <samp>0x00</samp> in all
  analyzed WD DL2100 firmware files.
- **<tt>FILE_OFFSET</tt> (offset +80, 4 bytes, 32-bit little-endian integer):**<br>
  Start offset of the file data, counted in bytes from the beginning of the firmware
  <samp>.bin</samp> file.
- **<tt>FILE_LENGTH</tt> (offset +84, 4 bytes, 32-bit little-endian integer):**<br>
  Length of file data in bytes.
- **<tt>FILE_CHECKSUM</tt> (offset +88, 4 bytes, 32-bit value):**<br>
  XOR checksum over the file data. The 32-bit value is calculated by XOR-ing the file
  data in blocks of 4 bytes.
- **<tt>NEXT_OFFSET</tt> (offset +92, 4 bytes, 32-bit little-endian integer):**<br>
  Start offset of the next extraction target header, counted in bytes from the
  beginning of the firmware <samp>.bin</samp> file. This value is 0 in all analyzed
  WD DL2100 firmware files.


## IMAGE FILE FORMATS

### uImage

uImage contains the kernel image wrapped into a u-Boot image container.


### uRamdisk

uRamdisk contains the initial ramdisk image wrapped into a u-Boot image container.
The filesystem of the ramdisk image is encapsulated in a GZIP-compressed CPIO archive
in *new ASCII* format.


### u-Boot Image Container

The u-Boot image container is organized as:

<pre>
Offset    +0   +1   +2   +3   +4   +5   +6   +7   +8   +9  +10  +11  +12  +13  +14  +15
       +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
    +0 | MAGIC             | HEADER_CRC        | TIMESTAMP         | IMAGE_DATA_LENGTH |
       +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
   +16 | LOAD_ADDRESS      | ENTRY_POINT       | IMAGE_DATA_CRC    | OS |ARCH|TYPE|COMP|
       +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
   +32 | IMAGE_NAME                                                                    |
       +                                                                               +
   +48 |                                                                               |
       +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
   +64 | IMAGE_DATA                                                                    |
       :                                                                               :
       :                                                                               :
       :                                                                               :
       +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
</pre>

- **<tt>MAGIC</tt> (offset +0, 4 bytes, 32-bit big-endian integer):**<br>
  The magic number is set to <samp>0x27051956</samp> indicating the u-Boot container
  format.
- **<tt>HEADER_CRC</tt> (offset +4, 4 bytes, 32-bit big-endian integer):**<br>
  A CRC32 checksum over the header (64 bytes starting at offset +0) using the polynomial
  <samp>0x04C11DB7</samp> (as used in, e.g., Ethernet and PKZIP).
- **<tt>TIMESTAMP</tt> (offset +8, 4 bytes, 32-bit big-endian integer):**<br>
  Timestamp of the image in seconds since the Epoch (Unix timestamp).
- **<tt>IMAGE_DATA_LENGTH</tt> (offset +12, 4 bytes, 32-bit big-endian integer):**<br>
  Length of <tt>IMAGE_DATA</tt> in bytes.
- **<tt>LOAD_ADDRESS</tt> (offset +16, 4 bytes, 32-bit big-endian integer):**<br>
  Load address for the image data. This value is 0 in all analyzed WD DL2100 firmware
  files.
- **<tt>ENTRY_POINT</tt> (offset +20, 4 bytes, 32-bit big-endian integer):**<br>
  Entry point address. This value is 0 in all analyzed WD DL2100 firmware files.
- **<tt>IMAGE_DATA_CRC</tt> (offset +24, 4 bytes, 32-bit big-endian integer):**<br>
  A CRC32 checksum over <tt>IMAGE_DATA</tt> using the polynomial <samp>0x04C11DB7</samp>
  (as used in, e.g., Ethernet and PKZIP). This value is <samp>0xFFFFFFFF</samp> in all
  analyzed WD DL2100 firmware files.
- **<tt>OS</tt> (offset +28, 1 byte, 8-bit integer):**<br>
  Operating system. This value is 5 (Linux) in all analyzed WD DL2100 firmware files.
- **<tt>ARCH</tt> (offset +29, 1 byte, 8-bit integer):**<br>
  CPU architecture code. This value is 3 (x86) in all analyzed WD DL2100 firmware files.
- **<tt>TYPE</tt> (offset +30, 1 byte, 8-bit integer):**<br>
  Image type. This value is 2 (kernel) for <samp>uImage</samp> and 3 (ramdisk) for
  <samp>uRamdisk</samp> in all analyzed WD DL2100 firmware files.
- **<tt>COMP</tt> (offset +31, 1 byte, 8-bit integer):**<br>
  Compression method. This value is 1 (gzip) in all analyzed WD DL2100 firmware files.
- **<tt>IMAGE_NAME</tt> (offset +32, 32 bytes, null-terminated ASCII string):**<br>
  Name of the contained image. This value is "kernel" for <samp>uImage</samp> and
  "Initramfs" for <samp>uRamdisk</samp> in all analyzed WD DL2100 firmware files.


### image.cfs

<samp>image.cfs</samp> contains the SquashFS filesystem for the mount point
<samp>/usr/local/modules/</samp> and embeds the main part of the Western Digital
firmware. The SquashFS image is prepended with a 2048-byte header. The the SquashFS
filesystem uses SquashFS 4.0 with the default block size of 131072 bytes and XZ
compression.

The <samp>image.cfs</samp> container is organized as:

<pre>
Offset    +0   +1   +2   +3   +4   +5   +6   +7   +8   +9  +10  +11  +12  +13  +14  +15
       +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
    +0 | DATA_LENGTH       | DATA_CHECKSUM     | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 |
       +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
   +16 | 00 ...                                                                        |
       :                                                                               :
       :                                                                               :
 +2032 |                                                                        ... 00 |
       +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
 +2048 | DATA                                                                          |
       :                                                                               :
       :                                                                               :
       :                                                                               :
       +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
</pre>

- **<tt>DATA_LENGTH</tt> (offset +0, 4 bytes, 32-bit little-endian integer):**<br>
  Length of file data in bytes.
- **<tt>DATA_CHECKSUM</tt> (offset +4, 4 bytes, 32-bit value):**<br>
  XOR checksum over the <tt>DATA</tt> field. The 32-bit value is calculated by XOR-ing
  the data in blocks of 4 bytes.


## DOWNLOAD FIRMWARE IMAGES

Original firmware <samp>.bin</samp> files are provided by Western Digital through their
[Software and Firmware Downloads](https://support.wdc.com/downloads.aspx?g=2703#firmware)
page.


## AUTHOR

Michael Roland <<mi.roland@gmail.com>>


## LICENSE

This work is licensed under a [Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License](http://creativecommons.org/licenses/by-nc-nd/4.0/).

[<img src="https://i.creativecommons.org/l/by-nc-nd/4.0/88x31.png">](http://creativecommons.org/licenses/by-nc-nd/4.0/)

**License:** [Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International Public License](https://creativecommons.org/licenses/by-nc-nd/4.0/legalcode)
