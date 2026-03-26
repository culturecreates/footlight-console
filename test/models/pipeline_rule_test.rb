require "test_helper"
require "minitest/spec"

describe PipelineRule do
  it "can belong to a website" do
    # GIVEN
    PipelineRule.delete_all
    Website.where(url: "pipeline-rule-model-site").delete_all
    User.where(email: "pipeline-rule-model@example.com").delete_all

    user = User.create!(
      name: "Pipeline Rule Model",
      email: "pipeline-rule-model@example.com",
      password: "password",
      password_confirmation: "password"
    )
    website = Website.create!(user: user, url: "pipeline-rule-model-site")
    rule = PipelineRule.create!(
      name: "Website rule",
      website: website,
      active: true,
      position: 2,
      conditions: { "metric" => "publishable_ratio" },
      status: "warning",
      diagnosis: "Website-specific diagnosis"
    )

    # WHEN
    associated_website = rule.website

    # THEN
    _(associated_website).must_equal website
  end

  it "can be global when website_id is nil" do
    # GIVEN
    PipelineRule.delete_all
    rule = PipelineRule.new(
      name: "Global rule",
      website: nil,
      active: true,
      position: 1,
      conditions: { "metric" => "pipeline_health" },
      status: "ok",
      diagnosis: "Global diagnosis"
    )

    # WHEN
    valid = rule.valid?

    # THEN
    _(valid).must_equal true
    _(rule.website_id).must_be_nil
  end

  it "respects the active scope" do
    # GIVEN
    PipelineRule.delete_all
    PipelineRule.create!(
      name: "Active rule",
      active: true,
      position: 1,
      conditions: { "metric" => "pipeline_health" },
      status: "warning",
      diagnosis: "Active diagnosis"
    )
    PipelineRule.create!(
      name: "Inactive rule",
      active: false,
      position: 2,
      conditions: { "metric" => "publishable_ratio" },
      status: "critical",
      diagnosis: "Inactive diagnosis"
    )

    # WHEN
    active_rules = PipelineRule.active.to_a

    # THEN
    _(active_rules.map(&:name)).must_equal ["Active rule"]
  end

  it "respects ordering by position" do
    # GIVEN
    PipelineRule.delete_all
    PipelineRule.create!(
      name: "Second rule",
      active: true,
      position: 2,
      conditions: { "metric" => "event_horizon_days" },
      status: "critical",
      diagnosis: "Second diagnosis"
    )
    PipelineRule.create!(
      name: "First rule",
      active: true,
      position: 1,
      conditions: { "metric" => "publishable_ratio" },
      status: "warning",
      diagnosis: "First diagnosis"
    )

    # WHEN
    ordered_rules = PipelineRule.ordered.to_a

    # THEN
    _(ordered_rules.map(&:name)).must_equal ["First rule", "Second rule"]
  end

  it "is invalid without a name" do
    # GIVEN
    PipelineRule.delete_all
    rule = PipelineRule.new(
      name: nil,
      active: true,
      position: 1,
      conditions: { "metric" => "publishable_ratio" },
      status: "warning",
      diagnosis: "Missing name diagnosis"
    )

    # WHEN
    valid = rule.valid?

    # THEN
    _(valid).must_equal false
  end

  it "is invalid without a status" do
    # GIVEN
    PipelineRule.delete_all
    rule = PipelineRule.new(
      name: "Missing status",
      active: true,
      position: 1,
      conditions: { "metric" => "publishable_ratio" },
      status: nil,
      diagnosis: "Missing status diagnosis"
    )

    # WHEN
    valid = rule.valid?

    # THEN
    _(valid).must_equal false
  end

  it "is invalid without a diagnosis" do
    # GIVEN
    PipelineRule.delete_all
    rule = PipelineRule.new(
      name: "Missing diagnosis",
      active: true,
      position: 1,
      conditions: { "metric" => "publishable_ratio" },
      status: "warning",
      diagnosis: nil
    )

    # WHEN
    valid = rule.valid?

    # THEN
    _(valid).must_equal false
  end

  it "rejects invalid status values" do
    # GIVEN
    PipelineRule.delete_all
    rule = PipelineRule.new(
      name: "Invalid status",
      active: true,
      position: 1,
      conditions: { "metric" => "publishable_ratio" },
      status: "banana",
      diagnosis: "Invalid"
    )

    # WHEN
    valid = rule.valid?

    # THEN
    _(valid).must_equal false
  end

  it "is invalid when conditions are missing metric" do
    # GIVEN
    PipelineRule.delete_all
    rule = PipelineRule.new(
      name: "Bad conditions",
      active: true,
      position: 1,
      conditions: {},
      status: "warning",
      diagnosis: "Invalid"
    )

    # WHEN
    valid = rule.valid?

    # THEN
    _(valid).must_equal false
  end
end
