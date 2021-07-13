#!/bin/bash

set -e

#############################################################################
#                                                                           #
# Project 'pterodactyl-installer'                                           #
#                                                                           #
# Copyright (C) 2018 - 2021, Vilhelm Prytz, <vilhelm@prytznet.se>           #
#                                                                           #
#   This program is free software: you can redistribute it and/or modify    #
#   it under the terms of the GNU General Public License as published by    #
#   the Free Software Foundation, either version 3 of the License, or       #
#   (at your option) any later version.                                     #
#                                                                           #
#   This program is distributed in the hope that it will be useful,         #
#   but WITHOUT ANY WARRANTY; without even the implied warranty of          #
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           #
#   GNU General Public License for more details.                            #
#                                                                           #
#   You should have received a copy of the GNU General Public License       #
#   along with this program.  If not, see <https://www.gnu.org/licenses/>.  #
#                                                                           #
# https://github.com/vilhelmprytz/pterodactyl-installer/blob/master/LICENSE #
#                                                                           #
# This script is not associated with the official Pterodactyl Project.      #
# https://github.com/vilhelmprytz/pterodactyl-installer                     #
#                                                                           #
#############################################################################

# versioning
SCRIPT_RELEASE="canary"

# exit with error status code if user is not root
if [[ $EUID -ne 0 ]]; then
  echo "* This script must be executed with root privileges (sudo)." 1>&2
  exit 1
fi

output() {
  echo -e "* ${1}"
}

error() {
  COLOR_RED='\033[0;31m'
  COLOR_NC='\033[0m'

  echo ""
  echo -e "* ${COLOR_RED}ERROR${COLOR_NC}: $1"
  echo ""
}

####### OS check funtions #######

detect_distro() {
  if [ -f /etc/os-release ]; then
    # freedesktop.org and systemd
    . /etc/os-release
    OS=$(echo "$ID" | awk '{print tolower($0)}')
    OS_VER=$VERSION_ID
  elif type lsb_release >/dev/null 2>&1; then
    # linuxbase.org
    OS=$(lsb_release -si | awk '{print tolower($0)}')
    OS_VER=$(lsb_release -sr)
  elif [ -f /etc/lsb-release ]; then
    # For some versions of Debian/Ubuntu without lsb_release command
    . /etc/lsb-release
    OS=$(echo "$DISTRIB_ID" | awk '{print tolower($0)}')
    OS_VER=$DISTRIB_RELEASE
  elif [ -f /etc/debian_version ]; then
    # Older Debian/Ubuntu/etc.
    OS="debian"
    OS_VER=$(cat /etc/debian_version)
  elif [ -f /etc/SuSe-release ]; then
    # Older SuSE/etc.
    OS="SuSE"
    OS_VER="?"
  elif [ -f /etc/redhat-release ]; then
    # Older Red Hat, CentOS, etc.
    OS="Red Hat/CentOS"
    OS_VER="?"
  else
    # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
    OS=$(uname -s)
    OS_VER=$(uname -r)
  fi

  OS=$(echo "$OS" | awk '{print tolower($0)}')
  OS_VER_MAJOR=$(echo "$OS_VER" | cut -d. -f1)
}

check_os_comp() {
  CPU_ARCHITECTURE=$(uname -m)
  if [ "${CPU_ARCHITECTURE}" != "x86_64" ]; then # check the architecture
    print_warning "Detected CPU architecture $CPU_ARCHITECTURE"
    print_warning "Using any other architecture than 64 bit (x86_64) will cause problems."

    echo -e -n "* Are you sure you want to proceed? (y/N):"
    read -r choice

    if [[ ! "$choice" =~ [Yy] ]]; then
      print_error "Installation aborted!"
      exit 1
    fi
  fi

  case "$OS" in
  ubuntu)
    PHP_SOCKET="/run/php/php8.0-fpm.sock"
    [ "$OS_VER_MAJOR" == "18" ] && SUPPORTED=true
    [ "$OS_VER_MAJOR" == "20" ] && SUPPORTED=true
    ;;
  debian)
    PHP_SOCKET="/run/php/php8.0-fpm.sock"
    [ "$OS_VER_MAJOR" == "9" ] && SUPPORTED=true
    [ "$OS_VER_MAJOR" == "10" ] && SUPPORTED=true
    ;;
  centos)
    PHP_SOCKET="/var/run/php-fpm/pterodactyl.sock"
    [ "$OS_VER_MAJOR" == "7" ] && SUPPORTED=true
    [ "$OS_VER_MAJOR" == "8" ] && SUPPORTED=true
    ;;
  *)
    SUPPORTED=false
    ;;
  esac

  # exit if not supported
  if [ "$SUPPORTED" == true ]; then
    echo "* $OS $OS_VER is supported."
  else
    echo "* $OS $OS_VER is not supported"
    print_error "Unsupported OS"
    exit 1
  fi
}

##### OS specific install functions #####

apt_update() {
  apt update -q -y && apt upgrade -y
}

yum_update() {
  yum -y update
}

dnf_update() {
  dnf -y upgrade
}

ubuntu_dep() {
  echo "* Installing dependencies for Ubuntu .."

  # Install phpmyadmin
  apt -y install phpmyadmin

  echo "* Dependencies for Ubuntu installed!"
}

debian_stretch_dep() {
  echo "* Installing dependencies for Debian 8/9.."

  # Install phpmyadmin
  apt -y install phpmyadmin

  echo "* Dependencies for Debian 8/9 installed!"
}

debian_dep() {
  echo "* Installing dependencies for Debian 10.."

  # Backports are necessary in buster
  echo "deb http://deb.debian.org/debian buster-backports main" | tee /etc/apt/sources.list.d/backports.list

  # Install phpmyadmin
  apt -y phpmyadmin

  echo "* Dependencies for Debian 10 installed!"
}

centos7_dep() {
  echo "* Installing dependencies for CentOS 7.."

  yum -y phpmyadmin

  echo "* Dependencies for CentOS installed!"
}

centos8_dep() {
  echo "* Installing dependencies for CentOS 8.."

  dnf -y 


  echo "* Dependencies for CentOS installed!"
}

##### MAIN FUNCTIONS #####

perform_install() {
  echo "* Starting installation.. this might take a while!"

  case "$OS" in
  debian | ubuntu)
    apt_update

    if [ "$OS" == "ubuntu" ]; then
      [ "$OS_VER_MAJOR" == "20" ] && ubuntu20_dep
      [ "$OS_VER_MAJOR" == "18" ] && ubuntu18_dep
    elif [ "$OS" == "debian" ]; then
      [ "$OS_VER_MAJOR" == "9" ] && debian_stretch_dep
      [ "$OS_VER_MAJOR" == "10" ] && debian_dep
    fi
    ;;

  centos)
    [ "$OS_VER_MAJOR" == "7" ] && yum_update
    [ "$OS_VER_MAJOR" == "8" ] && dnf_update

    [ "$OS_VER_MAJOR" == "7" ] && centos7_dep
    [ "$OS_VER_MAJOR" == "8" ] && centos8_dep
    ;;
  esac
}

configure_phpmyadmin_debian_based() {
  # work
  echo "work"
}

configure_phpmyadmin_centos() {
  # work
  echo "work"
}

configure_nginx() {
  # work
  echo "work"
}

main() {
  # check if we can detect an already existing installation
  if ! [ -d "/var/www/pterodactyl" ]; then
    error "Pterodactyl panel is not installed!"
    exit 1
  fi

  # detect distro
  detect_distro

  print_brake 70
  echo "* Pterodactyl panel phpmyadmin installation script @ $SCRIPT_RELEASE"
  echo "*"
  echo "* Copyright (C) 2018 - 2021, Vilhelm Prytz, <vilhelm@prytznet.se>"
  echo "* https://github.com/vilhelmprytz/pterodactyl-installer"
  echo "*"
  echo "* This script is not associated with the official Pterodactyl Project."
  echo "*"
  echo "* Running $OS version $OS_VER."
  echo "* Latest pterodactyl/panel is $PTERODACTYL_VERSION"
  print_brake 70



  # checks if the system is compatible with this installation script
  check_os_comp

  # confirm installation
  echo -e -n "* Continue with installation? (y/N): "
  read -r CONFIRM
  if [[ "$CONFIRM" =~ [Yy] ]]; then
    perform_install
  else
    # run welcome script again
    print_error "Installation aborted."
    exit 1
  fi
}

# run script
main