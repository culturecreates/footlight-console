require "test_helper"
require "minitest/spec"

describe PipelineStatusInterpreter do
  it "uses website-specific rules before global and YAML rules" do
    PipelineRule.delete_all

    website = create_website("interpreter-website-priority")
    PipelineRule.create!(
      name: "Website rule",
      website: website,
      active: true,
      position: 1,
      conditions: { "metric" => "has_problem", "operator" => "eq", "value" => true },
      status: "critical",
      diagnosis: "Event has statement problems"
    )
    PipelineRule.create!(
      name: "Global rule",
      website: nil,
      active: true,
      position: 1,
      conditions: { "metric" => "publishable", "operator" => "eq", "value" => false },
      status: "warning",
      diagnosis: "Global rule should not win"
    )

    result = PipelineStatusInterpreter.call(
      website: website,
      metrics: metrics("has_problem" => true, "publishable" => false)
    )

    _(result).must_equal(
      status: :error,
      diagnosis: "Event has statement problems"
    )
  end

  it "falls back to global rules when website-specific rules do not exist" do
    PipelineRule.delete_all

    website = create_website("interpreter-global-fallback")
    PipelineRule.create!(
      name: "Global warning",
      website: nil,
      active: true,
      position: 1,
      conditions: { "metric" => "publishable", "operator" => "eq", "value" => false },
      status: "warning",
      diagnosis: "Event is not publishable"
    )

    result = PipelineStatusInterpreter.call(
      website: website,
      metrics: metrics("publishable" => false)
    )

    _(result).must_equal(
      status: :warning,
      diagnosis: "Event is not publishable"
    )
  end

  it "falls back to YAML rules when database rules do not exist" do
    PipelineRule.delete_all

    website = create_website("interpreter-yaml-fallback")

    result = PipelineStatusInterpreter.call(
      website: website,
      metrics: metrics("needs_review" => true)
    )

    _(result).must_equal(
      status: :warning,
      diagnosis: "Event needs statement review"
    )
  end

  it "returns the first triggered rule when multiple rules match" do
    PipelineRule.delete_all

    website = create_website("interpreter-first-match")
    PipelineRule.create!(
      name: "First warning",
      website: website,
      active: true,
      position: 1,
      conditions: { "metric" => "publishable", "operator" => "eq", "value" => false },
      status: "warning",
      diagnosis: "First diagnosis"
    )
    PipelineRule.create!(
      name: "Second critical",
      website: website,
      active: true,
      position: 2,
      conditions: { "metric" => "publishable", "operator" => "eq", "value" => false },
      status: "critical",
      diagnosis: "Second diagnosis"
    )

    result = PipelineStatusInterpreter.call(
      website: website,
      metrics: metrics("publishable" => false)
    )

    _(result).must_equal(
      status: :warning,
      diagnosis: "First diagnosis"
    )
  end

  it "returns an ok default when no rule matches" do
    PipelineRule.delete_all

    website = create_website("interpreter-ok-default")
    PipelineRule.create!(
      name: "Global critical",
      website: nil,
      active: true,
      position: 1,
      conditions: { "metric" => "has_problem", "operator" => "eq", "value" => true },
      status: "critical",
      diagnosis: "Should not trigger"
    )

    result = PipelineStatusInterpreter.call(
      website: website,
      metrics: metrics
    )

    _(result).must_equal(
      status: :ok,
      diagnosis: "No pipeline issues detected"
    )
  end

  it "returns a status symbol and diagnosis string" do
    PipelineRule.delete_all

    website = create_website("interpreter-result-shape")
    PipelineRule.create!(
      name: "Global ok",
      website: nil,
      active: true,
      position: 1,
      conditions: { "metric" => "updated", "operator" => "eq", "value" => true },
      status: "ok",
      diagnosis: "Pipeline is stable"
    )

    result = PipelineStatusInterpreter.call(
      website: website,
      metrics: metrics
    )

    _(result[:status]).must_equal :ok
    _(result[:status]).must_be_instance_of Symbol
    _(result[:diagnosis]).must_equal "Pipeline is stable"
    _(result[:diagnosis]).must_be_instance_of String
  end

  it "supports a nil website by falling back to global rules" do
    PipelineRule.delete_all
    PipelineRule.create!(
      name: "Global critical",
      website: nil,
      active: true,
      position: 1,
      conditions: { "metric" => "has_problem", "operator" => "eq", "value" => true },
      status: "critical",
      diagnosis: "Event has statement problems"
    )

    result = PipelineStatusInterpreter.call(
      website: nil,
      metrics: metrics("has_problem" => true)
    )

    _(result).must_equal(
      status: :error,
      diagnosis: "Event has statement problems"
    )
  end

  it "uses provided rules instead of resolving them" do
    website = create_website("interpreter-provided-rules")
    rules = [
      {
        name: "Provided rule",
        conditions: {
          "metric" => "publishable",
          "operator" => "eq",
          "value" => false
        },
        status: "critical",
        diagnosis: "Provided diagnosis"
      }
    ]

    result = nil
    PipelineRuleResolver.stub :rules_for, ->(_website) { raise "should not resolve rules" } do
      result = PipelineStatusInterpreter.call(
        website: website,
        metrics: metrics("publishable" => false),
        rules: rules
      )
    end

    _(result).must_equal(
      status: :error,
      diagnosis: "Provided diagnosis"
    )
  end

  it "does not default unknown statuses to ok" do
    website = create_website("interpreter-unknown-status")
    rules = [
      {
        name: "Unknown rule",
        conditions: {
          "metric" => "publishable",
          "operator" => "eq",
          "value" => false
        },
        status: "banana",
        diagnosis: "Unknown status"
      }
    ]

    result = PipelineStatusInterpreter.call(
      website: website,
      metrics: metrics("publishable" => false),
      rules: rules
    )

    _(result).must_equal(
      status: :error,
      diagnosis: "Unknown status"
    )
  end

  def metrics(overrides = {})
    {
      "publishable" => true,
      "has_problem" => false,
      "needs_review" => false,
      "updated" => true
    }.merge(overrides)
  end

  def create_website(slug)
    Website.where(url: slug).delete_all
    User.where(email: "#{slug}@example.com").delete_all

    user = User.create!(
      name: slug.tr("-", " ").capitalize,
      email: "#{slug}@example.com",
      password: "password",
      password_confirmation: "password"
    )

    Website.create!(user: user, url: slug)
  end
end
