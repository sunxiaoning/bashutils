set -o nounset
set -o errexit
set -o pipefail

export __USE_DEBUG=${__USE_DEBUG:-"0"}

if [[ "${__USE_DEBUG}" == "1" ]]; then
  set -x
fi

__get-current-user() {
  echo "$(whoami)"
}

__get-original-user() {
  if ! __is-sudo; then
    __get-current-user
    return 0
  fi
  echo "$SUDO_USER"
}

__get-current-home-dir() {
  echo "$HOME"
}

__get-original-home-dir() {
  if __has-root-privileges && __is-sudo; then
    eval echo ~$SUDO_USER
    return 0
  fi
  __get-current-home-dir
}

__has-root-privileges() {
  [[ "$EUID" -eq 0 ]]
}

__is-real-root() {
  if [[ "$EUID" -eq 0 && -z "${SUDO_USER-}" ]]; then
    return 0
  fi
  return 1
}

__is-sudo() {
  if [ -z "${SUDO_USER-}" ]; then
    return 1
  fi
  return 0
}
