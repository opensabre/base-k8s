# Prometheus 运行监控

OpenSabre 使用 Prometheus 保存网关和基础微服务的运行指标，`base-gateway-admin` 负责执行固定
PromQL，`opensabre-admin` 负责图形化展示。浏览器不直接访问 Prometheus，也不能提交任意 PromQL。

## 部署边界

- Prometheus 只加入 `opensabre` Docker 网络，不映射宿主机端口。
- 应用管理端口 `18080` 只在 Docker 网络内可达。
- 默认每 15 秒抓取一次，数据保留 30 天或 20 GB，以先达到者为准。
- TSDB 使用 `prometheus-data` 命名卷，容器重建不会删除历史数据。
- 首批目标为网关、网关控制面、授权、组织和系统管理服务。

## 指标与基数

公共 Nacos 配置只为 `http.server.requests` 和 `spring.cloud.gateway.requests` 开启直方图，
用于计算 P50/P95/P99。不得使用原始 URL、用户标识、请求参数等无界值作为指标标签。

## 运维验证

```bash
docker compose -f docker-compose-infra.yml config --quiet
docker compose -f docker-compose-infra.yml up -d prometheus
docker exec opensabre-prometheus promtool check config /etc/prometheus/prometheus.yml
docker exec opensabre-prometheus wget -qO- http://127.0.0.1:9090/api/v1/targets
```

`base-gateway-admin` 使用 `PROMETHEUS_URL=http://prometheus:9090` 访问查询 API。Prometheus
不可达、查询失败和查询成功但无样本是不同状态，管理端不得统一显示为“无数据”。
