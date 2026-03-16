# frozen_string_literal: true

module AppLogger
  APP_ROOT = Rails.root.to_s

  def self.clean_backtrace(exception)
    return [] unless exception&.backtrace
    exception.backtrace.select { |l| l.start_with?(APP_ROOT) }
  end

  def self.error(context, exception)
    Rails.logger.error("[#{context}] #{exception.class}: #{exception.message}")

    trace = clean_backtrace(exception)
    Rails.logger.debug(trace.join("\n")) unless trace.empty?
  end

  def self.warn(context, exception)
    Rails.logger.warn("[#{context}] #{exception.class}: #{exception.message}")

    trace = clean_backtrace(exception)
    Rails.logger.debug(trace.join("\n")) unless trace.empty?
  end
end
