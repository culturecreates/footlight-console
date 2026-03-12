class EventAnomalyEngine

  FLAG_WEIGHTS = {
    archive_before_date: 4,
    missing_archive_date: 3,
    invalid_date_format: 4,
    far_future_date: 1,
    very_old_event: 1,
    malformed_price: 1,
    duplicate_title_cluster: 2
  }.freeze

  def initialize(events, website)
    @events = events || []
    @website = website
  end

  def analyze
    per_event_damage = {}
    flag_counts = Hash.new(0)

    @events.each do |event|
      flags = analyze_event(event)
      next if flags.empty?

      damage = flags.sum { |f| FLAG_WEIGHTS[f] || 1 }

      per_event_damage[event["rdf_uri"]] = damage
      flags.each { |f| flag_counts[f] += 1 }
    end

    total = @events.size
    total_damage = per_event_damage.values.sum
    max_possible = total * FLAG_WEIGHTS.values.sum

    ratio =
      if max_possible.zero?
        0
      else
        total_damage.to_f / max_possible
      end

    {
      total_events: total,
      anomaly_ratio: (ratio * 100).round(1),
      anomalies_by_type: flag_counts,
      systemic_flags: systemic_flags(flag_counts, total),
      per_event_damage: per_event_damage
    }
  end

  private

  def analyze_event(event)
    flags = []
    now = Time.zone.now.beginning_of_day

    date = parse_date(event["date"])
    archive = parse_date(event["archive_date"])

    flags << :missing_archive_date if archive.nil?

    if date && archive && archive < date
      flags << :archive_before_date
    end

    if date && date > now + @website.effective_far_future_years.years
      flags << :far_future_date
    end

    if date && date < now - @website.effective_far_future_years.years
      flags << :very_old_event
    end

    flags
  end

  def parse_date(value)
    return nil if value.blank?
    Time.zone.parse(value.to_s)
  rescue
    nil
  end

  def systemic_flags(counts, total)
    counts.select { |_k, v| v > total * 0.2 }.keys
  end
end