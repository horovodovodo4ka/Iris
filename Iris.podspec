#
# Be sure to run `pod lib lint Iris.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Iris'
  s.version          = '0.1.0'
  s.summary          = 'Protocol based network abstraction layer'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
    Protocol based network abstraction layer.
                       DESC

  s.homepage         = 'https://github.com/horovodovodo4ka/Iris'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'horovodovodo4ka' => 'xbitstream@gmail.com' }
  s.source           = { :git => 'https://github.com/horovodovodo4ka/Iris.git', :tag => s.version.to_s }

  s.ios.deployment_target = '9.0'


  s.subspec 'Core' do |sp|
    sp.source_files = 'Iris/Classes/Core/**/*.{swift}'

    sp.dependency 'Iris/Util'

    sp.dependency 'PromiseKit', '~> 6.15.0'
    sp.dependency 'PromiseKit/Alamofire'
  end

  s.subspec 'Alamofire' do |sp|
    sp.source_files = 'Iris/Classes/Alamofire/**/*.{swift}'

    sp.dependency 'Iris/Core'
    
    sp.dependency 'Alamofire', '~> 4.9.0'
    sp.dependency 'AlamofireActivityLogger', '~> 2.5.0'
  end

  s.subspec 'Logging' do |sp|
    sp.source_files = 'Iris/Classes/Logging/**/*.{swift}'

    sp.dependency 'Iris/Core'

    sp.dependency 'Astaroth', '~> 0.4.0'
  end

  s.subspec 'Util' do |sp|
    sp.source_files = 'Iris/Classes/Util/**/*.{swift}'

  end

  s.default_subspecs = 'Core' #, 'Logging', 'Alamofire'
  
end
