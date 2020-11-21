workspace 'Spectre'
project 'Spectre-iOS'
project 'Spectre-macOS'

target 'Spectre-iOS' do
  project 'Spectre-iOS'
  platform :ios, '12.4'

  use_modular_headers!
  use_frameworks!

  pod 'SwiftLinkPreview'

  pod 'Sentry', :git => 'https://github.com/getsentry/sentry-cocoa.git'
  pod 'Countly'
  pod 'FreshchatSDK'

  pod 'Reveal-SDK', :configurations => ['Debug']

  pod 'UpdraftSDK', :configurations => ['Release']

  target 'Spectre-AutoFill-iOS' do
    inherit! :search_paths
  end
end

target 'Spectre-macOS' do
  project 'Spectre-macOS'
  platform :osx, '10.11'

  use_modular_headers!
  use_frameworks!

  pod 'Logging'
  pod 'SwiftLinkPreview'

  pod 'Sentry', :git => 'https://github.com/getsentry/sentry-cocoa.git'
  pod 'Countly'
end
