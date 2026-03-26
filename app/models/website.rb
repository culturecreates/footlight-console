class Website < ApplicationRecord
  belongs_to :user
  has_many :pipeline_rules, dependent: :destroy

  validates :url, presence: true
  before_validation :normalize_url

  # ----------------------------------
  # Effective thresholds
  # ----------------------------------

  def effective_far_future_years
    self[:far_future_years] || WebsiteDefaults::FAR_FUTURE_YEARS
  end

  def effective_old_past_years
    self[:old_past_years] || WebsiteDefaults::OLD_PAST_YEARS
  end

  # Monitoring thresholds used by DashboardBuilder
  def effective_min_publishable_ratio
    self[:min_publishable_ratio] ||
      WebsiteDefaults::MIN_PUBLISHABLE_RATIO
  end

  def effective_warning_days_since_last_webpage
    self[:warning_days_since_last_webpage] ||
      WebsiteDefaults::WARNING_DAYS_SINCE_LAST_WEBPAGE
  end

  def effective_critical_days_since_last_webpage
    self[:critical_days_since_last_webpage] ||
      WebsiteDefaults::CRITICAL_DAYS_SINCE_LAST_WEBPAGE
  end

  def effective_warning_event_horizon_days
    self[:warning_event_horizon_days] ||
      WebsiteDefaults::WARNING_EVENT_HORIZON_DAYS
  end

  def effective_critical_event_horizon_days
    self[:critical_event_horizon_days] ||
      WebsiteDefaults::CRITICAL_EVENT_HORIZON_DAYS
  end

  # ----------------------------------
  # Property weight resolution
  # ----------------------------------

  def weight_for(prop)
    weight_overrides&.[](prop.to_s) ||
      WebsiteDefaults.weight_for(prop)
  end

  private

  def normalize_url
    self.url = SourceIdentity.from_url(url).to_seedurl
  end
end
