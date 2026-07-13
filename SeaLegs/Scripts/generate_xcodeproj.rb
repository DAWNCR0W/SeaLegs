#!/usr/bin/env ruby
# frozen_string_literal: true

require 'xcodeproj'
require 'xcodeproj/scheme'
require 'fileutils'

project_root = File.expand_path('..', __dir__)
repository_root = File.expand_path('..', project_root)
Dir.chdir(project_root)

project_path = 'SeaLegs.xcodeproj'
app_bundle_identifier = ENV.fetch('SEALEGS_BUNDLE_IDENTIFIER', 'com.dawncrow.SeaLegs')
test_bundle_identifier = ENV.fetch('SEALEGS_TEST_BUNDLE_IDENTIFIER', "#{app_bundle_identifier}Tests")
ui_test_bundle_identifier = ENV.fetch('SEALEGS_UI_TEST_BUNDLE_IDENTIFIER', "#{app_bundle_identifier}UITests")
development_team = ENV.fetch('SEALEGS_DEVELOPMENT_TEAM', '')
version_file = File.join(repository_root, 'VERSION')
unless File.file?(version_file)
  abort "Missing canonical version file: #{version_file}"
end

default_marketing_version = File.read(version_file).strip
if default_marketing_version.empty?
  abort "Canonical version file is empty: #{version_file}"
end

marketing_version = ENV.fetch('SEALEGS_MARKETING_VERSION', default_marketing_version)
build_number = ENV.fetch('SEALEGS_BUILD_NUMBER', '2')
FileUtils.rm_rf(project_path)

project = Xcodeproj::Project.new(project_path)
project.root_object.attributes['LastSwiftUpdateCheck'] = '2630'
project.root_object.attributes['LastUpgradeCheck'] = '2630'
project.root_object.known_regions = %w[en Base ko]

app_target = project.new_target(:application, 'SeaLegs', :osx, '14.0')
test_target = project.new_target(:unit_test_bundle, 'SeaLegsTests', :osx, '14.0')
ui_test_target = project.new_target(:ui_test_bundle, 'SeaLegsUITests', :osx, '14.0')
test_target.add_dependency(app_target)
ui_test_target.add_dependency(app_target)

app_group = project.main_group.new_group('SeaLegs', 'SeaLegs')
test_group = project.main_group.new_group('SeaLegsTests', 'SeaLegsTests')
ui_test_group = project.main_group.new_group('SeaLegsUITests', 'SeaLegsUITests')

def add_files(project_group, target, base_path)
  asset_catalogs = Dir.glob("#{base_path}/**/*.xcassets").sort
  localized_strings = Dir.glob("#{base_path}/**/*.lproj/*.strings").sort
  asset_catalogs.each do |path|
    relative_path = path.sub("#{base_path}/", '')
    file_ref = project_group.new_file(relative_path)
    target.resources_build_phase.add_file_reference(file_ref, true)
  end

  localized_strings.group_by { |path| File.basename(path) }.each do |name, paths|
    variant_group = project_group.new_variant_group(name)
    paths.each do |path|
      file_ref = variant_group.new_file(path.sub("#{base_path}/", ''))
      file_ref.name = File.basename(File.dirname(path), '.lproj')
    end
    target.resources_build_phase.add_file_reference(variant_group, true)
  end

  Dir.glob("#{base_path}/**/*").sort.each do |path|
    next if asset_catalogs.any? { |catalog| path == catalog || path.start_with?("#{catalog}/") }
    next if localized_strings.include?(path)
    next if File.directory?(path)

    relative_path = path.sub("#{base_path}/", '')
    file_ref = project_group.new_file(relative_path)
    case File.extname(path)
    when '.swift', '.metal'
      target.source_build_phase.add_file_reference(file_ref, true)
    when '.json'
      target.resources_build_phase.add_file_reference(file_ref, true)
    end
  end
end

add_files(app_group, app_target, 'SeaLegs')
add_files(test_group, test_target, 'SeaLegsTests')
add_files(ui_test_group, ui_test_target, 'SeaLegsUITests')

project.build_configurations.each do |config|
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  config.build_settings['SWIFT_VERSION'] = '6.0'
end

app_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_NAME'] = 'SeaLegs'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = app_bundle_identifier
  config.build_settings['INFOPLIST_FILE'] = 'SeaLegs/Info.plist'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'SeaLegs/SeaLegs.entitlements'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['DEVELOPMENT_TEAM'] = development_team
  config.build_settings['MARKETING_VERSION'] = marketing_version
  config.build_settings['CURRENT_PROJECT_VERSION'] = build_number
  config.build_settings['ENABLE_HARDENED_RUNTIME'] = 'YES'
  config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
  config.build_settings['SWIFT_VERSION'] = '6.0'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/../Frameworks'
end

test_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_NAME'] = 'SeaLegsTests'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = test_bundle_identifier
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['DEVELOPMENT_TEAM'] = development_team
  config.build_settings['MARKETING_VERSION'] = marketing_version
  config.build_settings['CURRENT_PROJECT_VERSION'] = build_number
  config.build_settings['SWIFT_VERSION'] = '6.0'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/SeaLegs.app/Contents/MacOS/SeaLegs'
  config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/../Frameworks @loader_path/../Frameworks'
end

ui_test_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_NAME'] = 'SeaLegsUITests'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = ui_test_bundle_identifier
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['DEVELOPMENT_TEAM'] = development_team
  config.build_settings['MARKETING_VERSION'] = marketing_version
  config.build_settings['CURRENT_PROJECT_VERSION'] = build_number
  config.build_settings['SWIFT_VERSION'] = '6.0'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  config.build_settings['TEST_TARGET_NAME'] = app_target.name
end

# The first pass normalizes UUID references created by xcodeproj; the second
# makes the path-derived UUIDs stable across independent generator runs.
2.times { project.predictabilize_uuids }
project.save

scheme = Xcodeproj::XCScheme.new
scheme.configure_with_targets(app_target, test_target, launch_target: true)
scheme.add_build_target(ui_test_target, false)
scheme.add_test_target(ui_test_target)
scheme.test_action.build_configuration = 'Debug'
scheme.launch_action.build_configuration = 'Debug'
scheme.profile_action.build_configuration = 'Release'
scheme.analyze_action.build_configuration = 'Debug'
scheme.archive_action.build_configuration = 'Release'
scheme.save_as(project_path, 'SeaLegs', true)

puts "Generated #{project_path}"
