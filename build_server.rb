# TODO authenticate

require 'goliath'
require 'grape'

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
      logger.info 'creating'
    end
  end

end

class BuildServer < Goliath::API

  def response(env)
    BuildAPI.call(env)
  end

end
