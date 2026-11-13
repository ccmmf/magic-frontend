#!/usr/bin/env bash
# list-environments.sh: list available PEcAn environment tarballs in S3.
# stdout: one line per environment, newest version first: VERSION<TAB>LAST_MODIFIED
# stderr: diagnostics. Exit codes: 0 ok; 10 aws not on PATH; 11 profile not found;
#   12 S3 path unreadable/denied; 13 no matching objects; 14 aws version too old; 15 no connectivity.
# Standalone: does not depend on magic-pecan.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=env-common.sh
source "${SCRIPT_DIR}/env-common.sh"

rc=0
fetch_environments || rc=$?
if [[ ${rc} -ne 0 ]]; then
  echo "ERROR: $(env_error_message "${rc}")" >&2
  exit "${rc}"
fi
printf '%s\n' "${ENV_LINES[@]}"
