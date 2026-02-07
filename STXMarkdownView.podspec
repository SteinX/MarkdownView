Pod::Spec.new do |s|
  s.name             = 'STXMarkdownView'
  s.version          = '1.0.0'
  s.summary          = 'High-performance Markdown rendering for iOS with rich attachments and streaming support.'

  s.description      = <<-DESC
    STXMarkdownView is a UITextView-based Markdown rendering library for iOS.
    Features include:
    - Rich attachments: tables, code blocks, images, block quotes
    - Streaming mode for real-time chat/AI assistant UI
    - Optional syntax highlighting via Highlightr
    - Adaptive table layouts
    - Memory + disk image caching
    - Fully customizable theming
  DESC

  s.homepage         = 'https://github.com/SteinX/MarkdownView'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'SteinX' => 'dev@steinx.com' }
  s.source           = { :git => 'https://github.com/SteinX/MarkdownView.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.swift_versions   = ['5.9', '5.10', '6.0']

  s.vendored_frameworks = 'Frameworks/STXMarkdownView.xcframework'

  s.frameworks       = 'UIKit', 'Foundation'

  s.pod_target_xcconfig = {
    'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'YES'
  }

  s.user_target_xcconfig = {
    'GENERATE_INFOPLIST_FILE' => 'YES'
  }
end
