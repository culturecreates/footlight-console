class AddWeightOverridesToWebsites < ActiveRecord::Migration[6.1]
  def change
    add_column :websites, :weight_overrides, :jsonb, default: {}
  end
end