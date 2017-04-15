#!/bin/bash

################################################################################
## 
## Patch support for customizable startup scripts into config partition of Western Digital DL2100 NAS
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
CONFIG_DIR=/usr/local/config


usage() {
	echo "Usage: ${SCRIPT_NAME} [options]"
	echo "Patch support for customizable startup scripts into config partition of Western Digital DL2100 NAS"
	echo ""
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

while getopts ":h?d:" opt; do
    case "$opt" in
    h|\?)
        if [ ! -z $OPTARG ] ; then
            echo "${SCRIPT_NAME}: invalid option -- $OPTARG" >&2
        fi
        usage
        exit 1
        ;;
    d)
        BLOCK_DEV=$OPTARG
        ;;
    esac
done

shift $((OPTIND-1))
[ "$1" = "--" ] && shift


TEMP_DIR=$(mktemp -d)

cleanup() {
	trap SIGINT
	if [ ! -z "${TEMP_DIR}" ] ; then
        if [ -d "${TEMP_DIR}" ] ; then
            rm -rf "${TEMP_DIR}"
        fi
    fi
}

interrupted() {
	cleanup
	exit 1
}

trap 'interrupted' INT

echo "Adding customizable startup scripts ..."
echo ""

SCRIPT_BOOTING_LAST="custom_booting_last.sh"
SCRIPT_HARDWARE_INIT="custom_hardware_init.sh"
SCRIPT_BOOTING_INIT="custom_booting_init.sh"


if [ ! -e "${CONFIG_DIR}/${SCRIPT_BOOTING_LAST}" ] ; then
    echo "Creating ${SCRIPT_BOOTING_LAST} ..."
    cat >>"${TEMP_DIR}/${SCRIPT_BOOTING_LAST}" <<END
#!/bin/bash
# 
# This file is executed after /usr/local/modules/script/system_init
# 
# Add commands to be run at the end of boot process here


END
    chmod u=rwx,go=rx "${TEMP_DIR}/${SCRIPT_BOOTING_LAST}"
    chown root.root "${TEMP_DIR}/${SCRIPT_BOOTING_LAST}"
    
    echo "Adding ${CONFIG_DIR}/${SCRIPT_BOOTING_LAST} ..."
    access_mtd "mv -f \"${TEMP_DIR}/${SCRIPT_BOOTING_LAST}\" \"${CONFIG_DIR}/${SCRIPT_BOOTING_LAST}\""
    echo "Done."
else
    echo "Skipping; ${CONFIG_DIR}/${SCRIPT_BOOTING_LAST} exists"
fi
echo ""


if [ ! -e "${CONFIG_DIR}/${SCRIPT_HARDWARE_INIT}" ] ; then
    echo "Creating ${SCRIPT_HARDWARE_INIT} ..."
    cat >>"${TEMP_DIR}/${SCRIPT_HARDWARE_INIT}" <<END
#!/bin/bash
# 
# This file is executed after /usr/local/modules/script/hardware_init.sh
# 
# Add commands to be run early during the boot process here


END
    chmod u=rwx,go=rx "${TEMP_DIR}/${SCRIPT_HARDWARE_INIT}"
    chown root.root "${TEMP_DIR}/${SCRIPT_HARDWARE_INIT}"
    
    echo "Adding ${CONFIG_DIR}/${SCRIPT_HARDWARE_INIT} ..."
    access_mtd "mv -f \"${TEMP_DIR}/${SCRIPT_HARDWARE_INIT}\" \"${CONFIG_DIR}/${SCRIPT_HARDWARE_INIT}\""
    echo "Done."
else
    echo "Skipping; ${CONFIG_DIR}/${SCRIPT_HARDWARE_INIT} exists"
fi
echo ""


if [ ! -e "${CONFIG_DIR}/${SCRIPT_BOOTING_INIT}" ] ; then
    echo "Adding ${SCRIPT_BOOTING_INIT} ..."
    cat >>"${TEMP_DIR}/${SCRIPT_BOOTING_INIT}" <<END
#!/bin/bash
# 
# This file is executed after /usr/local/modules/localsbin/custom_booting_init.sh
# 
# Add commands to be run at bootup after all core components are up and running here


END
    chmod u=rwx,go=rx "${TEMP_DIR}/${SCRIPT_BOOTING_INIT}"
    chown root.root "${TEMP_DIR}/${SCRIPT_BOOTING_INIT}"
    
    echo "Adding ${CONFIG_DIR}/${SCRIPT_BOOTING_INIT} ..."
    access_mtd "mv -f \"${TEMP_DIR}/${SCRIPT_BOOTING_INIT}\" \"${CONFIG_DIR}/${SCRIPT_BOOTING_INIT}\""
    echo "Done."
else
    echo "Skipping; ${CONFIG_DIR}/${SCRIPT_BOOTING_INIT} exists"
fi
echo ""


cleanup
