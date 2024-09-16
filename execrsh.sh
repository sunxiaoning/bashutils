#!/bin/bash
set -o nounset
set -o errexit
set -o pipefail

#set -ex

TERMINATE_DONE=0
CLEAN_DONE=0

trap terminate INT TERM
trap cleanup EXIT

USAGE="[-eu:p:b:h] remote_host file_paths bash_file"

FILE_PATHS=""
BASH_ENVS=""

SSH_OPTIONS=""
REMOTE_HOST=""
REMOTE_USER="${USER}"

SSH_CMD=("ssh")

REMOTE_TEMP_DIR=""
REMOTE_PID=""

SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE}")")
CHECK_HOST_NAME_SH_FILE="${SCRIPT_DIR}/checkhostname.sh"
CHECK_USER_NAME_SH_FILE="${SCRIPT_DIR}/checkusername.sh"

run-remote-bash() {
  REMOTE_HOST="${1-}"
  local bash_file_path="${2-}"

  if [ -z "${bash_file_path}" ]; then
    echo "bash_file_path param is empty!" >&2
    exit 1
  fi

  if [[ ! "${bash_file_path}" =~ \.sh$ ]]; then
    echo "Error: bash_file_path should be a .sh file!" >&2
    exit 1
  fi

  check-remotehost

  check-remoteuser

  if [ -n "${SSH_OPTIONS}" ]; then
    SSH_CMD+=("${SSH_OPTIONS}")
  fi

  echo "CurrentUser: ${REMOTE_USER}"

  REMOTE_TEMP_DIR=$("${SSH_CMD[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "mktemp -d -t remote_exec-XXXXXX")

  echo "Saved REMOTE_TEMP_DIR: ${REMOTE_TEMP_DIR}."

  local file_paths_array=()
  IFS=' ' read -r -a file_paths_array <<<"${FILE_PATHS}"

  if [ "${#file_paths_array[@]}" -gt 0 ]; then
    rsync -avzq -e "${SSH_CMD[*]}" --delete "${file_paths_array[@]}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_TEMP_DIR}/"
    echo "Synchronized file_paths: ${FILE_PATHS} to remote_host: ${REMOTE_HOST}."
  fi

  local bash_envs_array=()
  IFS=' ' read -r -a bash_envs_array <<<"${BASH_ENVS}"

  local pid_file="${REMOTE_TEMP_DIR}/$(basename ${bash_file_path} .sh)_$(date +%s).log"

  bash_envs_array+=("WORKDIR=${REMOTE_TEMP_DIR}" "PID_FILE=${pid_file}")
  echo "Bash envs: ${bash_envs_array[@]}"

  echo "Executing bash_file_path: ${bash_file_path}..."

  "${SSH_CMD[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "
        ${bash_envs_array[@]} bash ${REMOTE_TEMP_DIR}/${bash_file_path}
      " &

  local ssh_pid=$(echo $!)
  sleep 1

  if ! kill -0 ${ssh_pid} 2>/dev/null; then
    exit 1
  fi

  local wait_time=0
  local max_wait=30
  while true; do
    if "${SSH_CMD[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "[[ -s "${pid_file}" ]]"; then
      break
    fi
    if [ ${wait_time} -ge ${max_wait} ]; then
      echo "Error: Timeout waiting for remote pid." >&2
      exit 1
    fi
    echo "Waitting remote bash pid..."
    sleep 1
    ((wait_time++))
  done

  REMOTE_PID=$("${SSH_CMD[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "cat ${pid_file}")
  echo "Got remote_bash_pid: ${REMOTE_PID}."

  wait ${ssh_pid}
  echo "Remote bash process: ${REMOTE_PID} has completed."

  echo "Cleaning remote_pid_file..."
  "${SSH_CMD[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "rm -f ${pid_file}"
}

check-remotehost() {
  if [ -z "${REMOTE_HOST}" ]; then
    echo "Error: remote_host param is empty!" >&2
    exit 1
  fi

  if [[ ! -f "${CHECK_HOST_NAME_SH_FILE}" ]]; then
    echo "Error: require checkhostname.sh, but not found!" >&2
    exit 1
  fi

  if ! "${CHECK_HOST_NAME_SH_FILE}" "${REMOTE_HOST}" >/dev/null 2>&1; then
    echo "Error: remote_host param: '${REMOTE_HOST}'  is invalid!" >&2
    exit 1
  fi
}

check-remoteuser() {
  if [[ ! -f "${CHECK_USER_NAME_SH_FILE}" ]]; then
    echo "Error: require checkuser.sh, but not found!" >&2
    exit 1
  fi

  if ! "${CHECK_USER_NAME_SH_FILE}" "${REMOTE_USER}" >/dev/null 2>&1; then
    exit "Error: remote_user: '${REMOTE_USER}'  param is invalid!" >&2
    exit 1
  fi
}

terminate() {
  if [[ ${TERMINATE_DONE} -eq 1 ]]; then
    return
  fi
  TERMINATE_DONE=1

  echo "Received signal INT or TERM, performing terminate..."

  if [ -n "${REMOTE_PID}" ]; then
    while "${SSH_CMD[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "kill -0 ${REMOTE_PID} > /dev/null 2>&1"; do
      echo "Killing remote process ${REMOTE_PID}"
      "${SSH_CMD[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "kill -TERM -- ${REMOTE_PID}" || true
      echo "Waiting remote_pid: ${REMOTE_PID} exit..."
      sleep 5
    done
  fi

  for pid in $(pgrep -P $$); do
    pgid=$(ps -o pgid= $pid | grep -o '[0-9]*')
    if [ -n "${pgid}" ] && ps -p ${pgid} >/dev/null; then
      echo "Killing job: pgid: ${pgid}"
      kill -TERM -$pgid
    fi
  done

  wait

  echo "All jobs in group terminated."

  echo "Terminate done."
  exit 1
}

cleanup() {
  if [[ ${CLEAN_DONE} -eq 1 ]]; then
    return
  fi
  CLEAN_DONE=1
  echo "Received signal EXIT, performing cleanup..."

  if [ -n "${REMOTE_TEMP_DIR}" ]; then
    echo "Cleaning remote_temp_dir..."
    "${SSH_CMD[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "rm -rf ${REMOTE_TEMP_DIR}" || true
    echo "Cleanup done."
  fi
}

main() {
  local opt_string=":e:u:p:b:h"
  local opt

  #echo "Parsing arguments: $@ with opt_string: ${opt_string}"

  while getopts "${opt_string}" opt; do
    case ${opt} in
    e)
      SSH_OPTIONS=$OPTARG
      ;;
    u)
      REMOTE_USER=$OPTARG
      ;;
    p)
      FILE_PATHS=$OPTARG
      ;;
    b)
      BASH_ENVS=$OPTARG
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

  run-remote-bash "$@"
}

main "$@"
