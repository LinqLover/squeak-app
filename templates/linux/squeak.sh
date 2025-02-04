#!/usr/bin/env bash
# File:        squeak.sh
# Author:      Fabio Niephaus, K K Subramaniam, Marcel Taeumel
# Version:     2.6.0
# Date:        2022/01/05
# Description: Script to launch Squeak executable from a bundle
# usage:
#    squeak [<vmargs>] [ *.image [ <stargs> ... ]]

# extract top directory and app name from command
ROOT=$(cd -P $(dirname "$0"); pwd)
APP="%VM_NAME%"

CONF_FILEPATH="/etc/security/limits.d/${APP}.conf"
OS=$(uname -s)
CPU=$(uname -m)
case "${CPU}" in
    # "x86_64") ;;
    # "i686") ;;
    "i386") CPU="i686" ;;
    "aarch64") CPU="arm64" ;;
    # "arm64") ;;
    "armv6l"|"armv7l") CPU="arm" ;;
esac

if [[ -d ${ROOT}/bin ]]; then
    BINDIR="${ROOT}/bin"
    RESOURCES="${ROOT}/shared"
else # all-in-one bundle
    IMAGE_BITS="%IMAGE_BITS%"
    if [[ "${IMAGE_BITS}" == "32" ]]; then
        case "${CPU}" in
            "x86_64")
                CPU="i686"
                echo "Running 32-bit Squeak on a 64-bit System. install-libs32 may install them."
                ;;
            "arm64")
                echo "You cannot run a 32-bit Squeak on a 64-bit ARM platform."
                exit 1
                ;;
        esac
    fi

    aioAppPath="${ROOT}/%AIO_APP_NAME%"
    BINDIR="${aioAppPath}/Contents/Linux-${CPU}/"
    RESOURCES="${aioAppPath}/Contents/Resources/"
    IMAGE="${RESOURCES}/%SqueakImageName%"
fi

VM="${BINDIR}/${APP}"
VMOPTIONS="-encoding UTF-8"
STARGS=()

# separate vm and script arguments
while [[ -n "$1" ]] ; do
    case "$1" in
         *.image) break;;
         *.st|*.cs) STARGS+=("$1");;
	 --) break;;
         *) VMARGS="${VMARGS} $1";;
    esac
    shift
done
while [[ -n "$1" ]]; do
    case "$1" in
         *.image) IMAGE="$1";;
	 *) STARGS+=("$1");;
    esac
    shift
done

showerror() {
  if [[ -n "${DISPLAY}" && -x "$(command -v kdialog)" ]]; then
    kdialog --error "$1"
  elif [[ -n "${DISPLAY}" && -x "$(command -v zenity)" ]]; then
    zenity --error --text "$1"
  elif [[ -x "$(command -v dialog)" ]]; then
    dialog --msgbox "$1" 0 0
  else
    printf "ERROR: %s" "$1" 1>&2
  fi
}

# Ensure that Linux kernel is newer than 2.6.12 which is required for the heartbeat thread
ensure_linux_kernel() {
  local kernel_release="$(uname -r)"
  local re="[^0-9]*\([0-9]*\)[.]\([0-9]*\)[.]\([0-9]*\)\(.*\)"
  local major=$(echo "${kernel_release}" | sed -e "s#${re}#\1#")
  local minor=$(echo "${kernel_release}" | sed -e "s#${re}#\2#")
  local patch=$(echo "${kernel_release}" | sed -e "s#${re}#\3#")
  # 2.6.12
  local min_major="2"
  local min_minor="6"
  local min_patch="12"

  if [[ "${major}" -lt "${min_major}" ]] || \
     [[ "${major}" -le "${min_major}" && "${minor}" -lt "${min_minor}" ]] || \
     [[ "${major}" -le "${min_major}" && "${minor}" -le "${min_minor}" && "${patch}" -lt "${min_patch}" ]]; then
    showerror "Linux kernel ($(uname -r)) needs to be newer than ${min_major}.${min_minor}.${min_patch}."
    exit 1
  fi

  # Check for $CONF_FILEPATH on systems with Linux kernel earlier than 4.x.x
  if [[ "${major}" -lt "4" ]]; then
    ensure_conf_file
  fi
}

# Ensure that the $CONF_FILEPATH configuration file exists and help to create one
ensure_conf_file() {
  local user_input
  if ! [[ -f "${CONF_FILEPATH}" ]]; then
    read -p "${CONF_FILEPATH} is missing. Do you want to create one?
This operation requires sudo permissions. (y/N): " user_input
    if [[ "${user_input}" = "y" ]]; then
      echo "You may be asked to enter your password..."
      sudo tee -a "${CONF_FILEPATH}" > /dev/null <<END
*       hard    rtprio  2
*       soft    rtprio  2
END
      echo "Done! Please log out and log back in before you try again."
    else
      echo "Operation cancelled."
    fi
    exit 0
  fi
}

ensure_vm() {
  if [[ ! -x "${VM}" ]]; then
    if [[ ! -r "${VM}" ]]; then
      showerror "This Squeak version does not support $(uname -s)-${CPU}."
    else
      showerror "Squeak does not have permissions to execute."
    fi
  fi
}

# Ensure that an image is selected
ensure_image() {
  local image_count
  # zenity is part of GNOME
  if [[ -z "${IMAGE}" ]]; then
    image_count=$(ls "${RESOURCES}"/*.image 2>/dev/null | wc -l)
    if which zenity &>/dev/null && [[ "$image_count" -ne 1 ]]; then
      IMAGE=$(zenity --title 'Select an image' --file-selection --filename "${RESOURCES}/" --file-filter '*.image' --file-filter '*')
    else
      # Try to find first .image file in RESOURCES directory not starting with a dot
      IMAGE="$(find "${RESOURCES}" -maxdepth 1 \( -iname "*.image" ! -iname ".*" \) | head -n 1)"
    fi
  fi
}

detect_sound() {
    if pulseaudio --check 2>/dev/null ; then
        if "${VM}" --help 2>/dev/null | grep -q vm-sound-pulse ; then
	    VMOPTIONS="${VMOPTIONS} -vm-sound-pulse"
        else
            VMOPTIONS="${VMOPTIONS} -vm-sound-oss"
            if padsp true 2>/dev/null; then
                SOUNDSERVER=padsp
            fi
        fi
    fi
}

[[ "${OS}" == Linux ]] && ensure_linux_kernel
ensure_vm
ensure_image
detect_sound

echo "Using ${VM} ..."
exec ${SOUNDSERVER} "${VM}" ${VMOPTIONS} ${VMARGS} "${IMAGE}" "${STARGS[@]}"
