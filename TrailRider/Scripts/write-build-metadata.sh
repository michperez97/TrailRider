#!/bin/sh
set -eu

repo_root="${SRCROOT}/.."
output_dir="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
output_file="${output_dir}/GitCommit.txt"

commit="unknown"
if command -v git >/dev/null 2>&1 && git -C "${repo_root}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    commit="$(git -C "${repo_root}" rev-parse --short HEAD 2>/dev/null || printf unknown)"
    if [ -n "$(git -C "${repo_root}" status --porcelain 2>/dev/null)" ]; then
        commit="${commit}-dirty"
    fi
fi

mkdir -p "${output_dir}"
printf "%s\n" "${commit}" > "${output_file}"
