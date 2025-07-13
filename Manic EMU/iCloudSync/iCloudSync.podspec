Pod::Spec.new do |s|
  s.name             = 'iCloudSync'
  s.version          = '8.0.21'
  s.license          = { :type => 'MIT'  }
  s.summary          = 'Sync and Manage iCloud Documents. A fork, complete rewrite, of iCloud Document Sync written in pure Swift.'
 
  s.description      = <<-DESC
iCloudSync is a fork of iCloud Document Sync Framework by iRare Media. Original
framework was done under MIT license, so this one follows MIT licensing.

iCloudSync makes it incredibly simple to integrate iCloud document storage
APIs into iOS applications. This is how iCloud document-storage and 
management should've been out of the box from Apple. Integrate iCloud
into iOS Swift document projects with one-line code methods.
Sync, upload, manage, and remove documents to and from iCloud with
only a few lines of code (compared to the hundreds of lines and hours 
that it usually takes). Get iCloud up and running in your iOS app in
only a few minutes.
                       DESC
 
  s.homepage         = 'https://github.com/oskarirauta/iCloudSync'
  s.author           = { 'Oskari Rauta' => 'oskari.rauta@gmail.com' }
  s.source           = { :git => 'https://github.com/oskarirauta/iCloudSync.git', :tag => s.version.to_s }

  s.swift_version = '5.0' 
  s.ios.deployment_target = '12.1'
  s.source_files = [
			'iCloudSync/*.swift'
		]
 
end
