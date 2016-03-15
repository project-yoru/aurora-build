# TODO 
# - authenticate request
# - set auth for notification
# - logging
# - deployment

require 'logger'
logger = Logger.new STDOUT

logger.info 'Loading initializers...'
Dir["./config/initializers/*.rb"].each do |file|
  logger.info "- #{file}"
  require file
end

logger.info 'Loading workers...'
Dir["./workers/*.rb"].each do |file|
  logger.info "- #{file}"
  require file
end

# API by Grape
class BuildAPI < Grape::API

  version 'v1', using: :path
  format :json

  # helpers do
  #   def logger
  #     BuildAPI.logger
  #   end
  # end

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
      BuildWorker.perform_async params[:distribution]
      NotifyWorker.perform_async params[:distribution], 'building_progress', 'start'
    end
  end

end

# Web server by Goliath
class BuildServer < Goliath::API

  def response(env)
    BuildAPI.call(env)
  end

end
