class PipelineAggregateStatus
  HEALTHY_DIAGNOSIS = "No pipeline issues detected".freeze
  EMPTY_DIAGNOSIS = "No pipeline statuses available".freeze

  def self.call(rows:)
    new(rows).call
  end

  def initialize(rows)
    @rows = Array(rows)
  end

  def call
    counts = build_counts(rows)
    status = aggregate_status(counts)

    {
      status: status,
      diagnosis: diagnosis_for(status, counts),
      counts: counts
    }
  end

  private

  attr_reader :rows

  def build_counts(rows)
    rows.each_with_object(ok: 0, warning: 0, error: 0) do |row, counts|
      counts[normalized_status(row)] += 1
    end
  end

  def normalized_status(row)
    raw = row[:status]

    status =
      if raw.is_a?(Hash)
        raw[:status] || raw["status"]
      else
        raw
      end

    case status&.to_sym
    when :healthy, :ok then :ok
    when :degraded, :warning then :warning
    when :broken, :error then :error
    else :error
    end
  rescue
    :error
  end

  def aggregate_status(counts)
    return :degraded if rows.empty?
    return :broken if counts[:error].positive?
    return :degraded if counts[:warning].positive?

    :healthy
  end

  def diagnosis_for(status, counts)
    total = counts.values.sum

    case status
    when :broken
      "#{counts[:error]} of #{total} events have errors"
    when :degraded
      return EMPTY_DIAGNOSIS if total.zero?

      "#{counts[:warning]} of #{total} events have warnings"
    else
      HEALTHY_DIAGNOSIS
    end
  end
end
