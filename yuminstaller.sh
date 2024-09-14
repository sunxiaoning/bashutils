#!/bin/bash
set -o nounset
set -o errexit
set -o pipefail

USAGE="[-of] [-h] yum_options pkg_name pkg_version"

YUM_CMD=("yum")

YUM_OPTIONS=""
FORCE=""

install-pkg() {
  PKG_NAME="${1-}"
  PKG_VERSION="${2-}"

  if [ -n "${YUM_OPTIONS}" ]; then
    YUM_CMD+=("${YUM_OPTIONS}")
  fi

  if [ -z "${PKG_NAME}" ]; then
    echo "PKG_NAME param is invalid!" >&2
    return 1
  fi

  if [ -z "${PKG_VERSION}" ]; then
    echo "PKG_VERSION param is invalid!" >&2
    return 1
  fi

  if rpm -q "${PKG_NAME}-${PKG_VERSION}" &>/dev/null; then
    return 0
  fi

  if rpm -q "${PKG_NAME}" &>/dev/null; then
    if [ -n "${FORCE}" ]; then
      echo "[Warning] old ${PKG_NAME} installed is ignored!"
      return 0
    fi
    echo "Find old ${PKG_NAME} installed, abort!" >&2
    return 1
  fi

  echo "Installing ${PKG_NAME} version ${PKG_VERSION} ..."
  if ! "${YUM_CMD[@]}" install "${PKG_NAME}-${PKG_VERSION}"; then
    echo "Failed to install ${PKG_NAME} !" >&2
    return 1
  fi

  if ! rpm -q "${PKG_NAME}-${PKG_VERSION}" &>/dev/null; then
    echo "Failed to install ${PKG_NAME} !" >&2
    return 1
  fi
}

main() {
  local opt_string=":o:fh"
  local opt

  #echo "Parsing arguments: $@ with opt_string: ${opt_string}"

  while getopts "${opt_string}" opt; do
    case ${opt} in
    o)
      YUM_OPTIONS=$OPTARG
      ;;
    f)
      FORCE="1"
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

  install-pkg "$@"
}

main "$@"
