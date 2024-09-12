#!/bin/bash
set -o nounset
set -o errexit
set -o pipefail

USAGE="[-v:h] ip"

IP=""
IP_VERSION="4"
IPV4_REGEX='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
IPV6_REGEX='^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){0,3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))$'

check-ipv4() {
  if [[ "${IP}" =~ $IPV4_REGEX ]]; then
    IFS='.' read -r -a octets <<<"${IP}"
    for octet in "${octets[@]}"; do
      if ((octet < 0 || octet > 255)); then
        echo "Error: IP address '${IP}' is invalid." >&2
        return 1
      fi
    done
    return 0
  fi
  echo "Error: IP address '${IP}' is invalid." >&2
  return 1
}

check-ipv6() {
  if [[ "${IP}" =~ $IPV6_REGEX ]]; then
    return 0
  fi
  echo "Error: IPv6 address '${IP}' is invalid."
  return 1
}

check-ip() {
  IP="${1-}"

  if [[ -z "${IP}" ]]; then
    echo "Error: ip param can't be empty!" >&2
    return 1
  fi

  case ${IP_VERSION} in
  4)
    check-ipv4
    ;;
  6)
    check-ipv6
    ;;
  *)
    echo "IP_VERSION: ${IP_VERSION} is invalid!" >&2
    return 1
    ;;
  esac
}

main() {
  local opt_string=":v:h"
  local opt

  #echo "Parsing arguments: $@ with opt_string: ${opt_string}"

  while getopts "${opt_string}" opt; do
    case ${opt} in
    v)
      IP_VERSION=$OPTARG
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

  check-ip "$@"
}

main "$@"
