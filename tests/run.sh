#!/usr/bin/env bash
# run.sh — run the whole atomic-workstation test suite.
#   ./tests/run.sh          everything (mocked e2e + unit-file checks)
#   ./tests/run.sh flatpak  just one suite (flatpak|brew|distrobox|git|systemd)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${HERE}/.." && pwd)"
export REPO_ROOT

SUITES=(flatpak brew distrobox inventory git systemd ujust image_integration dotfiles)
if [[ ${1:-} != "" ]]; then
    SUITES=("$1")
fi

TOTAL_FAILED=0
for suite in "${SUITES[@]}"; do
    if [[ ! -f "${HERE}/test_${suite}.sh" ]]; then
        echo "no such suite: $suite" >&2
        exit 2
    fi
    if bash "${HERE}/test_${suite}.sh"; then
        :
    else
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
    fi
done

echo
if [[ $TOTAL_FAILED -eq 0 ]]; then
    echo "ALL SUITES PASSED" >&2
    exit 0
else
    echo "${TOTAL_FAILED} SUITE(S) FAILED" >&2
    exit 1
fi
