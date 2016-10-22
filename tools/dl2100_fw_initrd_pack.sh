#!/bin/bash

################################################################################
## 
## Pack initial ramdisk image of Western Digital DL2100 NAS
## 
## Copyright (c) 2016 Michael Roland <mi.roland@gmail.com>
## 
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
## 
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
## 
## You should have received a copy of the GNU General Public License
## along with this program.  If not, see <http://www.gnu.org/licenses/>.
## 
################################################################################


SCRIPT_NAME=$(basename $0)
SCRIPT_PATH=$(readlink -f "$(dirname $0)")
UBOOT_OSNAMES=("invalid" "openbsd" "netbsd" "freebsd" "4_4bsd" "linux" "svr4" "esix" "solaris" "irix" "sco" "dell" "ncr" "lynxos" "vxworks" "psos" "qnx" "u-boot" "rtems" "artos" "unity" "integrity" "ose" "plan9" "openrtos")
UBOOT_ARCHNAMES=("invalid" "alpha" "arm" "x86" "ia64" "mips" "mips64" "powerpc" "s390" "sh" "sparc" "sparc64" "m68k" "nios" "microblaze" "nios2" "blackfin" "avr32" "st200" "sandbox" "nds32" "or1k" "arm64" "arc" "x86_64" "xtensa")
UBOOT_TYPENAMES=("invalid" "standalone" "kernel" "ramdisk" "multi" "firmware" "script" "filesystem" "flat_dt" "kwbimage" "imximage" "ublimage" "omapimage" "aisimage" "kernel_noload" "pblimage" "mxsimage" "gpimage" "atmelimage" "socfpgaimage" "x86_setup" "lpc32xximage" "loadable" "rkimage" "rksd" "rkspi" "zynqimage" "zynqmpimage" "fpga" "vybridimage")
UBOOT_COMPNAMES=("none" "gzip" "bzip2" "lzma" "lzo" "lz4")
OUTPUT_FILE=

PATH=$PATH:$SCRIPT_PATH


usage() {
	echo "Usage: ${SCRIPT_NAME} [options] source-directory"
	echo "Pack initial ramdisk image of Western Digital DL2100 NAS"
	echo ""
	echo -e "  <source-directory>"
	echo -e "  \tDirectory with (previously extracted) ramdisk contents"
	echo -e "  "
	echo -e "Options:"
	echo -e "\t-o <file>   Use <file> as output uRamdisk image file instead"
    echo -e "\t            of storing the ramdisk image to the initramfs"
    echo -e "\t            flash partition (which is done by default); if"
    echo -e "\t            <file> is a block device, the device is mounted"
    echo -e "\t            and the image file is stored to \"/uRamdisk\""
	echo -e "\t-h          Show this message"
	echo ""
    echo "Copyright (c) 2016 Michael Roland <mi.roland@gmail.com>"
    echo "License GPLv3+: GNU GPL version 3 or later <http://www.gnu.org/licenses/>"
	echo ""
    echo "This is free software: you can redistribute and/or modify it under the"
    echo "terms of the GPLv3+.  There is NO WARRANTY; not even the implied warranty"
    echo "of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE."
	echo ""
}

while getopts ":h?o:" opt; do
    case "$opt" in
    h|\?)
        if [ ! -z $OPTARG ] ; then
            echo "${SCRIPT_NAME}: invalid option -- $OPTARG" >&2
        fi
        usage
        exit 1
        ;;
    o)
        OUTPUT_FILE=$OPTARG
        ;;
    f)
        FORCE_OVERWRITE=1
        ;;
    esac
done

shift $((OPTIND-1))
[ "$1" = "--" ] && shift

if [ -z "$1" ] ; then
    echo "${SCRIPT_NAME}: missing argument -- source-directory" >&2
    usage
    exit 1
fi

INPUT_DIRECTORY=$1
if [ ! -d "${INPUT_DIRECTORY}" ] ; then
    echo "${SCRIPT_NAME}: ${INPUT_DIRECTORY} does not exist or is not a directory" >&2
    exit 1
fi
INPUT_UBOOTHEAD="${INPUT_DIRECTORY}/uBoot-header"
INPUT_RAMFSROOT="${INPUT_DIRECTORY}/initramfs-root"

if [ ! -f "${INPUT_UBOOTHEAD}" ] ; then
    echo "${SCRIPT_NAME}: ${INPUT_UBOOTHEAD} does not exist or is not a regular file" >&2
    exit 1
fi
if [ ! -d "${INPUT_RAMFSROOT}" ] ; then
    echo "${SCRIPT_NAME}: ${INPUT_RAMFSROOT} does not exist or is not a directory" >&2
    exit 1
fi


# Usage: get_integer_be_from_file_at_offset <result variable name> <file name> <offset> <length>
function get_integer_be_from_file_at_offset() {
    local file_name=$2
    local value_offset=$3
    local value_end=$((value_offset + $4 - 1))
    local result=0
    for i in $(seq -- $value_offset 1 $value_end) ; do
        local b=$(dd if=$file_name bs=1 skip=$i count=1 2>/dev/null)
        local bval=$(printf "%d" "'$b")
        result=$((result * 256 + bval))
    done
    eval "$1=\"$result\""
}


TEMP_DIR=$(mktemp -d)

cleanup() {
	trap SIGINT
	if [ ! -z "${TEMP_DIR}" ] ; then
        if [ -d "${TEMP_DIR}" ] ; then
            umount "${TEMP_DIR}" >/dev/null 2>&1
            rmdir "${TEMP_DIR}"
        fi
    fi
}

interrupted() {
	cleanup
	exit 1
}

trap 'interrupted' INT

BLOCK_DEV=
if [ -z "${OUTPUT_FILE}" ] ; then
    BLOCK_DEV=$(blkid | grep 'wdnas_initramfs' | awk -F: 'NR==1{gsub(/^\s*/,"",$1); gsub(/\s*$/,"",$1); print$1}')
    OUTPUT_FILE="${INPUT_DIRECTORY}/uRamdisk"
elif [ -b "${OUTPUT_FILE}" ] ; then
    BLOCK_DEV=$OUTPUT_FILE
    OUTPUT_FILE="${INPUT_DIRECTORY}/uRamdisk"
fi
if [ -z "${OUTPUT_FILE}" ] ; then
    echo "${SCRIPT_NAME}: Device wdnas_initramfs not found" >&2
    exit 1
elif [ -e "${OUTPUT_FILE}" -a ! -f "${OUTPUT_FILE}" ] ; then
    echo "${SCRIPT_NAME}: ${OUTPUT_FILE} is not a regular file" >&2
    exit 1
fi

echo "Building u-Boot image file ${OUTPUT_FILE} ..."
echo "Header file:     ${INPUT_UBOOTHEAD}"
echo "Filesystem root: ${INPUT_RAMFSROOT}"
echo ""

uboot_magic=0
get_integer_be_from_file_at_offset uboot_magic "${INPUT_UBOOTHEAD}" 0 4
if [ "${uboot_magic}" -ne "654645590" ] ; then
    echo "${SCRIPT_NAME}: ${INPUT_UBOOTHEAD} is not a valid u-Boot header" >&2
    exit 1
fi

ramdisk_load=0
get_integer_be_from_file_at_offset ramdisk_load "${INPUT_UBOOTHEAD}" 16 4
ramdisk_entry=0
get_integer_be_from_file_at_offset ramdisk_entry "${INPUT_UBOOTHEAD}" 20 4
ramdisk_os=0
get_integer_be_from_file_at_offset ramdisk_os "${INPUT_UBOOTHEAD}" 28 1
ramdisk_arch=0
get_integer_be_from_file_at_offset ramdisk_arch "${INPUT_UBOOTHEAD}" 29 1
ramdisk_type=0
get_integer_be_from_file_at_offset ramdisk_type "${INPUT_UBOOTHEAD}" 30 1
ramdisk_comp=0
get_integer_be_from_file_at_offset ramdisk_comp "${INPUT_UBOOTHEAD}" 31 1
ramdisk_name="$(dd if="${INPUT_UBOOTHEAD}" bs=1 skip=32 count=32 2>/dev/null)"

echo "Packing image ..."
printf "Image name:       %s\n" "${ramdisk_name}"
printf "Image type:       %s\n" "${UBOOT_TYPENAMES[${ramdisk_type}]}"
printf "Compression:      %s\n" "${UBOOT_COMPNAMES[${ramdisk_comp}]}"
printf "Operating system: %s\n" "${UBOOT_OSNAMES[${ramdisk_os}]}"
printf "CPU architecture: %s\n" "${UBOOT_ARCHNAMES[${ramdisk_arch}]}"
printf "Load address:     0x%x\n" ${ramdisk_load}
printf "Entry point:      0x%x\n" ${ramdisk_entry}
echo ""

previous_dir=$(pwd)
cd "${INPUT_RAMFSROOT}"
find . | cpio -oa --format='newc' | gzip -c -9 >"${INPUT_DIRECTORY}/initramfs.img.gz"
cd "${previous_dir}"
mkimage -O ${UBOOT_OSNAMES[${ramdisk_os}]} \
        -A ${UBOOT_ARCHNAMES[${ramdisk_arch}]} \
        -T ${UBOOT_TYPENAMES[${ramdisk_type}]} \
        -C ${UBOOT_COMPNAMES[${ramdisk_comp}]} \
        -a $(printf "0x%x" "${ramdisk_load}") \
        -e $(printf "0x%x" "${ramdisk_entry}") \
        -n "${ramdisk_name}" \
        -d "${INPUT_DIRECTORY}/initramfs.img.gz" \
        "${OUTPUT_FILE}"

echo "Done."
echo ""

if [ ! -z "${BLOCK_DEV}" ] ; then
    echo "Mounting initramfs block device ${BLOCK_DEV} ..."
    mount -o rw "${BLOCK_DEV}" "${TEMP_DIR}"

    echo "Storing image to /uRamdisk on ${BLOCK_DEV} ..."
    dd if="${OUTPUT_FILE}" of="${TEMP_DIR}/uRamdisk"

    echo "Unmounting filesystem ..."
    umount "${TEMP_DIR}"
    
    echo "Done."
    echo ""
fi

cleanup
