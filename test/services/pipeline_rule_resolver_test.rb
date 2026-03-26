require "test_helper"
require "minitest/spec"

describe PipelineRuleResolver do
  it "uses website rules first" do
    PipelineRule.delete_all
    Website.where(url: "resolver-website-rules-first").delete_all
    User.where(email: "resolver-website-rules-first@example.com").delete_all

    user = User.create!(
      name: "Resolver Website Rules First",
      email: "resolver-website-rules-first@example.com",
      password: "password",
      password_confirmation: "password"
    )
    website = Website.create!(user: user, url: "resolver-website-rules-first")

    PipelineRule.create!(
      name: "Website rule B",
      website: website,
      active: true,
      position: 2,
      conditions: { "metric" => "needs_review" },
      status: "critical",
      diagnosis: "Website diagnosis B"
    )
    PipelineRule.create!(
      name: "Website rule A",
      website: website,
      active: true,
      position: 1,
      conditions: { "metric" => "publishable" },
      status: "warning",
      diagnosis: "Website diagnosis A"
    )
    PipelineRule.create!(
      name: "Global rule",
      website: nil,
      active: true,
      position: 0,
      conditions: { "metric" => "has_problem" },
      status: "ok",
      diagnosis: "Global diagnosis"
    )

    rules = PipelineRuleResolver.rules_for(website)

    _(rules).must_equal [
      {
        name: "Website rule A",
        conditions: { "metric" => "publishable" },
        status: "warning",
        diagnosis: "Website diagnosis A",
        position: 1,
        source: :database
      },
      {
        name: "Website rule B",
        conditions: { "metric" => "needs_review" },
        status: "critical",
        diagnosis: "Website diagnosis B",
        position: 2,
        source: :database
      }
    ]
  end

  it "uses global rules when website rules do not exist" do
    PipelineRule.delete_all
    Website.where(url: "resolver-global-fallback").delete_all
    User.where(email: "resolver-global-fallback@example.com").delete_all

    user = User.create!(
      name: "Resolver Global Fallback",
      email: "resolver-global-fallback@example.com",
      password: "password",
      password_confirmation: "password"
    )
    website = Website.create!(user: user, url: "resolver-global-fallback")

    PipelineRule.create!(
      name: "Global rule B",
      website: nil,
      active: true,
      position: 2,
      conditions: { "metric" => "has_problem" },
      status: "critical",
      diagnosis: "Global diagnosis B"
    )
    PipelineRule.create!(
      name: "Global rule A",
      website: nil,
      active: true,
      position: 1,
      conditions: { "metric" => "publishable" },
      status: "warning",
      diagnosis: "Global diagnosis A"
    )

    rules = PipelineRuleResolver.rules_for(website)

    _(rules).must_equal [
      {
        name: "Global rule A",
        conditions: { "metric" => "publishable" },
        status: "warning",
        diagnosis: "Global diagnosis A",
        position: 1,
        source: :database
      },
      {
        name: "Global rule B",
        conditions: { "metric" => "has_problem" },
        status: "critical",
        diagnosis: "Global diagnosis B",
        position: 2,
        source: :database
      }
    ]
  end

  it "uses YAML fallback when database rules do not exist" do
    PipelineRule.delete_all
    Website.where(url: "resolver-yaml-fallback").delete_all
    User.where(email: "resolver-yaml-fallback@example.com").delete_all

    user = User.create!(
      name: "Resolver YAML Fallback",
      email: "resolver-yaml-fallback@example.com",
      password: "password",
      password_confirmation: "password"
    )
    website = Website.create!(user: user, url: "resolver-yaml-fallback")

    rules = PipelineRuleResolver.rules_for(website)

    _(rules.first).must_equal(
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

  it "ignores inactive website rules" do
    PipelineRule.delete_all
    Website.where(url: "resolver-inactive-website-rule").delete_all
    User.where(email: "resolver-inactive-website-rule@example.com").delete_all

    user = User.create!(
      name: "Resolver Inactive Website Rule",
      email: "resolver-inactive-website-rule@example.com",
      password: "password",
      password_confirmation: "password"
    )
    website = Website.create!(user: user, url: "resolver-inactive-website-rule")

    PipelineRule.create!(
      name: "Inactive website rule",
      website: website,
      active: false,
      position: 1,
      conditions: { "metric" => "publishable" },
      status: "warning",
      diagnosis: "Inactive website diagnosis"
    )
    PipelineRule.create!(
      name: "Global rule",
      website: nil,
      active: true,
      position: 1,
      conditions: { "metric" => "has_problem" },
      status: "critical",
      diagnosis: "Global fallback diagnosis"
    )

    rules = PipelineRuleResolver.rules_for(website)

    _(rules).must_equal [
      {
        name: "Global rule",
        conditions: { "metric" => "has_problem" },
        status: "critical",
        diagnosis: "Global fallback diagnosis",
        position: 1,
        source: :database
      }
    ]
  end

  it "falls back to global rules when website is nil" do
    PipelineRule.delete_all
    PipelineRule.create!(
      name: "Global rule",
      website: nil,
      active: true,
      position: 1,
      conditions: { "metric" => "updated" },
      status: "warning",
      diagnosis: "Nil website diagnosis"
    )

    rules = PipelineRuleResolver.rules_for(nil)

    _(rules).must_equal [
      {
        name: "Global rule",
        conditions: { "metric" => "updated" },
        status: "warning",
        diagnosis: "Nil website diagnosis",
        position: 1,
        source: :database
      }
    ]
  end

  it "uses YAML fallback when only inactive global rules exist" do
    PipelineRule.delete_all
    Website.where(url: "resolver-inactive-global-fallback").delete_all
    User.where(email: "resolver-inactive-global-fallback@example.com").delete_all

    user = User.create!(
      name: "Resolver Inactive Global Fallback",
      email: "resolver-inactive-global-fallback@example.com",
      password: "password",
      password_confirmation: "password"
    )
    website = Website.create!(user: user, url: "resolver-inactive-global-fallback")

    PipelineRule.create!(
      name: "Inactive global rule",
      website: nil,
      active: false,
      position: 1,
      conditions: { "metric" => "updated" },
      status: "critical",
      diagnosis: "Inactive global diagnosis"
    )

    rules = PipelineRuleResolver.rules_for(website)

    _(rules.first).must_equal(
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
end
