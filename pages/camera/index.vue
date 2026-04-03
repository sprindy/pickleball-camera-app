<template>
  <view class="camera-page">
    <view class="preview" id="nativeCameraHost"></view>
    <view class="status">{{ statusText }}</view>

    <view class="controls">
      <button class="btn photo" @click="onTakePhoto" :disabled="busy">Photo</button>
      <button class="btn record" :class="{ active: recording }" @click="onToggleRecord" :disabled="busy">
        {{ recording ? 'Stop' : 'Record' }}
      </button>
      <button class="btn review" @click="openReview" :disabled="!lastMediaPath">Review</button>
    </view>
  </view>
</template>

<script>
import { cameraBridge } from '@/common/cameraBridge'

export default {
  data() {
    return {
      recording: false,
      busy: false,
      statusText: 'Ready',
      lastMediaPath: '',
      lastMediaType: ''
    }
  },
  async onLoad() {
    await this.init()
  },
  onUnload() {
    cameraBridge.stopPreview().catch(() => {})
  },
  methods: {
    async init() {
      try {
        this.statusText = 'Ready'
        cameraBridge.setEventHandler(this.handleNativeEvent)
        await cameraBridge.initCamera('nativeCameraHost')
        await cameraBridge.startPreview()
      } catch (e) {
        this.statusText = 'Permission required'
      }
    },
    async onTakePhoto() {
      this.busy = true
      try {
        const res = await cameraBridge.takePhoto()
        this.lastMediaType = 'photo'
        this.lastMediaPath = res.path
        uni.navigateTo({ url: `/pages/review/index?type=photo&path=${encodeURIComponent(res.path)}` })
      } finally {
        this.busy = false
      }
    },
    async onToggleRecord() {
      this.busy = true
      try {
        if (!this.recording) {
          await cameraBridge.startRecording()
          this.recording = true
          this.statusText = 'Recording...'
        } else {
          this.recording = false
          this.statusText = 'Processing video...'
          const stopRes = await cameraBridge.stopRecording()
          const output = await cameraBridge.exportVideoWithOverlay(stopRes.sessionId)
          this.lastMediaType = 'video'
          this.lastMediaPath = output.outputPath || stopRes.rawVideoPath
          this.statusText = 'Saved'
          uni.navigateTo({ url: `/pages/review/index?type=video&path=${encodeURIComponent(this.lastMediaPath)}` })
        }
      } catch (e) {
        this.statusText = e.message || 'error'
      } finally {
        this.busy = false
      }
    },
    handleNativeEvent(evt) {
      if (evt?.type === 'trackingUpdate') {
        this.statusText = evt.payload?.state === 'tracking' ? 'Tracking ball...' : 'Ball lost'
      }
    },
    openReview() {
      if (!this.lastMediaPath) return
      uni.navigateTo({ url: `/pages/review/index?type=${this.lastMediaType}&path=${encodeURIComponent(this.lastMediaPath)}` })
    }
  }
}
</script>

<style>
.camera-page { width: 100vw; height: 100vh; background: #000; position: relative; }
.preview { position: absolute; inset: 0; }
.status { position: absolute; top: 56rpx; left: 32rpx; color: #fff; font-size: 28rpx; z-index: 10; }
.controls { position: absolute; bottom: 56rpx; width: 100%; display: flex; justify-content: center; gap: 24rpx; z-index: 10; }
.btn { border-radius: 999px; padding: 20rpx 40rpx; border: none; }
.photo { background: #fff; color: #000; }
.record { background: #2f2f2f; color: #fff; }
.record.active { background: #c62828; }
.review { background: #444; color: #fff; }
</style>
