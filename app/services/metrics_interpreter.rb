# ======================================================================================================================
# File        : app/services/metrics_interpreter.rb
# Project     : Footlight Console
# Component   : Monitoring / Dashboard Metrics
#
# Purpose
# -------
# Interprets raw monitoring metrics returned by Condenser and converts them into normalized dashboard metrics.
#
# Responsibilities
# ----------------
# • Extract metrics for a website
# • Compute pipeline freshness status
# • Normalize extreme values for dashboard display
# • Produce a metrics hash consumed by DashboardBuilder and dashboard views
# ======================================================================================================================

class MetricsInterpreter

  # --------------------------------------------------------------------------------------------------------------------
  # initialize
  #
  # condenser_metrics  : Hash keyed by seedurl containing raw metrics
  # condenser_websites : Optional metadata returned by Condenser
  # --------------------------------------------------------------------------------------------------------------------

  def initialize(condenser_metrics, condenser_websites)
    @metrics  = condenser_metrics  || {}
    @websites = condenser_websites || []
  end


  # --------------------------------------------------------------------------------------------------------------------
  # pipeline_health
  #
  # Computes pipeline freshness score based on the number of days since a new webpage was discovered.
  #
  # Returns
  # -------
  # 100 → healthy
  # 50  → warning
  # 0   → critical
  # --------------------------------------------------------------------------------------------------------------------

  def pipeline_health(days_since_last_webpage, website)

    warning  = WebsiteDefaults.threshold(website, :warning_days_since_last_webpage)
    critical = WebsiteDefaults.threshold(website, :critical_days_since_last_webpage)

    return 100 if days_since_last_webpage.nil?

    return 0  if critical > 0 && days_since_last_webpage >= critical
    return 50 if warning  > 0 && days_since_last_webpage >= warning

    100
  end


  # --------------------------------------------------------------------------------------------------------------------
  # health_score
  #
  # Computes data health score. Currently equivalent to publishable ratio.
  # Returns nil if the website has no webpages.
  # --------------------------------------------------------------------------------------------------------------------

  def health_score(raw)

    publishable_ratio = raw["publishable_ratio"]&.to_f
    total_webpages    = raw["total_webpages"].to_i

    return nil if total_webpages.zero?

    publishable_ratio
  end


  # ====================================================================================================================
  # NORMALIZATION HELPERS
  # ====================================================================================================================


  # --------------------------------------------------------------------------------------------------------------------
  # normalize_days_since_last_webpage
  #
  # Converts a raw freshness metric into a dashboard-friendly label.
  # Example: 645 → ">365"
  # --------------------------------------------------------------------------------------------------------------------

  def normalize_days_since_last_webpage(days)

    return nil if days.nil?

    max = WebsiteDefaults::MAX_DAYS_SINCE_WEBPAGE_DISPLAY

    return ">#{max}" if days > max

    days
  end


  # --------------------------------------------------------------------------------------------------------------------
  # normalize_event_horizon
  #
  # Converts raw event horizon values into a readable dashboard label.
  # Example: -280 → "Past"
  # --------------------------------------------------------------------------------------------------------------------

  def normalize_event_horizon(days)

    return nil if days.nil?

    min = WebsiteDefaults::MIN_EVENT_HORIZON_DISPLAY

    return "Past" if days < min

    days
  end


  # ====================================================================================================================
  # METRICS INTERPRETATION
  # ====================================================================================================================


  # --------------------------------------------------------------------------------------------------------------------
  # metrics_for
  #
  # Extracts and computes normalized monitoring metrics for a specific website.
  #
  # seedurl : String
  # website : Website
  #
  # Returns
  # -------
  # Hash containing dashboard-ready metrics.
  # --------------------------------------------------------------------------------------------------------------------

  def metrics_for(seedurl, website)

    raw = @metrics[seedurl] || {}

    total_webpages    = raw["total_webpages"].to_i
    publishable_ratio = raw["publishable_ratio"]&.to_f
    days_overdue      = raw["days_overdue"].to_i
    event_horizon_raw = raw["event_horizon_days"].to_i


    last_webpage_created_at =
      begin
        value = raw["last_webpage_created_at"]
        value.present? ? Time.zone.parse(value.to_s) : nil
      rescue StandardError
        nil
      end


    # ------------------------------------------------------------------------------------------------------------------
    # Compute raw freshness metric
    # ------------------------------------------------------------------------------------------------------------------

    days_since_last_webpage =
      if last_webpage_created_at
        (Time.zone.today - last_webpage_created_at.to_date).to_i
      end


    # ------------------------------------------------------------------------------------------------------------------
    # Display-normalized values
    # ------------------------------------------------------------------------------------------------------------------

    days_since_last_webpage_label =
      normalize_days_since_last_webpage(days_since_last_webpage)

    event_horizon_label =
      normalize_event_horizon(event_horizon_raw)


    # ------------------------------------------------------------------------------------------------------------------
    # Pipeline health evaluation
    # ------------------------------------------------------------------------------------------------------------------

    pipeline_health_score =
      pipeline_health(days_since_last_webpage, website)

    warning =
      WebsiteDefaults.threshold(website, :warning_days_since_last_webpage)

    pipeline_warning =
      days_since_last_webpage.present? &&
      warning.present? &&
      days_since_last_webpage >= warning


    # ------------------------------------------------------------------------------------------------------------------
    # Publishable ratio undefined when no webpages exist
    # ------------------------------------------------------------------------------------------------------------------

    publishable_ratio = nil if total_webpages.zero?


    {
      total_webpages: total_webpages,
      publishable_ratio: publishable_ratio,

      days_overdue: days_overdue,

      event_horizon_days: event_horizon_raw,
      event_horizon_label: event_horizon_label,

      days_since_last_webpage: days_since_last_webpage,
      days_since_last_webpage_label: days_since_last_webpage_label,

      pipeline_health: pipeline_health_score,
      pipeline_warning: pipeline_warning,

      health_score: health_score(raw)
    }

  end

end