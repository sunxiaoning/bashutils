#!/bin/bash
set -o nounset
set -o errexit
set -o pipefail

. hack/env.sh

trap cleanup EXIT

export REPO_ORIGIN_SOURCE=${REPO_ORIGIN_SOURCE:-"0"}

AUTH_GH_SH_URL_GITHUB="https://raw.githubusercontent.com/sunxiaoning/ghcli/main/autorun.sh"
AUTH_GH_SH_URL_GITEE="https://gitee.com/williamsun/ghcli/raw/main/autorun.sh"

AUTH_GH_SH_URL=${AUTH_GH_SH_URL:-${AUTH_GH_SH_URL_GITHUB}}

install-rel() {
  if gh release view "${REL_TAG}" &>/dev/null; then
    echo "Release ${REL_TAG} already exists!"
    return
  fi

  gh release create "${REL_TAG}" "${PKG_PATH}/${PKG_NAME}" --title "${REL_TITLE}" --notes "${REL_NOTES}"
}

auth-gh() {
  if [[ "1" == "${REPO_ORIGIN_SOURCE}" ]]; then
    AUTH_GH_SH_URL="${AUTH_GH_SH_URL_GITEE}"
  fi

  /bin/bash -c "$(curl -fsSL ${AUTH_GH_SH_URL})"
}

main() {
  auth-gh
  install-rel
}

CLEAN_DONE=0
cleanup() {
  if [[ ${CLEAN_DONE} -eq 1 ]]; then
    return
  fi
  CLEAN_DONE=1
  echo "Received signal EXIT, performing cleanup..."

  rm -rf "${PKG_PATH}"

  echo "Cleanup done."
}

main "$@"
