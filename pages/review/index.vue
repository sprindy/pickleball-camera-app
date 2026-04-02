<template>
  <view class="review-page">
    <button class="back-button" @click="goBack">Back</button>
    <image v-if="type === 'photo'" class="photo" :src="path" mode="aspectFit" />
    <video v-else class="video" :src="path" controls autoplay object-fit="contain"></video>
  </view>
</template>

<script>
export default {
  data() {
    return {
      type: 'photo',
      path: ''
    }
  },
  onLoad(query) {
    this.type = query.type || 'photo'
    this.path = decodeURIComponent(query.path || '')
  },
  methods: {
    goBack() {
      uni.navigateBack({ delta: 1 })
    }
  }
}
</script>

<style>
.review-page {
  width: 100%;
  height: 100vh;
  background: #000;
  display: flex;
  align-items: center;
  justify-content: center;
}

.back-button {
  position: absolute;
  top: calc(16rpx + env(safe-area-inset-top));
  left: 20rpx;
  z-index: 20;
  border-radius: 14rpx;
  background: rgba(0, 0, 0, 0.55);
  color: #fff;
  border: 2rpx solid rgba(255, 255, 255, 0.7);
  font-size: 24rpx;
  padding: 0 18rpx;
}

.back-button::after {
  border: 0;
}

.photo,
.video {
  width: 100%;
  height: 100%;
}
</style>
