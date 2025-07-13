Pod::Spec.new do |s|
  s.name             = 'Closures'
  s.version          = '1.0.1'
  s.summary          = 'Swifty closures for UIKit and Foundation'
  s.homepage         = 'https://github.com/KrishnaM0618/Closures'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.authors          = { 'Vinnie Hesener' => 'email@example.com' }  # Replace with real email if available
  s.platform         = :ios, '9.0'
  s.source           = { :git => 'https://github.com/KrishnaM0618/Closures.git'}
  s.source_files     = 'Source/**/*'
  s.description      = <<-DESC
    Closures is an iOS Framework that adds closure handlers to many of the popular
    UIKit and Foundation classes. Although this framework is a substitute for 
    some Cocoa Touch design patterns, such as Delegation and Data Sources, and 
    Target-Action, the authors make no claim regarding which is a better way to 
    accomplish the same type of task. Most of the time it is a matter of style, 
    preference, or convenience that will determine if any of these closure extensions 
    are beneficial.

    Whether you’re a functional purist, dislike a particular API, or simply just 
    want to organize your code a little bit, you might enjoy using this library.
  DESC
end