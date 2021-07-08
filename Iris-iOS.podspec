#
# Be sure to run `pod lib lint Iris-iOS.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Iris-iOS'
  s.version          = '2.0.2'
  s.summary          = 'Protocol based network abstraction layer'
  s.description      = <<-DESC
    Protocol based network abstraction layer.
                       DESC

  s.homepage         = 'https://github.com/horovodovodo4ka/Iris'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'horovodovodo4ka' => 'xbitstream@gmail.com' }
  s.source           = { :git => 'https://github.com/horovodovodo4ka/Iris.git', :tag => s.version.to_s }

  s.module_name = 'Iris'
  s.ios.deployment_target = '13.0'
  s.swift_version = '5.4'

  s.subspec 'Core' do |sp|
    sp.source_files = 'Iris/Classes/Core/**/*.{swift}'
  end

  s.subspec 'Alamofire' do |sp|
      sp.source_files = 'Iris/Classes/Alamofire/**/*.{swift}'

      sp.dependency 'Iris-iOS/Core'
      sp.dependency 'Iris-iOS/Logging'

      sp.dependency 'Alamofire', '~> 5.1'
  end

  s.subspec 'URLSession' do |sp|
      sp.source_files = 'Iris/Classes/URLSession/**/*.{swift}'

      sp.dependency 'Iris-iOS/Core'
      sp.dependency 'Iris-iOS/Logging'
  end

  s.subspec 'Logging' do |sp|
    sp.source_files = 'Iris/Classes/Logging/**/*.{swift}'

    sp.dependency 'Iris-iOS/Core'

    sp.dependency 'Astaroth', '~> 0.5'
  end

  s.subspec 'Defaults' do |sp|
      sp.source_files = 'Iris/Classes/Defaults/**/*.{swift}'

      sp.dependency 'Iris-iOS/Core'
  end

  s.default_subspecs = 'Core', 'URLSession'
  
end
