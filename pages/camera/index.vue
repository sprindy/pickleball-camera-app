<template>
  <view class="camera-page">
    <view class="preview" id="cameraPreview"></view>

    <view class="status-bar">
      <text class="status-text">{{ statusText }}</text>
    </view>

    <view class="controls">
      <button class="capture-btn" :disabled="!isReady || !isIOS || busy" @click="onTakePhoto">PHOTO</button>
      <button :class="['record-btn', isRecording ? 'active' : '']" :disabled="!isReady || !isIOS || busy" @click="onToggleRecord">
        {{ isRecording ? 'STOP' : 'REC' }}
      </button>
    </view>
  </view>
</template>

<script>
import bridge from '@/utils/nativeBridge'

export default {
  data() {
    return {
      statusText: 'Initializing...',
      isReady: false,
      isIOS: false,
      busy: false,
      isRecording: false,
      currentSessionId: '',
      lastRawVideoPath: '',
      unsubscribeTracking: null,
      unsubscribeRecordingFinished: null
    }
  },
  onReady() {
    this.bootstrap()
  },
  onUnload() {
    bridge.stopPreview().catch(() => {})
    if (this.unsubscribeTracking) {
      this.unsubscribeTracking()
    }
    if (this.unsubscribeRecordingFinished) {
      this.unsubscribeRecordingFinished()
    }
  },
  methods: {
    async bootstrap() {
      try {
        this.isIOS = this.detectIOS()
        if (!this.isIOS) {
          this.statusText = 'This build supports iOS only.'
          return
        }

        await this.ensurePermissions()
        await bridge.initCamera({ position: 'rear', zoom: false })
        await bridge.startPreview({
          viewId: 'cameraPreview',
          rearOnly: true,
          autoRotate: true,
          enableZoom: false
        })

        this.unsubscribeTracking = bridge.onTrackingUpdate((payload) => {
          if (!this.isRecording) {
            return
          }
          if (payload && payload.detected) {
            this.statusText = `Recording • tracking (${Number(payload.confidence || 0).toFixed(2)})`
          } else {
            this.statusText = 'Recording • no ball'
          }
        })

        this.unsubscribeRecordingFinished = bridge.onRecordingFinished((payload) => {
          if (!payload) {
            return
          }
          this.currentSessionId = payload.sessionId || this.currentSessionId
          this.lastRawVideoPath = payload.videoFilePath || this.lastRawVideoPath
        })

        this.isReady = true
        this.statusText = 'Camera ready'
      } catch (error) {
        this.statusText = `Init failed: ${error.message || error}`
      }
    },

    detectIOS() {
      try {
        if (typeof plus !== 'undefined' && plus.os && plus.os.name) {
          return plus.os.name.toLowerCase() === 'ios'
        }
      } catch (error) {
        return false
      }
      return false
    },

    async ensurePermissions() {
      const permissions = ['scope.camera', 'scope.record']
      for (const scope of permissions) {
        // #ifdef APP-PLUS
        // uni.authorize can reject if already denied; we keep the error to surface exact permission issue.
        // #endif
        await new Promise((resolve, reject) => {
          uni.authorize({
            scope,
            success: resolve,
            fail: reject
          })
        })
      }
    },

    async onTakePhoto() {
      if (!this.isReady || !this.isIOS || this.busy) {
        return
      }

      try {
        this.busy = true
        this.statusText = 'Capturing photo...'
        const result = await bridge.takePhoto()
        const photoPath = result.photoFilePath || ''
        this.statusText = 'Photo saved'

        uni.navigateTo({
          url: `/pages/review/index?type=photo&path=${encodeURIComponent(photoPath)}`
        })
      } catch (error) {
        this.statusText = `Photo failed: ${error.message || error}`
      } finally {
        this.busy = false
      }
    },

    async onToggleRecord() {
      if (!this.isReady || !this.isIOS || this.busy) {
        return
      }

      if (!this.isRecording) {
        await this.startRecord()
      } else {
        await this.stopRecord()
      }
    },

    async startRecord() {
      try {
        this.busy = true
        this.statusText = 'Starting recording...'
        const result = await bridge.startRecording({ trackBall: true })
        this.currentSessionId = result.sessionId || ''
        this.lastRawVideoPath = result.videoFilePath || ''
        this.isRecording = true
        this.statusText = 'Recording • waiting for ball'
      } catch (error) {
        this.statusText = `Record failed: ${error.message || error}`
      } finally {
        this.busy = false
      }
    },

    async stopRecord() {
      let stopResult = null
      let outputPath = ''

      try {
        this.busy = true
        this.statusText = 'Stopping recording...'
        stopResult = await bridge.stopRecording({ sessionId: this.currentSessionId })
        this.currentSessionId = stopResult.sessionId || this.currentSessionId
        this.lastRawVideoPath = stopResult.videoFilePath || this.lastRawVideoPath

        this.statusText = 'Exporting trail overlay...'
        const exportResult = await bridge.exportVideoWithOverlay(this.currentSessionId)
        outputPath = exportResult.outputVideoFilePath || this.lastRawVideoPath
        this.statusText = exportResult.hasTrail ? 'Recording finished with trail' : 'Recording finished (no ball detected)'
      } catch (error) {
        outputPath = (stopResult && stopResult.videoFilePath) || this.lastRawVideoPath
        this.statusText = outputPath
          ? `Export skipped, using raw video: ${error.message || error}`
          : `Stop failed: ${error.message || error}`
      } finally {
        this.isRecording = false
        this.busy = false
      }

      if (outputPath) {
        uni.navigateTo({
          url: `/pages/review/index?type=video&path=${encodeURIComponent(outputPath)}`
        })
      }
    }
  }
}
</script>

<style>
.camera-page {
  position: relative;
  width: 100%;
  height: 100vh;
  background: #000;
}

.preview {
  position: absolute;
  inset: 0;
  background: #111;
}

.status-bar {
  position: absolute;
  top: 48rpx;
  left: 24rpx;
  right: 24rpx;
  z-index: 9;
}

.status-text {
  color: #fff;
  font-size: 28rpx;
}

.controls {
  position: absolute;
  bottom: 56rpx;
  left: 0;
  right: 0;
  z-index: 9;
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 24rpx;
}

.capture-btn,
.record-btn {
  width: 180rpx;
  height: 88rpx;
  border-radius: 44rpx;
  border: none;
  font-size: 28rpx;
  color: #fff;
}

.capture-btn {
  background: #2f2f2f;
}

.record-btn {
  background: #7a1212;
}

.record-btn.active {
  background: #d12d2d;
}

.capture-btn[disabled],
.record-btn[disabled] {
  opacity: 0.45;
}
</style>
