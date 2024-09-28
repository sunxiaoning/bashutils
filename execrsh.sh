#!/bin/bash

SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE}")")

. ${SCRIPT_DIR}/../bashutils/basicenv.sh

trap __terminate INT TERM
trap __cleanup EXIT

USAGE="[-eu:p:b:a:r:h] remote_host file_paths bash_file"

FILE_PATHS=""
BASH_ENVS=""
BASH_ARGS=""
BASH_RESULT=""

SSH_OPTIONS=""
REMOTE_HOST=""
REMOTE_USER="${USER}"

SSH_CMD=("ssh")

REMOTE_TEMP_DIR=""
REMOTE_PID=""
SCRIPT_NAME=$(basename "$0")
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
    local ssh_options_array=()
    IFS=' ' read -r -a ssh_options_array <<<"${SSH_OPTIONS}"
    SSH_CMD+=("${ssh_options_array[@]}")
  fi

  echo "CurrentUser: ${REMOTE_USER}"

  REMOTE_TEMP_DIR=$("${SSH_CMD[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "mktemp -d -t remote_exec-XXXXXX")

  echo "Saved REMOTE_TEMP_DIR: ${REMOTE_TEMP_DIR}."

  local file_paths_array=()
  IFS=' ' read -r -a file_paths_array <<<"${FILE_PATHS}"

  if [ "${#file_paths_array[@]}" -gt 0 ]; then
    for i in "${!file_paths_array[@]}"; do
      file_paths_array[$i]="$(check_and_resolve_path "${file_paths_array[$i]}")"
    done

    rsync -avzq -e "${SSH_CMD[*]}" --delete "${file_paths_array[@]}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_TEMP_DIR}/"
    echo "Synchronized file_paths: ${FILE_PATHS} to remote_host: ${REMOTE_HOST}."
  fi

  local bash_envs_array=()
  IFS=' ' read -r -a bash_envs_array <<<"${BASH_ENVS}"

  local pid_file="${REMOTE_TEMP_DIR}/$(basename ${bash_file_path} .sh)_$(date +%s).log"

  bash_envs_array+=("WORKDIR=${REMOTE_TEMP_DIR}" "PID_FILE=${pid_file}")

  local pid_res_file=""
  if [[ -n ${BASH_RESULT} ]]; then
    pid_res_file="${REMOTE_TEMP_DIR}/$(basename ${bash_file_path} .sh)_res_$(date +%s).log"
    bash_envs_array+=("PID_RES_FILE=${pid_res_file}")
  fi
  echo "Bash envs: ${bash_envs_array[@]}"

  echo "Executing bash_file_path: ${bash_file_path}..."

  if [[ -n "${BASH_ARGS}" ]]; then
    echo "Bash args: ${BASH_ARGS}"
  fi

  "${SSH_CMD[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "
       bash -c '
        if [[ -f "${REMOTE_TEMP_DIR}/${bash_file_path}" && -x "${REMOTE_TEMP_DIR}/${bash_file_path}" ]]; then
          ${bash_envs_array[@]} \"${REMOTE_TEMP_DIR}/${bash_file_path}\" ${BASH_ARGS}
        else
          echo "Error: File ${REMOTE_TEMP_DIR}/${bash_file_path} does not exist or is not executable." >&2
          exit 1
        fi
      '
      " &

  local ssh_pid=$(echo $!)
  # sleep 1

  # if ! kill -0 ${ssh_pid} 2>/dev/null; then
  #   exit 1
  # fi

  local wait_time=0
  local max_wait=30

  set +e
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
  set -e

  REMOTE_PID=$("${SSH_CMD[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "cat ${pid_file}")
  echo "Got remote_bash_pid: ${REMOTE_PID}."

  wait ${ssh_pid}

  echo "Remote bash process: ${REMOTE_PID} has completed."

  if [[ -n ${BASH_RESULT} ]]; then
    echo "Writting bash result..."
    "${SSH_CMD[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "cat ${pid_res_file}" >"${BASH_RESULT}"
  fi
}

check_and_resolve_path() {
  local path="$1"
  if [ -e "$path" ]; then
    realpath "$path"
  else
    echo "Error: Path '$path' does not exist." >&2
    exit 1
  fi
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
  kill-remote-pid
}

kill-remote-pid() {
  if [ -n "${REMOTE_PID}" ]; then
    while "${SSH_CMD[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "kill -0 ${REMOTE_PID} > /dev/null 2>&1"; do
      echo "Killing remote process ${REMOTE_PID}"
      "${SSH_CMD[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "kill -TERM -- ${REMOTE_PID}" || true
      echo "Waiting remote_pid: ${REMOTE_PID} exit..."
      sleep 5
    done
  fi
}

cleanup() {
  kill-remote-pid

  if [ -n "${REMOTE_TEMP_DIR}" ]; then
    echo "[${SCRIPT_NAME}] Cleaning remote_temp_dir..."
    "${SSH_CMD[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "rm -rf ${REMOTE_TEMP_DIR}" || true
    echo "[${SCRIPT_NAME}] Cleanup done."
  fi
}

main() {
  local opt_string=":e:u:p:b:a:r:h"
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
    a)
      BASH_ARGS=$OPTARG
      ;;
    r)
      BASH_RESULT=$OPTARG
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
