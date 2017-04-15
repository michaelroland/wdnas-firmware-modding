#!/bin/bash

################################################################################
## 
## Pack SquashFS container (image.cfs) of Western Digital DL2100 NAS
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
OUTPUT_FILE=

PATH=$PATH:$SCRIPT_PATH


usage() {
	echo "Usage: ${SCRIPT_NAME} [options] source-directory"
	echo "Pack SquashFS container (image.cfs) of Western Digital DL2100 NAS"
	echo ""
	echo -e "  <source-directory>"
	echo -e "  \tDirectory with (previously extracted) SquashFS contents"
	echo -e "  "
	echo -e "Options:"
	echo -e "\t-o <file>   Use <file> as output SquashFS container file instead"
    echo -e "\t            of storing the file image.cfs to the image.cfs flash"
    echo -e "\t            partition (which is done by default); if <file> is a"
    echo -e "\t            block device, the device is mounted and the image"
    echo -e "\t            file is stored to \"/image.cfs\""
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
INPUT_SQFSNEWIMG="${INPUT_DIRECTORY}/new-image.squashfs"
INPUT_SQFSROOT="${INPUT_DIRECTORY}/squashfs-root"

if [ ! -d "${INPUT_SQFSROOT}" ] ; then
    echo "${SCRIPT_NAME}: ${INPUT_SQFSROOT} does not exist or is not a directory" >&2
    exit 1
fi


# Usage: put_integer_le_to_file_at_offset <value> <file name> <offset> <length>
function put_integer_le_to_file_at_offset() {
    local file_name=$2
    local value_offset=$3
    local value_end=$((value_offset + $4 - 1))
    local value=$1
    for i in $(seq -- $value_offset 1 $value_end) ; do
        local bval=$((value & 0x0ff))
        local bhex=$(printf '%02X' $bval)
        printf "\\x${bhex}" | dd of=$file_name conv=notrunc bs=1 seek=$i count=1 2>/dev/null
        value=$((value >> 8))
    done
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
    BLOCK_DEV=$(blkid | grep 'wdnas_image.cfs' | awk -F: 'NR==1{gsub(/^\s*/,"",$1); gsub(/\s*$/,"",$1); print$1}')
    OUTPUT_FILE="${INPUT_DIRECTORY}/image.cfs"
elif [ -b "${OUTPUT_FILE}" ] ; then
    BLOCK_DEV=$OUTPUT_FILE
    OUTPUT_FILE="${INPUT_DIRECTORY}/image.cfs"
fi
if [ -z "${OUTPUT_FILE}" ] ; then
    echo "${SCRIPT_NAME}: Device wdnas_image.cfs not found" >&2
    exit 1
elif [ -e "${OUTPUT_FILE}" -a ! -f "${OUTPUT_FILE}" ] ; then
    echo "${SCRIPT_NAME}: ${OUTPUT_FILE} is not a regular file" >&2
    exit 1
fi

echo "Building SquashFS container file ${OUTPUT_FILE} ..."
echo "Filesystem root: ${INPUT_SQFSROOT}"
echo ""

echo "Packing image ..."
rm -f "${INPUT_SQFSNEWIMG}"
LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${SCRIPT_PATH}" \
        mksquashfs "${INPUT_SQFSROOT}" \
                   "${INPUT_SQFSNEWIMG}" \
                   -comp xz
echo "Done."
echo ""

sqfs_size=$(stat -c"%s" "${INPUT_SQFSNEWIMG}")
sqfs_calc_checksum=$(($(xor_checksum "${INPUT_SQFSNEWIMG}" 4)))

echo "Building container header ..."
printf "SquashFS size:     %d\n" ${sqfs_size}
printf "SquashFS checksum: 0x%04X\n" ${sqfs_calc_checksum}
echo ""

dd if=/dev/zero of="${OUTPUT_FILE}" bs=2048 count=1
put_integer_le_to_file_at_offset $sqfs_size "${OUTPUT_FILE}" 0 4
put_integer_le_to_file_at_offset $sqfs_calc_checksum "${OUTPUT_FILE}" 4 4
dd if="${INPUT_SQFSNEWIMG}" >>"${OUTPUT_FILE}"

echo "Done."
echo ""

if [ ! -z "${BLOCK_DEV}" ] ; then
    echo "Mounting image.cfs block device ${BLOCK_DEV} ..."
    mount -o rw "${BLOCK_DEV}" "${TEMP_DIR}"

    echo "Storing image to /image.cfs on ${BLOCK_DEV} ..."
    dd if="${OUTPUT_FILE}" of="${TEMP_DIR}/image.cfs"

    echo "Done."
    echo ""
fi

cleanup
