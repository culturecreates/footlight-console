class AddIframeToWebsite < ActiveRecord::Migration[5.1]
  def change
    add_column :websites, :iframe, :boolean, default: true
  end
end
