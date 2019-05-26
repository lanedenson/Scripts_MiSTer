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

# Copyright 2019 Alessandro "Locutus73" Miele

# You can download the latest version of this script from:
# https://github.com/MiSTer-devel/Scripts_MiSTer

# Version 1.0.3 - 2019-05-26 - Improved DEB packages downloading routine.
# Version 1.0.2 - 2019-05-26 - Added error checks during DEB packages downloading.
# Version 1.0.1 - 2019-05-26 - Added Windows(CrLf)<->Unix(Lf) character handling.
# Version 1.0 - 2019-05-26 - First commit



# ========= OPTIONS ==================

# ========= ADVANCED OPTIONS =========
MISTER_INI_FILE="/media/fat/config/MiSTer.ini"

INI_KEYS="video_mode video_mode_ntsc video_mode_pal vsync_adjust vscale_mode hdmi_limited dvi_mode vga_scaler forced_scandoubler ypbpr composite_sync hdmi_audio_96k fb_size video_info font volumectl"

KEY_video_mode=(
	"Video resolution and frequency"
	"0|1280x720 60Hz"
	"1|1024x768 60Hz"
	"2|720x480 60Hz"
	"3|720x576 50Hz"
	"4|1280x1024 60Hz"
	"5|800x600 60Hz"
	"6|640x480 60Hz"
	"7|1280x720 50Hz"
	"8|1920x1080 60Hz"
	"9|1920x1080 50Hz"
	"10|1366x768 60Hz"
	"11|1024x600 60Hz"
)

KEY_video_mode_ntsc=(
	"Video resolution and frequency for NTSC cores"
	"0|1280x720 60Hz"
	"1|1024x768 60Hz"
	"2|720x480 60Hz"
	"3|720x576 50Hz"
	"4|1280x1024 60Hz"
	"5|800x600 60Hz"
	"6|640x480 60Hz"
	"7|1280x720 50Hz"
	"8|1920x1080 60Hz"
	"9|1920x1080 50Hz"
	"10|1366x768 60Hz"
	"11|1024x600 60Hz"
)

KEY_video_mode_pal=(
	"Video resolution and frequency PAL cores"
	"0|1280x720 60Hz"
	"1|1024x768 60Hz"
	"2|720x480 60Hz"
	"3|720x576 50Hz"
	"4|1280x1024 60Hz"
	"5|800x600 60Hz"
	"6|640x480 60Hz"
	"7|1280x720 50Hz"
	"8|1920x1080 60Hz"
	"9|1920x1080 50Hz"
	"10|1366x768 60Hz"
	"11|1024x600 60Hz"
)

KEY_vscale_mode=(
	"Video scaling mode"
	"0|Scale to fit the screen height|Some possible shimmering during vertical scroolling, not optimal for scanlines"
	"1|Use integer scale only|No shimmering during vertical scroolling, optimal for scanlines"
	"2|Use 0.5 steps of scale|Some possible shimmering during vertical scroolling, good scanlines"
	"3|Use 0.25 steps of scale|Some possible shimmering during vertical scroolling, good scanlines"
)

KEY_vsync_adjust=(
	"Video scaling sync frequency"
	"0|Match display frequency|Best display compatibility, some stuttering, 1-2 frames of lag"
	"1|Match core frequency (some lag, possible incompatibilities)|Some display incompatibilities, no stuttering, 1-2 frames of lag"
	"2|Low lag|Some display incompatibilities, no stuttering, virtually no lag"
)

KEY_hdmi_limited=(
	"Sets HDMI RGB output to limited (16 to 235, full range otherwise)"
	"0|Off"
	"1|On"
)

KEY_dvi_mode=(
	"Sets DVI mode on HDMI output"
	"0|Off|Audio will be transmitted through HDMI"
	"1|On|Audio won't be transmitted through HDMI"
)

KEY_vga_scaler=(
	"Connects VGA to the scaler output"
	"0|Off"
	"1|On"
)

KEY_forced_scandoubler=(
	"Forces scandoubler on VGA output"
	"0|Off"
	"1|On"
)

KEY_ypbpr=(
	"Sets YPbPr on VGA output"
	"0|Off"
	"1|On"
)

KEY_composite_sync=(
	"Sets composite sync on HSync signal of VGA output"
	"0|Off"
	"1|On"
)

KEY_hdmi_audio_96k=(
	"Sets HDMI audio to 96khz/16bit (48khz/16bit otherwise)"
	"0|Off"
	"1|On"
)

KEY_fb_size=(
	"Framebuffer resolution"
	"0|Automatic"
	"1|Full size"
	"2|1/2 of resolution"
	"4|1/4 of resolution"	
)

KEY_video_info=(
	"Sets the number of seconds video info will be displayed on startup/change"
	"0|Off"
	"1|1 second"
	"2|2 seconds"
	"3|3 seconds"
	"4|4 seconds"
	"5|5 seconds"
	"6|6 seconds"
	"7|7 seconds"
	"8|8 seconds"
	"9|9 seconds"
	"10|10 seconds"
)

KEY_font=(
	"Custom font. Put custom fonts in /media/fat/font"
)

KEY_volumectl=(
	"Enables audio volume control with multimedia keys"
	"0|Off"
	"1|on"
)

ALLOW_INSECURE_SSL="true"



# ========= CODE STARTS HERE =========

function checkTERMINAL {
	if [ "$(uname -n)" != "MiSTer" ]
	then
		echo "This script must be run"
		echo "on a MiSTer system."
		exit 1
	fi
	if [[ ! (-t 0 && -t 1 && -t 2) ]]
	then
		echo "This script must be run"
		echo "from an interactive terminal."
		echo "Please press F9 (F12 to exit)"
		echo "or use SSH."
		exit 2
	fi
}

function setupScriptINI {
	# get the name of the script, or of the parent script if called through a 'curl ... | bash -'
	ORIGINAL_SCRIPT_PATH="${0}"
	[[ "${ORIGINAL_SCRIPT_PATH}" == "bash" ]] && \
		ORIGINAL_SCRIPT_PATH="$(ps -o comm,pid | awk -v PPID=${PPID} '$2 == PPID {print $1}')"

	# ini file can contain user defined variables (as bash commands)
	# Load and execute the content of the ini file, if there is one
	INI_PATH="${ORIGINAL_SCRIPT_PATH%.*}.ini"
	if [[ -f "${INI_PATH}" ]] ; then
		TMP=$(mktemp)
		# preventively eliminate DOS-specific format and exit command  
		dos2unix < "${INI_PATH}" 2> /dev/null | grep -v "^exit" > ${TMP}
		source ${TMP}
		rm -f ${TMP}
	fi
}

function setupCURL
{
	[ ! -z "${CURL}" ] && return
	CURL_RETRY="--connect-timeout 15 --max-time 120 --retry 3 --retry-delay 5"
	# test network and https by pinging the most available website 
	SSL_SECURITY_OPTION=""
	curl ${CURL_RETRY} --silent https://google.com > /dev/null 2>&1
	case $? in
		0)
			;;
		60)
			if [[ "${ALLOW_INSECURE_SSL}" == "true" ]]
			then
				SSL_SECURITY_OPTION="--insecure"
			else
				echo "CA certificates need"
				echo "to be fixed for"
				echo "using SSL certificate"
				echo "verification."
				echo "Please fix them i.e."
				echo "using security_fixes.sh"
				exit 2
			fi
			;;
		*)
			echo "No Internet connection"
			exit 1
			;;
	esac
	CURL="curl ${CURL_RETRY} ${SSL_SECURITY_OPTION} --location"
	CURL_SILENT="${CURL} --silent --fail"
}

function installDEBS () {
	DEB_REPOSITORIES=( "${@}" )
	TEMP_PATH="/tmp"
	for DEB_REPOSITORY in "${DEB_REPOSITORIES[@]}"; do
		OLD_IFS="${IFS}"
		IFS="|"
		PARAMS=(${DEB_REPOSITORY})
		DEBS_URL="${PARAMS[0]}"
		DEB_PREFIX="${PARAMS[1]}"
		ARCHIVE_FILES="${PARAMS[2]}"
		STRIP_COMPONENTS="${PARAMS[3]}"
		DEST_DIR="${PARAMS[4]}"
		IFS="${OLD_IFS}"
		if [ ! -f "${DEST_DIR}/$(echo $ARCHIVE_FILES | sed 's/*//g')" ]
		then
			DEB_NAMES=$(${CURL_SILENT} "${DEBS_URL}" | grep -oE "\"${DEB_PREFIX}[a-zA-Z0-9%./_+-]*_(armhf|all)\.deb\"" | sed 's/\"//g')
			MAX_VERSION=""
			MAX_DEB_NAME=""
			for DEB_NAME in $DEB_NAMES; do
				CURRENT_VERSION=$(echo "${DEB_NAME}" | grep -o '_[a-zA-Z0-9%.+-]*_' | sed 's/_//g')
				if [[ "${CURRENT_VERSION}" > "${MAX_VERSION}" ]]
				then
					MAX_VERSION="${CURRENT_VERSION}"
					MAX_DEB_NAME="${DEB_NAME}"
				fi
			done
			[ "${MAX_DEB_NAME}" == "" ] && echo "Error searching for ${DEB_PREFIX} in ${DEBS_URL}" && exit 1
			echo "Downloading ${MAX_DEB_NAME}"
			${CURL} "${DEBS_URL}/${MAX_DEB_NAME}" -o "${TEMP_PATH}/${MAX_DEB_NAME}"
			[ ! -f "${TEMP_PATH}/${MAX_DEB_NAME}" ] && echo "Error: no ${TEMP_PATH}/${MAX_DEB_NAME} found." && exit 1
			echo "Extracting ${ARCHIVE_FILES}"
			ORIGINAL_DIR="$(pwd)"
			cd "${TEMP_PATH}"
			rm data.tar.xz > /dev/null 2>&1
			ar -x "${TEMP_PATH}/${MAX_DEB_NAME}" data.tar.xz
			cd "${ORIGINAL_DIR}"
			rm "${TEMP_PATH}/${MAX_DEB_NAME}"
			mkdir -p "${DEST_DIR}"
			[ ! -f "${TEMP_PATH}/data.tar.xz" ] && echo "Error: no ${TEMP_PATH}/data.tar.xz found." && exit 1
			tar -xJf "${TEMP_PATH}/data.tar.xz" --wildcards --no-anchored --strip-components="${STRIP_COMPONENTS}" -C "${DEST_DIR}" "${ARCHIVE_FILES}"
			rm "${TEMP_PATH}/data.tar.xz" > /dev/null 2>&1
		fi
	done
}

function setupDIALOG {
	if which dialog > /dev/null 2>&1
	then
		DIALOG="dialog"
	else
		if [ ! -f /media/fat/linux/dialog/dialog ]
		then
			setupCURL
			installDEBS "http://http.us.debian.org/debian/pool/main/d/dialog|dialog_1.3-2016|dialog|3|/media/fat/linux/dialog" "http://http.us.debian.org/debian/pool/main/n/ncurses|libncursesw5_6.0|libncursesw.so.5*|3|/media/fat/linux/dialog" "http://http.us.debian.org/debian/pool/main/n/ncurses|libtinfo5_6.0|libtinfo.so.5*|3|/media/fat/linux/dialog"
		fi
		DIALOG="/media/fat/linux/dialog/dialog"
	fi
	export LD_LIBRARY_PATH="/media/fat/linux/dialog"
	export NCURSES_NO_UTF8_ACS=1
	export DIALOGRC="/media/fat/config/dialogrc"
	
	if [ ! -f "${DIALOGRC}" ]
	then
		${DIALOG} --create-rc "${DIALOGRC}"
		sed -i "s/use_colors = OFF/use_colors = ON/g" "${DIALOGRC}"
		sed -i "s/screen_color = (CYAN,BLUE,ON)/screen_color = (CYAN,BLACK,ON)/g" "${DIALOGRC}"
		sync
	fi
	
	: ${DIALOG_OK=0}
	: ${DIALOG_CANCEL=1}
	: ${DIALOG_HELP=2}
	: ${DIALOG_EXTRA=3}
	: ${DIALOG_ITEM_HELP=4}
	: ${DIALOG_ESC=255}

	: ${SIG_NONE=0}
	: ${SIG_HUP=1}
	: ${SIG_INT=2}
	: ${SIG_QUIT=3}
	: ${SIG_KILL=9}
	: ${SIG_TERM=15}
}

function setupDIALOGtempfile {
	DIALOG_TEMPFILE=`(DIALOG_TEMPFILE) 2>/dev/null` || DIALOG_TEMPFILE=/tmp/dialog_tempfile$$
	trap "rm -f $DIALOG_TEMPFILE" 0 $SIG_NONE $SIG_HUP $SIG_INT $SIG_QUIT $SIG_TERM
}

function readDIALOGtempfile {
	DIALOG_RETVAL=$?
	DIALOG_OUTPUT="$(cat ${DIALOG_TEMPFILE})"
	#rm -f ${DIALOG_TEMPFILE}
	#unset DIALOG_TEMPFILE
}

function loadMiSTerINI {
	if [ ! -f "${MISTER_INI_FILE}" ]
	then
		echo "Downloading MiSTer.ini"
		${CURL} "https://github.com/MiSTer-devel/Main_MiSTer/blob/master/MiSTer.ini?raw=true" -o "${MISTER_INI_FILE}"
	fi
	MISTER_INI_ORIGINAL="$(cat "${MISTER_INI_FILE}" | dos2unix)"
	MISTER_INI="${MISTER_INI_ORIGINAL}"
}

function checkKEY () {
	INI_KEY="${1}"
	echo "${MISTER_INI}" | grep -qE "^\s*${INI_KEY}\s*="
	return ${?}
}


function getVALUE () {
	INI_KEY="${1}"
	INI_VALUE=$(echo "${MISTER_INI}" | grep -oE "^\s*${INI_KEY}\s*=\s*[a-zA-Z0-9.,/_-]+"|sed "s/^\s*${INI_KEY}\s*=\s*//")
}

function setVALUE () {
	INI_KEY="${1}"
	INI_VALUE="${2}"
	INI_VALUE=$(echo "${INI_VALUE}" | sed 's/\//\\\//g' | sed 's/\./\\\./g')
	MISTER_INI=$(echo "${MISTER_INI}" | sed "1,/^\s*$INI_KEY=[a-zA-Z0-9.,/_-]*/{s/^\s*$INI_KEY=[a-zA-Z0-9.,/_-]*/$INI_KEY=$INI_VALUE/}")
}


function showMainMENU_GUI {
	MENU_ITEMS=""
	for INI_KEY in ${INI_KEYS}; do
		checkKEY ${INI_KEY} || continue
		getVALUE "${INI_KEY}"
		INI_KEY_HELP=""
		INI_VALUE_DESCRIPTION=""
		for INDEX in $(eval echo \${!KEY_${INI_KEY}[@]}); do
			KEY_VALUE_CONFIG="$(eval echo \${KEY_${INI_KEY}[${INDEX}]})"
			if [ "${INDEX}" == "0" ]
			then
				INI_KEY_HELP="${KEY_VALUE_CONFIG}"
			else
				if echo "${KEY_VALUE_CONFIG}" | grep -q "^${INI_VALUE}|"
				then
					INI_VALUE_DESCRIPTION=$(echo "${KEY_VALUE_CONFIG}" | sed "s/^${INI_VALUE}|//" | sed "s/|.*//")
					break
				fi
			fi
		done
		[ "${INI_VALUE_DESCRIPTION}" == "" ] && INI_VALUE_DESCRIPTION="${INI_VALUE}"
		MENU_ITEMS="${MENU_ITEMS} \"${INI_KEY}\" \"${INI_VALUE_DESCRIPTION}\" \"${INI_KEY_HELP}\""
	done
	
	[ "${MISTER_INI}" == "${MISTER_INI_ORIGINAL}" ] && SAVE_BUTTON="" || SAVE_BUTTON="--extra-button --extra-label \"Save\""
	
	setupDIALOGtempfile
	eval ${DIALOG} --clear --item-help --ok-label \"Select\" \
		${SAVE_BUTTON} \
		--help-button --help-label \"Advanced...\" \
		--title \"MiSTer INI Settings\" \
		--menu \"Please choose an option you want to change.$'\n'Use arrow keys, tab, space, enter and esc.\" 0 0 0 \
		${MENU_ITEMS} \
		2> ${DIALOG_TEMPFILE}
	readDIALOGtempfile
}

function showMainMENU_EDITOR {
	EDITOR_TEMPFILE=/tmp/editor_tempfile$$
	echo "${MISTER_INI}" > "${EDITOR_TEMPFILE}"
	setupDIALOGtempfile
	eval ${DIALOG} --clear \
		--title \"MiSTer INI Settings\" \
		--editbox "${EDITOR_TEMPFILE}" 0 0 \
		2> ${DIALOG_TEMPFILE}
	readDIALOGtempfile
	rm -f "${EDITOR_TEMPFILE}"
	unset EDITOR_TEMPFILE
}

function showOptionMENU {
	INI_KEY=${DIALOG_OUTPUT}
	getVALUE "${INI_KEY}"
	MENU_ITEMS=""
	ADDITIONAL_OPTIONS=""
	getVALUE "${INI_KEY}"
	case "${INI_KEY}" in
		"font")
			[ ! -d /media/fat/font ] && return ${DIALOG_CANCEL}
			ADDITIONAL_OPTIONS="--no-items"
			INI_KEY_HELP="$(eval echo \${KEY_${INI_KEY}[0]})"
			for FONT in /media/fat/font/*.pf
			do
				INI_VALUE_RAW="${FONT}"
				# INI_VALUE_DESCRIPTION="${FONT}"
				{ echo "${FONT}" | grep -q "^${INI_VALUE}$"; } && INI_VALUE_SELECTED="ON" || INI_VALUE_SELECTED="off"
				INI_VALUE_HELP=""
				MENU_ITEMS="${MENU_ITEMS} \"${INI_VALUE_RAW}\" ${INI_VALUE_SELECTED} \"${INI_VALUE_HELP}\""
			done
			;;
		*)
			for INDEX in $(eval echo \${!KEY_${INI_KEY}[@]}); do
				KEY_VALUE_CONFIG="$(eval echo \${KEY_${INI_KEY}[${INDEX}]})"
				if [ "${INDEX}" == "0" ]
				then
					INI_KEY_HELP="${KEY_VALUE_CONFIG}"
				else
					INI_VALUE_RAW=$(echo "${KEY_VALUE_CONFIG}" | sed "s/|.*//")
					INI_VALUE_DESCRIPTION=$(echo "${KEY_VALUE_CONFIG}" | sed "s/^[^|]*|//" | sed "s/|.*//")
					{ echo "${KEY_VALUE_CONFIG}" | grep -q "^${INI_VALUE}|"; } && INI_VALUE_SELECTED="ON" || INI_VALUE_SELECTED="off"
					{ echo "${KEY_VALUE_CONFIG}" | grep -q "|.*|"; } && INI_VALUE_HELP=$(echo "${KEY_VALUE_CONFIG}" | sed "s/^.*|//") || INI_VALUE_HELP=""
					MENU_ITEMS="${MENU_ITEMS} \"${INI_VALUE_RAW}\" \"${INI_VALUE_DESCRIPTION}\" ${INI_VALUE_SELECTED} \"${INI_VALUE_HELP}\""
				fi
			done
			;;
	esac
	
	setupDIALOGtempfile
	eval ${DIALOG} --clear  --item-help \
		--title \"MiSTer INI Settings\" \
		${ADDITIONAL_OPTIONS} \
		--radiolist \"${INI_KEY_HELP}\" 0 0 0 \
		${MENU_ITEMS} \
		2> ${DIALOG_TEMPFILE}
	readDIALOGtempfile
}



checkTERMINAL
setupScriptINI
setupCURL
setupDIALOG

loadMiSTerINI

SHOW_GUI="true"

while true; do
	if [ "${SHOW_GUI}" == "true" ]
	then
		showMainMENU_GUI
		case ${DIALOG_RETVAL} in
			${DIALOG_OK})
				# OK=Select INI key to change
				INI_KEY=${DIALOG_OUTPUT}
				showOptionMENU
				case ${DIALOG_RETVAL} in
					${DIALOG_OK})
						INI_VALUE="${DIALOG_OUTPUT}"
						setVALUE "${INI_KEY}" "${INI_VALUE}"
						;;
					${DIALOG_CANCEL})
						;;
					${DIALOG_ESC})
						break;;
				esac
				;;
			${DIALOG_CANCEL})
				break;;
			${DIALOG_HELP})
				# Help=Advanced... manual INI editor
				SHOW_GUI="false"
				;;
			${DIALOG_EXTRA})
				# Extra=Save
				cp "${MISTER_INI_FILE}" "${MISTER_INI_FILE}.bak"
				echo "${MISTER_INI}" | unix2dos > "${MISTER_INI_FILE}"
				sync
				${DIALOG} --clear --title "MiSTer INI Settings" --defaultno --yesno "Do you want to reboot in order to apply the changes?" 0 0 && reboot now
				break;;
			${DIALOG_ESC})
				break;;
		esac
	else
		showMainMENU_EDITOR
		case ${DIALOG_RETVAL} in
			${DIALOG_OK})
				MISTER_INI="${DIALOG_OUTPUT}"
				SHOW_GUI="true"
				;;
			${DIALOG_CANCEL})
				SHOW_GUI="true"
				;;
			${DIALOG_ESC})
				break;;
		esac
	fi
done

clear

exit 0