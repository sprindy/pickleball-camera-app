const fs = require('fs')

const required = [
  'pickleball_ios_camera_app_spec.md',
  'pages/camera/index.vue',
  'pages/review/index.vue',
  'common/cameraBridge.js',
  'ios-native/PickleballTrailCamera/Bridge/PickleballCameraBridge.swift',
  'ios-native/PickleballTrailCamera/Tracking/BallTracker.swift',
  'ios-native/PickleballTrailCamera/Export/VideoOverlayExporter.swift'
]

const missing = required.filter((p) => !fs.existsSync(p))
if (missing.length) {
  console.error('Missing files:\n' + missing.join('\n'))
  process.exit(1)
}
console.log('Structure check passed. Required source files exist.')
