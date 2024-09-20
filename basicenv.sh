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

__TERMINATE_DONE=0

__terminate() {
  if [[ ${__TERMINATE_DONE} -eq 1 ]]; then
    return
  fi
  __TERMINATE_DONE=1

  echo "[${SCRIPT_NAME}] Received signal INT or TERM, performing terminate..."

  for pid in $(pgrep -P $$); do
    pgid=$(ps -o pgid= $pid | grep -o '[0-9]*')
    if [ -n "${pgid}" ] && ps -p ${pgid} >/dev/null; then
      echo "Killing job: pgid: ${pgid}"
      kill -TERM -$pgid
    fi
  done

  wait

  echo "[${SCRIPT_NAME}] All child process in group terminated."

  terminate

  echo "[${SCRIPT_NAME}] Terminate done."
  exit 1
}

__CLEAN_DONE=0

__cleanup() {
  if [[ ${__CLEAN_DONE} -eq 1 ]]; then
    return
  fi
  __CLEAN_DONE=1
  echo "[${SCRIPT_NAME}] Received signal EXIT, performing cleanup..."

  cleanup

  echo "[${SCRIPT_NAME}] Cleanup done."
}
