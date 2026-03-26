class PipelineMetricsBuilder
  METRICS = [
    :publishable,
    :has_problem,
    :needs_review,
    :updated,
    :archive_date,
    :days_until_archive,
    :recently_updated
  ].freeze

  REQUIRED_BOOLEAN_METRICS = [
    :publishable,
    :has_problem,
    :needs_review,
    :updated
  ].freeze

  def self.call(event:)
    new(event).call
  end

  def initialize(event)
    @event = event
  end

  def call
    return default_metrics if event.nil?

    statements_status = normalize_hash(read_value(:statements_status))
    updated = boolean_value(statements_status["updated"])
    archive_date = safely_parsed_date(read_value(:archive_date))

    {
      publishable: boolean_value(statements_status["publishable"]),
      has_problem: boolean_value(statements_status["problem"]),
      needs_review: boolean_value(statements_status["to_review"]),
      updated: updated,
      archive_date: archive_date,
      days_until_archive: days_until_archive(archive_date),
      recently_updated: updated == true
    }
  end

  private

  attr_reader :event

  def read_value(name)
    return event.public_send(name) if event.respond_to?(name)
    return nil unless event.respond_to?(:[])

    return event[name] if event.key?(name)
    return event[name.to_s] if event.key?(name.to_s)

    nil
  end

  def normalize_hash(value)
    value.is_a?(Hash) ? value.deep_stringify_keys : {}
  end

  def boolean_value(value)
    return true if value == true || value.to_s.casecmp("true").zero?
    return false if value == false || value.to_s.casecmp("false").zero?

    nil
  end

  def safely_parsed_date(value)
    Date.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def days_until_archive(value)
    return nil if value.nil?

    (value.to_date - Date.today).to_i
  rescue StandardError
    nil
  end

  def default_metrics
    {
      publishable: nil,
      has_problem: nil,
      needs_review: nil,
      updated: nil,
      archive_date: nil,
      days_until_archive: nil,
      recently_updated: false
    }
  end
end
