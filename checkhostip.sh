#!/bin/bash
set -o nounset
set -o errexit
set -o pipefail

USAGE="[-l] [-h] host_ip"
LOOP_BACK=""
LOOP_BACK_IP="127.0.0.1"

function check-hostip() {
  local host_ip="${1-}"
  if [ -z "${host_ip}" ]; then
    echo "host_ip param is invalid !" >&2
    return 1
  fi

  if [[ "${LOOP_BACK}" == "1" && ${host_ip} == "${LOOP_BACK_IP}" ]]; then
    return 0
  fi

  local available_ips=$(hostname -I)

  IFS=' ' read -r -a available_ips_array <<< "$available_ips"

  for ip in "${available_ips_array[@]}"; do
    if [ "$ip" == "${host_ip}" ]; then
      return 0
    fi
  done

  echo "host_ip: ${host_ip} is invalid!" >&2
  return 1
}

main() {
  local opt_string=":lh"
  local opt

  #echo "Parsing arguments: $@ with opt_string: ${opt_string}"

  while getopts "${opt_string}" opt; do
    case ${opt} in
    l)
      LOOP_BACK="1"
      ;;
    h)
      echo "Usage: ${0} ${USAGE}"
      return 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG, Usage: ${0} ${USAGE}" >&2
      return 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      return 1
      ;;
    esac
  done
  shift $((OPTIND - 1))

  #echo "Remaining arguments after parsing: $@"

  check-hostip "$@"
}

main "$@"

