#!/bin/bash
set -o nounset
#set -o errexit
set -o pipefail

USAGE="[-o:h] username"

USER_NAME=""
OS_NAME="unix"

UNIX_USER_REGEX='^[a-z_][a-z0-9_-]*$'
UNIX_MAX_USERNAME_LENGTH=32

WINDOWS_USER_REGEX='^[a-zA-Z0-9 ._-]+$'
WINDOWS_MAX_USERNAME_LENGTH=20

SSH_USER_REGEX='^[a-zA-Z0-9 ._-]+$'
SSH_MAX_USERNAME_LENGTH=64

check-unix-username() {
  if [[ "${USER_NAME}" =~ ^\  || "${USER_NAME}" =~ \ $ ]]; then
    echo "Error: Local username '${USER_NAME}' has leading or trailing spaces." >&2
    return 1
  fi

  if [[ ${#USER_NAME} -gt ${UNIX_MAX_USERNAME_LENGTH} ]]; then
    echo "Error: Local username '${USER_NAME}' exceeds maximum length of ${UNIX_MAX_USERNAME_LENGTH} characters." >&2
    return 1
  fi

  if [[ ! "${USER_NAME}" =~ ${UNIX_USER_REGEX} ]]; then
    echo "Error: Local username '${USER_NAME}' is invalid." >&2
    return 1
  fi
}

check-windows-username() {
  if [[ "${USER_NAME}" =~ ^\  || "${USER_NAME}" =~ \ $ ]]; then
    echo "Error: Windows username '${USER_NAME}' has leading or trailing spaces." >&2
    return 1
  fi

  if [[ "${USER_NAME}" =~ \.$ ]]; then
    echo "Error: Windows username '${USER_NAME}' cannot end with a dot." >&2
    return 1
  fi

  if [[ ${#USER_NAME} -gt ${WINDOWS_MAX_USERNAME_LENGTH} ]]; then
    echo "Error: Windows username '${USER_NAME}' exceeds maximum length of ${WINDOWS_MAX_USERNAME_LENGTH} characters." >&2
    return 1
  fi

  if [[ ! "${USER_NAME}" =~ ${WINDOWS_USER_REGEX} ]]; then
    echo "Error: Windows username '${USER_NAME}' contains invalid characters." >&2
    return 1
  fi
}

check-ssh-username() {

  if [[ "${USER_NAME}" =~ ^\  || "${USER_NAME}" =~ \ $ ]]; then
    echo "Error: SSH username '${USER_NAME}' has leading or trailing spaces." >&2
    return 1
  fi

  if [[ ${#USER_NAME} -gt ${SSH_MAX_USERNAME_LENGTH} ]]; then
    echo "Error: SSH username '${USER_NAME}' exceeds maximum length of ${SSH_MAX_USERNAME_LENGTH} characters." >&2
    return 1
  fi

  if [[ ! "${USER_NAME}" =~ ${SSH_USER_REGEX} ]]; then
    echo "Error: SSH username '${USER_NAME}' is invalid." >&2
    return 1
  fi
}

check-username() {
  USER_NAME="${1-}"

  if [[ -z "${USER_NAME}" ]]; then
    echo "Error: username param can't be empty!" >&2
    return 1
  fi

  case ${OS_NAME} in
  unix)
    check-unix-username
    ;;
  windows)
    check-windows-username
    ;;
  ssh)
    check-ssh-username
    ;;
  :)
    echo "OS_NAME: ${IP_VERSION} is invalid!" >&2
    return 1
    ;;
  esac
}

main() {
  local opt_string=":o:h"
  local opt

  #echo "Parsing arguments: $@ with opt_string: ${opt_string}"

  while getopts "${opt_string}" opt; do
    case ${opt} in
    o)
      OS_NAME=$OPTARG
      ;;
    h)
      echo "Usage: ${0} ${USAGE}"
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG, Usage: ${0} ${USAGE}" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
    esac
  done
  shift $((OPTIND - 1))

  #echo "Remaining arguments after parsing: $@"

  check-username "$@"
}

main "$@"
