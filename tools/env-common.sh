# env-common.sh: shared constants and S3 environment-discovery helpers.
# Sourced by tools/list-environments.sh (and through it, by magic-pecan).
# Does not set shell options. Does not read credential files: profile
# presence is checked with 'aws configure list-profiles' (names only).
#
# NOTE: tools/setup-pecan-env.sh is intentionally NOT sourcing this file; it is
# also distributed standalone and must stay self-contained. If the bucket,
# profile default or filename pattern change, update both places.

S3_PROFILE="${AWS_PROFILE:-magic}"
S3_BUCKET="s3://carb/environments"
ENV_NAME_REGEX='^pecan-all-([0-9]+(\.[0-9]+)*)\.tar\.gz$'
DEFAULT_ENV="${HOME}/.conda/envs/pecan-all"
S3_TIMEOUT=10

# Return codes used by the functions below (also used as exit codes by
# tools/list-environments.sh).
ENVC_ERR_AWS_MISSING=10  # aws CLI not on PATH
ENVC_ERR_PROFILE=11      # aws profile not configured
ENVC_ERR_S3=12           # connected, but bucket path unreadable, missing, or access denied
ENVC_ERR_EMPTY=13        # readable, but no objects match ENV_NAME_REGEX
ENVC_ERR_AWS_VERSION=14  # aws CLI present but older than 1.29
ENVC_ERR_NET=15          # no connectivity (timeout, DNS, connection refused)
AWS_MODULE="awscli_v2"

# Populated by the functions below.
ENV_LINES=()   # "VERSION<TAB>LAST_MODIFIED", newest version first
ENVC_DETAIL="" # extra detail (aws stderr) for ENVC_ERR_S3

aws_version_ok() {
  command -v aws >/dev/null 2>&1 || return 1
  local ver major minor
  ver=$(aws --version 2>&1 | awk '{print $1}' | cut -d/ -f2)
  major=$(echo "${ver}" | cut -d. -f1)
  minor=$(echo "${ver}" | cut -d. -f2)
  [[ "${major}" =~ ^[0-9]+$ && "${minor}" =~ ^[0-9]+$ ]] || return 1
  [[ "${major}" -ge 2 ]] && return 0
  [[ "${major}" -eq 1 && "${minor}" -ge 29 ]] && return 0
  return 1
}

# Ensure a usable aws CLI; fall back to 'module load awscli_v2'.
# Distinguishes "not on PATH" from "wrong version".
ensure_aws() {
  aws_version_ok && return 0
  module load "${AWS_MODULE}" 2>/dev/null || true
  aws_version_ok && return 0
  command -v aws >/dev/null 2>&1 || return "${ENVC_ERR_AWS_MISSING}"
  return "${ENVC_ERR_AWS_VERSION}"
}

# Profile presence by name only; no credential file is read.
check_profile() {
  aws configure list-profiles 2>/dev/null | grep -Fxq -- "${S3_PROFILE}" \
    || return "${ENVC_ERR_PROFILE}"
}

# List bucket, filter by regex, sort newest version first. Populates ENV_LINES.
fetch_environments() {
  ENV_LINES=()
  ENVC_DETAIL=""
  ensure_aws || return $?
  check_profile || return $?

  local errfile out rc
  errfile="$(mktemp)"
  out="$(timeout "${S3_TIMEOUT}" aws s3 ls \
          --profile "${S3_PROFILE}" \
          --cli-connect-timeout "${S3_TIMEOUT}" \
          --cli-read-timeout "${S3_TIMEOUT}" \
          "${S3_BUCKET}/" 2>"${errfile}")" && rc=0 || rc=$?
  ENVC_DETAIL="$(cat "${errfile}")"
  rm -f "${errfile}"
  if [[ ${rc} -eq 124 ]]; then
    ENVC_DETAIL="timed out after ${S3_TIMEOUT}s"
    return "${ENVC_ERR_NET}"
  fi
  if [[ ${rc} -ne 0 ]]; then
    # Connectivity failures vs. reachable-but-unreadable (denied / missing path).
    if grep -qiE 'Could not connect|Connect timeout|Read timeout|Could not resolve|Name or service not known|Temporary failure in name resolution|Connection refused|Network is unreachable|EndpointConnectionError' <<<"${ENVC_DETAIL}"; then
      return "${ENVC_ERR_NET}"
    fi
    return "${ENVC_ERR_S3}"
  fi

  # 'aws s3 ls' line: "YYYY-MM-DD HH:MM:SS   <size> <name>"
  local line name date time unsorted=()
  while IFS= read -r line; do
    [[ -n "${line}" ]] || continue
    read -r date time _ name <<<"${line}"
    if [[ "${name}" =~ ${ENV_NAME_REGEX} ]]; then
      unsorted+=("${BASH_REMATCH[1]}"$'\t'"${date} ${time}")
    fi
  done <<<"${out}"

  [[ ${#unsorted[@]} -gt 0 ]] || return "${ENVC_ERR_EMPTY}"
  mapfile -t ENV_LINES < <(printf '%s\n' "${unsorted[@]}" | sort -t$'\t' -k1,1Vr)
}

# Human-readable message for a return code from the functions above.
env_error_message() {
  case "$1" in
    "${ENVC_ERR_AWS_MISSING}")
      echo "aws CLI not found on PATH. Fix: module load ${AWS_MODULE}" ;;
    "${ENVC_ERR_AWS_VERSION}")
      echo "aws CLI version is too old (need >= 1.29). Fix: module load ${AWS_MODULE}" ;;
    "${ENVC_ERR_PROFILE}")
      echo "aws profile '${S3_PROFILE}' not found (not listed by 'aws configure list-profiles'). Fix: adjust aws configuration to add that profile, or set AWS_PROFILE to an existing profile." ;;
    "${ENVC_ERR_NET}")
      echo "no connectivity to ${S3_BUCKET}/${ENVC_DETAIL:+ (${ENVC_DETAIL})}." ;;
    "${ENVC_ERR_S3}")
      echo "connected, but cannot read ${S3_BUCKET}/ with profile '${S3_PROFILE}': path missing or access denied${ENVC_DETAIL:+ (${ENVC_DETAIL})}." ;;
    "${ENVC_ERR_EMPTY}")
      echo "no objects under ${S3_BUCKET}/ match ${ENV_NAME_REGEX}." ;;
    *)
      echo "unexpected failure (code $1)." ;;
  esac
}
