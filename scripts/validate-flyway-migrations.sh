#!/usr/bin/env bash
set -euo pipefail

workspace_root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
services=(base-authorization base-organization base-sysadmin base-gateway-admin iqc-platform)
failed=0

for service in "${services[@]}"; do
  migration_dir="${workspace_root}/${service}/src/main/resources/db/migration/mysql"
  if [[ ! -d "${migration_dir}" ]]; then
    echo "ERROR ${service}: missing ${migration_dir}" >&2
    failed=1
    continue
  fi

  file_count=0
  versions=""
  baseline_count=0
  while IFS= read -r file; do
    file_count=$((file_count + 1))
    name="$(basename "${file}")"
    if [[ ! "${name}" =~ ^V[0-9]+([._][0-9]+)*__[a-z0-9_]+\.sql$ ]]; then
      echo "ERROR ${service}: invalid Flyway filename ${name}" >&2
      failed=1
      continue
    fi
    versions="${versions}${name%%__*}\n"
    if [[ "${name}" == *"__baseline.sql" ]]; then
      baseline_count=$((baseline_count + 1))
    fi
    if grep -Eni '^[[:space:]]*(USE([[:space:]]|`)|CREATE[[:space:]]+DATABASE|DROP[[:space:]]+DATABASE)|`os_base_[^`]+`[[:space:]]*\.' "${file}" >/dev/null; then
      echo "ERROR ${service}: ${name} may not switch, create, drop, or explicitly qualify an OpenSabre database" >&2
      grep -Eni '^[[:space:]]*(USE([[:space:]]|`)|CREATE[[:space:]]+DATABASE|DROP[[:space:]]+DATABASE)|`os_base_[^`]+`[[:space:]]*\.' "${file}" >&2
      failed=1
    fi
  done < <(find "${migration_dir}" -maxdepth 1 -type f -name '*.sql' -print | sort)

  if [[ ${file_count} -eq 0 ]]; then
    echo "ERROR ${service}: no Flyway migrations" >&2
    failed=1
    continue
  fi

  duplicates="$(printf '%b' "${versions}" | sort | uniq -d)"
  if [[ -n "${duplicates}" ]]; then
    echo "ERROR ${service}: duplicate Flyway versions: ${duplicates}" >&2
    failed=1
  fi
  if [[ ${baseline_count} -ne 1 ]]; then
    echo "ERROR ${service}: expected exactly one baseline migration, found ${baseline_count}" >&2
    failed=1
  fi
  if find "${workspace_root}/${service}/src/main/resources/db/migrations" -type f -name '*.sql' -print -quit 2>/dev/null | grep -q .; then
    echo "ERROR ${service}: legacy db/migrations directory still contains SQL" >&2
    failed=1
  fi
done

if [[ ${failed} -ne 0 ]]; then
  exit 1
fi

echo "Flyway migration layout is valid for ${#services[@]} services."
