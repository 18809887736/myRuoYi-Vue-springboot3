# RuoYi-Vue-springboot3 Docker Compose 部署规划

> 目标:把 `myRuoYi-Vue-springboot3`(RuoYi v3.9.2 / Spring Boot 3.5.14)用 **4 个 docker compose 容器**(MySQL + Redis + 后端 + 前端)运行在 `43.155.156.140` 上,网络互通、单 compose 文件一键拉起。

## 1. 架构总览

```
┌─────────────────────────── 43.155.156.140 ───────────────────────────┐
│                                                                     │
│  ┌─ host port ──────────────────────────────────────────────────┐ │
│  │  18080 → nginx (前端 SPA 静态托管)  ─┐                      │ │
│  │  18081 → ruoyi-admin (Spring Boot)      │                     │ │
│  │                                         │                     │ │
│  │  docker network: ruoyi-net              │                     │ │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐   │ │
│  │  │ ruoyi-    │ │ ruoyi-    │ │ ruoyi-    │ │ ruoyi-     │   │ │
│  │  │ mysql     │ │ redis     │ │ backend   │ │ frontend   │   │ │
│  │  │ 8.0       │ │ 7-alpine  │ │  (Spring  │ │ (nginx +   │   │ │
│  │  │ 容器内    │ │ 容器内    │ │  Boot 3 / │ │  SPA dist) │   │ │
│  │  │ 13306     │ │ 16379     │ │  JDK 17)  │ │            │   │ │
│  │  │           │ │           │ │ 容器内    │ │ 容器内    │   │ │
│  │  │           │ │           │ │ 18080     │ │ 80        │   │ │
│  │  └────────────┘ └────────────┘ └────────────┘ └────────────┘   │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

容器间走内部 docker 网络 `ruoyi-net`(bridge),对外只暴露 18080(前端)和 18081(后端),其他端口(3306/6379)不外暴,减少攻击面。

## 2. 容器清单

| 容器名       | 镜像                                | 宿主机端口 | 容器端口 | 数据卷                         |
| ------------ | ----------------------------------- | --------- | ------- | ------------------------------ |
| ruoyi-mysql  | `mysql:8.0`                          | 不外暴     | 13306   | `ruoyi-mysql-data:/var/lib/mysql` |
| ruoyi-redis  | `redis:7-alpine`                      | 不外暴     | 16379   | `ruoyi-redis-data:/data`         |
| ruoyi-backend| 自建镜像(`Dockerfile` 多阶段构建)     | 18081     | 18080   | `/opt/apps/logs:/ruoyi/logs`     |
| ruoyi-frontend| `nginx:1.27-alpine`                 | 18080     | 80      | (挂前端 dist 到 nginx 目录)      |

### 镜像构建

- **ruoyi-backend**:从 `eclipse-temurin:17-jdk-jammy` 多阶段构建
  - 阶段 1:`mvn -B -q -DskipTests package` 打 jar
  - 阶段 2:拷贝 jar 运行
- **ruoyi-frontend**:从 `node:20-alpine` 多阶段构建
  - 阶段 1:`npm ci && npm run build:prod` 打 dist
  - 阶段 2:从 `nginx:1.27-alpine` 拷 dist 到 `/usr/share/nginx/html`

## 3. 目录结构

```
/home/ubuntu/work/myRuoYi-Vue-springboot3/
├── docker/                                # 本次新增
│   ├── docker-compose.yml
│   ├── .env                              # 环境变量(端口、密码等)
│   ├── mysql/
│   │   ├── conf.d/
│   │   │   └── my.cnf                    # MySQL 配置(utf8mb4 / sql_mode)
│   │   └── initdb/
│   │       └── 01-ry.sql                 # 初始化 SQL(从 sql/ry_20260417.sql 拷贝)
│   ├── redis/
│   │   └── redis.conf                    # RDB + AOF 持久化、密码
│   ├── backend/
│   │   ├── Dockerfile                    # 多阶段构建
│   │   ├── docker-entrypoint.sh         # 启动脚本(等 mysql/redis 就绪)
│   │   └── conf/
│   │       └── application-druid.yml    # 用环境变量覆盖 url/username/password
│   ├── frontend/
│   │   ├── Dockerfile                    # 多阶段构建
│   │   └── nginx.conf                    # SPA 路由 + /api 反代到 backend
│   └── README.md                         # 操作手册
└── doc/
    └── docker-compose-deploy-plan.md    # 本文档
```

## 4. 端口规划

| 用途           | 宿主机端口 | 备注 |
| -------------- | --------- | ---- |
| 前端 Web       | 18080      | 通过 nginx 反代 `/api` 到 18081 |
| 后端 Spring   | 18081      | Swagger UI / actuator 暴露 |
| MySQL          | 不外暴     | 容器内 13306,只内网通信 |
| Redis          | 不外暴     | 容器内 16379,只内网通信 |

**已占用的端口(避开)**:
- 22 SSH, 3000 new-api, 3443 dsh-https, 8000/9000/9443 portainer, 8080 未知服务。

## 5. 环境变量(`.env`)

```ini
# 镜像 tag
MYSQL_TAG=8.0
REDIS_TAG=7-alpine
NGINX_TAG=1.27-alpine
NODE_TAG=20-alpine
JAVA_TAG=17-jdk-jammy

# 端口
HOST_PORT_FRONTEND=18080
HOST_PORT_BACKEND=18081
HOST_PORT_MYSQL=13306
HOST_PORT_REDIS=16379

# MySQL
MYSQL_ROOT_PASSWORD=ChangeMe_RootPwd_2026!
MYSQL_DATABASE=ry-vue
MYSQL_USER=ruoyi
MYSQL_PASSWORD=ChangeMe_RuoyiPwd_2026!

# Redis
REDIS_PASSWORD=ChangeMe_RedisPwd_2026!

# 后端
RUOYI_PROFILE=prod
JVM_OPTS=-Xms512m -Xmx1024m
APP_PORT=18080
```

## 6. docker-compose.yml 骨架

```yaml
name: ruoyi

services:
  mysql:
    image: mysql:${MYSQL_TAG}
    container_name: ruoyi-mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE:      ${MYSQL_DATABASE}
      MYSQL_USER:          ${MYSQL_USER}
      MYSQL_PASSWORD:      ${MYSQL_PASSWORD}
    command: --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci --default-authentication-plugin=mysql_native_password
    volumes:
      - ruoyi-mysql-data:/var/lib/mysql
      - ./mysql/conf.d:/etc/mysql/conf.d:ro
      - ./mysql/initdb:/docker-entrypoint-initdb.d:ro
    networks: [ruoyi-net]
    healthcheck:
      test: ["CMD-SHELL", "mysqladmin ping -h localhost -u root -p${MYSQL_ROOT_PASSWORD}"]
      interval: 5s
      timeout: 3s
      retries: 30

  redis:
    image: redis:${REDIS_TAG}
    container_name: ruoyi-redis
    restart: unless-stopped
    command: ["redis-server", "/usr/local/etc/redis/redis.conf"]
    volumes:
      - ruoyi-redis-data:/data
      - ./redis/redis.conf:/usr/local/etc/redis/redis.conf:ro
    networks: [ruoyi-net]
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 5s
      timeout: 3s
      retries: 30

  backend:
    build:
      context: ../              # 仓库根(包含 pom.xml)
      dockerfile: docker/backend/Dockerfile
    image: ruoyi-backend:local
    container_name: ruoyi-backend
    restart: unless-stopped
    depends_on:
      mysql: { condition: service_healthy }
      redis: { condition: service_healthy }
    environment:
      SPRING_PROFILES_ACTIVE: ${RUOYI_PROFILE}
      SPRING_DATASOURCE_URL: jdbc:mysql://mysql:3306/${MYSQL_DATABASE}?...
      SPRING_DATASOURCE_USERNAME: ${MYSQL_USER}
      SPRING_DATASOURCE_PASSWORD: ${MYSQL_PASSWORD}
      SPRING_REDIS_HOST: redis
      SPRING_REDIS_PORT: 6379
      SPRING_REDIS_PASSWORD: ${REDIS_PASSWORD}
      SERVER_PORT: ${APP_PORT}
      JVM_OPTS: ${JVM_OPTS}
    volumes:
      - /opt/apps/iflytek/ruoyi-backend-logs:/ruoyi/logs
    networks: [ruoyi-net]
    healthcheck:
      test: ["CMD-SHELL", "wget -q -O - http://localhost:${APP_PORT}/actuator/health || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 12
      start_period: 60s

  frontend:
    build:
      context: ../ruoyi-ui
      dockerfile: ../docker/frontend/Dockerfile
    image: ruoyi-frontend:local
    container_name: ruoyi-frontend
    restart: unless-stopped
    depends_on:
      - backend
    ports:
      - "${HOST_PORT_FRONTEND}:80"
    volumes:
      - ./frontend/nginx.conf:/etc/nginx/conf.d/default.conf:ro
    networks: [ruoyi-net]
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost/"]
      interval: 10s
      timeout: 3s
      retries: 6

networks:
  ruoyi-net:
    driver: bridge

volumes:
  ruoyi-mysql-data:
  ruoyi-redis-data:
```

## 7. backend application-druid.yml 关键覆盖

把现有 `localhost:3306` 改成读环境变量:

```yaml
spring:
  datasource:
    druid:
      url: jdbc:mysql://${SPRING_DATASOURCE_HOST:mysql}:${SPRING_DATASOURCE_PORT:3306}/${SPRING_DATASOURCE_DB:ry-vue}?useUnicode=true&characterEncoding=utf8&zeroDateTimeBehavior=convertToNull&useSSL=false&serverTimezone=GMT%2B8&allowPublicKeyRetrieval=true
    username: ${SPRING_DATASOURCE_USERNAME}
    password: ${SPRING_DATASOURCE_PASSWORD}
  redis:
    host: ${SPRING_REDIS_HOST:redis}
    port: ${SPRING_REDIS_PORT:6379}
    password: ${SPRING_REDIS_PASSWORD:}
```

> ⚠️ `useSSL=true` 在容器内可能因为 MySQL 默认 `caching_sha2_password` 配 RSA 失败,改成 `false` + `allowPublicKeyRetrieval=true` 更稳。

## 8. frontend nginx.conf(关键片段)

```nginx
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    # SPA 路由 fallback
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API 反代到后端容器
    location /api/ {
        proxy_pass http://backend:18080;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 60s;
    }

    # 静态资源缓存
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 7d;
        add_header Cache-Control "public, max-age=604800";
    }
}
```

## 9. 启动步骤

```bash
# 0. 准备工作(一次性)
mkdir -p /opt/apps/iflytek/ruoyi-backend-logs
cp sql/ry_20260417.sql docker/mysql/initdb/01-ry.sql

# 1. 检查 server 端口(没占用 18080/18081/13306/16379)
ss -tlnp | grep -E ':18080|:18081|:13306|:16379'

# 2. 生成强密码写进 .env
sed -i 's/^MYSQL_ROOT_PASSWORD=.*/MYSQL_ROOT_PASSWORD=$(openssl rand -hex 24)/' docker/.env
sed -i 's/^MYSQL_PASSWORD=.*/MYSQL_PASSWORD=$(openssl rand -hex 16)/' docker/.env
sed -i 's/^REDIS_PASSWORD=.*/REDIS_PASSWORD=$(openssl rand -hex 16)/' docker/.env

# 3. 首次构建并拉起
cd /home/ubuntu/work/myRuoYi-Vue-springboot3/docker
docker compose build --no-cache
docker compose up -d

# 4. 验证
docker compose ps
docker compose logs -f backend | grep "Started RuoYiApplication"
curl -sI http://43.155.156.140:18080/        # 期待 200
curl -sI http://43.155.156.140:18081/actuator/health  # 期待 200

# 5. 浏览器访问
open http://43.155.156.140:18080
# 默认账号 admin / admin123
```

## 10. 初始化数据

第一次启动时,`docker-entrypoint-initdb.d/01-ry.sql` 会自动跑,创建库表 + 默认数据:

- 默认账号:`admin` / `admin123`
- 默认定时任务、白名单、字典数据都在 SQL 里

> ⚠️ 默认密码 **必须**在首次登录后立即改!登录页 → 个人中心 → 修改密码。

## 11. 运维

| 操作 | 命令 |
| ---- | ---- |
| 启动 | `docker compose up -d` |
| 停止 | `docker compose down` |
| 重启单服务 | `docker compose restart backend` |
| 看日志 | `docker compose logs -f backend` |
| 进后端容器 | `docker exec -it ruoyi-backend bash` |
| 进 MySQL | `docker exec -it ruoyi-mysql mysql -uroot -p${MYSQL_ROOT_PASSWORD} ry-vue` |
| 进 Redis | `docker exec -it ruoyi-redis redis-cli -a ${REDIS_PASSWORD}` |
| 备份 DB | `docker exec ruoyi-mysql sh -c 'mysqldump -uroot -p${MYSQL_ROOT_PASSWORD} --all-databases' > backup_$(date +%F).sql` |
| 升级后端 | `cd .. && mvn -B -DskipTests package && cd docker && docker compose build backend && docker compose up -d backend` |
| 升级前端 | `cd ../ruoyi-ui && npm run build:prod && cd ../docker && docker compose build frontend && docker compose up -d frontend` |

## 12. 安全建议

1. **必改默认密码**:MySQL root、ruoyi 用户、Redis 密码、admin123 全部改
2. **容器间全内网**:3306/6379/18080 不要 publish 到宿主
3. **后端 actuator 限制**:正式环境把 `/actuator/health` 之外的全部 endpoint 禁掉(改 `management.endpoints.web.exposure.include=health`)
4. **不要在 .env 里写真实密码提交 git**:`.env` 加进 `.gitignore`;提供 `.env.example` 模板
5. **HTTPS 反代**:18080 前面挂 nginx + Let's Encrypt,后端 18081 限制只允许 frontend 容器访问
6. **防火墙**:Ubuntu ufw 或云防火墙只放行 22 / 18080 / 18081 给可信 IP

## 13. 资源估算

| 容器       | 内存(MB) | CPU(share) | 磁盘(MB) |
| ---------- | -------- | --------- | ------- |
| mysql       | 512     | 1024      | 500+   |
| redis       | 128     | 512       | 50     |
| backend     | 1024    | 2048      | 1000   |
| frontend    | 64      | 256       | 100    |
| **合计**   | **1728** | **3840**  | **1650+** |

需要至少 2GB 内存(当前 1.9GB,需要扩到至少 4GB 才安全)。
