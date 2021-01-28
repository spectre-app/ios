workspace 'Spectre'
project 'Spectre'

# Unfortunately, this plugin causes build errors as of 2021-01-28.
# plugin 'cocoapods-binary'
# all_binary!
# keep_source_code_for_prebuilt_frameworks!
# enable_bitcode_for_prebuilt_frameworks!

target 'Spectre' do
  project 'Spectre'
  platform :ios, '12.4'

  use_modular_headers!
  use_frameworks!

  pod 'Macaw'

  pod 'Sentry', :git => 'https://github.com/getsentry/sentry-cocoa.git'
  pod 'Countly'
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
