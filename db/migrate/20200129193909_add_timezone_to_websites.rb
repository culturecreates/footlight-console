class AddTimezoneToWebsites < ActiveRecord::Migration[5.1]
  def change
    add_column :websites, :timezone, :string
  end
end
