# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'Tidy iOS' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for Tidy iOS
  pod 'DeepDiff', '1.4.0'
  pod 'Charts', '3.2.1'
  pod 'ReSwift', '4.0.1'
  pod 'CocoaImageHashing', '1.6.1'
  pod 'ReachabilitySwift', '4.3.0'
  pod 'JGProgressHUD', '2.0.3'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      target.build_settings(config.name)['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
    end
  end
end

