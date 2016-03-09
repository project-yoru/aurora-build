# TODO authenticate
# TODO logging
# TODO deployment

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
secrets = (YAML.load_file Pathname.new(__dir__).join('config/secrets.yml'))[Goliath.env]

# 
logger.info 'Configuring redis...'
Sidekiq.configure_server do |config|
  config.redis = { namespace: 'aurora-core-build-server', url: secrets[:redis][:url] }
end
Sidekiq.configure_client do |config|
  config.redis = { namespace: 'aurora-core-build-server', url: secrets[:redis][:url] }
end

# 
logger.info 'Loading workers...'
require_relative 'workers/build_worker.rb'

class BuildAPI < Grape::API

  version 'v1', using: :path
  format :json

  helpers do
    def logger
      BuildAPI.logger
    end
  end

  resource :building_jobs do

    desc 'Create a building_job'
    params do
      requires :distribution, type: Hash do
        requires :id, type: String
        requires :source_type, type: String
        requires :github_repo_path, type: String
        requires :platform, type: String
      end
    end
    post do
      # TODO authenticate
      BuildWorker.perform_async params[:distribution]
    end
  end

end

class BuildServer < Goliath::API

  def response(env)
    BuildAPI.call(env)
  end

end
