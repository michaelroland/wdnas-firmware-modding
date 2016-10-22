#!/bin/bash

################################################################################
## 
## Unpack vendor firmware image for Western Digital DL2100 NAS
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
OUTPUT_PREFIX=
FIX_PERMISSIONS=0


usage() {
	echo "Usage: ${SCRIPT_NAME} [options] image-file"
	echo "Unpack vendor firmware image for Western Digital DL2100 NAS"
	echo ""
	echo -e "  <image-file>"
	echo -e "  \tInput vendor firmware image file"
	echo -e "  "
	echo -e "Options:"
	echo -e "\t-o <name>   Output prefix to be prepended to output file name"
    echo -e "\t            (default: the value of <image-file> with the file"
    echo -e "\t            extension \".bin\" removed and a dash (\"-\") added)"
	echo -e "\t-x          Fix permissions on output files (set owner root,"
    echo -e "\t            group root, world rwx), use if output is on a"
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

while getopts ":h?o:x" opt; do
    case "$opt" in
    h|\?)
        if [ ! -z $OPTARG ] ; then
            echo "${SCRIPT_NAME}: invalid option -- $OPTARG" >&2
        fi
        usage
        exit 1
        ;;
    o)
        OUTPUT_PREFIX=$OPTARG
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
if [ ! -f "${FIRMWARE_FILE}" ] ; then
    echo "${SCRIPT_NAME}: Firmware image ${FIRMWARE_FILE} not found" >&2
    exit 1
fi
if [ -z "${OUTPUT_PREFIX}" ] ; then
    OUTPUT_PREFIX=$(echo "${FIRMWARE_FILE}" | awk '{gsub(/\.bin\s*$/,"",$0); print$0}')-
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


firmware_version="$(dd if="${FIRMWARE_FILE}" bs=1 skip=65 count=47 2>/dev/null)"
firmware_target="$(dd if="${FIRMWARE_FILE}" bs=1 skip=50 count=8 2>/dev/null)"
printf "Firmware version: %s\n" "${firmware_version}"
printf "Firmware target:  %s\n" "${firmware_target}"
echo ""

echo -n "${firmware_version}" >"${OUTPUT_PREFIX}version.txt"
echo -n "${firmware_target}" >"${OUTPUT_PREFIX}codename.txt"

images=("uImage" "uRamdisk" "image.cfs" "config_default.tar.gz")

for image_index in $(seq -- 0 1 3) ; do
    printf "Image %d\n" $image_index
    printf "Image name: %s\n" "${images[${image_index}]}"
    
    image_start=0
    image_length=0
    get_integer_le_from_file_at_offset image_start "${FIRMWARE_FILE}" $((image_index * 8)) 4
    get_integer_le_from_file_at_offset image_length "${FIRMWARE_FILE}" $((image_index * 8 + 4)) 4

    printf "Offset:     %d\n" $image_start
    printf "Length:     %d bytes\n" $image_length
    echo ""
    
    echo "Extracting to ${OUTPUT_PREFIX}${images[${image_index}]} ..."
    dd if="${FIRMWARE_FILE}" of="${OUTPUT_PREFIX}${images[${image_index}]}" ibs=1 skip=$image_start count=$image_length obs=2048
    if [ "${FIX_PERMISSIONS}" -ne "0" ] ; then
        echo "Setting permissions ..."
        chmod ugo=rwx "${OUTPUT_PREFIX}${images[${image_index}]}"
        chown root.root "${OUTPUT_PREFIX}${images[${image_index}]}"
    fi
    echo "Done."
    echo ""
done

extarget_index=0
extarget_start=0
get_integer_le_from_file_at_offset extarget_start "${FIRMWARE_FILE}" 124 4
while [ "${extarget_start}" -ne "0" ] ; do
    printf "Extraction target %04d\n" $extarget_index
    
    extarget_path="$(dd if="${FIRMWARE_FILE}" bs=1 skip=$((extarget_start + 0)) count=32 2>/dev/null)"
    extarget_name="$(dd if="${FIRMWARE_FILE}" bs=1 skip=$((extarget_start + 32)) count=32 2>/dev/null)"
    extarget_mode=0
    get_integer_le_from_file_at_offset extarget_mode "${FIRMWARE_FILE}" $((extarget_start + 64)) 2
    extarget_exec=0
    get_integer_le_from_file_at_offset extarget_exec "${FIRMWARE_FILE}" $((extarget_start + 66)) 1
    extarget_offset=0
    extarget_length=0
    get_integer_le_from_file_at_offset extarget_offset "${FIRMWARE_FILE}" $((extarget_start + 80)) 4
    get_integer_le_from_file_at_offset extarget_length "${FIRMWARE_FILE}" $((extarget_start + 84)) 4
    
    printf "File name:   %s\n" "${extarget_name}"
    printf "Offset:      %d\n" $extarget_offset
    printf "Length:      %d bytes\n" $extarget_length
    printf "Target path: %s\n" "${extarget_path}"
    printf "File mode:   %04d\n" $extarget_mode
    printf "Execute:     %d\n" $extarget_exec
    echo ""
    
    extract_file=$(printf "ext_%04d" $extarget_index)
    echo "Extracting to ${OUTPUT_PREFIX}${extract_file} ..."
    dd if="${FIRMWARE_FILE}" of="${OUTPUT_PREFIX}${extract_file}.head" ibs=1 skip=$extarget_start count=80 obs=80
    dd if="${FIRMWARE_FILE}" of="${OUTPUT_PREFIX}${extract_file}.data" ibs=1 skip=$extarget_offset count=$extarget_length obs=2048
    if [ "${FIX_PERMISSIONS}" -ne "0" ] ; then
        echo "Setting permissions ..."
        chmod ugo=rwx "${OUTPUT_PREFIX}${extract_file}.head" "${OUTPUT_PREFIX}${extract_file}.data"
        chown root.root "${OUTPUT_PREFIX}${extract_file}.head" "${OUTPUT_PREFIX}${extract_file}.data"
    fi
    echo "Done."
    echo ""
    
    extarget_index=$((extarget_index + 1))
    get_integer_le_from_file_at_offset extarget_start "${FIRMWARE_FILE}" $((extarget_start + 92)) 4
done
