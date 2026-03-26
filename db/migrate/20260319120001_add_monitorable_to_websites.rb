class AddMonitorableToWebsites < ActiveRecord::Migration[6.1]
  def change
    add_column :websites, :monitorable, :boolean, null: false, default: true
  end
end
