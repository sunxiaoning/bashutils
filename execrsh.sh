#!/bin/bash

SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE}")")

. ${SCRIPT_DIR}/../bashutils/basicenv.sh

trap __terminate INT TERM
trap __cleanup EXIT

USAGE="[-e:u:t:p:b:a:r:sh] remote_host file_paths bash_file"

FILE_PATHS=""

# TODO env, arg don't known file_paths, at least should known it's root path, one way is to convert path in env,arg to an inner path, `using root path identifier`.

BASH_ENVS=""
BASH_ARGS=""
BASH_RESULT=""

SSH_OPTIONS=""
REMOTE_HOST=""

REMOTE_USER=$(__get-original-user)
REMOTE_SUDO=""
REMOTE_SH="bash"
REMOTE_PASSWORD=""

SSH_CMD=("ssh")

REMOTE_TEMP_DIR=""
REMOTE_PID=""

SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE}")")
CHECK_HOST_NAME_SH_FILE="${SCRIPT_DIR}/checkhostname.sh"
CHECK_USER_NAME_SH_FILE="${SCRIPT_DIR}/checkusername.sh"

SSH_PID=""

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

  if [[ -n "${REMOTE_PASSWORD}" ]]; then
    if ! rpm -q "sshpass" &>/dev/null; then
      sudo yum -y install sshpass
    fi

    local remote_password="${REMOTE_PASSWORD}"
    unset REMOTE_PASSWORD

    SSH_CMD=("sshpass" "-v" "-p" "${remote_password}" "ssh")
  fi

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

  if [[ -n "${REMOTE_SUDO}" ]]; then
    REMOTE_SH="sudo ${REMOTE_SH}"
  fi

  trap '' INT TERM

  setsid "${SSH_CMD[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "
      ${REMOTE_SH} -c '
        if [[ -f "${REMOTE_TEMP_DIR}/${bash_file_path}" && -x "${REMOTE_TEMP_DIR}/${bash_file_path}" ]]; then
          ${bash_envs_array[@]} "${REMOTE_TEMP_DIR}/${bash_file_path}" ${BASH_ARGS}
        else
          echo "Error: File ${REMOTE_TEMP_DIR}/${bash_file_path} does not exist or is not executable." >&2
          exit 1
        fi
      '
      " &

  SSH_PID=$(echo $!)

  local wait_time=0
  local max_wait=30

  while true; do
    if ! kill -0 ${SSH_PID}; then
      echo "[Warning] SSH_PID: ${SSH_PID} has terminated."
      break
    fi

    if "${SSH_CMD[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "[[ -s ${pid_file} ]]"; then
      break
    fi
    if [ ${wait_time} -ge ${max_wait} ]; then
      echo "Error: Timeout waiting for remote pid." >&2
      exit 1
    fi
    echo "Waitting remote bash pid..."
    sleep 1
    wait_time=$((wait_time + 1))
  done

  REMOTE_PID=$("${SSH_CMD[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "cat ${pid_file}") || echo "[Warning] Get remote_bash_pid failed."

  if [[ -n "${REMOTE_PID}" ]]; then
    echo "Got remote_bash_pid: ${REMOTE_PID}."
  fi

  trap __terminate INT TERM


  wait ${SSH_PID}

  echo "SSH_PID: ${SSH_PID} has exited with $?."

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
  echo "[${SCRIPT_NAME}] Terminating..."

  if [[ -n "${SSH_PID}" ]]; then
    echo "[${SCRIPT_NAME}] ssh_pid(${SSH_PID}) is alive:  $(kill -0 ${SSH_PID} 2>/dev/null && echo "yes" || echo "no")"
  fi

  if [[ -n "${REMOTE_PID}" ]]; then
    kill-remote-pid || echo "[${SCRIPT_NAME}] [Warning] Kill remote pid: ${REMOTE_PID} failed."
  fi

  if [[ -n "${SSH_PID}" ]]; then
    kill-ssh-pid || echo "[${SCRIPT_NAME}] [Warning] Kill ssh_pid: ${SSH_PID} failed."
  fi
}

kill-ssh-pid() {
  if [ -z "${SSH_PID}" ]; then
    echo "Error: SSH_PID param is empty." >&2
    return 1
  fi

  local ssh_pgid=$(ps -o pgid= ${SSH_PID} | grep -o '[0-9]*') || {
    echo "Search process group for SSH_PID: ${SSH_PID} failed." >&2
    return 1
  }

  if [[ -z "${ssh_pgid}" ]]; then
    echo "Process group of pid(${ssh_pgid}) is not exists, maybe it is already terminated?" >&2
    return 1
  fi

  local max_wait=60
  local wait_time=0

  while kill -0 -- -"${ssh_pgid}" 2>/dev/null || {
    echo "Kill -0 to ssh_pgid group exit with $?"
    return 1
  }; do
    if [[ ${wait_time} -ge ${max_wait} ]]; then
      echo "Waiting ssh_pgid group: ${ssh_pgid} timeout..." >&2
      return 2
    fi

    kill -TERM -- -"${ssh_pgid}" || echo "Kill TERM signal to ssh_pgid group ${ssh_pgid} failed." >&2

    echo "Waiting ssh_pgid group: ${ssh_pgid} exit..."
    sleep 5
    wait_time=$((wait_time + 5))
  done

  echo "ssh_pgid(${ssh_pgid}) is alive:  $(kill -0 ${ssh_pgid} 2>/dev/null && echo "yes" || echo "no")"

  SSH_PID=""
}

kill-remote-pid() {
  if [ -z "${REMOTE_PID}" ]; then
    echo "Error: REMOTE_PID param is empty." >&2
    return 1
  fi

  local remote_pgid=$("${SSH_CMD[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "
    echo \$(ps -o pgid= ${REMOTE_PID} | grep -o "[0-9]*") || {
      echo "Search process group for remote_pid: ${REMOTE_PID} failed." >&2
      exit 1
    }")

  if [[ -z "${remote_pgid}" ]]; then
    echo "Process group of pid(${REMOTE_PID}) is not exists,maybe it is already terminated?" >&2
    return 1
  fi

  local max_wait=60
  local wait_time=0

  while "${SSH_CMD[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "
      ${REMOTE_SH} -c '
       kill -0 -- -${remote_pgid} 2>/dev/null || {
          echo "Kill -0 to remote process group exit with \$?"
          exit 1
       }
      '
      "; do

    if [[ ${wait_time} -ge ${max_wait} ]]; then
      echo "Error: waiting remote process group: ${remote_pgid} timeout." >&2
      return 2
    fi

    echo "Killing remote process group ${remote_pgid}"
    "${SSH_CMD[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "
        ${REMOTE_SH} -c '
        kill -TERM -- -${remote_pgid} || echo "Kill TERM signal to remote process group ${remote_pgid} failed." >&2
        '
        "

    echo "Waiting remote process group: ${remote_pgid} exit..."
    sleep 5
    wait_time=$((wait_time + 5))
  done

  REMOTE_PID=""
}

cleanup() {
  echo "[${SCRIPT_NAME}] Cleanup..."

  if [[ -n "${SSH_PID}" ]]; then
    echo "[${SCRIPT_NAME}] ssh_pid(${SSH_PID}) is alive:  $(kill -0 ${SSH_PID} 2>/dev/null && echo "yes" || echo "no")"
  fi

  if [[ -n "${REMOTE_PID}" ]]; then
    kill-remote-pid || echo "[${SCRIPT_NAME}] [Warning] Kill remote pid: ${REMOTE_PID} failed."
  fi

  if [[ -n "${SSH_PID}" ]]; then
    kill-ssh-pid || echo "[${SCRIPT_NAME}] [Warning] Kill ssh_pid: ${SSH_PID} failed."
  fi

  if [ -n "${REMOTE_TEMP_DIR}" ]; then
    echo "[${SCRIPT_NAME}] Cleaning remote_temp_dir..."
    "${SSH_CMD[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "rm -rf ${REMOTE_TEMP_DIR}" || true
    echo "[${SCRIPT_NAME}] Cleanup done."
  fi
}

main() {
  local opt_string=":e:u:t:p:b:a:r:sh"
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
    t)
      REMOTE_PASSWORD=$OPTARG
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
    s)
      REMOTE_SUDO="1"
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
