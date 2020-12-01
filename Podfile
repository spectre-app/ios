workspace 'Spectre'
project 'Spectre-iOS'
project 'Spectre-macOS'

target 'Spectre-iOS' do
  project 'Spectre-iOS'
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

target 'Spectre-AutoFill-iOS' do
  project 'Spectre-iOS'
  platform :ios, '12.4'

  use_modular_headers!
  use_frameworks!

  pod 'Macaw'

  pod 'SwiftLinkPreview'
  pod 'Sentry', :git => 'https://github.com/getsentry/sentry-cocoa.git'

  pod 'Reveal-SDK', :configurations => ['Debug']
end

target 'Spectre-macOS' do
  project 'Spectre-macOS'
  platform :osx, '10.11'

  use_modular_headers!
  use_frameworks!
end
