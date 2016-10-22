#!/bin/bash

################################################################################
## 
## Build vendor firmware image for Western Digital DL2100 NAS
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
INPUT_PREFIX=
IMAGE_VERSION="2.21.119.0901.2016"
FORCE_OVERWRITE=0
FIX_PERMISSIONS=0

PATH=$PATH:$SCRIPT_PATH

usage() {
	echo "Usage: ${SCRIPT_NAME} [options] image-file"
	echo "Build vendor firmware image for Western Digital DL2100 NAS"
	echo ""
	echo -e "  <image-file>"
	echo -e "  \tOutput vendor firmware image file"
	echo -e "  "
	echo -e "Options:"
	echo -e "\t-i <name>   Input file prefix, must end in \"/\" if a"
    echo -e "\t            directory (default: current working directory)"
	echo -e "\t-v <ver>    Version information for image, must have format"
    echo -e "\t            M.mm.RRR.MMDD.YYYY (default: $IMAGE_VERSION)"
	echo -e "\t-f          Force overwriting existing <image-file>"
	echo -e "\t-x          Fix permissions on output files (set owner root,"
    echo -e "\t            group root, world rwX), use if output is on a"
    echo -e "\t            samba share"
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

while getopts ":h?i:v:fx" opt; do
    case "$opt" in
    h|\?)
        if [ ! -z $OPTARG ] ; then
            echo "${SCRIPT_NAME}: invalid option -- $OPTARG" >&2
        fi
        usage
        exit 1
        ;;
    i)
        INPUT_PREFIX=$OPTARG
        ;;
    v)
        IMAGE_VERSION=$OPTARG
        if ! echo "${IMAGE_VERSION}" | grep -Eq '^[0-9]\.[0-9]{1,2}\.[0-9]{1,3}(\.(0[1-9]|1[0-2])(0[1-9]|[1-2][0-9]|3[0-1])\.[0-9]{4})?$' ; then
            echo "${SCRIPT_NAME}: invalid version string -- ${IMAGE_VERSION}" >&2
            usage
            exit 1
        fi
        ;;
    f)
        FORCE_OVERWRITE=1
        ;;
    x)
        FIX_PERMISSIONS=1
        ;;
    esac
done

shift $((OPTIND-1))
[ "$1" = "--" ] && shift

if [ -z "$1" ] ; then
    echo "${SCRIPT_NAME}: missing argument -- image-file" >&2
    usage
    exit 1
fi

FIRMWARE_FILE=$1
if [ "${FORCE_OVERWRITE}" -eq 0 ] ; then
    if [ -f "${FIRMWARE_FILE}" ] ; then
        echo "${SCRIPT_NAME}: Firmware image ${FIRMWARE_FILE} exists" >&2
        exit 1
    fi
fi
if [ -z "${INPUT_PREFIX}" ] ; then
    INPUT_PREFIX=./
fi


# Usage: get_integer_le_from_file_at_offset <result variable name> <file name> <offset> <length>
get_integer_le_from_file_at_offset() {
    local file_name=$2
    local value_offset=$3
    local value_end=$((value_offset + $4 - 1))
    local result=0
    for i in $(seq -- $value_end -1 $value_offset) ; do
        local b=$(dd if="${file_name}" bs=1 skip=$i count=1 2>/dev/null)
        local bval=$(printf "%d" "'$b")
        result=$((result * 256 + bval))
    done
    eval "$1=\"$result\""
}

# Usage: put_integer_le_to_file_at_offset <value> <file name> <offset> <length>
function put_integer_le_to_file_at_offset() {
    local file_name=$2
    local value_offset=$3
    local value_end=$((value_offset + $4 - 1))
    local value=$1
    for i in $(seq -- $value_offset 1 $value_end) ; do
        local bval=$((value & 0x0ff))
        local bhex=$(printf '%02X' $bval)
        printf "\\x${bhex}" | dd of="${file_name}" conv=notrunc bs=1 seek=$i count=1 2>/dev/null
        value=$((value >> 8))
    done
}


images=("uImage" "uRamdisk" "image.cfs" "config_default.tar.gz")

echo "Creating main header ..."
printf "Firmware version: %s\n" "${IMAGE_VERSION}"
printf "Firmware target:  %s\n" "Aurora"
echo ""
image_start=128
first_image_start=$image_start
dd if=/dev/zero of="${FIRMWARE_FILE}" bs=$image_start count=1

# set magic number and firmware version
printf "\\x55\\xAA\\x41\\x75\\x72\\x6F\\x72\\x61\\x00\\x00\\x55\\xAA\\x00\\x14\\x06\\x01\\x01%s" "${IMAGE_VERSION}" | dd of="${FIRMWARE_FILE}" conv=notrunc bs=1 seek=48 2>/dev/null
echo "Done."
echo ""

for image_index in $(seq -- 0 1 3) ; do
    printf "Adding image %d ...\n" $image_index
    printf "Input file: %s\n" "${INPUT_PREFIX}${images[${image_index}]}"
    printf "Image name: %s\n" "${images[${image_index}]}"
    
    image_length=$(($(stat -c"%s" "${INPUT_PREFIX}${images[${image_index}]}")))
    image_checksum=$(($(xor_checksum "${INPUT_PREFIX}${images[${image_index}]}" 4)))
    
    put_integer_le_to_file_at_offset $image_start "${FIRMWARE_FILE}" $((image_index * 8)) 4
    put_integer_le_to_file_at_offset $image_length "${FIRMWARE_FILE}" $((image_index * 8 + 4)) 4
    put_integer_le_to_file_at_offset $image_checksum "${FIRMWARE_FILE}" $((32 + image_index * 4)) 4

    printf "Offset:     %d\n" $image_start
    printf "Length:     %d bytes\n" $image_length
    printf "Checksum:   %04X\n" $image_checksum
    echo ""
    
    dd if="${INPUT_PREFIX}${images[${image_index}]}" >>"${FIRMWARE_FILE}"
    echo "Done."
    echo ""
    
    image_start=$((image_start + image_length))
done

extarget_index=0
last_next_field=$((first_image_start - 4))
extarget_start=$image_start
for source_file in $(ls ${INPUT_PREFIX}ext_*.head | grep -Eo -- 'ext_[0-9]*\.head$' | grep -Eo -- '^ext_[0-9]*\.') ; do
    put_integer_le_to_file_at_offset $image_start "${FIRMWARE_FILE}" $last_next_field 4
    
    printf "Adding extraction target %04d\n" $extarget_index
    printf "Input file:  %s\n" "${INPUT_PREFIX}${source_file}head"
    printf "Offset:      %d\n" $extarget_start
    printf "Length:      %d bytes\n" 96
    
    extarget_path="$(dd if="${INPUT_PREFIX}${source_file}head" bs=1 skip=0 count=32 2>/dev/null)"
    extarget_name="$(dd if="${INPUT_PREFIX}${source_file}head" bs=1 skip=32 count=32 2>/dev/null)"
    extarget_mode=0
    get_integer_le_from_file_at_offset extarget_mode "${INPUT_PREFIX}${source_file}head" 64 2
    extarget_exec=0
    get_integer_le_from_file_at_offset extarget_exec "${INPUT_PREFIX}${source_file}head" 66 1
    
    dd if="${INPUT_PREFIX}${source_file}head" bs=96 count=1 >>"${FIRMWARE_FILE}"
    dd if=/dev/zero bs=16 count=1 >>"${FIRMWARE_FILE}"
    
    extarget_offset=$((extarget_start + 96))
    extarget_length=$(($(stat -c"%s" "${INPUT_PREFIX}${source_file}data")))
    extarget_checksum=$(($(xor_checksum "${INPUT_PREFIX}${source_file}data" 4)))
    
    put_integer_le_to_file_at_offset $extarget_offset "${FIRMWARE_FILE}" $((extarget_start + 80)) 4
    put_integer_le_to_file_at_offset $extarget_length "${FIRMWARE_FILE}" $((extarget_start + 84)) 4
    put_integer_le_to_file_at_offset $extarget_checksum "${FIRMWARE_FILE}" $((extarget_start + 88)) 4
    
    printf "Input file:  %s\n" "${INPUT_PREFIX}${source_file}data"
    printf "Offset:      %d\n" $extarget_offset
    printf "Length:      %d bytes\n" $extarget_length
    printf "Checksum:    %04X\n" $image_checksum
    printf "File name:   %s\n" "${extarget_name}"
    printf "Target path: %s\n" "${extarget_path}"
    printf "File mode:   %04d\n" $extarget_mode
    printf "Execute:     %d\n" $extarget_exec
    echo ""

    dd if="${INPUT_PREFIX}${source_file}data" >>"${FIRMWARE_FILE}"
    echo "Done."
    echo ""
    
    extarget_index=$((extarget_index + 1))
    last_next_field=$((extarget_start + 92))
    extarget_start=$((extarget_offset + extarget_length))
done

echo "Updating header checksum ..."
header_checksum=$(($(xor_checksum "${FIRMWARE_FILE}" 4 0 $first_image_start)))
put_integer_le_to_file_at_offset $header_checksum "${FIRMWARE_FILE}" $((first_image_start - 8)) 4
echo "Done."
echo ""

if [ "${FIX_PERMISSIONS}" -ne "0" ] ; then
    echo "Setting permissions ..."
    chmod ugo=rwx "${FIRMWARE_FILE}"
    chown root.root "${FIRMWARE_FILE}"
    echo "Done."
    echo ""
fi
