class AlignPipelineRulesStatusAndDiagnosis < ActiveRecord::Migration[6.1]
  class MigrationPipelineRule < ActiveRecord::Base
    self.table_name = "pipeline_rules"
  end

  def up
    add_column :pipeline_rules, :status, :string
    add_column :pipeline_rules, :diagnosis, :string

    MigrationPipelineRule.reset_column_information

    MigrationPipelineRule.find_each do |rule|
      actions = rule[:actions].is_a?(Hash) ? rule[:actions] : {}

      rule.update_columns(
        status: actions["severity"] || actions[:severity] || "warning",
        diagnosis: actions["label"] || actions[:label] || rule.name
      )
    end

    change_column_null :pipeline_rules, :status, false
    change_column_null :pipeline_rules, :diagnosis, false

    remove_column :pipeline_rules, :actions, :json
  end

  def down
    add_column :pipeline_rules, :actions, :json, null: false, default: {}

    MigrationPipelineRule.reset_column_information

    MigrationPipelineRule.find_each do |rule|
      rule.update_columns(
        actions: {
          "severity" => rule[:status],
          "label" => rule[:diagnosis]
        }
      )
    end

    remove_column :pipeline_rules, :status, :string
    remove_column :pipeline_rules, :diagnosis, :string
  end
end
