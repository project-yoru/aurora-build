require 'fileutils'
require 'open3'
require 'securerandom'
require 'json'
require 'ox'
require 'hashie'

module AuroraBuilder
  class Builder
    DEFAULT_CONFIG = {
      meta: {
        id: 'com.projectyoru.workshopaurora.defaultappid',
        name: 'WorkshopAuroraDefaultAppName',
        version: '0.0.1',
        description: 'Workshop Aurora default app description.',
        author: {
          name: 'Workshop Aurora',
          email: 'fake@email.address',
          link: 'https://github.com/project-yoru'
        },
        source: 'https://github.com/project-yoru/aurora-demo-app',
        license: 'MIT'
      },
      appearance: {
        orientation: 'landscape'
        # TODO icon, logo
      },
      custom: {}
    }.extend Hashie::Extensions::DeepMerge

    def build job
      @job = job

      case @job[:type]
      when 'config'
        @project = @job[:project] # :id, :name, :git_repo_path

        log "Starting config job for job #{job[:id]}"

        @building_workspace_path = spawn_building_workspace

        pull_app_content_repo @project[:git_repo_path]

        # parse config
        @config = DEFAULT_CONFIG.deep_merge( parse_app_config )

        notify 'succeed', { parsed_config: @config.to_json }
      when 'build'
        @project = @job[:project] # :id, :name, :git_repo_path
        @distribution = @job[:distribution] # :id, :platform

        log "Starting building for job #{job[:id]}"
        notify 'start_building'

        notify 'spawning building workspace'
        @building_workspace_path = spawn_building_workspace

        notify 'Pulling app content...'
        pull_app_content_repo @project[:git_repo_path]

        notify 'Parsing app config...'
        @config = DEFAULT_CONFIG.deep_merge( parse_app_config )

        case @distribution[:platform]
        when 'web'
          dist_path = build_web
          archive_file_path = compress
        when 'android'
          dist_path = build_web
          archive_file_path = ( build_android prod: :debug )
        end

        uploaded_archive_url = upload archive_file_path

        notify 'succeed', { uploaded_archive_url: uploaded_archive_url }
      end

    rescue => e
      # TODO log e.backtrace

      if $env == :development
        puts e.backtrace
        puts e
        byebug
      end

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
      pulling_cmd = $operating_cmds[:pull] % { building_workspace_path: @building_workspace_path, git_repo_path: git_repo_path }
      exec_cmd pulling_cmd
    end

    def parse_app_config
      # TODO valid required fields

      app_config_dir = @building_workspace_path.join 'app/config/'

      # parse application.json
      if File.exist? (config_file_path = app_config_dir.join('application.json'))
        return JSON.parse File.read config_file_path
      end

      # parse application.cson, cson -> json via cson2json
      if File.exist? (config_file_path = app_config_dir.join('application.cson'))
        parse_app_config_cson_cmd = $operating_cmds[:parse_app_config_cson] % {
          app_config_dir: app_config_dir
        }
        exec_cmd parse_app_config_cson_cmd
        parsed_config_file_path = app_config_dir.join 'application.json'
        return JSON.parse File.read parsed_config_file_path
      end

      # TODO application.yml

    end

    def build_web
      # return built dist path

      # TODO separate gulp scripts
      # TODO handle stderr and stuff

      notify 'Building to web version...'

      building_web_cmd = $operating_cmds[:build_web] % {
        building_workspace_path: @building_workspace_path
      }
      exec_cmd building_web_cmd
      @building_workspace_path.join('dist')
    end

    def build_android prod: :debug
      # return the apk file path
      # prod: :debug or :release
      # target: :device or :emulator

      notify 'Building android version...'
      @cordova_workspace_path = init_cordova 'android'

      configure_cordova

      notify 'Building via cordova...'
      build_via_cordova_cmd = $operating_cmds[:build_via_cordova] % {
        building_workspace_path: @building_workspace_path,
        platform: 'android'
      }
      exec_cmd build_via_cordova_cmd

      filename = case prod
                 when :debug
                   'android-debug.apk'
                 when :release
                   'android.apk'
                 end

      filepath = @cordova_workspace_path.join "platforms/android/build/outputs/apk/#{filename}"

      new_filename = "#{SecureRandom.uuid}.apk"
      new_filepath = @cordova_workspace_path.join "platforms/android/build/outputs/apk/#{new_filename}"

      File.rename filepath, new_filepath
      new_filepath
    end

    def init_cordova platform
      notify 'Initializing cordova...'
      init_cordova_cmd = $operating_cmds[:init_cordova] % {
        building_workspace_path: @building_workspace_path,
        built_web_dist_path: @building_workspace_path.join('dist'),
        app_id: @config['meta']['id'],
        app_name: @config['meta']['name'],
        platform: platform
      }
      exec_cmd init_cordova_cmd
      @building_workspace_path.join 'cordova_workspace'
    end

    def configure_cordova
      # fill config.xml for cordova with @config

      notify 'Configuring cordova...'

      cordova_config_path = @cordova_workspace_path.join 'config.xml'

      # load config xml
      config = Ox.load File.read cordova_config_path

      # meta
      ## description
      config.widget.description.replace_text @config['meta']['description']
      ## author
      config.widget.author.replace_text @config['meta']['author']['name']
      config.widget.author[:email] = @config['meta']['author']['email']
      config.widget.author[:href] = @config['meta']['author']['link']

      #appearance
      ## icon
      # TODO to be fair, maybe should not put icon res in www
      if icon_path = @config['appearance']['icon']
        icon_conf = Ox::Element.new('icon')
        icon_conf[:src] = "www/resources/images/#{icon_path}" # TODO SECURITY filter icon_path like ../../.../etc/secrets
        config.widget << icon_conf
      end
      ## preference orientation
      preference_orientation = Ox::Element.new('preference')
      preference_orientation[:name] = 'Orientation'
      preference_orientation[:value] = @config['appearance']['orientation']
      config.widget << preference_orientation

      # dump and write config.xml file
      File.write cordova_config_path, ( Ox.dump config )
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
      # TODO SECURITY user may easily construct args in cmds to execute danger codes

      log "Executing cmd: #{cmd}"
      stdout, stderr, status = Open3.capture3 cmd

      # log "STDOUT:"
      # log stdout # TODO format

      if status.exitstatus != 0
        log "Executing failed with exitstatus: #{status.exitstatus}"
        log "STDERR:"
        # TODO format
        log stderr

        byebug if $env == :development

        error_occur! stderr.lines.last
        return
      end

      log 'Executing exited with status 0, assuming succeed...'
    end

    def notify progress, extra_message = {}
      log "notifying: #{progress}, #{extra_message}"

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
        sent_at: Time.now.to_i,
        message: message.merge(extra_message)
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
