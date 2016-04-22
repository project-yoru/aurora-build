require 'logger'
logger = Logger.new STDOUT

$root_dir = __dir__

logger.info 'Loading initializers...'
# COMMENT sort is needed on some platform like Ubuntu to make sure that '_initializer.rb' got load first
Dir["./config/initializers/*.rb"].sort.each do |file|
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
      logger.info "creating building_job for distribution ##{params[:distribution][:id]}"
      {
        job_id: ( BuildWorker.perform_async params[:distribution] )
      }
    end

    desc 'Stop a building_job'
    params do
      requires :job_id, type: String
    end
    delete ':job_id' do
      logger.info "shutting building_job for job ##{params[:job_id]}"

      # get and stop jobs
      # TODO seems this can only stop in-queue-and-not-running jobs
      # TODO figure some workaround
      # TODO also stop all notifying job related to this distribution
      if job = ( Sidekiq::Queue.new('building').find_job params[:job_id] )
        job.delete
      end

      # clean up tmp files
      # TODO make following a shared lib
      FileUtils.rm_rf Pathname.new($root_dir).join("tmp/building_workspaces/#{params[:job_id]}/")
      FileUtils.rm_f Pathname.new($root_dir).join("tmp/built_archives/#{params[:job_id]}.zip") 

      # TODO proper response
      {
        message: "job #{params[:job_id]} deleted"
      }
    end

  end

end

# Web server by Goliath
class BuildServer < Goliath::API

  def response(env)
    BuildAPI.call(env)
  end

end
