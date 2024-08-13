#!/bin/bash
set -o nounset
set -o errexit
set -o pipefail

USAGE="[-f] [-h] pkg_name pkg_version"
FORCE=""

install-pkg() {
  PKG_NAME="${1-}"
  PKG_VERSION="${2-}"

  if [ -z "${PKG_NAME}" ]; then
    echo "PKG_NAME param is invalid!"
    exit 1
  fi

  if [ -z "${PKG_VERSION}" ]; then
    echo "PKG_VERSION param is invalid!"
    exit 1
  fi

  if rpm -q "${PKG_NAME}-${PKG_VERSION}" &>/dev/null; then
    echo "${PKG_NAME} is already installed!"
    return 0
  fi

  if rpm -q "${PKG_NAME}" &>/dev/null; then
    if [ -n "${FORCE}" ]; then
      echo "[Warning] old ${PKG_NAME} installed is ignored!"
      return 0
    fi
    echo "Find old ${PKG_NAME} installed, abort!"
    exit 1
  fi

  echo "Installing ${PKG_NAME} version ${PKG_VERSION} ..."
  if ! yum install "${PKG_NAME}-${PKG_VERSION}" -y &>>/var/log/install.log; then
    echo "Failed to install ${PKG_NAME}. Check /var/log/install.log for details."
    exit 1
  fi

  if ! rpm -q "${PKG_NAME}-${PKG_VERSION}" &>/dev/null; then
    echo "Failed to install ${PKG_NAME}. Check /var/log/install.log for details."
    exit 1
  fi
}

main() {
  local opt_string=":fh"
  local opt

  #echo "Parsing arguments: $@ with opt_string: ${opt_string}"

  while getopts "${opt_string}" opt; do
    case ${opt} in
    f)
      FORCE="1"
      ;;
    h)
      echo "Usage: ${0} ${USAGE}"
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG, Usage: ${0} ${USAGE}"
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

  install-pkg "$@"
}

main "$@"
