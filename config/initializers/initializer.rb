require 'logger'
logger = Logger.new STDOUT

# 
logger.info 'Loading dependencies...'
require 'sidekiq'
require 'goliath'
require 'grape'

case Goliath.env
when :development
  require 'byebug'
  require 'awesome_print'
end

# 
logger.info 'Loading secrets...'
require 'pathname'
require 'yaml'
$secrets = (YAML.load_file Pathname.new(__dir__).join('../secrets.yml'))[Goliath.env]
