#!/bin/bash
set -o nounset
set -o errexit
set -o pipefail

. .meta/hack/env.sh

trap cleanup EXIT

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

install-rel() {
  if gh release view "${REL_TAG}" &>/dev/null; then
    echo "Release ${REL_TAG} already exists!"
    return
  fi

  gh release create "${REL_TAG}" "${PKG_PATH}/${PKG_NAME}" --title "${REL_TITLE}" --notes "${REL_NOTES}"
}

auth-gh() {
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/sunxiaoning/ghcli/main/autorun.sh)"
}

main() {
  auth-gh
  install-rel
}

main "$@"