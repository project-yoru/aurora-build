# aurora-build server

# TODO support options for pid, log, daemon

require 'trollop'
require 'logger'
require 'pathname'

module AuroraBuilder
  $logger = Logger.new "| #{$env.to_s}.log"
  $root_path = Pathname.new __dir__

  # parse options
  $options = Trollop::options do
    opt :env, 'environment, dev/development/prod/production', type: :string, default: 'dev'
  end

  $env =
    case $options[:env].to_sym
    when :development, :dev then :development
    when :production, :prod then :production
    end

  $logger.info "Starting aurora builder server in #{$env}..."

  # load libs
  $logger.info 'Loading libs...'
  Dir["./aurora_builder/*.rb"].each do |file|
    $logger.info "- #{file}"
    require file
  end

  # initializers
  $logger.info 'Loading initializers...'
  # COMMENT sort is needed on some platform like Ubuntu to make sure that '_initializer.rb' got load first
  Dir["./config/initializers/*.rb"].sort.each do |file|
    $logger.info "- #{file}"
    require file
  end

  # 
  $logger.info 'Clearing and re-building tmps'
  FileUtils.rm_rf $root_path.join 'tmp/building_workspaces'
  FileUtils.rm_rf $root_path.join 'tmp/built_archives'
  FileUtils.mkdir_p $root_path.join 'tmp/building_workspaces'
  FileUtils.mkdir_p $root_path.join 'tmp/built_archives'

  # 
  $logger.info 'Starting fetcher, manager, builders...'

  $fetcher = AuroraBuilder::Fetcher.new
  $manager = AuroraBuilder::Manager.new
  $notifier = AuroraBuilder::Notifier.new

  threads = [
    $fetcher.thread
  ]
  threads.each(&:join)
end
