require 'sidekiq'

class BuildWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'building'

  def perform distribution
    logger.info "Performing BuildWorker for distribution #{distribution}"
  end
end
