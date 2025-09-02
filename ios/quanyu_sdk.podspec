#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint quanyu_sdk.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'quanyu_sdk'
  s.version          = '0.0.3'
  s.summary          = 'A Flutter SDK for integrating with native iOS.'
  s.description      = <<-DESC
A Flutter SDK for integrating with native iOS SDKs.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :type => 'MIT' }
  s.author           = { 'QuanYu' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'

  s.platform = :ios, '12.0'

  s.dependency 'Flutter'

  vendored = []

  # QuanYu via CocoaPods by default; use local xcframework if present
  if File.directory?(File.join(__dir__, 'Frameworks', 'QuanYu.xcframework'))
    vendored << 'Frameworks/QuanYu.xcframework'
  else
    s.dependency 'QuanYu', '1.0.6'
  end

  # PortSIPVoIPSDK: REQUIRED to be placed locally in Frameworks directory
  # Users must contact customer service to obtain this framework
  portsip_framework_path = File.join(__dir__, 'Frameworks', 'PortSIPVoIPSDK.framework')
  if File.directory?(portsip_framework_path)
    vendored << 'Frameworks/PortSIPVoIPSDK.framework'
  else
    # This will cause an error during pod install, which is intentional
    # Users need to place PortSIPVoIPSDK.framework in the correct location
    puts "ERROR: PortSIPVoIPSDK.framework not found!"
    puts "Please contact customer service to obtain PortSIPVoIPSDK.framework"
    puts "and place it in: #{File.expand_path(portsip_framework_path)}"
    raise "Missing required framework: PortSIPVoIPSDK.framework"
  end

  unless vendored.empty?
    s.vendored_frameworks = vendored
  end

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '-ObjC'
  }

  # System frameworks
  s.frameworks = 'Foundation', 'UIKit', 'AVFoundation', 'CoreAudio', 'AudioToolbox', 'VideoToolbox', 'GLKit', 'MetalKit', 'Network'
  # System libraries
  s.libraries = 'c++', 'resolv'
end
