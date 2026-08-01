#!/usr/bin/env sh
set -eu

# 发布版本库中的非敏感公共配置；密钥和令牌不得加入该文件。
NACOS_HOST="${REGISTER_HOST:-rnacos}"
NACOS_PORT="${REGISTER_PORT:-8848}"
DATA_ID="${OPENSABRE_COMMON_CONFIG_DATA_ID:-opensabre-common.yml}"
GROUP="${OPENSABRE_COMMON_CONFIG_GROUP:-DEFAULT_GROUP}"
CONFIG_FILE="${1:-config/nacos/opensabre-common.yml}"

test -f "$CONFIG_FILE"
curl --fail-with-body --silent --show-error --request POST \
  "http://${NACOS_HOST}:${NACOS_PORT}/nacos/v1/cs/configs" \
  --data-urlencode "dataId=${DATA_ID}" \
  --data-urlencode "group=${GROUP}" \
  --data-urlencode "type=yaml" \
  --data-urlencode "content@${CONFIG_FILE}"
printf '\nPublished %s/%s to Nacos.\n' "$GROUP" "$DATA_ID"
