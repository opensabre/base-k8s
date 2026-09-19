# Prometheus 运行监控

OpenSabre 使用 Prometheus 保存网关和基础微服务的运行指标，`base-gateway-admin` 负责执行固定
PromQL，`opensabre-admin` 负责图形化展示。浏览器不直接访问 Prometheus，也不能提交任意 PromQL。

## 部署边界

- Prometheus 只加入 `opensabre` Docker 网络，不映射宿主机端口。
- 应用管理端口 `18080` 只在 Docker 网络内可达。
- 默认每 15 秒抓取一次，数据保留 30 天或 20 GB，以先达到者为准。
- TSDB 使用 `prometheus-data` 命名卷，容器重建不会删除历史数据。
- 首批目标为网关、网关控制面、授权、组织和系统管理服务。
- `/actuator/**` 不允许匿名访问。固定的单项指标及密钥版本检查保留 OpenSabre
  内部 Token；Prometheus 抓取及网关运行参数读取使用具有 `actuator.read` scope 的
  OAuth2 client-credentials 令牌。Framework 不需要改动。
- Prometheus 与网关控制面使用不同的 OAuth2 客户端，便于独立轮换和审计；凭据只保存在
  服务器 `secrets/` 目录，不进入 Git、Nacos 或 Prometheus 配置文件。

## 指标与基数

公共 Nacos 配置只为 `http.server.requests` 和 `spring.cloud.gateway.requests` 开启直方图，
用于计算 P50/P95/P99。不得使用原始 URL、用户标识、请求参数等无界值作为指标标签。
当前 Spring Cloud Gateway 5 的路由请求指标默认关闭，Compose 为网关显式设置
`SPRING_CLOUD_GATEWAY_SERVER_WEBFLUX_METRICS_ENABLED=true`；发布后应经网关请求一条路由并
确认 `spring_cloud_gateway_requests_seconds_bucket` 在 Prometheus 中出现。

## 运维验证

首次部署在 `base-k8s` 目录执行 `python3 scripts/provision-actuator-oauth-clients.py`。
脚本复用授权服务已有的 `oauth2_registered_client` 表，生成两组随机凭据并写入
`secrets/`；须确认服务器已有 `python3` 的 `bcrypt` 模块、运行中的 MySQL 容器和数据库
Root 凭据。脚本不输出明文或密钥哈希。不要把仓库中的公共 Nacos 配置直接覆盖线上
`opensabre-common.yml`，线上文件还包含运行时注入的认证密钥。

部署顺序：先注册客户端并配置 Prometheus OAuth2 抓取，再部署收紧了 Actuator 访问规则的
应用，最后验证所有目标为 `UP`。如果 OAuth2 令牌获取失败，先恢复原应用镜像，不要放宽
`/actuator/**` 的匿名访问。

```bash
docker compose -f docker-compose-infra.yml config --quiet
docker compose -f docker-compose-infra.yml up -d prometheus
docker exec opensabre-prometheus promtool check config /etc/prometheus/prometheus.yml
docker exec opensabre-prometheus wget -qO- http://127.0.0.1:9090/api/v1/targets
```

应分别验证未带凭据的 `/actuator/prometheus`、`/actuator/health` 返回 401，Prometheus
`client_credentials` 抓取返回 200，内部 Token 单项指标请求返回 200；只检查容器健康或
前端图表不足以证明鉴权链路正确。

`base-gateway-admin` 使用 `PROMETHEUS_URL=http://prometheus:9090` 访问查询 API。Prometheus
不可达、查询失败和查询成功但无样本是不同状态，管理端不得统一显示为“无数据”。
