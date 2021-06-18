#
# Be sure to run `pod lib lint Iris-iOS.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Iris-iOS'
  s.version          = '1.0.0'
  s.summary          = 'Protocol based network abstraction layer'
  s.description      = <<-DESC
    Protocol based network abstraction layer.
                       DESC

  s.homepage         = 'https://github.com/horovodovodo4ka/Iris-iOS'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'horovodovodo4ka' => 'xbitstream@gmail.com' }
  s.source           = { :git => 'https://github.com/horovodovodo4ka/Iris-iOS.git', :tag => s.version.to_s }

  s.module_name = 'Iris'
  s.ios.deployment_target = '9.0'
  s.swift_version = '5.4'

  s.subspec 'Core' do |sp|
    sp.source_files = 'Iris/Classes/Core/**/*.{swift}'

    sp.dependency 'PromiseKit', '~> 6.15.0'
    sp.dependency 'PromiseKit/Alamofire'
  end

  s.subspec 'Alamofire' do |sp|
    sp.source_files = 'Iris/Classes/Alamofire/**/*.{swift}'

    sp.dependency 'Iris-iOS/Core'
    
    sp.dependency 'Alamofire', '~> 4.9.0'
    sp.dependency 'AlamofireActivityLogger', '~> 2.5.0'
  end

  s.subspec 'Logging' do |sp|
    sp.source_files = 'Iris/Classes/Logging/**/*.{swift}'

    sp.dependency 'Iris-iOS/Core'

    sp.dependency 'Astaroth', '~> 0.5.0'
  end

  s.subspec 'Defaults' do |sp|
      sp.source_files = 'Iris/Classes/Defaults/**/*.{swift}'
  end

  s.default_subspecs = 'Core', 'Logging', 'Alamofire'
  
end
