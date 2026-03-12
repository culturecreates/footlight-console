class AddAnomalySettingsToWebsites < ActiveRecord::Migration[6.1]
  def change
    add_column :websites, :far_future_years, :integer
    add_column :websites, :old_past_years, :integer
  end
end
