# RuoYi-Vue-springboot3 Docker Compose 部署手册

> 对应规划文档: [doc/docker-compose-deploy-plan.md](../doc/docker-compose-deploy-plan.md)
> 拓扑: 4 容器(MySQL 8.0 + Redis 7 + Spring Boot 3 后端 + nginx 前端), 内部网络 `ruoyi-net`, 对外只暴露 **18080(前端)** / **18081(后端)**。

## 目录结构

```
docker/
├── docker-compose.yml          # 一键编排
├── .env                        # 真实密码/端口(gitignore, 不入库)
├── .env.example                # 模板, 拷贝为 .env 后改密码
├── mysql/
│   ├── conf.d/my.cnf           # utf8mb4 / 关 performance_schema 省内存 / lower_case_table_names
│   └── initdb/
│       ├── 01-ry.sql           # 业务库表+数据(拷自 sql/ry_20260417.sql)
│       └── 02-quartz.sql       # 定时任务表(拷自 sql/quartz.sql)
├── redis/redis.conf            # AOF+RDB 持久化, 密码由 compose 注入
├── backend/
│   ├── Dockerfile              # maven:3.9-temurin-17 构建 → temurin-17-jre 运行
│   ├── docker-entrypoint.sh    # 等 mysql/redis 就绪后起 jar
│   └── mvn-settings.xml        # 阿里云 Maven 镜像
├── frontend/
│   ├── Dockerfile              # node:20 构建 dist → nginx:1.27 托管
│   └── nginx.conf              # SPA fallback + /prod-api/ 反代 backend:18080 + websocket
└── README.md                   # 本文件
```

## 首次部署

```bash
cd /home/ubuntu/work/myRuoYi-Vue-springboot3/docker

# 1. 准备 .env(生成强密码)
cp .env.example .env
sed -i "s/^MYSQL_ROOT_PASSWORD=.*/MYSQL_ROOT_PASSWORD=$(openssl rand -hex 24)/" .env
sed -i "s/^MYSQL_PASSWORD=.*/MYSQL_PASSWORD=$(openssl rand -hex 16)/"     .env
sed -i "s/^REDIS_PASSWORD=.*/REDIS_PASSWORD=$(openssl rand -hex 16)/"     .env
sed -i "s/^TOKEN_SECRET=.*/TOKEN_SECRET=$(openssl rand -hex 32)/"         .env
chmod 600 .env

# 2. 构建并启动
docker compose build
docker compose up -d

# 3. 验证
docker compose ps
docker compose logs -f backend      # 等待 "Started RuoYiApplication"
curl -sI http://127.0.0.1:18080/                      # 200
curl -s  http://127.0.0.1:18081/captchaImage | head -c 200
```

浏览器访问 `http://43.155.156.140:18080`,默认账号 `admin / admin123`,**首次登录后立即改密码**。

## 日常运维

| 操作 | 命令 |
| ---- | ---- |
| 启动 | `docker compose up -d` |
| 停止 | `docker compose down` |
| 重启单服务 | `docker compose restart backend` |
| 看日志 | `docker compose logs -f backend` |
| 进后端容器 | `docker exec -it ruoyi-backend bash` |
| 进 MySQL | `docker exec -it ruoyi-mysql mysql -uroot -p ry-vue` |
| 进 Redis | `docker exec -it ruoyi-redis redis-cli -a "$(grep ^REDIS_PASSWORD .env \| cut -d= -f2)"` |
| 备份 DB | `docker exec ruoyi-mysql sh -c 'mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" ry-vue' > backup_$(date +%F).sql` |
| 升级后端 | `docker compose build backend && docker compose up -d backend` |
| 升级前端 | `docker compose build frontend && docker compose up -d frontend` |

## 实现与规划文档的差异(以实际代码为准)

| 规划文档 | 实际实现 | 原因 |
| -------- | -------- | ---- |
| `SPRING_REDIS_HOST/PORT/PASSWORD` | `SPRING_DATA_REDIS_*` | Spring Boot 3 的 redis 配置在 `spring.data.redis` 下 |
| `SPRING_DATASOURCE_URL/USERNAME/PASSWORD` | `SPRING_DATASOURCE_DRUID_MASTER_*` | RuoYi 主库配置在 `spring.datasource.druid.master.*` |
| `SPRING_PROFILES_ACTIVE=prod` | 不设置(保留默认 `druid`) | 数据源配置在 `application-druid.yml`,切走 druid profile 会导致启动失败 |
| nginx 反代 `/api/` | 反代 `/prod-api/` | 前端 `VUE_APP_BASE_API=/prod-api` |
| backend 挂载 `/ruoyi/logs` | 挂载 `/home/ruoyi/logs` | logback.xml 中 `log.path=/home/ruoyi/logs` |
| 后端健康检查 `/actuator/health` | TCP 端口探活 | pom 中没有 actuator 依赖 |
| frontend context=`../ruoyi-ui`, dockerfile 在上下文外 | 两个服务 context 均为仓库根 | BuildKit 禁止 Dockerfile 位于构建上下文之外 |
| MySQL 挂配置外的端口暴露 | 3306/6379 完全不外暴 | 同方案 §1, 减少攻击面 |

另外的加固/调整:

- `npm ci` → `npm install --legacy-peer-deps`(仓库无 package-lock.json)
- 前端构建加 `NODE_OPTIONS=--openssl-legacy-provider`(vue-cli4/webpack4 在 Node 17+ 必需)
- `ruoyi.profile` 上传目录由默认 `D:/ruoyi/uploadPath` 改为容器内 `/home/ruoyi/uploadPath` 并挂载持久化
- JWT `token.secret` 由默认值改为 `.env` 注入的随机密钥
- druid 监控台(`/druid/*`)已通过环境变量关闭
- 新增 `token.secret` 随机化; MySQL 关闭 `performance_schema` 省 300-400M 内存

## 安全注意事项(方案 §12)

1. `.env` 含真实密码,已加入 `.gitignore`,勿提交/外传
2. `admin/admin123` 默认密码**必须**首登即改
3. 3306/6379/13306/16379 均未对外发布,仅容器网络内互通
4. 建议后续在云防火墙只放行 22 / 18080 / 18081,并考虑 HTTPS 反代
