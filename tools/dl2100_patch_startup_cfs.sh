#!/bin/bash

################################################################################
## 
## Patch support for customizable startup scripts into CFS filesystem of Western Digital DL2100 NAS
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
MAGIC="PjjK2y6"


usage() {
	echo "Usage: ${SCRIPT_NAME} [options] destination-directory"
	echo "Patch support for customizable startup scripts into CFS filesystem of Western Digital DL2100 NAS"
	echo ""
	echo -e "  <squashfs-root>"
	echo -e "  \tRoot directory of the extracted SquashFS filesystem"
	echo -e "  "
	echo -e "Options:"
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

while getopts ":h?" opt; do
    case "$opt" in
    h|\?)
        if [ ! -z $OPTARG ] ; then
            echo "${SCRIPT_NAME}: invalid option -- $OPTARG" >&2
        fi
        usage
        exit 1
        ;;
    esac
done

shift $((OPTIND-1))
[ "$1" = "--" ] && shift

if [ -z "$1" ] ; then
    echo "${SCRIPT_NAME}: missing argument -- squashfs-root" >&2
    usage
    exit 1
fi

ROOT_DIRECTORY=$1
if [ ! -d "${ROOT_DIRECTORY}" ] ; then
    echo "${SCRIPT_NAME}: ${ROOT_DIRECTORY} does not exists or is not a directory" >&2
    exit 1
fi


echo "Patching modifications into ${ROOT_DIRECTORY} ..."
echo ""

SCRIPT_SYSTEM_INIT="${ROOT_DIRECTORY}/script/system_init"
SCRIPT_HARDWARE_INIT="${ROOT_DIRECTORY}/script/hardware_init.sh"
SCRIPT_CUSTOM_BOOT_INIT="${ROOT_DIRECTORY}/localsbin/custom_booting_init.sh"


echo "Modifying ${SCRIPT_SYSTEM_INIT} ..."
if [ -e "${SCRIPT_SYSTEM_INIT}" ] ; then
    if grep -E "^##${MAGIC}##" "${SCRIPT_SYSTEM_INIT}" >/dev/null ; then
        echo "Skipping; modifications already present"
    else
        cat >>"${SCRIPT_SYSTEM_INIT}" <<END

##${MAGIC}## hook for customizable script at end of boot
if [ -e /usr/local/config/custom_booting_last.sh ] ; then
    /usr/local/config/custom_booting_last.sh
fi
END
        echo "Done."
    fi
else
    echo "File not found!"
fi
echo ""


echo "Modifying ${SCRIPT_HARDWARE_INIT} ..."
if [ -e "${SCRIPT_HARDWARE_INIT}" ] ; then
    if grep -E "^##${MAGIC}##" "${SCRIPT_HARDWARE_INIT}" >/dev/null ; then
        echo "Skipping; modifications already present"
    else
        cat >>"${SCRIPT_HARDWARE_INIT}" <<END

##${MAGIC}## hook for customizable script at hardware init
if [ -e /usr/local/config/custom_hardware_init.sh ] ; then
    /usr/local/config/custom_hardware_init.sh
fi
END
        echo "Done."
    fi
else
    echo "File not found!"
fi
echo ""


echo "Modifying ${SCRIPT_CUSTOM_BOOT_INIT} ..."
if [ -e "${SCRIPT_CUSTOM_BOOT_INIT}" ] ; then
    if grep -E "^##${MAGIC}##" "${SCRIPT_CUSTOM_BOOT_INIT}" >/dev/null ; then
        echo "Skipping; modifications already present"
    else
        cat >>"${SCRIPT_CUSTOM_BOOT_INIT}" <<END

##${MAGIC}## hook for customizable script at custom booting init
if [ -e /usr/local/config/custom_booting_init.sh ] ; then
    /usr/local/config/custom_booting_init.sh
fi
END
        echo "Done."
    fi
else
    echo "File not found!"
fi
echo ""
