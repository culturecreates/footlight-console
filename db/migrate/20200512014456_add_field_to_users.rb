class AddFieldToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :login_at, :datetime
  end
end
