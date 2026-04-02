<template>
  <view class="camera-page">
    <view class="preview" id="cameraPreview"></view>

    <view class="top-overlay">
      <text class="status-chip">{{ statusText }}</text>
    </view>

    <view v-if="permissionBlocked" class="permission-panel">
      <text class="permission-title">Permission required</text>
      <text class="permission-copy">Allow camera, microphone, and Photos access to continue.</text>
      <button class="permission-button" @click="openSystemSettings">Open Settings</button>
    </view>

    <view class="bottom-overlay">
      <view class="mode-strip">
        <text :class="['mode-item', mode === 'PHOTO' ? 'active' : '']" @click="setMode('PHOTO')">PHOTO</text>
        <text :class="['mode-item', mode === 'VIDEO' ? 'active' : '']" @click="setMode('VIDEO')">VIDEO</text>
      </view>

      <view class="capture-row">
        <button class="review-button" :disabled="!lastOutputPath" @click="openLastReview">Last</button>

        <button
          class="capture-button"
          :class="[
            mode === 'VIDEO' ? 'video-mode' : 'photo-mode',
            isRecording ? 'recording' : ''
          ]"
          :disabled="!isReady || !isIOS || busy || permissionBlocked"
          @click="onCapture"
        >
          <view class="capture-inner"></view>
        </button>

        <view class="spacer"></view>
      </view>
    </view>
  </view>
</template>

<script>
import bridge from '@/utils/nativeBridge'

const RECORDING_STATE = {
  IDLE: 'idle',
  RECORDING: 'recording',
  PROCESSING: 'processing_export',
  REVIEW_READY: 'review_ready',
  ERROR: 'error'
}

const TRACKING_STATE = {
  NOT_STARTED: 'not_started',
  SEARCHING: 'searching',
  TRACKING: 'tracking',
  TEMP_LOST: 'temporarily_lost',
  LOST: 'lost'
}

export default {
  data() {
    return {
      mode: 'PHOTO',
      statusText: 'Ready',
      isReady: false,
      isIOS: false,
      busy: false,
      isRecording: false,
      permissionBlocked: false,
      recordingState: RECORDING_STATE.IDLE,
      trackingState: TRACKING_STATE.NOT_STARTED,
      currentSessionId: '',
      lastRawVideoPath: '',
      lastOutputPath: '',
      lastOutputType: 'photo',
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
          this.statusText = 'Permission required'
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

          const state = payload.state || TRACKING_STATE.SEARCHING
          this.trackingState = state
          if (state === TRACKING_STATE.TRACKING) {
            this.statusText = 'Tracking ball...'
          } else if (state === TRACKING_STATE.TEMP_LOST || state === TRACKING_STATE.LOST) {
            this.statusText = 'Ball lost'
          } else {
            this.statusText = 'Recording...'
          }
        })

        this.unsubscribeRecordingFinished = bridge.onRecordingFinished((payload) => {
          if (!payload) {
            return
          }
          this.currentSessionId = payload.sessionId || this.currentSessionId
          this.lastRawVideoPath = payload.videoFilePath || this.lastRawVideoPath
        })

        this.permissionBlocked = false
        this.isReady = true
        this.statusText = 'Ready'
      } catch (error) {
        this.permissionBlocked = true
        this.statusText = 'Permission required'
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

    getAuthSetting() {
      return new Promise((resolve) => {
        uni.getSetting({
          success: resolve,
          fail: () => resolve({ authSetting: {} })
        })
      })
    },

    authorize(scope) {
      return new Promise((resolve, reject) => {
        uni.authorize({
          scope,
          success: resolve,
          fail: reject
        })
      })
    },

    async ensurePermissions() {
      const settings = await this.getAuthSetting()
      const auth = settings.authSetting || {}
      const scopes = ['scope.camera', 'scope.record', 'scope.writePhotosAlbum']

      for (const scope of scopes) {
        if (auth[scope] === true) {
          continue
        }
        await this.authorize(scope)
      }
    },

    openSystemSettings() {
      try {
        if (typeof plus !== 'undefined' && plus.runtime && plus.runtime.openURL) {
          plus.runtime.openURL('app-settings:')
        }
      } catch (error) {
        uni.showModal({
          title: 'Permission required',
          content: 'Allow camera, microphone, and Photos access from iOS Settings.',
          showCancel: false
        })
      }
    },

    setMode(nextMode) {
      if (this.isRecording || this.busy) {
        return
      }
      this.mode = nextMode
      this.statusText = 'Ready'
    },

    async onCapture() {
      if (!this.isReady || !this.isIOS || this.busy || this.permissionBlocked) {
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
        this.statusText = 'Ready'
        const result = await bridge.takePhoto()
        const photoPath = result.photoFilePath || ''
        const saveWarning = result.saveWarning || ''

        this.lastOutputPath = photoPath
        this.lastOutputType = 'photo'
        this.statusText = saveWarning ? saveWarning : 'Saved'

        if (photoPath) {
          uni.navigateTo({
            url: `/pages/review/index?type=photo&path=${encodeURIComponent(photoPath)}`
          })
        }
      } catch (error) {
        this.recordingState = RECORDING_STATE.ERROR
        this.statusText = error.message || 'Error'
      } finally {
        this.busy = false
      }
    },

    async startRecord() {
      try {
        this.busy = true
        this.statusText = 'Recording...'
        const result = await bridge.startRecording({ trackBall: true })
        this.currentSessionId = result.sessionId || ''
        this.lastRawVideoPath = result.videoFilePath || ''
        this.recordingState = result.recordingState || RECORDING_STATE.RECORDING
        this.trackingState = result.trackingState || TRACKING_STATE.SEARCHING
        this.isRecording = true
        this.statusText = 'Recording...'
      } catch (error) {
        this.recordingState = RECORDING_STATE.ERROR
        this.statusText = error.message || 'Error'
      } finally {
        this.busy = false
      }
    },

    async stopRecord() {
      let stopResult = null
      let outputPath = ''

      try {
        this.busy = true
        this.statusText = 'Recording...'
        stopResult = await bridge.stopRecording({ sessionId: this.currentSessionId })
        this.currentSessionId = stopResult.sessionId || this.currentSessionId
        this.lastRawVideoPath = stopResult.videoFilePath || this.lastRawVideoPath

        this.recordingState = RECORDING_STATE.PROCESSING
        this.statusText = 'Processing video...'
        const exportResult = await bridge.exportVideoWithOverlay(this.currentSessionId)
        outputPath = exportResult.outputVideoFilePath || this.lastRawVideoPath
        this.recordingState = exportResult.recordingState || RECORDING_STATE.REVIEW_READY

        this.statusText = exportResult.warning || 'Saved'
      } catch (error) {
        outputPath = (stopResult && stopResult.videoFilePath) || this.lastRawVideoPath
        this.recordingState = RECORDING_STATE.ERROR
        this.statusText = outputPath ? 'Saved' : error.message || 'Error'
      } finally {
        this.isRecording = false
        this.trackingState = TRACKING_STATE.NOT_STARTED
        this.busy = false
      }

      if (outputPath) {
        this.lastOutputPath = outputPath
        this.lastOutputType = 'video'
        uni.navigateTo({
          url: `/pages/review/index?type=video&path=${encodeURIComponent(outputPath)}`
        })
      }
    },

    openLastReview() {
      if (!this.lastOutputPath) {
        return
      }
      uni.navigateTo({
        url: `/pages/review/index?type=${this.lastOutputType}&path=${encodeURIComponent(this.lastOutputPath)}`
      })
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

.top-overlay {
  position: absolute;
  top: env(safe-area-inset-top);
  left: 0;
  right: 0;
  z-index: 20;
  display: flex;
  justify-content: center;
  padding-top: 20rpx;
}

.status-chip {
  color: #fff;
  font-size: 24rpx;
  line-height: 1;
  padding: 14rpx 18rpx;
  border-radius: 24rpx;
  background: rgba(0, 0, 0, 0.44);
}

.permission-panel {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  width: 78%;
  z-index: 40;
  border-radius: 24rpx;
  background: rgba(0, 0, 0, 0.76);
  padding: 34rpx 28rpx;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 18rpx;
}

.permission-title {
  color: #fff;
  font-size: 34rpx;
  font-weight: 600;
}

.permission-copy {
  color: rgba(255, 255, 255, 0.82);
  text-align: center;
  font-size: 25rpx;
  line-height: 1.35;
}

.permission-button {
  margin-top: 8rpx;
  width: 100%;
  border-radius: 16rpx;
  color: #000;
  background: #ffd400;
  font-size: 28rpx;
  font-weight: 600;
}

.permission-button::after {
  border: 0;
}

.bottom-overlay {
  position: absolute;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 20;
  padding: 18rpx 36rpx calc(24rpx + env(safe-area-inset-bottom));
  background: linear-gradient(to top, rgba(0, 0, 0, 0.62), rgba(0, 0, 0, 0));
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 24rpx;
}

.mode-strip {
  min-width: 280rpx;
  border-radius: 999rpx;
  background: rgba(0, 0, 0, 0.48);
  padding: 10rpx 12rpx;
  display: flex;
  justify-content: center;
  gap: 12rpx;
}

.mode-item {
  color: rgba(255, 255, 255, 0.72);
  font-size: 25rpx;
  letter-spacing: 1rpx;
  padding: 10rpx 20rpx;
  border-radius: 999rpx;
}

.mode-item.active {
  color: #ffd400;
  background: rgba(255, 212, 0, 0.18);
}

.capture-row {
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.review-button {
  width: 72rpx;
  height: 72rpx;
  border-radius: 16rpx;
  border: 2rpx solid rgba(255, 255, 255, 0.7);
  background: rgba(0, 0, 0, 0.34);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 28rpx;
}

.review-button::after {
  border: 0;
}

.review-button[disabled] {
  opacity: 0.35;
}

.capture-button {
  width: 152rpx;
  height: 152rpx;
  border-radius: 50%;
  border: 10rpx solid #fff;
  background: rgba(255, 255, 255, 0.12);
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
  transition: all 0.16s ease;
}

.capture-button.video-mode .capture-inner {
  background: #ff3b30;
}

.capture-button.video-mode.recording .capture-inner {
  width: 56rpx;
  height: 56rpx;
  border-radius: 12rpx;
}

.capture-button[disabled] {
  opacity: 0.55;
}

.spacer {
  width: 72rpx;
  height: 72rpx;
}
</style>
