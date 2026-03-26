class PipelineBuilder
  class EvaluationError < StandardError
    attr_reader :error, :metrics, :rules

    def initialize(error:, metrics:, rules:)
      @error = error
      @metrics = metrics
      @rules = rules
      super(error.message)
      set_backtrace(error.backtrace)
    end
  end

  class PipelineEvent
    attr_reader :payload, :website

    def initialize(payload, website)
      @payload = payload || {}
      @website = website
    end

    def id
      value_for(:id)
    end

    def key
      value_for(:rdf_uri) || id
    end

    def respond_to_missing?(name, include_private = false)
      payload_key?(name) || super
    end

    def method_missing(name, *args)
      return value_for(name) if args.empty? && payload_key?(name)

      super
    end

    private

    def payload_key?(name)
      payload.respond_to?(:key?) && (payload.key?(name) || payload.key?(name.to_s))
    end

    def value_for(name)
      return payload[name] if payload.respond_to?(:[]) && !payload[name].nil?
      return payload[name.to_s] if payload.respond_to?(:[])

      nil
    end
  end

  def self.call(events:, website:, trace: false)
    new(website, trace: trace).call(events: events)
  end

  def self.evaluate(event:)
    PipelineEvaluator.call(event: event)
  end

  def initialize(website = nil, trace: false)
    @website = website
    @trace = trace
  end

  def call(events:)
    Array(events).map do |event|
      build_row(normalize_event(event))
    end
  end

  private

  attr_reader :website, :trace

  def normalize_event(event)
    return event if event.respond_to?(:website)

    PipelineEvent.new(event, website)
  end

  def build_row(event)
    return { event: event, status: build_status(event) } unless trace

    build_traced_row(event)
  end

  def build_status(event)
    status, _, _ = PipelineEvaluator.call(event: event)
    status
  rescue EvaluationError => e
    error_status(event, e.error)
  end

  def build_traced_row(event)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    error = nil

    begin
      status, metrics, rules = PipelineEvaluator.call(event: event)
    rescue EvaluationError => e
      status = error_status(event, e.error)
      metrics = e.metrics
      rules = e.rules
      error = {
        message: e.error.message,
        class: e.error.class.name
      }
    end

    {
      event: event,
      status: status,
      trace: {
        metrics: metrics,
        rules_applied: rules,
        duration_ms: duration_ms(start),
        error: error
      }
    }
  end

  def duration_ms(start)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    (elapsed * 1000).round(2)
  end

  def error_status(event, error)
    {
      event_id: event.respond_to?(:id) ? event.id : nil,
      status: :error,
      diagnosis: error.message
    }
  end
end
