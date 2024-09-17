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
  if [ -z "$SUDO_USER" ]; then
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
  [[ "$EUID" -eq 0 && -z "$SUDO_USER" ]]
}

__is-sudo() {
  [[ -n "$SUDO_USER" ]]
}
