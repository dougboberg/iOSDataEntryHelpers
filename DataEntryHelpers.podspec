
Pod::Spec.new do |spec|
	spec.name = 'DataEntryHelpers'
	spec.version = '2.0'
	spec.summary = 'Toggles, pickers, and other data entry components'
	spec.homepage = 'https://www.ikonetics.com'
	spec.author = 'Douglas Boberg'
	spec.license = { :file => 'LICENSE', :type => 'Ikonetics DataEntryHelpers © 2016 by Douglas Boberg is licensed under a Creative Commons Attribution 4.0 International License. You should have received a copy of the license along with this work. If not, see <http://creativecommons.org/licenses/by/4.0/>.' }
	spec.source = { :git => 'https://bitbucket.org/postureco/pcilibrary.git' }
	spec.swift_version = '5.0'
	spec.ios.deployment_target = '14.0'
	spec.source_files = ['DataEntryHelpers/*.{swift,h,m}']
end
