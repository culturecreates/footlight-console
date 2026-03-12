# ======================================================================================================================
# File        : app/models/website_defaults.rb
# Project     : Footlight Console
# Component   : Monitoring / Dashboard Configuration
#
# Purpose
# -------
# Defines **system-wide default configuration values** used by event quality evaluation, ingestion monitoring,
# and dashboard health scoring.
#
# These defaults act as fallbacks whenever a Website instance does not define its own monitoring configuration.
# This avoids hardcoded constants across services and ensures monitoring behaviour remains consistent.
#
# Responsibilities
# ----------------
# • Provide default property importance weights for event completeness scoring
# • Define monitoring thresholds used by pipeline and data quality checks
# • Define default health component weighting used in dashboard scoring
#
# Dependencies
# ------------
# None (pure configuration model).
#
# Used By
# -------
# - Website model (effective_* configuration helpers)
# - MetricsInterpreter (pipeline monitoring logic)
# - DashboardMetrics (dashboard health scoring)
#
# ======================================================================================================================

class WebsiteDefaults


  # ====================================================================================================================
  # EVENT PROPERTY WEIGHTS
  #
  # Defines the relative importance of event fields when evaluating event completeness.
  #
  # Higher weights indicate fields that are critical for event usability.
  #
  # Example
  # -------
  # Missing a title is far more serious than missing a price.
  # ====================================================================================================================

  PROPERTY_WEIGHTS = {
    "title"       => 12,
    "dates"       => 12,
    "location"    => 12,
    "description" => 3,
    "image"       => 3,
    "price"       => 1
  }.freeze


  # ====================================================================================================================
  # TEMPORAL VALIDATION LIMITS
  #
  # Used to detect suspicious event dates that may indicate parsing errors.
  # ====================================================================================================================

  FAR_FUTURE_YEARS = 1
  OLD_PAST_YEARS   = 2


  # ====================================================================================================================
  # SYSTEMIC ANOMALY DETECTION
  #
  # If more than this proportion of statements contain the same anomaly,
  # the issue may indicate a systemic pipeline problem.
  # ====================================================================================================================

  SYSTEMIC_THRESHOLD = 0.2


  # ====================================================================================================================
  # DATA QUALITY THRESHOLDS
  #
  # Defines the minimum acceptable proportion of publishable events before
  # the dataset is considered unhealthy.
  # ====================================================================================================================

  MIN_PUBLISHABLE_RATIO = 0.6


  # ====================================================================================================================
  # PIPELINE FRESHNESS THRESHOLDS
  #
  # Determines when ingestion pipelines may be stalled.
  # ====================================================================================================================

  WARNING_DAYS_SINCE_LAST_WEBPAGE  = 30
  CRITICAL_DAYS_SINCE_LAST_WEBPAGE = 90


  # ====================================================================================================================
  # EVENT HORIZON THRESHOLDS
  #
  # Defines when absence of future events may indicate ingestion failure.
  # Negative values indicate the most recent event already passed.
  # ====================================================================================================================

  WARNING_EVENT_HORIZON_DAYS  = -30
  CRITICAL_EVENT_HORIZON_DAYS = -120


  # ====================================================================================================================
  # HEALTH COMPONENT WEIGHTS
  #
  # Determines the relative influence of major monitoring subsystems.
  # ====================================================================================================================

  HEALTH_COMPONENT_WEIGHTS = {
    "data_health"     => 10,
    "pipeline_health" => 10
  }.freeze


  # ====================================================================================================================
  # DASHBOARD HEALTH SIGNAL WEIGHTS
  #
  # Defines how individual monitoring signals influence the dashboard health score.
  # ====================================================================================================================

  DASHBOARD_HEALTH_WEIGHTS = {
    "publishable" => 10,
    "freshness"   => 8,
    "horizon"     => 6,
    "overdue"     => 4
  }.freeze

  # ====================================================================================================================
  # DASHBOARD DISPLAY NORMALIZATION
  #
  # Defines limits and transformations used when presenting monitoring values on the dashboard.
  #
  # These rules do not change the raw metrics; they only improve readability for users.
  #
  # Example
  # -------
  # 645 days since last webpage → display as ">365"
  # -280 horizon → display as "Past"
  # ====================================================================================================================

  MAX_DAYS_SINCE_WEBPAGE_DISPLAY = 365

  MIN_EVENT_HORIZON_DISPLAY = 0

  # ----------------------------------------------------------------------------------------------------------------------
  # weight_for
  #
  # Returns the importance weight assigned to a given event property.
  #
  # Parameters
  # ----------
  # prop : String or Symbol
  #   Event property name.
  #
  # Returns
  # -------
  # Integer
  #   Weight value used in completeness scoring.
  #
  # ----------------------------------------------------------------------------------------------------------------------
  def self.weight_for(prop)
    PROPERTY_WEIGHTS[prop.to_s] || 1
  end


  # ----------------------------------------------------------------------------------------------------------------------
  # health_weight_for
  #
  # Returns the weight assigned to a monitoring subsystem when computing global health.
  #
  # Parameters
  # ----------
  # key : String or Symbol
  #
  # Returns
  # -------
  # Integer
  #
  # ----------------------------------------------------------------------------------------------------------------------
  def self.health_weight_for(key)
    HEALTH_COMPONENT_WEIGHTS[key.to_s] || 1
  end


  # ----------------------------------------------------------------------------------------------------------------------
  # dashboard_weight_for
  #
  # Returns the weight assigned to an individual dashboard monitoring signal.
  #
  # Parameters
  # ----------
  # key : String or Symbol
  #
  # Returns
  # -------
  # Integer
  #
  # ----------------------------------------------------------------------------------------------------------------------
  def self.dashboard_weight_for(key)
    DASHBOARD_HEALTH_WEIGHTS[key.to_s] || 1
  end

  # --------------------------------------------------------------------------------------------------------------------
  # threshold
  #
  # Returns the effective monitoring threshold for a website.
  # If the user has defined a value it is used, otherwise the system default is returned.
  #
  # Parameters
  # ----------
  # website : Website
  # key     : Symbol
  #
  # Example
  # -------
  # threshold(website, :warning_days_since_last_webpage)
  #
  # --------------------------------------------------------------------------------------------------------------------
  def self.threshold(website, key)
    user_value = website&.send(key)
    return user_value if user_value.present?
    const_get(key.to_s.upcase)
  end

end