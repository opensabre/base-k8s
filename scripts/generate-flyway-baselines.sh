#!/usr/bin/env bash
set -euo pipefail

workspace_root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
mysql_image="${MYSQL_TEST_IMAGE:-mysql:8.0}"
flyway_image="${FLYWAY_TEST_IMAGE:-redgate/flyway:11.18.0}"
run_id="$(date +%Y%m%d%H%M%S)-$$"
network="flyway-baseline-${run_id}"
mysql_container="flyway-baseline-mysql-${run_id}"
root_password="root_${run_id//-/_}_${RANDOM}"

services=(base-authorization base-organization base-sysadmin base-gateway-admin iqc-platform)
databases=(os_base_auth os_base_organization os_base_sysadmin os_base_gateway_admin iqc_platform)
versions=(20260823_06 20260831_02 20260829_02 20260901_01 1.1.20)

cleanup() {
  status=$?
  if [[ ${status} -ne 0 ]]; then
    docker logs "${mysql_container}" >&2 2>/dev/null || true
  fi
  docker rm -f "${mysql_container}" >/dev/null 2>&1 || true
  docker network rm "${network}" >/dev/null 2>&1 || true
  return "${status}"
}
trap cleanup EXIT INT TERM

docker network create "${network}" >/dev/null
docker run -d --name "${mysql_container}" --network "${network}" \
  --memory 768m --memory-swap 1g \
  -e MYSQL_ROOT_PASSWORD="${root_password}" -e MYSQL_ROOT_HOST=% \
  "${mysql_image}" --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci >/dev/null

ready=0
for _ in $(seq 1 60); do
  if docker exec "${mysql_container}" sh -c \
    'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -Nse "SELECT 1"' >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 2
done
[[ ${ready} -eq 1 ]] || { echo "ERROR: isolated MySQL did not become ready" >&2; exit 1; }

for index in "${!services[@]}"; do
  service="${services[$index]}"
  database="${databases[$index]}"
  migration_dir="${workspace_root}/${service}/src/main/resources/db/migration/mysql"
  baseline_dir="${migration_dir}/baseline"
  output="${baseline_dir}/B${versions[$index]}__baseline.sql"

  mkdir -p "${baseline_dir}"
  docker exec "${mysql_container}" sh -c \
    'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE \`$1\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"' \
    -- "${database}"

  docker run --rm --network "${network}" -v "${migration_dir}:/flyway/sql:ro" "${flyway_image}" \
    "-url=jdbc:mysql://${mysql_container}:3306/${database}?useSSL=false&allowPublicKeyRetrieval=true" \
    -user=root "-password=${root_password}" -connectRetries=60 -validateMigrationNaming=true \
    -baselineOnMigrate=false -cleanDisabled=true migrate

  {
    echo "-- Generated from the complete verified migration history."
    echo "-- Regenerate with base-k8s/scripts/generate-flyway-baselines.sh; do not edit manually."
    docker exec "${mysql_container}" sh -c \
      'exec mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --skip-comments --skip-add-locks --skip-disable-keys --no-tablespaces --set-gtid-purged=OFF --ignore-table="$1.flyway_schema_history" "$1"' \
      -- "${database}"
  } >"${output}"

  echo "Generated ${output}"
done
