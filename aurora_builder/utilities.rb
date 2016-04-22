module AuroraBuilder
  module Utilities
    def log message, prefix = nil
      prefix = self.class.name.split('::').last if prefix.nil?
      $logger.info "#{prefix}: #{message}"
    end
    module_function :log
  end
end
