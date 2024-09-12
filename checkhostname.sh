#!/bin/bash
set -o nounset
set -o errexit
set -o pipefail

HOST_NAME=""
SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE}")")

CHECK_DOMAIN_SH_FILE="${SCRIPT_DIR}/checkdomain.sh"
CHECK_IP_SH_FILE="${SCRIPT_DIR}/checkip.sh"

check-hostname() {
  if "${CHECK_DOMAIN_SH_FILE}" "${HOST_NAME}" >/dev/null 2>&1; then
    return 0
  fi

  if "${CHECK_IP_SH_FILE}" "${HOST_NAME}" >/dev/null 2>&1; then
    return 0
  fi

  if "${CHECK_IP_SH_FILE}" -v 6 "${HOST_NAME}" >/dev/null 2>&1; then
    return 0
  fi

  echo "Error: Hostname '${HOST_NAME}' is invalid." >&2
  return 1
}

main() {
  HOST_NAME="${1-}"
  if [[ -z "${HOST_NAME}" ]]; then
    echo "Error: host_name param can't be empty!" >&2
    return 1
  fi

  if [[ ! -f "${CHECK_DOMAIN_SH_FILE}" ]]; then
    echo "Error: require checkdoman.sh, but not found!" >&2
    return 1
  fi

  if [[ ! -f "${CHECK_IP_SH_FILE}" ]]; then
    echo "Error: require checkip.sh, but not found!" >&2
    return 1
  fi
  check-hostname
}

main "$@"
