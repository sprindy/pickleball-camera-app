const PLUGIN_NAME = 'PickleballCameraBridge'

function callNative(method, payload = {}) {
  return new Promise((resolve, reject) => {
    // #ifdef APP-PLUS
    const plugin = uni.requireNativePlugin(PLUGIN_NAME)
    if (!plugin || typeof plugin[method] !== 'function') {
      reject(new Error(`Native method not found: ${method}`))
      return
    }
    plugin[method](payload, (res) => {
      if (res && res.error) reject(new Error(res.error))
      else resolve(res || {})
    })
    // #endif

    // #ifndef APP-PLUS
    reject(new Error('Native camera plugin available on iOS app build only.'))
    // #endif
  })
}

export const cameraBridge = {
  initCamera: (viewId) => callNative('initCamera', { viewId }),
  startPreview: () => callNative('startPreview'),
  stopPreview: () => callNative('stopPreview'),
  takePhoto: () => callNative('takePhoto'),
  startRecording: () => callNative('startRecording'),
  stopRecording: () => callNative('stopRecording'),
  exportVideoWithOverlay: (sessionId) => callNative('exportVideoWithOverlay', { sessionId }),
  getRecordingStatus: () => callNative('getRecordingStatus'),
  setEventHandler(handler) {
    // #ifdef APP-PLUS
    const globalEvent = uni.requireNativePlugin('globalEvent')
    globalEvent.addEventListener('PickleballCameraEvent', handler)
    // #endif
  }
}
