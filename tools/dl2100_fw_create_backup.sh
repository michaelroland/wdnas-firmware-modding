#!/bin/bash

################################################################################
## 
## Create firmware backup for Western Digital DL2100 NAS
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
CURRENT_DATE=$(date +%Y%m%d-%H%M%S)
EXTRACT_DISKIMAGE=0
EXTRACT_PARTITIONIMAGE=0
EXTRACT_FILESYSTEM=0
COMPRESS_IMAGE=gzip
NO_TIMESTAMP_DIR=0
FIX_PERMISSIONS=0


usage() {
	echo "Usage: ${SCRIPT_NAME} [options] destination-directory"
	echo "Create firmware backup for Western Digital DL2100 NAS"
	echo ""
	echo -e "  <destination-directory>"
	echo -e "  \tTarget directory for storing backup files"
	echo -e "  "
	echo -e "Options:"
	echo -e "\t-d          Create whole-disk images"
	echo -e "\t-p          Create partition images"
	echo -e "\t-f          Create file system archives"
	echo -e "\t-c <comp>   Compress images using <comp>"
    echo -e "\t            (available: gzip (default), none)"
	echo -e "\t-i          Store backup directly in destination-directory"
    echo -e "\t            (default: create timestamp-based sub-directory,"
    echo -e "\t            e.g. ${CURRENT_DATE}/)"
	echo -e "\t-x          Fix permissions on <destination-directory> (set"
    echo -e "\t            owner root, group root, world rwx) for backups"
    echo -e "\t            on samba shares"
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

while getopts ":h?dpfc:ix" opt; do
    case "$opt" in
    h|\?)
        if [ ! -z $OPTARG ] ; then
            echo "${SCRIPT_NAME}: invalid option -- $OPTARG" >&2
        fi
        usage
        exit 1
        ;;
    d)
        EXTRACT_DISKIMAGE=1
        ;;
    p)
        EXTRACT_PARTITIONIMAGE=1
        ;;
    f)
        EXTRACT_FILESYSTEM=1
        ;;
    c)
        COMPRESS_IMAGE=${OPTARG,,}
        case "${COMPRESS_IMAGE}" in
            none|gzip)
                ;;
            *)
                if [ ! -z $OPTARG ] ; then
                    echo "${SCRIPT_NAME}: compression not supported -- $OPTARG" >&2
                fi
                usage
                exit 1
                ;;
        esac
        ;;
    i)
        NO_TIMESTAMP_DIR=1
        ;;
    x)
        FIX_PERMISSIONS=1
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

BACKUP_BASE_DIR=$1
if [ ! -d "${BACKUP_BASE_DIR}" ] ; then
    echo "${SCRIPT_NAME}: Target directory ${BACKUP_BASE_DIR} not found" >&2
    exit 1
fi
BACKUP_DIR=$BACKUP_BASE_DIR
if [ "${NO_TIMESTAMP_DIR}" -eq "0" ] ; then
    BACKUP_DIR=$BACKUP_DIR/$CURRENT_DATE
    mkdir -p "${BACKUP_DIR}"
fi


TEMP_DIR=$(mktemp -d)
#mkdir -p "${TEMP_DIR}"

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

firmware_devs=$(blkid | grep 'wdnas_' | awk -F: '{gsub(/^\s*/,"",$1); gsub(/[0-9]+\s*$/,"",$1); print$1}' | sort -u)
firmware_parts=$(blkid | grep 'wdnas_' | awk -F: '{gsub(/^\s*/,"",$1); gsub(/\s*$/,"",$1); print$1}' | sort -u)

if [ "${EXTRACT_DISKIMAGE}" -ne "0" ] ; then
    for i in $firmware_devs ; do
        echo "Backing up device $i ..."
        
        dev_name=$(echo "$i" | awk '{gsub(/^\/dev\//,"",$1); gsub(/\//,"_",$1); print$1}')
        echo -n "$i" >"${BACKUP_DIR}/${dev_name}-device_node.txt"
        dd if="$i" of="${BACKUP_DIR}/${dev_name}-device.img"
        
        if [ "${COMPRESS_IMAGE}" = "gzip" ] ; then
            echo "Compressing image ..."
            gzip "${BACKUP_DIR}/${dev_name}-device.img"
        fi
        
        echo "Done."
        echo ""
    done
fi

if [ "$((EXTRACT_PARTITIONIMAGE + EXTRACT_FILESYSTEM))" -ne "0" ] ; then
    for i in $firmware_parts ; do
        echo "Backing up partition $i ..."
        
        part_name=$(echo "$i" | awk '{gsub(/^\/dev\//,"",$1); gsub(/\//,"_",$1); print$1}')
        echo -n "$i" >"${BACKUP_DIR}/${part_name}-device_node.txt"
        
        part_blkid=$(blkid | grep "$i:" | awk -F: '{gsub(/^\s*/,"",$2); gsub(/\s*$/,"",$2); print$2}')
        echo -n "$part_blkid" >"${BACKUP_DIR}/${part_name}-device_blkid.txt"
        
        if [ "${EXTRACT_PARTITIONIMAGE}" -ne "0" ] ; then
            dd if="$i" of="${BACKUP_DIR}/${part_name}-partition.img"
        
            if [ "${COMPRESS_IMAGE}" = "gzip" ] ; then
                echo "Compressing image ..."
                gzip "${BACKUP_DIR}/${part_name}-partition.img"
            fi
        fi
        
        if [ "${EXTRACT_FILESYSTEM}" -ne "0" ] ; then
            echo "Mounting filesystem ..."
            mount -o ro "$i" "${TEMP_DIR}"

            if [ "${COMPRESS_IMAGE}" = "gzip" ] ; then
                echo "Packing filesystem into compressed tar ..."
                tar -zcf "${BACKUP_DIR}/${part_name}-partition_files.tar.gz" -C "${TEMP_DIR}" .
            else
                echo "Packing filesystem into tar ..."
                tar -cf "${BACKUP_DIR}/${part_name}-partition_files.tar" -C "${TEMP_DIR}" .
            fi
            
            echo "Unmounting filesystem ..."
            umount "${TEMP_DIR}"
        fi
        
        echo "Done."
        echo ""
    done
fi

if [ "${FIX_PERMISSIONS}" -ne "0" ] ; then
    echo "Setting permissions on backup files ..."
    chmod -R ugo=rwx "${BACKUP_DIR}"
    chown -R root.root "${BACKUP_DIR}"
    echo "Done."
    echo ""
fi

cleanup
