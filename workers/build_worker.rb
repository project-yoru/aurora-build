require 'sidekiq'
require 'sidekiq-symbols'
require 'open3'
require 'faraday'

class BuildWorker
  include Sidekiq::Worker
  include Sidekiq::Symbols

  sidekiq_options queue: :building, retry: false

  def perform distribution
    logger.info "Performing BuildWorker for distribution ##{distribution[:id]} ..."

    logger.info "Running gulp script..."

    # TODO separate gulp scripts
    # TODO use open3 instead of backticks
    # TODO logging

    building_cmd = $secrets[:building_cmd] % { appContentRepoPath: distribution[:github_repo_path] }

    logger.info "Building cmd: #{building_cmd}"

    stdout, stderr, status = Open3.capture3 building_cmd
    if status.exitstatus == 0
      logger.info "Builder exited with state 0, assume succeed..."

      # notify succeed
      notify distribution, :succeed
    else
      logger.info "Builder exited with state #{status.exitstatus}, assume failed..."
      logger.info "Builder exited with stderr:"
      # TODO format
      logger.info stderr

      # notify failed
      # TODO get failed message
      notify distribution, :fail
    end
  end

  private

  def notify distribution, result
    logger.info "Notifying server on #{$secrets[:aurora_web_server][:url]}"
    NotifyWorker.perform_async distribution, 'building_progress', result
  end

end
