workspace 'Spectre'
project 'Spectre'

target 'Spectre' do
  project 'Spectre'
  platform :ios, '12.4'

  use_modular_headers!
  use_frameworks!

  pod 'Macaw'

  pod 'Sentry', :git => 'https://github.com/getsentry/sentry-cocoa.git'
  pod 'Countly', :git => 'https://github.com/Countly/countly-sdk-ios.git'
  pod 'FreshchatSDK'
  pod 'SwiftLinkPreview'

  pod 'Reveal-SDK', :configurations => ['Debug']

  pod 'UpdraftSDK', :configurations => ['Release']
end

target 'Spectre-AutoFill' do
  project 'Spectre'
  platform :ios, '12.4'

  use_modular_headers!
  use_frameworks!

  pod 'Macaw'

  pod 'SwiftLinkPreview'
  pod 'Sentry', :git => 'https://github.com/getsentry/sentry-cocoa.git'

  pod 'Reveal-SDK', :configurations => ['Debug']
end
