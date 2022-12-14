#
# Be sure to run `pod lib lint AlimFMDBTool.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'AlimFMDBTool'
  s.version          = '0.1.0'
  s.summary          = 'A short description of AlimFMDBTool.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/shengmaoyuan/AlimFMDBTool'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'shengmaoyuan' => 'maoyuan.sheng@ctechm.com' }
  s.source           = { :git => 'https://github.com/SMYdamao/FMDBTool.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '10.0'

  s.source_files = 'AlimFMDBTool/Classes/**/*'
  
  s.source_files = 'AlimFMDBTool/Classes/*.{h,m}'

  s.subspec 'AlimDB' do |ss|
    ss.dependency 'FMDB/SQLCipher'
    ss.dependency 'YYModel'
    ss.source_files = 'AlimFMDBTool/Classes/AlimDB/*.{h,m}'
  end

  s.subspec 'FTS' do |ss|
    ss.dependency 'FMDB/SQLCipher'
    ss.source_files = 'AlimFMDBTool/Classes/FTS/*.{h,m}'
  end

  s.subspec 'FMDBExt' do |ss|
    ss.dependency 'FMDB/SQLCipher'
    ss.source_files = 'AlimFMDBTool/Classes/FMDBExt/*.{h,m}'
  end
  
  s.subspec 'Common' do |ss|
    ss.source_files = 'AlimFMDBTool/Classes/Common/*.{h,m}'
  end

end
