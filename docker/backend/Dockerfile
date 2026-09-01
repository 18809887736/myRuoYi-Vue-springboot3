# 后端镜像: 多阶段构建(方案 §2)
# 注意: BuildKit 要求 Dockerfile 位于构建上下文内,
#       因此 docker-compose.yml 中 backend/frontend 的 context 都是仓库根目录
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /build

# 使用阿里云 Maven 镜像加速
COPY docker/backend/mvn-settings.xml /usr/share/maven/conf/settings.xml

# 先拷 pom 拉依赖, 利用层缓存加速重复构建
COPY pom.xml .
COPY ruoyi-admin/pom.xml ruoyi-admin/
COPY ruoyi-common/pom.xml ruoyi-common/
COPY ruoyi-framework/pom.xml ruoyi-framework/
COPY ruoyi-generator/pom.xml ruoyi-generator/
COPY ruoyi-quartz/pom.xml ruoyi-quartz/
COPY ruoyi-system/pom.xml ruoyi-system/
RUN mvn -B -q dependency:go-offline -DskipTests || true

COPY . .
RUN mvn -B -q -DskipTests package

# 运行镜像用 JRE, 体积更小
FROM eclipse-temurin:17-jre-jammy
ENV TZ=Asia/Shanghai \
    LANG=C.UTF-8
WORKDIR /ruoyi
RUN mkdir -p /home/ruoyi/logs /home/ruoyi/uploadPath
COPY --from=build /build/ruoyi-admin/target/ruoyi-admin.jar app.jar
COPY docker/backend/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
EXPOSE 18080
ENTRYPOINT ["docker-entrypoint.sh"]
