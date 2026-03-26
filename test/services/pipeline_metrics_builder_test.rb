require "test_helper"
require "minitest/spec"

describe PipelineMetricsBuilder do
  PipelineMetricsBuilderEvent = Struct.new(:id, :website, :statements_status, :archive_date)

  it "returns the expected metric structure" do
    event = PipelineMetricsBuilderEvent.new(
      1,
      Object.new,
      {
        "publishable" => true,
        "problem" => false,
        "to_review" => false,
        "updated" => true
      },
      "2026-03-20"
    )

    result = PipelineMetricsBuilder.call(event: event)

    _(result.keys).must_equal [
      :publishable,
      :has_problem,
      :needs_review,
      :updated,
      :archive_date,
      :days_until_archive,
      :recently_updated
    ]
  end

  it "extracts real event metrics and parses archive_date" do
    event = PipelineMetricsBuilderEvent.new(
      1,
      Object.new,
      {
        "publishable" => true,
        "problem" => false,
        "to_review" => true,
        "updated" => false
      },
      "2026-03-20"
    )

    result = nil
    Date.stub :today, Date.new(2026, 3, 18) do
      result = PipelineMetricsBuilder.call(event: event)
    end

    _(result).must_equal(
      publishable: true,
      has_problem: false,
      needs_review: true,
      updated: false,
      archive_date: Date.new(2026, 3, 20),
      days_until_archive: 2,
      recently_updated: false
    )
  end

  it "returns positive days_until_archive for a future archive_date" do
    event = PipelineMetricsBuilderEvent.new(
      1,
      Object.new,
      { "updated" => true },
      "2026-03-25"
    )

    result = nil
    Date.stub :today, Date.new(2026, 3, 20) do
      result = PipelineMetricsBuilder.call(event: event)
    end

    _(result[:days_until_archive]).must_equal 5
  end

  it "returns negative days_until_archive for a past archive_date" do
    event = PipelineMetricsBuilderEvent.new(
      1,
      Object.new,
      { "updated" => true },
      "2026-03-18"
    )

    result = nil
    Date.stub :today, Date.new(2026, 3, 20) do
      result = PipelineMetricsBuilder.call(event: event)
    end

    _(result[:days_until_archive]).must_equal(-2)
  end

  it "returns nil days_until_archive when archive_date is missing" do
    event = PipelineMetricsBuilderEvent.new(
      1,
      Object.new,
      { "updated" => true },
      nil
    )

    result = PipelineMetricsBuilder.call(event: event)

    _(result[:archive_date]).must_be_nil
    _(result[:days_until_archive]).must_be_nil
  end

  it "returns nil for an invalid archive_date" do
    event = PipelineMetricsBuilderEvent.new(
      1,
      Object.new,
      {
        "publishable" => true,
        "problem" => false,
        "to_review" => false,
        "updated" => true
      },
      "not-a-date"
    )

    result = PipelineMetricsBuilder.call(event: event)

    _(result[:archive_date]).must_be_nil
    _(result[:days_until_archive]).must_be_nil
  end

  it "supports symbol keyed statements_status values" do
    event = PipelineMetricsBuilderEvent.new(
      1,
      Object.new,
      {
        publishable: false,
        problem: true,
        to_review: false,
        updated: true
      },
      nil
    )

    result = PipelineMetricsBuilder.call(event: event)

    _(result[:publishable]).must_equal false
    _(result[:has_problem]).must_equal true
    _(result[:needs_review]).must_equal false
    _(result[:updated]).must_equal true
    _(result[:recently_updated]).must_equal true
  end

  it "sets recently_updated false when updated is false" do
    event = PipelineMetricsBuilderEvent.new(
      1,
      Object.new,
      { "updated" => false },
      nil
    )

    result = PipelineMetricsBuilder.call(event: event)

    _(result[:updated]).must_equal false
    _(result[:recently_updated]).must_equal false
  end

  it "handles missing statements_status safely" do
    event = PipelineMetricsBuilderEvent.new(1, Object.new, nil, "2026-03-20")

    result = nil
    Date.stub :today, Date.new(2026, 3, 18) do
      result = PipelineMetricsBuilder.call(event: event)
    end

    _(result[:publishable]).must_be_nil
    _(result[:has_problem]).must_be_nil
    _(result[:needs_review]).must_be_nil
    _(result[:updated]).must_be_nil
    _(result[:archive_date]).must_equal Date.new(2026, 3, 20)
    _(result[:days_until_archive]).must_equal 2
    _(result[:recently_updated]).must_equal false
  end

  it "handles a nil event safely" do
    result = PipelineMetricsBuilder.call(event: nil)

    _(result).must_equal(
      publishable: nil,
      has_problem: nil,
      needs_review: nil,
      updated: nil,
      archive_date: nil,
      days_until_archive: nil,
      recently_updated: false
    )
  end
end
