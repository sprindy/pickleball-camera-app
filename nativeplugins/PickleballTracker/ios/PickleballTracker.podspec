Pod::Spec.new do |s|
  s.name = 'PickleballTracker'
  s.version = '1.0.0'
  s.summary = 'Pickleball camera tracking module for uni-app iOS builds'
  s.description = 'Rear-camera preview, photo capture, video recording, pickleball tracking, trajectory overlay, and export compositing.'
  s.license = { :type => 'MIT' }
  s.author = { 'Pickleball Camera' => 'dev@example.com' }
  s.platform = :ios, '14.0'
  s.source = { :path => '.' }
  s.source_files = 'Sources/**/*.{h,m}'
  s.frameworks = ['AVFoundation', 'Vision', 'UIKit', 'CoreGraphics', 'CoreMedia', 'CoreVideo', 'QuartzCore']
  s.requires_arc = true
end
