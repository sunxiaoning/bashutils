set -o nounset
set -o errexit
set -o pipefail

export __USE_DEBUG=${__USE_DEBUG:-"0"}

if [[ "${__USE_DEBUG}" == "1" ]]; then
  set -x
fi

__get-current-user() {
  whoami
}

__get-original-user() {
  if __is-sudo; then
    echo "${SUDO_USER}"
    return 0
  fi
  __get-current-user
}

__get-current-home-dir() {
  if __has-root-privileges; then
    echo "/root"
  else
    echo "${HOME}"
  fi
}

__get-original-home-dir() {
  if __is-sudo; then
    eval echo "~${SUDO_USER}"
  else
    echo "${HOME}"
  fi
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
  if [ "$EUID" -eq 0 ] && [ -n "${SUDO_USER-}" ]; then
    return 0
  fi
  return 1
}

__TERMINATE_DONE=0

__terminate() {
  if [[ ${__TERMINATE_DONE} -eq 1 ]]; then
    return
  fi
  __TERMINATE_DONE=1

  echo "[${SCRIPT_NAME}] Received signal INT or TERM, performing terminate..."

  trap '' INT TERM

  terminate

  local pgid=$(ps -o pgid= $$ | grep -o '[0-9]*') || {
    echo "[${SCRIPT_NAME}] Error: Search process group for $$ failed." >&2
    exit 1
  }

  local max_wait=60
  local wait_time=0

  while true; do
    if [ ${wait_time} -ge ${max_wait} ]; then
      echo "[${SCRIPT_NAME}] Error: Kill TERM to process group: ${pgid} timeout." >&2
      exit 1
    fi

    if kill -TERM -- -"${pgid}"; then
      break
    fi

    echo "[${SCRIPT_NAME}] [Warning] Kill TERM to process group: ${pgid} exited with $?"
    sleep 5
    wait_time=$((wait_time + 5))
  done

  wait

  echo "[${SCRIPT_NAME}] All child process in group terminated."

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

  trap '' INT TERM

  cleanup

  echo "[${SCRIPT_NAME}] Cleanup done."
}
