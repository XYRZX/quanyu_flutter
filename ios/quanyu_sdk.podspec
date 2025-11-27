#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint quanyu_sdk.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'quanyu_sdk'
  s.version          = '0.0.16'
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

  quan_yu_path = File.join(__dir__, 'Frameworks', 'QuanYu.xcframework')
  portsip_path = File.join(__dir__, 'Frameworks', 'PortSIPVoIPSDK.framework')

  unless File.directory?(quan_yu_path)
    puts "ERROR: QuanYu.xcframework not found!"
    puts "Please place QuanYu.xcframework at: #{File.expand_path(quan_yu_path)}"
    raise "Missing required framework: QuanYu.xcframework"
  end

  unless File.directory?(portsip_path)
    puts "ERROR: PortSIPVoIPSDK.framework not found!"
    puts "Please contact customer service to obtain PortSIPVoIPSDK.framework"
    puts "and place it at: #{File.expand_path(portsip_path)}"
    raise "Missing required framework: PortSIPVoIPSDK.framework"
  end

  s.vendored_frameworks = [
    'Frameworks/QuanYu.xcframework',
    'Frameworks/PortSIPVoIPSDK.framework'
  ]

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
