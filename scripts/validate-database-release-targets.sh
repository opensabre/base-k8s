#!/usr/bin/env bash
set -euo pipefail

workspace_root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
release_file="${2:?usage: validate-database-release-targets.sh WORKSPACE RELEASE_FILE}"
[[ -f "${release_file}" ]] || { echo "ERROR: release file not found: ${release_file}" >&2; exit 1; }

set -a
# shellcheck disable=SC1090
source "${release_file}"
set +a

services=(base-authorization base-organization base-sysadmin base-gateway-admin iqc-platform)
target_variables=(BASE_AUTHORIZATION_DATABASE_TARGET BASE_ORGANIZATION_DATABASE_TARGET BASE_SYSADMIN_DATABASE_TARGET BASE_GATEWAY_ADMIN_DATABASE_TARGET IQC_PLATFORM_DATABASE_TARGET)

for index in "${!services[@]}"; do
  service="${services[$index]}"
  variable="${target_variables[$index]}"
  expected="${!variable:?${variable} is required}"
  latest_file="$(find "${workspace_root}/${service}/src/main/resources/db/migration/mysql" -type f -name 'V*.sql' -print | sort -V | tail -1)"
  actual="$(basename "${latest_file}" | sed -E 's/^V([^_]+(_[^_]+)?)__.*/\1/; s/_/./g')"
  [[ "${actual}" == "${expected}" ]] || {
    echo "ERROR ${service}: release target ${expected}, migration history ends at ${actual}" >&2
    exit 1
  }
  echo "PASS ${service}: target ${expected}"
done
