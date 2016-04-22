$logger.info 'Loading dependencies...'

case $env
when :development
  require 'byebug'
  require 'awesome_print'
end

#
$logger.info 'Loading secrets...'
require 'pathname'
require 'yaml'
$secrets = (YAML.load_file $root_path.join('config/secrets.yml'))[$env]

$logger.info 'Loading operating cmds...'
$operating_cmds = (YAML.load_file $root_path.join('config/operating_cmds.yml'))[$env]

if $env == :development
  # for debugging
  Thread.abort_on_exception = true
end
