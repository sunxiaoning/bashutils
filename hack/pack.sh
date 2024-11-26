#!/bin/bash
set -o nounset
set -o errexit
set -o pipefail

. hack/env.sh

EXCLUDES=(
  --exclude='*/.meta'
  --exclude='*/Makefile'
  --exclude='*/.DS_Store'
  --exclude='*/README.md'
  --exclude='*/hack'
  --exclude='*/.gh_token.txt'
  --exclude='*/.git'
  --exclude='*/.git*'
  --exclude='*/.vscode'
  --exclude='*/.dmypasswd.txt'
)

mkdir -p "${PKG_PATH}"

gtar "${EXCLUDES[@]}" -czvf "${PKG_PATH}/${PKG_NAME}" .
