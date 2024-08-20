class AddStatementIdToMicroposts < ActiveRecord::Migration[5.1]
  def change
    add_column :microposts, :related_statement_id, :integer
    add_column :microposts, :related_statement_property, :string
    add_column :microposts, :related_statement_language, :string
    add_column :microposts, :related_subject_uri, :string
  end
end
