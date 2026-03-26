require "test_helper"
require "minitest/spec"
require "tempfile"

describe PipelineRuleYamlLoader do
  it "loads config/pipeline_rules.yml" do
    path = Rails.root.join("config/pipeline_rules.yml")

    rules = PipelineRuleYamlLoader.load(path: path)

    _(rules.map { |rule| rule[:name] }).must_equal [
      "event_has_problem",
      "event_needs_review",
      "event_not_publishable",
      "event_outdated",
      "event_stale"
    ]
  end

  it "returns structured rules with status and diagnosis" do
    path = Rails.root.join("config/pipeline_rules.yml")

    first_rule = PipelineRuleYamlLoader.load(path: path).first

    _(first_rule).must_equal(
      {
        name: "event_has_problem",
        conditions: {
          "metric" => "has_problem",
          "operator" => "eq",
          "value" => true
        },
        status: "critical",
        diagnosis: "Event has statement problems",
        position: 1,
        source: :yaml
      }
    )
  end

  it "loads the appended freshness and activity rules" do
    path = Rails.root.join("config/pipeline_rules.yml")

    rules = PipelineRuleYamlLoader.load(path: path)

    _(rules.last(2)).must_equal [
      {
        name: "event_outdated",
        conditions: {
          "metric" => "days_until_archive",
          "operator" => "lt",
          "value" => 0
        },
        status: "warning",
        diagnosis: "Event is outdated (archive date passed)",
        position: 4,
        source: :yaml
      },
      {
        name: "event_stale",
        conditions: {
          "metric" => "recently_updated",
          "operator" => "eq",
          "value" => false
        },
        status: "warning",
        diagnosis: "Event has not been updated recently",
        position: 5,
        source: :yaml
      }
    ]
  end

  it "assigns fallback position when YAML omits it" do
    file = Tempfile.new(["pipeline_rules", ".yml"])
    file.write(<<~YAML)
      rules:
        - name: fallback_rule
          conditions:
            metric: publishable
          status: warning
          diagnosis: Fallback position diagnosis
    YAML
    file.close

    rules = PipelineRuleYamlLoader.load(path: file.path)

    _(rules).must_equal [
      {
        name: "fallback_rule",
        conditions: { "metric" => "publishable" },
        status: "warning",
        diagnosis: "Fallback position diagnosis",
        position: 1,
        source: :yaml
      }
    ]
  ensure
    file.unlink
  end

  it "ignores YAML rules missing a diagnosis" do
    file = Tempfile.new(["pipeline_rules", ".yml"])
    file.write(<<~YAML)
      rules:
        - name: incomplete_rule
          conditions:
            metric: publishable
          status: warning
        - name: complete_rule
          conditions:
            metric: has_problem
          status: critical
          diagnosis: Complete diagnosis
    YAML
    file.close

    rules = PipelineRuleYamlLoader.load(path: file.path)

    _(rules).must_equal [
      {
        name: "complete_rule",
        conditions: { "metric" => "has_problem" },
        status: "critical",
        diagnosis: "Complete diagnosis",
        position: 2,
        source: :yaml
      }
    ]
  ensure
    file.unlink
  end

  it "ignores YAML rules with invalid status safely" do
    file = Tempfile.new(["pipeline_rules", ".yml"])
    file.write(<<~YAML)
      rules:
        - name: invalid_status_rule
          conditions:
            metric: publishable
          status: banana
          diagnosis: Bad status diagnosis
        - name: valid_status_rule
          conditions:
            metric: has_problem
          status: critical
          diagnosis: Valid status diagnosis
    YAML
    file.close

    rules = PipelineRuleYamlLoader.load(path: file.path)

    _(rules).must_equal [
      {
        name: "valid_status_rule",
        conditions: { "metric" => "has_problem" },
        status: "critical",
        diagnosis: "Valid status diagnosis",
        position: 2,
        source: :yaml
      }
    ]
  ensure
    file.unlink
  end

  it "ignores YAML rules missing metric safely" do
    file = Tempfile.new(["pipeline_rules", ".yml"])
    file.write(<<~YAML)
      rules:
        - name: missing_metric_rule
          conditions: {}
          status: warning
          diagnosis: Missing metric diagnosis
        - name: complete_rule
          conditions:
            metric: updated
          status: ok
          diagnosis: Complete diagnosis
    YAML
    file.close

    rules = PipelineRuleYamlLoader.load(path: file.path)

    _(rules).must_equal [
      {
        name: "complete_rule",
        conditions: { "metric" => "updated" },
        status: "ok",
        diagnosis: "Complete diagnosis",
        position: 2,
        source: :yaml
      }
    ]
  ensure
    file.unlink
  end

  it "handles empty YAML safely" do
    file = Tempfile.new(["pipeline_rules", ".yml"])
    file.write("")
    file.close

    rules = PipelineRuleYamlLoader.load(path: file.path)

    _(rules).must_equal []
  ensure
    file.unlink
  end

  it "handles invalid YAML input safely" do
    file = Tempfile.new(["pipeline_rules", ".yml"])
    file.write("rules: invalid")
    file.close

    rules = PipelineRuleYamlLoader.load(path: file.path)

    _(rules).must_equal []
  ensure
    file.unlink
  end
end
