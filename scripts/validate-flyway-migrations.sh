#!/usr/bin/env bash
set -euo pipefail

workspace_root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
shift || true
if [[ $# -gt 0 ]]; then
  services=("$@")
else
  services=(base-authorization base-organization base-sysadmin base-gateway-admin iqc-platform)
fi
failed=0

for service in "${services[@]}"; do
  migration_dir="${workspace_root}/${service}/src/main/resources/db/migration/mysql"
  if [[ ! -d "${migration_dir}" ]]; then
    echo "ERROR ${service}: missing ${migration_dir}" >&2
    failed=1
    continue
  fi

  for directory in baseline history ddl dml; do
    if [[ ! -d "${migration_dir}/${directory}" ]]; then
      echo "ERROR ${service}: missing ${directory}/ migration directory" >&2
      failed=1
    fi
  done

  file_count=0
  versioned_versions=""
  baseline_count=0
  baseline_version=""
  while IFS= read -r file; do
    file_count=$((file_count + 1))
    relative="${file#${migration_dir}/}"
    directory="${relative%%/*}"
    name="$(basename "${file}")"

    if [[ ! "${name}" =~ ^[VB][0-9]+([._][0-9]+)*__[a-z0-9_]+\.sql$ ]]; then
      echo "ERROR ${service}: invalid Flyway filename ${relative}" >&2
      failed=1
      continue
    fi
    if [[ ! "${directory}" =~ ^(baseline|history|ddl|dml)$ ]]; then
      echo "ERROR ${service}: SQL must be under baseline/, history/, ddl/, or dml/: ${relative}" >&2
      failed=1
    fi

    prefix="${name:0:1}"
    version="${name%%__*}"
    version="${version:1}"
    if [[ "${prefix}" == B ]]; then
      baseline_count=$((baseline_count + 1))
      baseline_version="${version}"
      if [[ "${directory}" != baseline || "${name}" != *"__baseline.sql" ]]; then
        echo "ERROR ${service}: baseline migration must be baseline/B<version>__baseline.sql: ${relative}" >&2
        failed=1
      fi
    else
      versioned_versions="${versioned_versions}${version}\n"
      if [[ "${directory}" == baseline ]]; then
        echo "ERROR ${service}: V migration is not allowed in baseline/: ${relative}" >&2
        failed=1
      fi
      if [[ "${directory}" == ddl && "${name}" != *"__ddl_"* ]]; then
        echo "ERROR ${service}: DDL migration description must start with ddl_: ${relative}" >&2
        failed=1
      fi
      if [[ "${directory}" == dml && "${name}" != *"__dml_"* ]]; then
        echo "ERROR ${service}: DML migration description must start with dml_: ${relative}" >&2
        failed=1
      fi
    fi

    if grep -Eni '^[[:space:]]*(USE([[:space:]]|\`)|CREATE[[:space:]]+DATABASE|DROP[[:space:]]+DATABASE)|\`(os_base_[^\`]+|iqc_platform)\`[[:space:]]*\.' "${file}" >/dev/null; then
      echo "ERROR ${service}: ${relative} may not switch, create, drop, or explicitly qualify an OpenSabre database" >&2
      failed=1
    fi
    if [[ "${directory}" == ddl ]] && grep -Eni '^[[:space:]]*(INSERT|UPDATE|DELETE|REPLACE|MERGE)[[:space:]]' "${file}" >/dev/null; then
      echo "ERROR ${service}: DDL migration contains data-changing SQL: ${relative}" >&2
      failed=1
    fi
    if [[ "${directory}" == dml ]] && grep -Eni '^[[:space:]]*(CREATE|ALTER|DROP|TRUNCATE|RENAME)[[:space:]]' "${file}" >/dev/null; then
      echo "ERROR ${service}: DML migration contains schema-changing SQL: ${relative}" >&2
      failed=1
    fi
  done < <(find "${migration_dir}" -type f -name '*.sql' -print | sort)

  if [[ ${file_count} -eq 0 ]]; then
    echo "ERROR ${service}: no Flyway migrations" >&2
    failed=1
    continue
  fi
  duplicates="$(printf '%b' "${versioned_versions}" | sed '/^$/d' | sort | uniq -d)"
  if [[ -n "${duplicates}" ]]; then
    echo "ERROR ${service}: duplicate V migration versions: ${duplicates}" >&2
    failed=1
  fi
  if [[ ${baseline_count} -ne 1 ]]; then
    echo "ERROR ${service}: expected exactly one B baseline migration, found ${baseline_count}" >&2
    failed=1
  else
    latest_version="$(printf '%b' "${versioned_versions}" | sed '/^$/d' | sort -V | tail -1)"
    newest_version="$(printf '%s\n%s\n' "${baseline_version//_/.}" "${latest_version//_/.}" | sort -V | tail -1)"
    if [[ "${newest_version}" != "${latest_version//_/.}" ]]; then
      echo "ERROR ${service}: baseline ${baseline_version} may not be newer than latest V migration ${latest_version}" >&2
      failed=1
    fi
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
