const plugin = typeof uni !== 'undefined' && uni.requireNativePlugin
  ? uni.requireNativePlugin('PickleballTracker')
  : null

const listeners = {
  tracking: new Set(),
  recordingFinished: new Set()
}

let nativeEventsBound = false
let pluginCallbacksBound = false
let plusReadyPromise = null

function normalizePayload(payload) {
  if (!payload) {
    return {}
  }
  if (payload.detail && typeof payload.detail === 'object') {
    return payload.detail
  }
  if (payload.data && typeof payload.data === 'object') {
    return payload.data
  }
  return payload
}

function waitForPlusReady() {
  if (typeof plus !== 'undefined') {
    return Promise.resolve()
  }
  if (plusReadyPromise) {
    return plusReadyPromise
  }

  plusReadyPromise = new Promise((resolve) => {
    if (typeof document !== 'undefined') {
      document.addEventListener('plusready', () => resolve(), { once: true })
      return
    }
    resolve()
  })

  return plusReadyPromise
}

function fanOut(name, payload) {
  const normalized = normalizePayload(payload)
  listeners[name].forEach((cb) => cb(normalized || {}))
}

function bindNativeEvents() {
  if (nativeEventsBound) {
    return
  }

  const hasPlusGlobalEvent = typeof plus !== 'undefined' && plus.globalEvent

  if (hasPlusGlobalEvent) {
    plus.globalEvent.addEventListener('PickleballTrackingUpdate', (payload) => {
      fanOut('tracking', payload)
    })

    plus.globalEvent.addEventListener('PickleballRecordingFinished', (payload) => {
      fanOut('recordingFinished', payload)
    })
  }

  if (!hasPlusGlobalEvent && !pluginCallbacksBound && plugin) {
    if (typeof plugin.onTrackingUpdate === 'function') {
      plugin.onTrackingUpdate({}, (payload) => {
        const normalized = normalizePayload(payload)
        if (normalized && Object.prototype.hasOwnProperty.call(normalized, 'detected')) {
          fanOut('tracking', normalized)
        }
      })
    }

    if (typeof plugin.onRecordingFinished === 'function') {
      plugin.onRecordingFinished({}, (payload) => {
        const normalized = normalizePayload(payload)
        if (normalized && normalized.sessionId) {
          fanOut('recordingFinished', normalized)
        }
      })
    }

    pluginCallbacksBound = true
  }

  nativeEventsBound = true
}

function invokeNative(method, payload = {}) {
  return waitForPlusReady().then(() => {
    bindNativeEvents()

    return new Promise((resolve, reject) => {
      if (!plugin || typeof plugin[method] !== 'function') {
        reject(new Error(`Native method unavailable: ${method}`))
        return
      }

      try {
        plugin[method](payload, (result) => {
          const normalized = normalizePayload(result)
          if (normalized && normalized.error) {
            reject(new Error(normalized.error))
            return
          }
          resolve(normalized || {})
        })
      } catch (error) {
        reject(error)
      }
    })
  })
}

function subscribe(name, cb) {
  bindNativeEvents()
  listeners[name].add(cb)
  return () => listeners[name].delete(cb)
}

export default {
  initCamera(payload = {}) {
    return invokeNative('initCamera', payload)
  },
  startPreview(payload = {}) {
    return invokeNative('startPreview', payload)
  },
  stopPreview(payload = {}) {
    return invokeNative('stopPreview', payload)
  },
  takePhoto(payload = {}) {
    return invokeNative('takePhoto', payload)
  },
  startRecording(payload = {}) {
    return invokeNative('startRecording', payload)
  },
  stopRecording(payload = {}) {
    return invokeNative('stopRecording', payload)
  },
  exportVideoWithOverlay(sessionId) {
    return invokeNative('exportVideoWithOverlay', { sessionId })
  },
  onTrackingUpdate(callback) {
    return subscribe('tracking', callback)
  },
  onRecordingFinished(callback) {
    return subscribe('recordingFinished', callback)
  }
}
