#!/usr/bin/env bash

set -Eeuo pipefail

usage() {
  cat <<EOF
Add ansible user to a host to run your playbooks.

Usage:
  $(basename "${BASH_SOURCE[0]}") [-h|--help] [-v|--verbose] -h|--host host -f|--file ansible_authorized_keys [-u|--uid] uid [-U|--user] user

Options:
  -h --help               Show this screen
  -v --verbose            Use extended output
  -H --host               Specify your host
  -f --file               Specify ansible authorized_keys file

Examples:
  $(basename "${BASH_SOURCE[0]}") --help                                : Show help screen
  $(basename "${BASH_SOURCE[0]}") -H 192.168.1.2 -f ~/.ssh/id_rsa.pub   : Add ansible user with key to host
EOF
  exit
}

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

parse_params() {
  # default values of variables set from params
  HOST=''
  FILE=''
  USER=root

  [[ "$#" -eq 0 ]] && usage

  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -v | --verbose) set -x ;;
    -H | --host)
      [[ ! "${2-}" =~ ^-.* ]] && HOST="${2-}" || die "No host was specified for --host option."
      shift
      ;;
    -f | --file)
      [[ ! "${2-}" =~ ^-.* ]] && FILE="${2-}" || die "No file was specified for --file option."
      shift
      ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  args=("$@")
  [[ ${#args[@]} -gt 0 ]] && die "This script takes no arguments"

  [[ -z "${HOST-}" ]] && die "Missing required parameter: --host"
  [[ -z "${FILE-}" ]] && die "Missing required parameter: --file"
  [[ -f "${FILE-}" ]] || die "Can not open ${FILE-}"

  return 0
}

check_connection() {
  echo "Checking connection to host ${HOST}:"
  ping -q -c 1 -W 1 "${HOST}" > /dev/null && echo "Connection is up, continue." || die "No connection to ${HOST}. Finish."
}

create_user_with_key() {
  echo "Start process of creating ansible user"
  ssh "${USER}"@"${HOST}" "
    sudo useradd -s /bin/bash ansible 
    sudo mkdir -p /home/ansible/.ssh
    sudo echo $(cat ${FILE-}) > /home/ansible/.ssh/authorized_keys
    chown -R ansible:ansible /home/ansible
    chmod -R 700 /home/ansible
  "
}

parse_params "$@"
check_connection
create_user_with_key