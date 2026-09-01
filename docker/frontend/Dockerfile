# 前端镜像: 多阶段构建(方案 §2)
# RuoYi-Vue 前端是 vue-cli4/webpack4: 在 Node 17+ 上需要 --openssl-legacy-provider
# 仓库没有 package-lock.json, 因此用 npm install(而非 npm ci)
FROM node:20-alpine AS build
WORKDIR /app
ENV NODE_OPTIONS=--openssl-legacy-provider
COPY ruoyi-ui/package.json ./
RUN npm install --registry=https://registry.npmmirror.com --legacy-peer-deps --no-audit --no-fund
COPY ruoyi-ui/ ./
RUN npm run build:prod

FROM nginx:1.27-alpine
ENV TZ=Asia/Shanghai
COPY docker/frontend/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
