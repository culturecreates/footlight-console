class AddImageRatioToWebsite < ActiveRecord::Migration[5.1]
  def change
    add_column :websites, :image_ratio, :string
  end
end
