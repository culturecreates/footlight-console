class CreatePipelineRules < ActiveRecord::Migration[6.1]
  def change
    create_table :pipeline_rules do |t|
      t.references :website, null: true, foreign_key: true
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.json :conditions, null: false, default: {}
      t.json :actions, null: false, default: {}

      t.timestamps
    end

    add_index :pipeline_rules, [:website_id, :active, :position],
              name: "index_pipeline_rules_on_scope_activity_position"
  end
end
