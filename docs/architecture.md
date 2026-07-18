# 架构与边界

本仓库提供 OpenSabre 的容器化运行编排和初始化材料。根目录各 `docker-compose*.yml` 按基础设施、应用或单服务拆分；`config/` 存放运行配置样例，`initdb/` 存放数据库初始化入口。

部署文档不应复制敏感 `.env` 内容；变量名、默认值和覆盖方式以 `.env.example` 与 Compose 文件为准。
