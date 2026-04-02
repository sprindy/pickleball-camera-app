<template>
  <view class="review-page">
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

.photo,
.video {
  width: 100%;
  height: 100%;
}
</style>
