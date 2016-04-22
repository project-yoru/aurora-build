require_relative 'utilities'

module AuroraBuilder
  class Manager
    include Utilities

    BUILDERS_LIMIT = 3

    def initialize
      @jobs = Queue.new
      start_builders
    end

    def new_job job
      @jobs.push job
    end

    private

    def start_builders
      @builders = (BUILDERS_LIMIT).times.map do
        Thread.new do
          begin
            log 'Builder thread started'
            while job = @jobs.pop do
              AuroraBuilder::Builder.new.build job
            end
          end
        end
      end
    end
  end
end
