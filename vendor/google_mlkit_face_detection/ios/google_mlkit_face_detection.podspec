require 'yaml'

pubspec = YAML.load_file(File.join('..', 'pubspec.yaml'))
library_version = pubspec['version'].gsub('+', '-')

Pod::Spec.new do |s|
  s.name             = pubspec['name']
  s.version          = library_version
  s.summary          = pubspec['description']
  s.description      = pubspec['description']
  s.homepage         = pubspec['homepage']
  s.license          = { :file => '../LICENSE' }
  s.authors          = 'Multiple Authors'
  s.source           = { :path => '.' }
  screenshot_simulator = ENV['SCREENSHOT_SIMULATOR'] == '1'

  s.source_files = screenshot_simulator ? 'ClassesStub/**/*' : 'Classes/**/*'
  s.public_header_files = screenshot_simulator ? 'ClassesStub/**/*.h' : 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.dependency 'GoogleMLKit/FaceDetection', '~> 7.0.0' unless screenshot_simulator
  s.dependency 'google_mlkit_commons'
  s.platform = :ios, '15.5.0'
  s.ios.deployment_target = '15.5.0'
  s.static_framework = true
  s.swift_version = '5.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
