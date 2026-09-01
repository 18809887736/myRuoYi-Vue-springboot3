<template>
  <div class="app-container home">
    <el-card class="welcome-card" shadow="never">
      <div class="welcome-body">
        <h1>{{ title }}</h1>
        <p class="greeting">{{ greeting }}，{{ nickName || '欢迎回来' }}</p>
        <p class="date">{{ today }}</p>
        <el-divider />
        <p class="tip">系统运行正常，请在左侧菜单选择要使用的功能。</p>
      </div>
    </el-card>
  </div>
</template>

<script>
import { mapGetters } from 'vuex'

export default {
  name: 'Index',
  data() {
    return {
      title: process.env.VUE_APP_TITLE
    }
  },
  computed: {
    ...mapGetters([
      'nickName'
    ]),
    greeting() {
      const hour = new Date().getHours()
      if (hour < 6) return '凌晨好'
      if (hour < 9) return '早上好'
      if (hour < 12) return '上午好'
      if (hour < 14) return '中午好'
      if (hour < 18) return '下午好'
      return '晚上好'
    },
    today() {
      const d = new Date()
      const week = ['日', '一', '二', '三', '四', '五', '六'][d.getDay()]
      return `${d.getFullYear()} 年 ${d.getMonth() + 1} 月 ${d.getDate()} 日 星期${week}`
    }
  }
}
</script>

<style lang="scss" scoped>
.home {
  min-height: calc(100vh - 84px);
  display: flex;
  align-items: center;
  justify-content: center;
  background-color: #f5f7fa;

  .welcome-card {
    width: 560px;
    max-width: 90%;
    border-radius: 8px;
    text-align: center;
  }

  .welcome-body {
    padding: 40px 24px;

    h1 {
      margin: 0 0 16px;
      font-size: 28px;
      font-weight: 600;
      color: #303133;
    }

    .greeting {
      margin: 0 0 8px;
      font-size: 18px;
      color: #606266;
    }

    .date {
      margin: 0;
      font-size: 14px;
      color: #909399;
    }

    .tip {
      margin: 0;
      font-size: 14px;
      color: #909399;
    }
  }
}
</style>
