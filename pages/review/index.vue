<template>
  <view class="review-page">
    <image v-if="type === 'photo'" :src="path" mode="aspectFit" class="media" />
    <video v-else :src="path" controls autoplay class="media"></video>
    <button class="back" @click="goBack">Back</button>
  </view>
</template>

<script>
export default {
  data() {
    return { type: 'photo', path: '' }
  },
  onLoad(query) {
    this.type = query.type || 'photo'
    this.path = decodeURIComponent(query.path || '')
  },
  methods: {
    goBack() { uni.navigateBack() }
  }
}
</script>

<style>
.review-page { width: 100vw; height: 100vh; background: #000; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 24rpx; }
.media { width: 100vw; height: 85vh; }
.back { background: #fff; color: #000; border-radius: 999px; padding: 16rpx 40rpx; }
</style>
