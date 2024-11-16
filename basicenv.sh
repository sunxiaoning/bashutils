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

  terminate

  # kill_process_tree $$

  local pgids=$(pgrep -P $$) || true
  for pid in $pgids; do
    local pgid=$(ps -o pgid= $pid | grep -o '[0-9]*') || true
    if [ -n "${pgid}" ] && ps -p ${pgid} >/dev/null; then
      echo "Killing job: pgid: ${pgid}"
      kill -TERM -$pgid || true
    fi
  done

  wait

  echo "[${SCRIPT_NAME}] All child process in group terminated."

  echo "[${SCRIPT_NAME}] Terminate done."
  exit 1
}

sent_pgid=()

kill_process_tree() {
  local pid=$1

  local pgid=$(ps -o pgid= -p $pid | grep -o '[0-9]*') || true

  if [[ -z "$pgid" ]]; then
    echo "Invalid process ID or failed to get PGID."
    return 1
  fi

  if [[ " ${sent_pgid[@]} " =~ " ${pgid} " ]]; then
    echo "Process group $pgid has already been killed. Skipping."
    return 0
  fi

  echo "Killing process group: $pgid"
  kill -TERM -$pgid || true

  sent_pgid+=($pgid)

  local child_pids=$(pgrep -P $pid) || true

  for child_pid in $child_pids; do
    kill_process_tree $child_pid || true
  done
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
