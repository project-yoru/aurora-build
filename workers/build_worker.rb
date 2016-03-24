require 'open3'
require 'securerandom'

class BuildWorker
  include Sidekiq::Worker
  include Sidekiq::Symbols

  sidekiq_options queue: :building, retry: false

  def perform distribution
    logger.info "Performing BuildWorker for distribution ##{distribution[:id]} ..."

    # spawn a new builder
    builder_path = Pathname.new($root_dir).join("tmp/builders/#{self.jid}-#{SecureRandom.uuid}/")
    FileUtils.mkpath builder_path.dirname
    spawn_builder_cmd = $operating_cmds[:spawn_builder] % { builder_path: builder_path }
    logger.info "Spawning a new builder with cmd: #{spawn_builder_cmd}"
    # TODO refactor, make shell cmd exec a method
    stdout, stderr, status = Open3.capture3 spawn_builder_cmd

    unless status.exitstatus == 0
      logger.info "Spawning #{status.exitstatus}, assume failed..."
      logger.info "Spawning exited with stderr:"
      # TODO format
      logger.info stderr
      # TODO get and send failed message
      notify distribution, 'failure_occured'
      # TODO throw
      return
    end

    logger.info "Spawning exited with state 0, assume succeed..."

    notify distribution, 'started_pulling'
    # TODO separate pulling code

    # TODO separate gulp scripts
    # TODO logging
    notify distribution, 'started_building'
    logger.info "Running gulp script..."
    building_cmd = $operating_cmds[:build] % { builder_path: builder_path, app_content_repo_path: distribution[:github_repo_path] }
    logger.info "Building cmd: #{building_cmd}"
    stdout, stderr, status = Open3.capture3 building_cmd

    unless status.exitstatus == 0
      logger.info "Builder exited with state #{status.exitstatus}, assume failed..."
      logger.info "Builder exited with stderr:"
      # TODO format
      logger.info stderr

      # TODO get and send failed message
      notify distribution, 'failure_occured'

      # TODO throw
      return
    end

    logger.info "Builder exited with state 0, assume succeed..."

    notify distribution, 'started_uploading' # COMMENT actually that's compressing & uploading

    # compress archive
    logger.info 'Start compressing...'
    archive_file_path = Pathname.new($root_dir).join("tmp/built_archives/#{distribution[:id]}-#{SecureRandom.uuid}.zip") # TODO should be related to project name, distribution platform, version, etc...
    FileUtils.mkpath archive_file_path.dirname
    compressing_cmd = $operating_cmds[:compress] % { builder_path: builder_path, archive_file_path: archive_file_path }
    stdout, stderr, status = Open3.capture3 compressing_cmd

    unless status.exitstatus == 0
      logger.info "Compressing exited with state #{status.exitstatus}, assume failed..."
      logger.info "Compressing exited with stderr:"
      # TODO format
      logger.info stderr
      # TODO get and send failed message
      notify distribution, 'failure_occured'
      # TODO throw
      return
    end

    # upload
    logger.info 'Compresser exited with state 0, assume succeed, start uploading...'
    response_code, response_result, response_headers = Qiniu::Storage.upload_with_token_2(
      Qiniu::Auth.generate_uptoken( Qiniu::Auth::PutPolicy.new $secrets[:cdn][:qiniu][:bucket] ),
      archive_file_path
    )

    unless response_code == 200
      logger.info "Uploader responsed without 200, assume failed..."
      logger.info "Response headers: #{response_headers}"
      # TODO get and send failed message
      notify distribution, 'failure_occured'
      # TODO throw
      return      
    end

    uploaded_archive_url = URI::HTTP.build host: $secrets[:cdn][:qiniu][:domain], path: "/#{response_result['key']}"

    notify distribution, 'succeeded', { uploaded_archive_url: uploaded_archive_url }
    logger.info 'Uploading succeeded!'

    # cleanup builder and built_archive
    FileUtils.rm_rf builder_path
    FileUtils.rm_f archive_file_path
  end

  private

  def notify distribution, progress, extra_message = {}
    NotifyWorker.perform_async distribution, 'building_progress', { progress: progress }.merge(extra_message)
  end

end
