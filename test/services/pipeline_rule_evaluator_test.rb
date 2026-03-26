require "test_helper"
require "minitest/spec"

describe PipelineRuleEvaluator do
  it "supports boolean true comparisons" do
    rules = [
      {
        name: "problem_rule",
        conditions: {
          "metric" => "has_problem",
          "operator" => "eq",
          "value" => true
        },
        status: "critical",
        diagnosis: "Event has statement problems",
        position: 1
      }
    ]
    metrics = { "has_problem" => true }

    result = PipelineRuleEvaluator.evaluate(rules: rules, metrics: metrics)

    _(result).must_equal [
      {
        name: "problem_rule",
        status: "critical",
        diagnosis: "Event has statement problems",
        triggered: true
      }
    ]
  end

  it "supports boolean false comparisons with double equals" do
    rules = [
      {
        name: "publishable_rule",
        conditions: {
          "metric" => "publishable",
          "operator" => "==",
          "value" => false
        },
        status: "warning",
        diagnosis: "Event is not publishable",
        position: 1
      }
    ]
    metrics = { "publishable" => false }

    result = PipelineRuleEvaluator.evaluate(rules: rules, metrics: metrics)

    _(result.first[:triggered]).must_equal true
  end

  it "normalizes string booleans" do
    rules = [
      {
        name: "review_rule",
        conditions: {
          "metric" => "needs_review",
          "operator" => "eq",
          "value" => "true"
        },
        status: "warning",
        diagnosis: "Event needs statement review",
        position: 1
      }
    ]
    metrics = { "needs_review" => "true" }

    result = PipelineRuleEvaluator.evaluate(rules: rules, metrics: metrics)

    _(result).must_equal [
      {
        name: "review_rule",
        status: "warning",
        diagnosis: "Event needs statement review",
        triggered: true
      }
    ]
  end

  it "evaluates multiple rules independently and preserves order" do
    rules = [
      {
        name: "publishable_rule",
        conditions: {
          "metric" => "publishable",
          "operator" => "eq",
          "value" => false
        },
        status: "warning",
        diagnosis: "Event is not publishable",
        position: 1
      },
      {
        name: "problem_rule",
        conditions: {
          "metric" => "has_problem",
          "operator" => "eq",
          "value" => true
        },
        status: "critical",
        diagnosis: "Event has statement problems",
        position: 2
      }
    ]
    metrics = {
      "publishable" => false,
      "has_problem" => false
    }

    result = PipelineRuleEvaluator.evaluate(rules: rules, metrics: metrics)

    _(result).must_equal [
      {
        name: "publishable_rule",
        status: "warning",
        diagnosis: "Event is not publishable",
        triggered: true
      },
      {
        name: "problem_rule",
        status: "critical",
        diagnosis: "Event has statement problems",
        triggered: false
      }
    ]
  end

  it "flags invalid rule instead of skipping it" do
    rules = [
      {
        name: "invalid_rule",
        conditions: nil,
        status: "warning",
        diagnosis: "Invalid"
      }
    ]

    result = PipelineRuleEvaluator.evaluate(rules: rules, metrics: {})

    _(result.first[:triggered]).must_equal true
    _(result.first[:status]).must_equal "critical"
    _(result.first[:diagnosis]).must_equal "Invalid rule configuration"
    _(result.first[:error]).must_equal true
  end

  it "returns a non-triggering warning when a metric is missing" do
    rules = [
      {
        name: "missing_metric_rule",
        conditions: {
          "metric" => "updated",
          "operator" => "eq",
          "value" => true
        },
        status: "warning",
        diagnosis: "Should be replaced",
        position: 1
      }
    ]

    result = PipelineRuleEvaluator.evaluate(rules: rules, metrics: {})

    _(result).must_equal [
      {
        name: "missing_metric_rule",
        status: "warning",
        diagnosis: "Missing metric value: updated",
        triggered: false,
        missing_metric: true
      }
    ]
  end

  it "returns a non-triggering warning when a metric value is nil" do
    rules = [
      {
        name: "nil_metric_rule",
        conditions: {
          "metric" => "updated",
          "operator" => "eq",
          "value" => true
        },
        status: "warning",
        diagnosis: "Should be replaced",
        position: 1
      }
    ]
    metrics = { "updated" => nil }

    result = PipelineRuleEvaluator.evaluate(rules: rules, metrics: metrics)

    _(result).must_equal [
      {
        name: "nil_metric_rule",
        status: "warning",
        diagnosis: "Missing metric value: updated",
        triggered: false,
        missing_metric: true
      }
    ]
  end

  it "returns a warning for deprecated metrics and logs it" do
    rules = [
      {
        name: "legacy_rule",
        conditions: {
          "metric" => "condenser_failure_rate",
          "operator" => "gt",
          "value" => 0.5
        },
        status: "critical",
        diagnosis: "Legacy diagnosis",
        position: 1
      }
    ]
    metrics = { "condenser_failure_rate" => 0.9 }
    warnings = []

    result = nil
    Rails.logger.stub :warn, ->(message) { warnings << message } do
      result = PipelineRuleEvaluator.evaluate(rules: rules, metrics: metrics)
    end

    _(warnings).must_equal ["Deprecated metric used: condenser_failure_rate"]
    _(result).must_equal [
      {
        name: "legacy_rule",
        status: "warning",
        diagnosis: "Deprecated metric used: condenser_failure_rate",
        triggered: true,
        deprecated: true
      }
    ]
  end

  it "defaults a missing operator to eq" do
    rules = [
      {
        name: "default_eq_rule",
        conditions: {
          "metric" => "publishable",
          "value" => false
        },
        status: "warning",
        diagnosis: "Event is not publishable",
        position: 1
      }
    ]
    metrics = { "publishable" => false }

    result = PipelineRuleEvaluator.evaluate(rules: rules, metrics: metrics)

    _(result).must_equal [
      {
        name: "default_eq_rule",
        status: "warning",
        diagnosis: "Event is not publishable",
        triggered: true
      }
    ]
  end

  it "triggers the outdated rule when days_until_archive is negative" do
    rules = [
      {
        name: "event_outdated",
        conditions: {
          "metric" => "days_until_archive",
          "operator" => "lt",
          "value" => 0
        },
        status: "warning",
        diagnosis: "Event is outdated (archive date passed)",
        position: 4
      }
    ]
    metrics = { "days_until_archive" => -2 }

    result = PipelineRuleEvaluator.evaluate(rules: rules, metrics: metrics)

    _(result).must_equal [
      {
        name: "event_outdated",
        status: "warning",
        diagnosis: "Event is outdated (archive date passed)",
        triggered: true
      }
    ]
  end

  it "does not trigger the outdated rule when days_until_archive is missing" do
    rules = [
      {
        name: "event_outdated",
        conditions: {
          "metric" => "days_until_archive",
          "operator" => "lt",
          "value" => 0
        },
        status: "warning",
        diagnosis: "Event is outdated (archive date passed)",
        position: 4
      }
    ]
    metrics = { "days_until_archive" => nil }

    result = PipelineRuleEvaluator.evaluate(rules: rules, metrics: metrics)

    _(result).must_equal [
      {
        name: "event_outdated",
        status: "warning",
        diagnosis: "Missing metric value: days_until_archive",
        triggered: false,
        missing_metric: true
      }
    ]
  end

  it "triggers the stale rule when recently_updated is false" do
    rules = [
      {
        name: "event_stale",
        conditions: {
          "metric" => "recently_updated",
          "operator" => "eq",
          "value" => false
        },
        status: "warning",
        diagnosis: "Event has not been updated recently",
        position: 5
      }
    ]
    metrics = { "recently_updated" => false }

    result = PipelineRuleEvaluator.evaluate(rules: rules, metrics: metrics)

    _(result).must_equal [
      {
        name: "event_stale",
        status: "warning",
        diagnosis: "Event has not been updated recently",
        triggered: true
      }
    ]
  end
end
