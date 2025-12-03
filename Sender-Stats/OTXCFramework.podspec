Pod::Spec.new do |s|
  build          = "2401"
  s.name         = "OTXCFramework"
  s.version      = "2.32.0-preview.#{build}"
  s.summary      = "OpenTok lets you weave interactive live WebRTC video streaming right into your application"
  s.description  = <<-DESC
                   The OpenTok iOS SDK lets you use WebRTC video sessions in apps you build for iPad,
                   iPhone, and iPod touch devices.
                   DESC
  s.homepage     = "https://tokbox.com/developer/sdks/ios/"
  s.license      = { :type => "Commercial", :text => "https://tokbox.com/support/tos" }
  s.author       = { "TokBox, Inc." => "support@tokbox.com" }

  s.platform     = :ios
  s.ios.deployment_target = '15.0'
  s.source       = { :http => "https://s3.us-east-1.amazonaws.com/artifact.tokbox.com/pr/otkit-ios-sdk-xcframework/2401/OpenTok-iOS-2.32.0-preview.2401.zip"}
  s.resource_bundles = {
    'OTPrivacyResources' => ['OpenTok.xcframework/ios-arm64/**/OpenTok.framework/PrivacyInfo.xcprivacy']
  }
  s.vendored_frameworks = "OpenTok.xcframework"
  s.frameworks   = "Foundation", "AVFoundation", "AudioToolbox", "CoreFoundation", "CoreGraphics",
                   "CoreMedia", "CoreTelephony", "CoreVideo", "GLKit", "OpenGLES", "QuartzCore",
                   "SystemConfiguration", "UIKit", "VideoToolbox", "Network", "Accelerate", "MetalKit"
  s.libraries    = "c++"
  s.requires_arc = false
end