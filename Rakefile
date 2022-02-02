require 'onceover/rake_tasks'
require 'puppetlabs_spec_helper/rake_tasks'
require 'puppet/version'
require 'puppet-lint/tasks/puppet-lint'
require 'puppet-syntax/tasks/puppet-syntax'
require 'metadata-json-lint/rake_task'
require 'rubocop/rake_task'

desc 'Populate CONTRIBUTORS file'
task :contributors do
  system("git log --format='%aN' | sort -u > CONTRIBUTORS")
end

PuppetLint::RakeTask.new :lint do |config|
  # Pattern of files to check, defaults to `**/*.pp`
  config.pattern = 'site/**/*.pp'

  # List of checks to disable
  config.disable_checks = %w[documentation 140chars]

  # Should puppet-lint prefix it's output with the file being checked,
  # defaults to true
  config.with_filename = true

  # Should the task fail if there were any warnings, defaults to false
  config.fail_on_warnings = false

  # Format string for puppet-lint's output (see the puppet-lint help output
  # for details
  config.log_format = '%{filename} - %{message}'

  # Print out the context for the problem, defaults to false
  config.with_context = true

  # Enable automatic fixing of problems, defaults to false
  config.fix = true

  # Show ignored problems in the output, defaults to false
  config.show_ignored = true

  # Compare module layout relative to the module root
  config.relative = false
end
