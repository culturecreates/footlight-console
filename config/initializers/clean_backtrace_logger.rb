# config/initializers/clean_backtrace_logger.rb
module CleanBacktraceLogger
  APP_PATH = Rails.root.to_s

  # Filter stack traces to only include lines from app/ folder
  def self.clean_backtrace(exception)
    return [] unless exception&.backtrace
    exception.backtrace.select { |line| line.start_with?(APP_PATH) }
  end

  # Subscribe to Rails notifications and clean exceptions
  ActiveSupport::Notifications.subscribe(/.*/) do |name, started, finished, unique_id, payload|
    if payload[:exception_object]
      e = payload[:exception_object]
      short_trace = clean_backtrace(e)
      Rails.logger.error("[#{name}] #{e.class}: #{e.message}")
      Rails.logger.debug(short_trace.join("\n")) unless short_trace.empty?
    end
  end

  # Helper to log exceptions with cleaned backtrace
  def self.log_exception(name, exception)
    short_trace = clean_backtrace(exception)
    Rails.logger.error("[#{name}] #{exception.class}: #{exception.message}")
    Rails.logger.debug(short_trace.join("\n")) unless short_trace.empty?
  end
end
