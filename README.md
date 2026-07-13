# base-k8s

Opensabre 项目群 Docker Compose 初始化部署配置。

本目录提供三类入口：

- `docker-compose.yml`：推荐入口，用于新服务器快速初始化基础设施和项目群应用。
- `docker-compose-infra.yml`：中间件/数据库入口，用于专门部署 MySQL、Redis、RNacos、RabbitMQ、Sentinel。
- `docker-compose-apps.yml`：应用入口，用于专门部署 base 应用、网关和管理前端。
- `docker-compose-base-*.yml`、`docker-compose-opensabre-admin.yml`：兼容入口，用于已有基础设施/网络时单独启动某个应用。

## 目录说明

```text
base-k8s/
├── docker-compose.yml                     # 完整项目群编排
├── docker-compose-infra.yml               # 中间件/数据库编排
├── docker-compose-apps.yml                # 应用编排
├── docker-compose-base-*.yml              # 单应用兼容编排
├── docker-compose-opensabre-admin.yml     # 前端兼容编排
├── .env.example                           # 环境变量模板
├── initdb/
│   ├── 10-opensabre-init.sh               # MySQL 首次初始化入口
│   └── sql/                               # base 应用数据库初始化脚本
└── config/
    ├── bootstrap.yml                      # Spring Cloud bootstrap 覆盖配置
    ├── base-gateway-application.yml       # base-gateway 专用 application 覆盖配置
    ├── base-gateway.yml                   # base-gateway 专用 classpath 配置
    └── application.yml                    # 通用 application 覆盖配置
```

## 前置条件

- Docker Engine
- Docker Compose v2
- 已按 `.env.example` 准备当前环境变量。

## 首次部署

1. 复制环境变量模板。

```bash
cp .env.example .env
```

2. 修改 `.env`。

至少需要调整这些值：

```properties
PUBLIC_HOST=你的服务器域名或IP
AUTH_ISSUER_URI=http://你的服务器域名或IP:8000
GATEWAY_REDIRECT_URI=http://你的服务器域名或IP:8443/login/oauth2/code/base-gateway-client
MYSQL_ROOT_PASSWORD=替换为强密码
DATASOURCE_PASSWORD=替换为强密码
RABBITMQ_DEFAULT_PASS=替换为强密码
RABBIT_MQ_PASSWORD=替换为强密码
```

生产环境建议同时固定所有应用镜像标签，避免默认 `latest` 带来不可重复部署。

3. 启动完整项目群。

```bash
docker compose up -d
```

4. 查看状态和日志。

```bash
docker compose ps
docker compose logs -f base-gateway
```

## 多服务器拆分部署

如果中间件和应用部署在不同服务器，建议使用拆分入口：

- 中间件服务器：只运行 `docker-compose-infra.yml`。
- 应用服务器：只运行 `docker-compose-apps.yml`。

中间件服务器首次启动：

```bash
docker compose -f docker-compose-infra.yml up -d
```

应用服务器的 `.env` 需要把中间件地址改成中间件服务器的内网 IP 或 DNS：

```properties
REGISTER_HOST=中间件服务器内网IP
REDIS_HOST=中间件服务器内网IP
DATASOURCE_HOST=中间件服务器内网IP
RABBIT_MQ_HOST=中间件服务器内网IP
SENTINEL_DASHBOARD_HOST=中间件服务器内网IP
```

然后在应用服务器启动：

```bash
docker compose -f docker-compose-apps.yml up -d
```

拆分部署时，`docker-compose-apps.yml` 不依赖中间件容器的 `depends_on`，因为这些容器不在同一个 Docker Compose 项目或同一台机器上。启动前需要确认应用服务器可以访问中间件服务器的 `3306/6379/8848/9848/5672/8858` 等端口，生产环境建议只对应用服务器内网地址放行；`10848` 是 RNacos 控制台端口，不建议对公网开放。

## 端口

| 服务 | 宿主机端口 | 容器端口 | 说明 |
| --- | --- | --- | --- |
| opensabre-admin | 8080 | 80 | 管理前端 |
| base-gateway | 443, 8443 | 8443 | 网关 |
| base-authorization | 8000 | 8000 | 认证服务 |
| base-organization | 8010 | 8010 | 组织/RBAC 服务 |
| base-sysadmin | 8020 | 8020 | 系统管理服务 |
| mysql | 3306 | 3306 | 数据库 |
| redis | 6379 | 6379 | 缓存 |
| rnacos | 8848, 9848, 10848 | 同左 | 注册/配置中心，10848 为控制台 |
| rabbitmq | 5672, 15672 | 同左 | MQ 与管理端 |
| sentinel-dashboard | 8858 | 8858 | Sentinel 控制台 |

如果只想从网关访问后端服务，可以按安全策略移除 `8000/8010/8020/3306/6379` 等端口映射。

## 数据库初始化

MySQL 首次创建数据卷时会执行 `initdb/10-opensabre-init.sh`，该脚本按数据库显式执行：

- `initdb/sql/base-authorization/os-base-auth-db.sql`
- `initdb/sql/base-authorization/os-base-auth-ddl.sql`
- `initdb/sql/base-organization/os-base-org-db.sql`
- `initdb/sql/base-organization/os-base-org-ddl.sql`
- `initdb/sql/base-sysadmin/os-base-sysadmin-db.sql`
- `initdb/sql/base-sysadmin/os-base-sysadmin-ddl.sql`

注意：MySQL 官方镜像只在数据目录为空时执行 `/docker-entrypoint-initdb.d`。如果需要重新初始化数据库，需要先备份数据，再删除 `mysql-data` 卷。

## RNacos 注册 IP

默认 `NACOS_DISCOVERY_IP` 为空，此时 RNacos 会注册容器地址，适合只在单机 Docker 网络内互相调用的部署。

当本机或其他机器需要直接通过 RNacos 发现并访问这些服务实例时，设置为应用宿主机的可达 IP：

```properties
NACOS_DISCOVERY_IP=服务器内网IP
```

Compose 会通过 `config/bootstrap.yml` 写入 `spring.cloud.nacos.discovery.ip`，不要把固定旧服务器 IP 写死在 `config/bootstrap.yml` 中。

## 单服务兼容启动

单服务 compose 文件默认使用外部 Docker 网络 `opensabre`。如果未通过完整编排创建过该网络，需要先执行：

```bash
docker network create opensabre
```

示例：

```bash
docker compose -f docker-compose-base-gateway.yml up -d
docker compose -f docker-compose-opensabre-admin.yml up -d
```

单服务模式不会启动 MySQL、Redis、RNacos、RabbitMQ 等基础设施，需要 `.env` 指向已有服务。

## 常见问题

### 前端访问接口 502

`base-k8s` 会把 `config/opensabre-admin-nginx.conf` 挂载到前端容器，并代理到 Docker 网络内的 `base-gateway:8443`。如果没有使用本目录的 compose 文件启动前端，需要确认前端 Nginx upstream 与网关容器端口一致。

### OAuth 登录跳转不正确

检查 `.env` 中：

```properties
AUTH_ISSUER_URI=
GATEWAY_REDIRECT_URI=
```

这两个值必须和浏览器可访问的服务器地址、认证服务签发地址一致。

### 修改 SQL 后没有重新执行

MySQL 初始化脚本只在首次创建空数据卷时执行。开发/测试环境可删除数据卷后重启：

```bash
docker compose down -v
docker compose up -d
```

生产环境不要直接删除数据卷。
