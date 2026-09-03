#!/usr/bin/env bash
set -euo pipefail

workspace_root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
mysql_image="${MYSQL_TEST_IMAGE:-mysql:8.0}"
flyway_image="${FLYWAY_TEST_IMAGE:-redgate/flyway:11.18.0}"
run_id="$(date +%Y%m%d%H%M%S)-$$"
network="flyway-upgrade-${run_id}"
mysql_container="flyway-upgrade-mysql-${run_id}"
root_password="root_${run_id//-/_}_${RANDOM}"
snapshot_file="$(mktemp)"

services=(base-authorization base-organization base-sysadmin base-authorization base-organization base-sysadmin)
releases=(0.6 0.6 0.6 0.7 0.7 0.7)
commits=(26e662f1876d45ed19860fc659c3d71dfa3f1ef3 217663b54f6d40645c3995b31d3c9fc99c4bac1d 5de60935c325cab8720b6eb7c7dd8291d83c7eb2 e4f9ab4dec45d1f1928a060c7e2c7072f9bfa12c 1b69c9d4ee19c888f174de41bf34974b73a285f9 ed5f31219867ddc65d6a2281fe5a5453ff3616f4)
databases=(os_base_auth os_base_organization os_base_sysadmin os_base_auth os_base_organization os_base_sysadmin)
ddl_paths=(src/main/resources/db/os-base-auth-ddl.sql src/main/resources/db/os-base-org-ddl.sql src/main/resources/db/os-base-sysadmin-ddl.sql src/main/resources/db/os-base-auth-ddl.sql src/main/resources/db/os-base-org-ddl.sql src/main/resources/db/os-base-sysadmin-ddl.sql)
baselines=(20260723.01 20260721.02 20260720.02 20260808.01 20260810.01 20260729.01)

cleanup() {
  status=$?
  if [[ ${status} -ne 0 ]]; then
    docker logs "${mysql_container}" >&2 2>/dev/null || true
  fi
  docker rm -f "${mysql_container}" >/dev/null 2>&1 || true
  docker network rm "${network}" >/dev/null 2>&1 || true
  rm -f "${snapshot_file}"
  return "${status}"
}
trap cleanup EXIT INT TERM

"${workspace_root}/base-k8s/scripts/validate-flyway-migrations.sh" "${workspace_root}"
docker network create "${network}" >/dev/null
docker run -d --name "${mysql_container}" --network "${network}" --memory 768m --memory-swap 1g \
  -e MYSQL_ROOT_PASSWORD="${root_password}" -e MYSQL_ROOT_HOST=% "${mysql_image}" \
  --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci >/dev/null

for _ in $(seq 1 60); do
  docker exec "${mysql_container}" sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -Nse "SELECT 1"' >/dev/null 2>&1 && break
  sleep 2
done
docker exec "${mysql_container}" sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -Nse "SELECT 1"' >/dev/null

for index in "${!services[@]}"; do
  service="${services[$index]}"
  database="${databases[$index]}"
  user="upgrade_${index}_${RANDOM}"
  password="upgrade_${run_id//-/_}_${index}_${RANDOM}"
  git -C "${workspace_root}/${service}" show "${commits[$index]}:${ddl_paths[$index]}" >"${snapshot_file}"

  printf '%s\n' "DROP DATABASE IF EXISTS \`${database}\`;" \
    "CREATE DATABASE \`${database}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" \
    "CREATE USER '${user}'@'%' IDENTIFIED BY '${password}';" \
    "GRANT ALL PRIVILEGES ON \`${database}\`.* TO '${user}'@'%';" \
    | docker exec -i "${mysql_container}" sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD"'
  docker exec -i "${mysql_container}" sh -c \
    'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -D"$1"' -- "${database}" <"${snapshot_file}"

  flyway=(docker run --rm --network "${network}" -v "${workspace_root}/${service}/src/main/resources/db/migration/mysql:/flyway/sql:ro" "${flyway_image}"
    "-url=jdbc:mysql://${mysql_container}:3306/${database}?useSSL=false&allowPublicKeyRetrieval=true" "-user=${user}" "-password=${password}"
    -connectRetries=60 -validateMigrationNaming=true -baselineOnMigrate=false -cleanDisabled=true)
  "${flyway[@]}" "-baselineVersion=${baselines[$index]}" baseline
  "${flyway[@]}" migrate
  "${flyway[@]}" validate
  failed="$(docker exec "${mysql_container}" mysql -u"${user}" -p"${password}" -Nse \
    "SELECT COUNT(*) FROM \`${database}\`.flyway_schema_history WHERE success=0")"
  [[ "${failed}" -eq 0 ]] || { echo "ERROR ${service} ${releases[$index]}: failed migration history" >&2; exit 1; }
  echo "PASS ${service}: ${releases[$index]} snapshot adopted at ${baselines[$index]} and upgraded"
done

echo "Existing-database upgrade validation passed for OpenSabre 0.6 and 0.7 snapshots."
