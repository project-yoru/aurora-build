require 'fileutils'
require 'open3'
require 'securerandom'

module AuroraBuilder
  class Builder

    def build job
      @job = job
      @project = @job[:project] # :id, :name, :git_repo_path
      @distribution = @job[:distribution] # :id, :platform

      log "Starting building for job #{job[:id]}"
      notify 'start_building'

      notify 'spawning building workspace'
      @building_workspace_path = spawn_building_workspace

      pull_app_content_repo @project[:git_repo_path]

      case @distribution[:platform]
      when 'web'
        dist_path = build_web
        archive_file_path = compress
      when 'android'
        dist_path = build_web
        archive_file_path = ( build_android dist_path, prod: :debug )
      end

      uploaded_archive_url = upload archive_file_path

      notify 'succeed', { uploaded_archive_url: uploaded_archive_url }
    rescue => e
      notify 'error_occur', { progress_message: e }
    ensure
      # cleanup
      FileUtils.rm_rf @building_workspace_path unless @building_workspace_path.nil?
      FileUtils.rm_f archive_file_path unless archive_file_path.nil?
    end

    private

    def spawn_building_workspace
      building_workspace_path = $root_path.join("tmp/building_workspaces/#{@job[:id]}/")
      FileUtils.rm_rf(building_workspace_path, verbose: true, secure: true) if Dir.exists?(building_workspace_path)
      FileUtils.cp_r $root_path.join('vendor/aurora-core-structure'), building_workspace_path
      return building_workspace_path
    end

    def pull_app_content_repo git_repo_path
      notify 'pulling app content...'

      pulling_cmd = $operating_cmds[:pull] % { building_workspace_path: @building_workspace_path, git_repo_path: git_repo_path }
      exec_cmd pulling_cmd
    end

    def build_web
      # TODO separate gulp scripts
      # TODO handle stderr and stuff

      notify 'Building to web version...'

      building_web_cmd = $operating_cmds[:build_web] % { building_workspace_path: @building_workspace_path }
      exec_cmd building_web_cmd
      @building_workspace_path.join('dist')
    end

    def build_android built_dist_path, prod: :debug
      # return the apk file path
      # prod: :debug or :release
      # target: :device or :emulator

      # TODO rename filename

      notify 'Building to android version...'

      building_android_cmd = $operating_cmds[:build_android] % { building_workspace_path: @building_workspace_path, built_dist_path: built_dist_path, app_id: 'com.projectYoru.aurora.demo', app_name: 'AuroraDemo' }
      exec_cmd building_android_cmd

      filename = case prod
                 when :debug
                   'android-debug.apk'
                 when :release
                   'android.apk'
                 end

      filepath = @building_workspace_path.join "cordova_workspace/platforms/android/build/outputs/apk/#{filename}"

      new_filename = "#{SecureRandom.uuid}.apk"
      new_filepath = @building_workspace_path.join "cordova_workspace/platforms/android/build/outputs/apk/#{new_filename}"

      File.rename filepath, new_filepath
      new_filepath
    end

    def compress
      # TODO dist_path as input

      notify 'Start compressing...'

      archive_file_path = $root_path.join("tmp/built_archives/#{SecureRandom.uuid}.zip") # TODO should be related to project name, distribution platform, version, etc...
      FileUtils.mkpath archive_file_path.dirname
      compressing_cmd = $operating_cmds[:compress] % { building_workspace_path: @building_workspace_path, archive_file_path: archive_file_path }
      exec_cmd compressing_cmd

      return archive_file_path
    end

    def upload archive_file_path
      notify "Start uploading file..."

      response_code, response_result, response_headers = Qiniu::Storage.upload_with_token_2(
        Qiniu::Auth.generate_uptoken( Qiniu::Auth::PutPolicy.new $secrets[:cdn][:qiniu][:bucket] ),
        archive_file_path
      )

      unless response_code == 200
        log "Uploader responsed without 200, assume failed..."
        log "Response headers: #{response_headers}"
        # TODO get and send failed message
        error_occur! 'uploading failed'
      end

      uploaded_archive_url = URI::HTTP.build host: $secrets[:cdn][:qiniu][:domain], path: "/#{response_result['key']}"
      log "Uploaded succeeded to: #{uploaded_archive_url}"
      return uploaded_archive_url
    end

    def exec_cmd cmd
      log "Executing cmd: #{cmd}"
      stdout, stderr, status = Open3.capture3 cmd

      # log "STDOUT:"
      # log stdout # TODO format

      if status.exitstatus != 0
        log "Executing failed with exitstatus: #{status.exitstatus}"
        log "STDERR:"
        # TODO format
        log stderr
        # TODO get and send failed message, try get the last line of formated stderr
        # TODO
        error_occur! stderr.lines.last
        return
      end

      log 'Executing exited with status 0, assuming succeed...'
    end

    def notify progress, extra_message = {}
      log "notifying: #{progress}, #{extra_message}"

      default_message = {
        sent_at: Time.now.to_i
      }
      event_name = ''
      message = {}

      case progress
      when 'start_building', 'error_occur', 'succeed'
        # that's a major event
        event_name = progress
      else
        event_name = 'minor_update'
        message = {
          progress_message: progress
        }
      end

      $notifier.notify({
        job: @job,
        event_name: event_name,
        message: default_message.merge(message).merge(extra_message)
      })
    end

    def error_occur! error_message
      raise "AuroraBuilder::BuildingFailed: #{error_message}"
    end

    def log message
      AuroraBuilder::Utilities.log message, "AuroraBuilder-#{@job[:id]}"
    end

  end
end
