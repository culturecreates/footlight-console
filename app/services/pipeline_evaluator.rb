class PipelineEvaluator
  MISSING_STATEMENTS_STATUS_DIAGNOSIS = "Missing statements_status".freeze
  INCOMPLETE_STATEMENTS_STATUS_DIAGNOSIS = "Incomplete statements_status".freeze

  def self.call(event:)
    new(event).call
  end

  def self.batch(events:)
    events.each_with_object({}) do |event, results|
      key = event.key

      unless key.present?
        Rails.logger.error("[pipeline] missing key for event #{event.inspect}")
        next
      end

      status_data, metrics, = call(event: event)
      status = status_data&.dig(:status) || status_data&.dig("status")
      diagnosis = status_data&.dig(:diagnosis) || status_data&.dig("diagnosis")

      results[key] = {
        status: normalize_status(status),
        diagnosis: diagnosis,
        metrics: metrics
      }
    rescue StandardError => e
      Rails.logger.error(
        "[pipeline] key=#{key} error=#{e.class} message=#{e.message}"
      )

      results[key] = {
        status: :error,
        diagnosis: e.message,
        metrics: {}
      }
    end
  end

  def self.normalize_status(status)
    case status&.to_sym
    when :healthy, :ok
      :ok
    when :degraded, :warning
      :warning
    when :broken, :critical, :error
      :error
    else
      status&.to_sym
    end
  end

  def initialize(event)
    @event = event
  end

  def call
    metrics = PipelineMetricsBuilder.call(event: event)
    return [missing_statements_status_result, metrics, []] unless statements_status_present?

    rules = PipelineRuleResolver.rules_for(event.website)

    status = PipelineStatusInterpreter.call(
      website: event.website,
      metrics: metrics,
      rules: rules
    )
    status = incomplete_statements_status_result(metrics) if replace_ok_with_warning?(status, metrics)

    [status, metrics, rules]
  rescue StandardError => e
    raise PipelineBuilder::EvaluationError.new(
      error: e,
      metrics: metrics || {},
      rules: rules || []
    )
  end

  private

  attr_reader :event

  def statements_status_present?
    event_value(:statements_status).is_a?(Hash)
  end

  def event_value(name)
    return event.public_send(name) if event.respond_to?(name)
    return nil unless event.respond_to?(:[])

    return event[name] if event.key?(name)
    return event[name.to_s] if event.key?(name.to_s)

    nil
  end

  def replace_ok_with_warning?(status, metrics)
    status_value = status&.dig(:status) || status&.dig("status")
    status_value.to_sym == :ok && missing_required_metrics(metrics).any?
  end

  def missing_required_metrics(metrics)
    PipelineMetricsBuilder::REQUIRED_BOOLEAN_METRICS.select { |metric| metrics[metric].nil? }
  end

  def missing_statements_status_result
    {
      status: :error,
      diagnosis: MISSING_STATEMENTS_STATUS_DIAGNOSIS
    }
  end

  def incomplete_statements_status_result(metrics)
    missing_metrics = missing_required_metrics(metrics)

    {
      status: :warning,
      diagnosis: "#{INCOMPLETE_STATEMENTS_STATUS_DIAGNOSIS}: #{missing_metrics.join(', ')}"
    }
  end
end
