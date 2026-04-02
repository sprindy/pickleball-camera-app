<template>
  <view class="camera-page">
    <view class="preview" id="cameraPreview"></view>

    <view class="status-bar">
      <text class="status-text">{{ statusText }}</text>
    </view>

    <view class="bottom-controls">
      <view class="mode-selector">
        <text :class="['mode-item', mode === 'PHOTO' ? 'active' : '']" @click="setMode('PHOTO')">PHOTO</text>
        <text :class="['mode-item', mode === 'VIDEO' ? 'active' : '']" @click="setMode('VIDEO')">VIDEO</text>
      </view>

      <button
        class="capture-button"
        :class="[
          mode === 'VIDEO' ? 'video-mode' : 'photo-mode',
          isRecording ? 'recording' : ''
        ]"
        :disabled="!isReady || !isIOS || busy"
        @click="onCapture"
      >
        <view class="capture-inner"></view>
      </button>
    </view>
  </view>
</template>

<script>
import bridge from '@/utils/nativeBridge'

export default {
  data() {
    return {
      mode: 'PHOTO',
      statusText: 'Initializing...',
      isReady: false,
      isIOS: false,
      busy: false,
      isRecording: false,
      trackingDetected: false,
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

          const detected = Boolean(payload && payload.detected)
          this.trackingDetected = detected
          this.statusText = detected ? 'Recording - Tracking ball...' : 'Recording - Searching...'
        })

        this.unsubscribeRecordingFinished = bridge.onRecordingFinished((payload) => {
          if (!payload) {
            return
          }
          this.currentSessionId = payload.sessionId || this.currentSessionId
          this.lastRawVideoPath = payload.videoFilePath || this.lastRawVideoPath
        })

        this.isReady = true
        this.statusText = 'Ready'
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
      const permissions = ['scope.camera', 'scope.record', 'scope.writePhotosAlbum']
      for (const scope of permissions) {
        await new Promise((resolve, reject) => {
          uni.authorize({
            scope,
            success: resolve,
            fail: reject
          })
        })
      }
    },

    setMode(nextMode) {
      if (this.isRecording) {
        return
      }
      this.mode = nextMode
      this.statusText = nextMode === 'PHOTO' ? 'Ready' : 'Ready to record'
    },

    async onCapture() {
      if (!this.isReady || !this.isIOS || this.busy) {
        return
      }

      if (this.mode === 'PHOTO') {
        await this.capturePhoto()
        return
      }

      if (this.isRecording) {
        await this.stopRecord()
      } else {
        await this.startRecord()
      }
    },

    async capturePhoto() {
      try {
        this.busy = true
        this.statusText = 'Capturing photo...'
        const result = await bridge.takePhoto()
        const photoPath = result.photoFilePath || ''
        const saveWarning = result.saveWarning || ''

        this.statusText = saveWarning ? `Saved locally: ${saveWarning}` : 'Photo saved'
        if (photoPath) {
          uni.navigateTo({
            url: `/pages/review/index?type=photo&path=${encodeURIComponent(photoPath)}`
          })
        }
      } catch (error) {
        this.statusText = `Photo failed: ${error.message || error}`
      } finally {
        this.busy = false
      }
    },

    async startRecord() {
      try {
        this.busy = true
        this.trackingDetected = false
        this.statusText = 'Starting recording...'
        const result = await bridge.startRecording({ trackBall: true })
        this.currentSessionId = result.sessionId || ''
        this.lastRawVideoPath = result.videoFilePath || ''
        this.isRecording = true
        this.statusText = 'Recording - Searching...'
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

        this.statusText = 'Processing video...'
        const exportResult = await bridge.exportVideoWithOverlay(this.currentSessionId)
        outputPath = exportResult.outputVideoFilePath || this.lastRawVideoPath

        if (exportResult.hasTrail) {
          this.statusText = exportResult.warning || 'Saved with trajectory'
        } else {
          this.statusText = exportResult.warning || 'Saved video (no ball detected)'
        }
      } catch (error) {
        outputPath = (stopResult && stopResult.videoFilePath) || this.lastRawVideoPath
        this.statusText = outputPath
          ? `Saved raw video: ${error.message || error}`
          : `Stop failed: ${error.message || error}`
      } finally {
        this.isRecording = false
        this.trackingDetected = false
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
  overflow: hidden;
}

.preview {
  position: absolute;
  inset: 0;
  background: #000;
}

.status-bar {
  position: absolute;
  top: 56rpx;
  left: 24rpx;
  right: 24rpx;
  z-index: 20;
}

.status-text {
  color: #fff;
  font-size: 26rpx;
  background: rgba(0, 0, 0, 0.38);
  padding: 10rpx 14rpx;
  border-radius: 12rpx;
}

.bottom-controls {
  position: absolute;
  left: 0;
  right: 0;
  bottom: 34rpx;
  z-index: 20;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 24rpx;
}

.mode-selector {
  min-width: 300rpx;
  padding: 10rpx;
  border-radius: 999rpx;
  background: rgba(0, 0, 0, 0.4);
  display: flex;
  justify-content: center;
  gap: 12rpx;
}

.mode-item {
  color: rgba(255, 255, 255, 0.7);
  font-size: 24rpx;
  letter-spacing: 1rpx;
  padding: 8rpx 18rpx;
  border-radius: 999rpx;
}

.mode-item.active {
  color: #ffd400;
  background: rgba(255, 212, 0, 0.14);
}

.capture-button {
  width: 152rpx;
  height: 152rpx;
  border-radius: 50%;
  border: 10rpx solid #fff;
  background: rgba(255, 255, 255, 0.14);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0;
}

.capture-button::after {
  border: 0;
}

.capture-inner {
  width: 108rpx;
  height: 108rpx;
  border-radius: 50%;
  background: #fff;
  transition: all 0.15s ease;
}

.capture-button.video-mode .capture-inner {
  background: #ff3b30;
}

.capture-button.video-mode.recording .capture-inner {
  width: 58rpx;
  height: 58rpx;
  border-radius: 14rpx;
}

.capture-button[disabled] {
  opacity: 0.55;
}
</style>
