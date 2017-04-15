#!/bin/bash

################################################################################
## 
## Unpack SquashFS container (image.cfs) of Western Digital DL2100 NAS
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
INPUT_FILE=
FORCE_OVERWRITE=0

PATH=$PATH:$SCRIPT_PATH


usage() {
	echo "Usage: ${SCRIPT_NAME} [options] destination-directory"
	echo "Unpack SquashFS container (image.cfs) of Western Digital DL2100 NAS"
	echo ""
	echo -e "  <destination-directory>"
	echo -e "  \tTarget directory for storing extracted files"
	echo -e "  "
	echo -e "Options:"
	echo -e "\t-i <file>   Use <file> as input SquashFS container file instead"
    echo -e "\t            of obtaining the file image.cfs from the image.cfs"
    echo -e "\t            flash partition (which is done by default); if <file>"
    echo -e "\t            is a block device, the device is mounted and the"
    echo -e "\t            image file is expected to be located at \"/image.cfs\""
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
OUTPUT_SQFSIMG="${OUTPUT_DIRECTORY}/image.squashfs"
OUTPUT_SQFSROOT="${OUTPUT_DIRECTORY}/squashfs-root"

if [ "${FORCE_OVERWRITE}" -eq 0 ] ; then
    if [ -e "${OUTPUT_SQFSIMG}" ] ; then
        echo "${SCRIPT_NAME}: ${OUTPUT_SQFSIMG} exists" >&2
        exit 1
    fi
    if [ -e "${OUTPUT_SQFSROOT}" ] ; then
        echo "${SCRIPT_NAME}: ${OUTPUT_SQFSROOT} exists" >&2
        exit 1
    fi
fi


# Usage: get_integer_le_from_file_at_offset <result variable name> <file name> <offset> <length>
function get_integer_le_from_file_at_offset() {
    local file_name=$2
    local value_offset=$3
    local value_end=$((value_offset + $4 - 1))
    local result=0
    for i in $(seq -- $value_end -1 $value_offset) ; do
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
    BLOCK_DEV=$(blkid | grep 'wdnas_image.cfs' | awk -F: 'NR==1{gsub(/^\s*/,"",$1); gsub(/\s*$/,"",$1); print$1}')
    INPUT_FILE=$BLOCK_DEV
fi
if [ -z "${INPUT_FILE}" ] ; then
    echo "${SCRIPT_NAME}: Device wdnas_image.cfs not found" >&2
    exit 1
elif [ ! -f "${INPUT_FILE}" -a ! -b "${INPUT_FILE}" ] ; then
    echo "${SCRIPT_NAME}: ${INPUT_FILE} is neither a regular file nor a block device" >&2
    exit 1
fi

if [ -b "${INPUT_FILE}" ] ; then
    echo "Mounting image.cfs block device ${INPUT_FILE} ..."
    echo ""
    mount -o ro "${INPUT_FILE}" "${TEMP_DIR}"

    INPUT_FILE="${TEMP_DIR}/image.cfs"
    if [ ! -f "${INPUT_FILE}" ] ; then
        echo "${SCRIPT_NAME}: /image.cfs does not exist on ${BLOCK_DEV}" >&2
        exit 1
    fi
fi

mkdir -p "${OUTPUT_DIRECTORY}"

echo "Using SquashFS container file ${INPUT_FILE} ..."

cfs_file_size=$(stat -c"%s" "${INPUT_FILE}")

cfs_sqfs_size=0
get_integer_le_from_file_at_offset cfs_sqfs_size "${INPUT_FILE}" 0 4
cfs_sqfs_checksum=0
get_integer_le_from_file_at_offset cfs_sqfs_checksum "${INPUT_FILE}" 4 4

printf "File size:         0x%04X\n" "${cfs_file_size}"
printf "SquashFS size:     0x%04X\n" "${cfs_sqfs_size}"
printf "SquashFS checksum: 0x%04X\n" "${cfs_sqfs_checksum}"

if [ "${cfs_file_size}" -ne "$((cfs_sqfs_size + 2048))" ] ; then
    echo "${SCRIPT_NAME}: ${INPUT_FILE} is not a valid SquashFS container file" >&2
    exit 1
fi

cfs_sqfs_calc_checksum=$(($(xor_checksum "${INPUT_FILE}" 4 2048 ${cfs_sqfs_size})))

if [ "${cfs_sqfs_checksum}" -ne "${cfs_sqfs_calc_checksum}" ] ; then
    printf "Expected checksum: 0x%04X\n" "${cfs_sqfs_calc_checksum}"
    echo "${SCRIPT_NAME}: ${INPUT_FILE} is not a valid SquashFS container file" >&2
    exit 1
fi

echo ""

echo "Extracting SquashFS image ..."
dd if="${INPUT_FILE}" of="${OUTPUT_SQFSIMG}" bs=2048 skip=1
echo "Done."
echo ""

squashfs_info=$(LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${SCRIPT_PATH}" unsquashfs -s "${OUTPUT_SQFSIMG}")
squashfs_info_type=$(echo "${squashfs_info}" | awk 'NR==1{print$0}')
squashfs_info_comp=$(echo "${squashfs_info}" | grep '^Compression' | awk 'NR==1{gsub(/^\s*/,"",$2); gsub(/\s*$/,"",$2); print$2}')
squashfs_info_blocksize=$(echo "${squashfs_info}" | grep '^Block size' | awk 'NR==1{gsub(/^\s*/,"",$3); gsub(/\s*$/,"",$3); print$3}')

echo "${squashfs_info_type}"
printf "Compression: %s\n" "${squashfs_info_comp}"
printf "Block size:  %d\n" "${squashfs_info_blocksize}"
echo ""

echo "Extracting filesystem ..."
rm -rf "${OUTPUT_SQFSROOT}"
LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${SCRIPT_PATH}" unsquashfs -d "${OUTPUT_SQFSROOT}" "${OUTPUT_SQFSIMG}"
echo "Done."
echo ""

cleanup
