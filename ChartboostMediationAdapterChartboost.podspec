Pod::Spec.new do |spec|
  spec.name        = 'ChartboostMediationAdapterChartboost'
  spec.version     = '5.9.14.0.0'
  spec.license     = { :type => 'MIT', :file => 'LICENSE.md' }
  spec.homepage    = 'https://github.com/ChartBoost/chartboost-mediation-ios-adapter-chartboost'
  spec.authors     = { 'Chartboost' => 'https://www.chartboost.com/' }
  spec.summary     = 'Chartboost Mediation iOS SDK Chartboost adapter.'
  spec.description = 'Chartboost Adapters for mediating through Chartboost Mediation. Supported ad formats: Banner, Interstitial, and Rewarded.'

  # Source
  spec.module_name  = 'ChartboostMediationAdapterChartboost'
  spec.source       = { :git => 'https://github.com/ChartBoost/chartboost-mediation-ios-adapter-chartboost.git', :tag => spec.version }
  spec.source_files = 'Source/**/*.{swift}'
  spec.resource_bundles = { 'ChartboostMediationAdapterChartboost' => ['PrivacyInfo.xcprivacy'] }

  # Minimum supported versions
  spec.swift_version         = '5.0'
  spec.ios.deployment_target = '13.0'

  # System frameworks used
  spec.ios.frameworks = ['Foundation', 'SafariServices', 'UIKit', 'WebKit']

  # Dependencies
  spec.dependency 'ChartboostMediationSDK', '~> 5.0'
  spec.dependency 'ChartboostSDK', '~> 9.14.0'

  spec.static_framework = true
end
