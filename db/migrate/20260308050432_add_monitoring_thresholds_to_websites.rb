class AddMonitoringThresholdsToWebsites < ActiveRecord::Migration[6.1]
  def change
    add_column :websites, :min_publishable_ratio, :float
    add_column :websites, :warning_days_since_last_webpage, :integer
    add_column :websites, :critical_days_since_last_webpage, :integer
    add_column :websites, :warning_event_horizon_days, :integer
    add_column :websites, :critical_event_horizon_days, :integer
  end
end
