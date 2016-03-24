require 'logger'
logger = Logger.new STDOUT

# 
logger.info 'Loading dependencies...'
require 'goliath'
require 'grape'

require 'sidekiq'
require 'sidekiq-symbols'

case Goliath.env
when :development
  require 'byebug'
  require 'awesome_print'
end

# 
logger.info 'Loading secrets...'
require 'pathname'
require 'yaml'
$secrets = (YAML.load_file Pathname.new($root_dir).join('config/secrets.yml'))[Goliath.env]

logger.info 'Loading operating cmds...'
$operating_cmds = (YAML.load_file Pathname.new($root_dir).join('config/operating_cmds.yml'))[Goliath.env]

