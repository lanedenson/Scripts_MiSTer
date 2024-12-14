#!/bin/bash

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Copyright 2018-2023 Alessandro "Locutus73" Miele

# Version 2.2.0 - 2023-11-16 - Streamlined script, improved error handling, and updated Github link.

#=========   USER OPTIONS   =========
#You can edit these user options or make an ini file with the same
#name as the script, i.e. mount_cifs.ini, containing the same options.

#Your CIFS Server, i.e. your NAS name or its IP address.
SERVER=""

#The share name on the Server.
SHARE="MiSTer"

#Use this if only a specific directory from the share's root should be mounted.
SHARE_DIRECTORY=""

#The user name, leave blank for guest access.
USERNAME=""

#The user password, irrelevant (leave blank) for guest access.
PASSWORD=""

#Optional user domain, when in doubt leave blank.
DOMAIN=""

#Local directory/directories where the share will be mounted.
#- It can ba a single directory, i.e. "cifs", so the remote share, i.e. \\NAS\MiSTer
#  will be directly mounted on /media/fat/cifs (/media/fat is the root of the SD card).
#  NOTE: /media/fat/cifs is a special location that the mister binary will try before looking in
# the standard games location of /media/fat/games, so "cifs" is the suggested setting.
#- It can be a pipe "|" separated list of directories, i.e. "Amiga|C64|NES|SNES",
#  so the share subdirectiories with those names,
#  i.e. \\NAS\MiSTer\Amiga, \\NAS\MiSTer\C64, \\NAS\MiSTer\NES and \\NAS\MiSTer\SNES
#  will be mounted on local /media/fat/Amiga, /media/fat/C64, /media/fat/NES and /media/fat/SNES.
#- It can be an asterisk "*": when SINGLE_CIFS_CONNECTION="true",
#  all the directories in the remote share will be listed and mounted locally,
#  except the special ones (i.e. linux and config);
#  when SINGLE_CIFS_CONNECTION="false" all the directories in the SD root,
#  except the special ones (i.e. linux and config), will be mounted when one
#  with a matching name is found on the remote share.
LOCAL_DIR="cifs"

#Optional additional mount options, when in doubt leave blank.
#If you have problems not related to username/password, you can try "vers=2.0" or "vers=3.0".
ADDITIONAL_MOUNT_OPTIONS=""

#"true" in order to wait for the CIFS server to be reachable;
#useful when using this script at boot time.
WAIT_FOR_SERVER="false"

#"true" for automounting CIFS shares at boot time;
#it will create start/kill scripts in /etc/network/if-up.d and /etc/network/if-down.d.
MOUNT_AT_BOOT="false"



#========= ADVANCED OPTIONS =========
BASE_PATH="/media/fat"
#MISTER_CIFS_URL="https://github.com/MiSTer-devel/CIFS_MiSTer"
KERNEL_MODULES="md4.ko|md5.ko|des_generic.ko|fscache.ko|cifs.ko"
IFS="|"
SINGLE_CIFS_CONNECTION="true"
#Pipe "|" separated list of directories which will never be mounted when LOCAL_DIR="*"
SPECIAL_DIRECTORIES="config|linux|System Volume Information"

#=========CODE STARTS HERE=========
check_dependencies() {
    for KERNEL_MODULE in $KERNEL_MODULES; do
        if ! cat /lib/modules/$(uname -r)/modules.builtin | grep -q "$(echo "$KERNEL_MODULE" | sed 's/\./\\\./g')"; then
            if ! lsmod | grep -q "${KERNEL_MODULE%.*}"; then
                echo "The current Kernel doesn't support CIFS (SAMBA). Please update your MiSTer Linux system.\n"
                exit 1
            fi
        fi
    done
}

manage_boot_scripts() {
    NET_UP_SCRIPT="/etc/network/if-up.d/$(basename ${ORIGINAL_SCRIPT_PATH%.*})"
    NET_DOWN_SCRIPT="/etc/network/if-down.d/$(basename ${ORIGINAL_SCRIPT_PATH%.*})"

    if [ "$MOUNT_AT_BOOT" == "true" ]; then
        WAIT_FOR_SERVER="true"
        if [ ! -f "$NET_UP_SCRIPT" ] || [ ! -f "$NET_DOWN_SCRIPT" ]; then
            mount | grep "on / .*[(,]ro[,$]" -q && RO_ROOT="true"
            [ "$RO_ROOT" == "true" ] && mount / -o remount,rw
            echo "#!/bin/bash"$'\n'"$(realpath "$ORIGINAL_SCRIPT_PATH") &" > "$NET_UP_SCRIPT"
            chmod +x "$NET_UP_SCRIPT"
            echo "#!/bin/bash"$'\n'"umount -a -t cifs" > "$NET_DOWN_SCRIPT"
            chmod +x "$NET_DOWN_SCRIPT"
            sync
            [ "$RO_ROOT" == "true" ] && mount / -o remount,ro
        fi
    else
        if [ -f "$NET_UP_SCRIPT" ] || [ -f "$NET_DOWN_SCRIPT" ]; then
            mount | grep "on / .*[(,]ro[,$]" -q && RO_ROOT="true"
            [ "$RO_ROOT" == "true" ] && mount / -o remount,rw
            rm "$NET_UP_SCRIPT" > /dev/null 2>&1
            rm "$NET_DOWN_SCRIPT" > /dev/null 2>&1
            sync
            [ "$RO_ROOT" == "true" ] && mount / -o remount,ro
        fi
    fi
}

wait_for_server() {
    if ! echo "$SERVER" | grep -q "^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}$"; then
        echo "Waiting for $SERVER"
        until nmblookup $SERVER &>/dev/null; do
            sleep 1
        done
        SERVER=$(nmblookup $SERVER|awk 'END{print $1}')
    else
        echo "Waiting for $SERVER"
        until ping -q -w1 -c1 $SERVER &>/dev/null; do
            sleep 1
        done
    fi
}

mount_cifs() {
    MOUNT_SOURCE="//$SERVER/$SHARE"
    if [ -n "$SHARE_DIRECTORY" ] && [ -n "$MOUNT_SOURCE" ]; then
        MOUNT_SOURCE+=/$SHARE_DIRECTORY
    fi

    if [ "$USERNAME" == "" ]; then
        MOUNT_OPTIONS="sec=none"
    else
        MOUNT_OPTIONS="username=$USERNAME,password=$PASSWORD"
        if [ "$DOMAIN" != "" ]; then
            MOUNT_OPTIONS="$MOUNT_OPTIONS,domain=$DOMAIN"
        fi
    fi
    if [ "$ADDITIONAL_MOUNT_OPTIONS" != "" ]; then
        MOUNT_OPTIONS="$MOUNT_OPTIONS,$ADDITIONAL_MOUNT_OPTIONS"
    fi

    if [ "$LOCAL_DIR" == "*" ] || { echo "$LOCAL_DIR" | grep -q "|"; }; then
        if [ "$SINGLE_CIFS_CONNECTION" == "true" ]; then
            SCRIPT_NAME=${ORIGINAL_SCRIPT_PATH##*/}
            SCRIPT_NAME=${SCRIPT_NAME%.*}
            mkdir -p "/tmp/$SCRIPT_NAME" > /dev/null 2>&1
            if mount -t cifs "$MOUNT_SOURCE" "/tmp/$SCRIPT_NAME" -o "$MOUNT_OPTIONS"; then
                echo "$MOUNT_SOURCE mounted.\n"
                if [ "$LOCAL_DIR" == "*" ]; then
                    LOCAL_DIR=""
                    for DIRECTORY in "/tmp/$SCRIPT_NAME"/*; do
                        if [ -d "$DIRECTORY" ]; then
                            DIRECTORY=$(basename "$DIRECTORY")
                            for SPECIAL_DIRECTORY in $SPECIAL_DIRECTORIES; do
                                if [ "$DIRECTORY" == "$SPECIAL_DIRECTORY" ]; then
                                    DIRECTORY=""
                                    break
                                fi
                            done
                            if [ "$DIRECTORY" != "" ]; then
                                if [ "$LOCAL_DIR" != "" ]; then
                                    LOCAL_DIR="$LOCAL_DIR|"
                                fi
                                LOCAL_DIR="$LOCAL_DIR$DIRECTORY"
                            fi
                        fi
                    done
                fi
                for DIRECTORY in $LOCAL_DIR; do
                    mkdir -p "$BASE_PATH/$DIRECTORY" > /dev/null 2>&1
                    if mount --bind "/tmp/$SCRIPT_NAME/$DIRECTORY" "$BASE_PATH/$DIRECTORY"; then
                        echo -e "$DIRECTORY mounted.\n"
                    else
                        echo -e "$DIRECTORY not mounted.\n"
                    fi
                done
            else
                echo -e "$MOUNT_SOURCE not mounted.\n"
            fi
        else
            if [ "$LOCAL_DIR" == "*" ]; then
                LOCAL_DIR=""
                for DIRECTORY in "$BASE_PATH"/*; do
                    if [ -d "$DIRECTORY" ]; then
                        DIRECTORY=$(basename "$DIRECTORY")
                        for SPECIAL_DIRECTORY in $SPECIAL_DIRECTORIES; do
                            if [ "$DIRECTORY" == "$SPECIAL_DIRECTORY" ]; then
                                DIRECTORY=""
                                break
                            fi
                        done
                        if [ "$DIRECTORY" != "" ]; then
                            if [ "$LOCAL_DIR" != "" ]; then
                                LOCAL_DIR="$LOCAL_DIR|"
                            fi
                            LOCAL_DIR="$LOCAL_DIR$DIRECTORY"
                        fi
                    fi
                done
            fi
            for DIRECTORY in $LOCAL_DIR; do
                mkdir -p "$BASE_PATH/$DIRECTORY" > /dev/null 2>&1
                if mount -t cifs "$MOUNT_SOURCE" "$BASE_PATH/$DIRECTORY" -o "$MOUNT_OPTIONS"; then
                    echo -e "$DIRECTORY mounted.\n"
                else
                    echo -e "$DIRECTORY not mounted.\n"
                fi
            done
        fi
    else
        mkdir -p "$BASE_PATH/$LOCAL_DIR" > /dev/null 2>&1
        if mount -t cifs "$MOUNT_SOURCE" "$BASE_PATH/$LOCAL_DIR" -o "$MOUNT_OPTIONS"; then
            echo -e "$LOCAL_DIR mounted.\n"
            echo -e "Done!\n"

        else
            echo -e "$LOCAL_DIR not mounted.\n"
        fi
    fi
}

main() {
    ORIGINAL_SCRIPT_PATH="$0"
    if [ "$ORIGINAL_SCRIPT_PATH" == "bash" ]; then
        ORIGINAL_SCRIPT_PATH=$(ps | grep "^ *$PPID " | grep -o "[^ ]*$")
    fi
    INI_PATH=${ORIGINAL_SCRIPT_PATH%.*}.ini
    if [ -f $INI_PATH ]; then
        eval "$(cat $INI_PATH | tr -d '\r')"
    fi

    if [ "$SERVER" == "" ]; then
        echo -e "Please configure this script either editing ${ORIGINAL_SCRIPT_PATH##*/} or making a new ${INI_PATH##*/}"
        exit 1
    fi

    check_dependencies
    manage_boot_scripts
    if [ "$WAIT_FOR_SERVER" == "true" ]; then
        wait_for_server
    fi
    mount_cifs
    exit 0
}

main