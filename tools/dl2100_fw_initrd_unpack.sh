#!/bin/bash

################################################################################
## 
## Unpack initial ramdisk image of Western Digital DL2100 NAS
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
INPUT_FILE=
FORCE_OVERWRITE=0

PATH=$PATH:$SCRIPT_PATH


usage() {
	echo "Usage: ${SCRIPT_NAME} [options] destination-directory"
	echo "Unpack initial ramdisk image of Western Digital DL2100 NAS"
	echo ""
	echo -e "  <destination-directory>"
	echo -e "  \tTarget directory for storing extracted files"
	echo -e "  "
	echo -e "Options:"
	echo -e "\t-i <file>   Use <file> as input uRamdisk image file instead"
    echo -e "\t            of obtaining the ramdisk image from the initramfs"
    echo -e "\t            flash partition (which is done by default); if"
    echo -e "\t            <file> is a block device, the device is mounted"
    echo -e "\t            and the image file is expected to be located at"
    echo -e "\t            \"/uRamdisk\""
	echo -e "\t-f          Overwrite existing files in <destination-directory>"
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

while getopts ":h?i:f" opt; do
    case "$opt" in
    h|\?)
        if [ ! -z $OPTARG ] ; then
            echo "${SCRIPT_NAME}: invalid option -- $OPTARG" >&2
        fi
        usage
        exit 1
        ;;
    i)
        INPUT_FILE=$OPTARG
        ;;
    f)
        FORCE_OVERWRITE=1
        ;;
    esac
done

shift $((OPTIND-1))
[ "$1" = "--" ] && shift

if [ -z "$1" ] ; then
    echo "${SCRIPT_NAME}: missing argument -- destination-directory" >&2
    usage
    exit 1
fi

OUTPUT_DIRECTORY=$1
if [ -e "${OUTPUT_DIRECTORY}" -a ! -d "${OUTPUT_DIRECTORY}" ] ; then
    echo "${SCRIPT_NAME}: ${OUTPUT_DIRECTORY} exists and is not a directory" >&2
    exit 1
fi
OUTPUT_UBOOTHEAD="${OUTPUT_DIRECTORY}/uBoot-header"
OUTPUT_RAMFSROOT="${OUTPUT_DIRECTORY}/initramfs-root"

if [ "${FORCE_OVERWRITE}" -eq 0 ] ; then
    if [ -e "${OUTPUT_UBOOTHEAD}" ] ; then
        echo "${SCRIPT_NAME}: ${OUTPUT_UBOOTHEAD} exists" >&2
        exit 1
    fi
    if [ -e "${OUTPUT_RAMFSROOT}" ] ; then
        echo "${SCRIPT_NAME}: ${OUTPUT_RAMFSROOT} exists" >&2
        exit 1
    fi
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
if [ -z "${INPUT_FILE}" ] ; then
    BLOCK_DEV=$(blkid | grep 'wdnas_initramfs' | awk -F: 'NR==1{gsub(/^\s*/,"",$1); gsub(/\s*$/,"",$1); print$1}')
    INPUT_FILE=$BLOCK_DEV
fi
if [ -z "${INPUT_FILE}" ] ; then
    echo "${SCRIPT_NAME}: Device wdnas_initramfs not found" >&2
    exit 1
elif [ ! -f "${INPUT_FILE}" -a ! -b "${INPUT_FILE}" ] ; then
    echo "${SCRIPT_NAME}: ${INPUT_FILE} is neither a regular file nor a block device" >&2
    exit 1
fi

if [ -b "${INPUT_FILE}" ] ; then
    echo "Mounting initramfs block device ${INPUT_FILE} ..."
    echo ""
    mount -o ro "${INPUT_FILE}" "${TEMP_DIR}"

    INPUT_FILE="${TEMP_DIR}/uRamdisk"
    if [ ! -f "${INPUT_FILE}" ] ; then
        echo "${SCRIPT_NAME}: /uRamdisk does not exist on ${BLOCK_DEV}" >&2
        exit 1
    fi
fi

mkdir -p "${OUTPUT_DIRECTORY}"

echo "Using u-Boot image file ${INPUT_FILE} ..."
echo ""

uboot_magic=0
get_integer_be_from_file_at_offset uboot_magic "${INPUT_FILE}" 0 4
if [ "${uboot_magic}" -ne "654645590" ] ; then
    echo "${SCRIPT_NAME}: ${INPUT_FILE} is not a valid u-Boot image file" >&2
    exit 1
fi

ramdisk_size=0
get_integer_be_from_file_at_offset ramdisk_size "${INPUT_FILE}" 12 4
ramdisk_load=0
get_integer_be_from_file_at_offset ramdisk_load "${INPUT_FILE}" 16 4
ramdisk_entry=0
get_integer_be_from_file_at_offset ramdisk_entry "${INPUT_FILE}" 20 4
ramdisk_os=0
get_integer_be_from_file_at_offset ramdisk_os "${INPUT_FILE}" 28 1
ramdisk_arch=0
get_integer_be_from_file_at_offset ramdisk_arch "${INPUT_FILE}" 29 1
ramdisk_type=0
get_integer_be_from_file_at_offset ramdisk_type "${INPUT_FILE}" 30 1
ramdisk_comp=0
get_integer_be_from_file_at_offset ramdisk_comp "${INPUT_FILE}" 31 1
ramdisk_name="$(dd if="${INPUT_FILE}" bs=1 skip=32 count=32 2>/dev/null)"

echo "Found ${UBOOT_TYPENAMES[${ramdisk_type}]} (compression: ${UBOOT_COMPNAMES[${ramdisk_comp}]}) for ${UBOOT_OSNAMES[${ramdisk_os}]} on ${UBOOT_ARCHNAMES[${ramdisk_arch}]}"
printf "Image name:   %s\n" "${ramdisk_name}"
printf "Load address: 0x%x\n" ${ramdisk_load}
printf "Entry point:  0x%x\n" ${ramdisk_entry}
echo ""

echo "Extracting u-Boot header ..."
dd if="${INPUT_FILE}" of="${OUTPUT_UBOOTHEAD}" bs=64 count=1
echo "Done."
echo ""

echo "Extracting filesystem ..."
rm -rf "${OUTPUT_RAMFSROOT}"
mkdir -p "${OUTPUT_RAMFSROOT}"
previous_dir=$(pwd)
cd "${OUTPUT_RAMFSROOT}"
dd if="${INPUT_FILE}" ibs=64 skip=1 obs=2048 | gunzip | cpio -idm --no-absolute-filenames
cd "${previous_dir}"
echo "Done."
echo ""

cleanup
