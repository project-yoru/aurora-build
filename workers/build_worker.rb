# TODO handle notifying and logging more beautifully
# TODO handle git clone progress

require 'open3'
require 'securerandom'

class BuildWorker
  include Sidekiq::Worker
  include Sidekiq::Symbols

  sidekiq_options queue: :building, retry: false

  def perform distribution
    logger.info "Performing BuildWorker for distribution ##{distribution[:id]} ..."

    @distribution = distribution

    notify 'start_building'

    notify 'spawning building workspace'
    @building_workspace_path = spawn_building_workspace

    notify 'pulling'
    pull_app_content_repo @distribution[:github_repo_path]

    notify 'running building scripts'
    build

    notify 'compressing'
    archive_file_path = compress

    notify 'uploading'
    uploaded_archive_url = upload archive_file_path

    notify 'succeed', { uploaded_archive_url: uploaded_archive_url }
  rescue => e
    error_occur! e
  ensure
    # cleanup
    FileUtils.rm_rf @building_workspace_path
    FileUtils.rm_f archive_file_path
  end

  private

  def spawn_building_workspace
    building_workspace_path = Pathname.new($root_dir).join("tmp/building_workspaces/#{self.jid}/")
    FileUtils.rm_rf building_workspace_path if Dir.exists? building_workspace_path
    FileUtils.cp_r Pathname.new($root_dir).join('vendor/aurora-core-structure'), building_workspace_path
    return building_workspace_path
  end

  def pull_app_content_repo github_repo_path
    pulling_cmd = $operating_cmds[:pull] % { building_workspace_path: @building_workspace_path, github_repo_path: github_repo_path }
    exec_cmd pulling_cmd
  end

  def build
    # TODO separate gulp scripts
    # TODO handle stderr and stuff
    logger.info 'Running gulp script...'
    building_cmd = $operating_cmds[:build] % { building_workspace_path: @building_workspace_path }
    exec_cmd building_cmd
  end

  def compress
    logger.info 'Start compressing...'

    archive_file_path = Pathname.new($root_dir).join("tmp/built_archives/#{jid}.zip") # TODO should be related to project name, distribution platform, version, etc...
    FileUtils.mkpath archive_file_path.dirname
    compressing_cmd = $operating_cmds[:compress] % { building_workspace_path: @building_workspace_path, archive_file_path: archive_file_path }
    exec_cmd compressing_cmd

    return archive_file_path
  end

  def upload archive_file_path
    logger.info "Start uploading file: #{archive_file_path}"

    response_code, response_result, response_headers = Qiniu::Storage.upload_with_token_2(
      Qiniu::Auth.generate_uptoken( Qiniu::Auth::PutPolicy.new $secrets[:cdn][:qiniu][:bucket] ),
      archive_file_path
    )

    unless response_code == 200
      logger.info "Uploader responsed without 200, assume failed..."
      logger.info "Response headers: #{response_headers}"
      # TODO get and send failed message
      error_occur! 'uploading failed'
    end

    uploaded_archive_url = URI::HTTP.build host: $secrets[:cdn][:qiniu][:domain], path: "/#{response_result['key']}"
    logger.info "Uploaded succeeded to: #{uploaded_archive_url}"
    return uploaded_archive_url
  end

  def exec_cmd cmd
    logger.info "Executing cmd: #{cmd}"
    stdout, stderr, status = Open3.capture3 cmd

    logger.info "STDOUT:"
    logger.info stdout # TODO format

    if status.exitstatus != 0
      logger.info "Executing failed with exitstatus: #{status.exitstatus}"
      logger.info "STDERR:"
      # TODO format
      logger.info stderr
      # TODO get and send failed message, try get the last line of formated stderr
      error_occur! stderr.lines.last
      return
    end

    logger.info 'Executing exited with status 0, assuming succeed...'
  end

  def error_occur! error_message
    # TODO get and send failed message
    notify 'error_occur', { progress_message: error_message }

    raise error_message
  end

  def notify progress, extra_message = {}
    default_message = {
      job_id: jid,
      sent_at: Time.now.to_i
    }
    message = {}

    case progress
    when 'start_building', 'error_occur', 'succeed'
      event_name = 'building_progress'
      message = {
        progress: progress
      }
    else
      # that's a minor progress update
      event_name = 'building_progress'
      message = {
        progress: 'minor_update',
        progress_message: progress
      }
    end

    NotifyWorker.perform_async @distribution, event_name, default_message.merge(message).merge(extra_message)
  end

end
