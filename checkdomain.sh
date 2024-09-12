#!/bin/bash
set -o nounset
set -o errexit
set -o pipefail

DOMAIN_NAME=""
DOMAIN_REGEX='^([a-zA-Z0-9-]{1,63}\.)+[a-zA-Z]{2,}$'

check-domain() {
  if [[ "${DOMAIN_NAME}" =~ $DOMAIN_REGEX ]]; then
    IFS='.' read -r -a labels <<<"${DOMAIN_NAME}"
    for label in "${labels[@]}"; do
      if [[ ${#label} -gt 63 ]]; then
        echo "Error: Domain '${DOMAIN_NAME}' is invalid. Label '$label' exceeds 63 characters." >&2
        return 1
      fi
    done
    return 0
  fi

  echo "Error: Domain '${DOMAIN_NAME}' is invalid." >&2
  return 1
}

main() {
  DOMAIN_NAME="${1-}"

  if [[ -z "${DOMAIN_NAME}" ]]; then
    echo "Error: domain_name param can't be empty!" >&2
    return 1
  fi
  check-domain
}

main "$@"
