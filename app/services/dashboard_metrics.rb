class DashboardMetrics
  DAMAGE_WEIGHTS = {
    problem: 10,
    not_publishable: 8,
    to_review: 6,
    stale: 4,
    overdue_archive: 5
  }.freeze

  ANOMALY_WEIGHTS = {
    "critical" => 4.0,
    "warning"  => 1.0
  }.freeze

  def initialize(website, helpers, condenser)
    @website = website
    @helpers = helpers
    @condenser = condenser
  end

  def compute
    seedurl = @website.url

    cache_key = cache_key_for(seedurl)

    Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
      compute_fresh(seedurl)
    end
  end

  private

  def compute_fresh(seedurl)
    raw = @helpers.condenser_get_website_events(seedurl) rescue []

    if raw.is_a?(Hash)
      events = Array(raw["events"])
      total_events = raw["total_events"] || events.size
    else
      events = Array(raw)
      total_events = events.size
    end

    anomaly = EventAnomalyEngine.new(events, @website).analyze
    overdue_days = events.map { |e| days_overdue(e) }

    {
      total_events: total_events,
      publishable_ratio: compute_publishable(events),
      health_score: compute_health(events, anomaly, overdue_days),
      anomaly_ratio: anomaly[:anomaly_ratio] || 0,
      systemic_flags: anomaly[:systemic_flags] || [],
      schedule_risk_level: schedule_risk(overdue_days),
      days_overdue: overdue_days.max || 0
    }
  end

  # def cache_key_for(seedurl)
  #   "dashboard_metrics:#{seedurl}"
  # end

  def cache_key_for(seedurl, start_date = nil, end_date = nil)
    "dashboard_metrics:#{seedurl}:#{start_date}:#{end_date}"
  end

  # -----------------------------
  # HEALTH
  # -----------------------------

  def compute_health(events, anomaly, overdue_days)
    damage_score   = damage_component(events)
    anomaly_score  = anomaly_component(anomaly)
    schedule_score = schedule_component(overdue_days)

    weighted =
      (0.6 * damage_score) +
      (0.3 * anomaly_score) +
      (0.1 * schedule_score)

    weighted.round(1)
  end

  # -----------------------------
  # PUBLISHABLE
  # -----------------------------

  def compute_publishable(events)
    return 0 if events.empty?

    publishable = events.count do |e|
      e.dig("statements_status", "publishable")
    end

    percentage(publishable, events.size)
  end

  # -----------------------------
  # ANOMALY
  # -----------------------------

  def anomaly_component(anomaly)
    100 - (anomaly[:anomaly_ratio] || 0).to_f
  end

  # -----------------------------
  # DAMAGE
  # -----------------------------

  def compute_damage(event)
    status = event["statements_status"] || {}
    damage = 0

    damage += DAMAGE_WEIGHTS[:problem] if status["problem"]
    damage += DAMAGE_WEIGHTS[:not_publishable] unless status["publishable"]
    damage += DAMAGE_WEIGHTS[:to_review] if status["to_review"]
    damage += DAMAGE_WEIGHTS[:stale] unless status["updated"]
    damage += DAMAGE_WEIGHTS[:overdue_archive] if overdue?(event)

    damage
  end

  def damage_component(events)
    return 100 if events.empty?

    total_damage = events.sum { |e| compute_damage(e) }
    max_damage = events.size * DAMAGE_WEIGHTS.values.sum

    return 100 if max_damage.zero?

    100 - ((total_damage.to_f / max_damage) * 100)
  end

  # -----------------------------
  # DATE HELPERS (Rails-safe)
  # -----------------------------

  def archived?(event)
    archive = parse_time(event["archive_date"])
    archive && archive < Time.zone.now
  end

  def overdue?(event)
    archived?(event)
  end

  def days_overdue(event)
    archive = parse_time(event["archive_date"])
    return 0 unless archive && archive < Time.zone.now

    (Time.zone.today - archive.to_date).to_i
  end

  def parse_time(value)
    return nil if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  # -----------------------------
  # SCHEDULE RISK
  # -----------------------------

  def schedule_component(days)
    max = days.max || 0

    if max <= 0
      100
    elsif max <= 3
      70
    else
      40
    end
  end

  def schedule_risk(days)
    max = days.max || 0

    if max <= 0
      :ok
    elsif max <= 3
      :warning
    else
      :critical
    end
  end

  # -----------------------------
  # UTILS
  # -----------------------------

  def percentage(val, total)
    return 0 if total.zero?

    ((val.to_f / total) * 100).round(1)
  end
end