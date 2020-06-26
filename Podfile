workspace 'Spectre'
project 'Spectre-iOS'
project 'Spectre-macOS'

target 'Spectre-iOS' do
  project 'Spectre-iOS'
  platform :ios, '12.4'

  use_modular_headers!
  use_frameworks!

  pod 'Logging'
  pod 'SwiftLinkPreview'

  pod 'Sentry', :git => 'https://github.com/getsentry/sentry-cocoa.git'
  pod 'FreshchatSDK'
  pod 'Countly'
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

post_install do |installer|
  installer.pods_project.targets.each do |target|
    if target.name == 'Countly-iOS' || target.name == 'Countly-macOS'
      target.build_configurations.each do |config|
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << 'COUNTLY_EXCLUDE_IDFA=1'
      end
    end
  end
end
