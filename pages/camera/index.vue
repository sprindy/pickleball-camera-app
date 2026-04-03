<template>
  <view class="camera-page">
    <!-- Reliable live preview fallback -->
    <camera
      id="uniCamera"
      class="preview"
      device-position="back"
      flash="off"
      mode="normal"
    />

    <!-- Native host kept for plugin-based builds -->
    <view class="native-host" id="nativeCameraHost"></view>

    <canvas canvas-id="trailCanvas" id="trailCanvas" class="trail-canvas"></canvas>

    <view class="hud">
      <view class="status">{{ statusText }}</view>
      <view v-if="recording" class="timer">{{ formattedTimer }}</view>
    </view>

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
      lastMediaType: '',
      elapsedSeconds: 0,
      timerId: null,
      trailPoints: [],
      nativeReady: false,
      cameraCtx: null
    }
  },
  computed: {
    formattedTimer() {
      const m = Math.floor(this.elapsedSeconds / 60)
      const s = this.elapsedSeconds % 60
      return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
    }
  },
  async onLoad() {
    this.cameraCtx = uni.createCameraContext()
    await this.initNativeBestEffort()
    this.$nextTick(() => this.clearTrail())
  },
  onUnload() {
    this.stopTimer()
    if (this.nativeReady) cameraBridge.stopPreview().catch(() => {})
  },
  methods: {
    async initNativeBestEffort() {
      try {
        cameraBridge.setEventHandler(this.handleNativeEvent)
        await cameraBridge.initCamera('nativeCameraHost')
        await cameraBridge.startPreview()
        this.nativeReady = true
      } catch (e) {
        this.nativeReady = false
      }
    },
    startTimer() {
      this.stopTimer()
      this.elapsedSeconds = 0
      this.timerId = setInterval(() => {
        this.elapsedSeconds += 1
      }, 1000)
    },
    stopTimer() {
      if (this.timerId) {
        clearInterval(this.timerId)
        this.timerId = null
      }
    },
    async onTakePhoto() {
      this.busy = true
      try {
        if (this.nativeReady) {
          const res = await cameraBridge.takePhoto()
          this.lastMediaType = 'photo'
          this.lastMediaPath = res.path
        } else {
          const res = await new Promise((resolve, reject) => {
            this.cameraCtx.takePhoto({
              quality: 'high',
              success: resolve,
              fail: reject
            })
          })
          this.lastMediaType = 'photo'
          this.lastMediaPath = res.tempImagePath
        }

        uni.navigateTo({
          url: `/pages/review/index?type=photo&path=${encodeURIComponent(this.lastMediaPath)}`
        })
      } catch (e) {
        this.statusText = e.message || 'Photo failed'
      } finally {
        this.busy = false
      }
    },
    async onToggleRecord() {
      this.busy = true
      try {
        if (!this.recording) {
          this.recording = true
          this.startTimer()
          this.trailPoints = []
          this.clearTrail()
          this.statusText = 'Recording...'

          if (this.nativeReady) {
            await cameraBridge.startRecording()
          } else {
            await new Promise((resolve, reject) => {
              this.cameraCtx.startRecord({ success: resolve, fail: reject })
            })
          }
        } else {
          this.recording = false
          this.stopTimer()
          this.statusText = 'Processing video...'

          if (this.nativeReady) {
            const stopRes = await cameraBridge.stopRecording()
            const output = await cameraBridge.exportVideoWithOverlay(stopRes.sessionId)
            this.lastMediaPath = output.outputPath || stopRes.rawVideoPath
          } else {
            const res = await new Promise((resolve, reject) => {
              this.cameraCtx.stopRecord({ success: resolve, fail: reject })
            })
            this.lastMediaPath = res.tempVideoPath
          }

          this.lastMediaType = 'video'
          this.statusText = 'Saved'
          uni.navigateTo({
            url: `/pages/review/index?type=video&path=${encodeURIComponent(this.lastMediaPath)}`
          })
        }
      } catch (e) {
        // Roll back state if start failed
        if (this.recording) {
          this.recording = false
          this.stopTimer()
        }
        this.statusText = e.message || 'Recording failed'
      } finally {
        this.busy = false
      }
    },
    handleNativeEvent(evt) {
      const normalized = evt?.detail || evt || {}
      if (normalized?.type !== 'trackingUpdate') return

      const payload = normalized.payload || {}
      this.statusText = payload.state === 'tracking' ? 'Tracking ball...' : 'Ball lost'

      const points = Array.isArray(payload.recentPoints) ? payload.recentPoints : []
      this.trailPoints = points
      this.drawTrail(points)
    },
    clearTrail() {
      const ctx = uni.createCanvasContext('trailCanvas', this)
      ctx.clearRect(0, 0, 2000, 2000)
      ctx.draw()
    },
    drawTrail(points) {
      const ctx = uni.createCanvasContext('trailCanvas', this)
      ctx.clearRect(0, 0, 2000, 2000)
      if (!points.length) {
        ctx.draw()
        return
      }

      ctx.beginPath()
      ctx.setStrokeStyle('#FFD400')
      ctx.setLineWidth(5)
      ctx.setLineCap('round')
      ctx.setLineJoin('round')
      ctx.moveTo(points[0].x, points[0].y)
      for (let i = 1; i < points.length; i += 1) {
        ctx.lineTo(points[i].x, points[i].y)
      }
      ctx.stroke()
      ctx.draw()
    },
    openReview() {
      if (!this.lastMediaPath) return
      uni.navigateTo({
        url: `/pages/review/index?type=${this.lastMediaType}&path=${encodeURIComponent(this.lastMediaPath)}`
      })
    }
  }
}
</script>

<style>
.camera-page { width: 100vw; height: 100vh; background: #000; position: relative; }
.preview { position: absolute; inset: 0; width: 100vw; height: 100vh; }
.native-host { position: absolute; inset: 0; opacity: 0; pointer-events: none; }
.trail-canvas { position: absolute; inset: 0; width: 100vw; height: 100vh; z-index: 8; pointer-events: none; }
.hud { position: absolute; top: 56rpx; left: 32rpx; right: 32rpx; z-index: 10; display: flex; justify-content: space-between; align-items: center; }
.status { color: #fff; font-size: 28rpx; }
.timer { color: #FFD400; font-size: 30rpx; font-weight: 700; }
.controls { position: absolute; bottom: 56rpx; width: 100%; display: flex; justify-content: center; gap: 24rpx; z-index: 10; }
.btn { border-radius: 999px; padding: 20rpx 40rpx; border: none; }
.photo { background: #fff; color: #000; }
.record { background: #2f2f2f; color: #fff; }
.record.active { background: #c62828; }
.review { background: #444; color: #fff; }
</style>
