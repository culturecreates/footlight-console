require "test_helper"
require "minitest/spec"

describe PipelineAggregateStatus do
  it "returns degraded with zero counts when there are no pipeline rows" do
    rows = []

    result = PipelineAggregateStatus.call(rows: rows)

    _(result).must_equal(
      status: :degraded,
      diagnosis: "No pipeline statuses available",
      counts: {
        ok: 0,
        warning: 0,
        error: 0
      }
    )
  end

  it "returns healthy when all pipeline rows are ok" do
    rows = [pipeline_row(:ok), pipeline_row(:ok), pipeline_row(:ok)]

    result = PipelineAggregateStatus.call(rows: rows)

    _(result).must_equal(
      status: :healthy,
      diagnosis: "No pipeline issues detected",
      counts: {
        ok: 3,
        warning: 0,
        error: 0
      }
    )
  end

  it "returns degraded when at least one row is warning and none are errors" do
    rows = [pipeline_row(:ok), pipeline_row(:warning), pipeline_row(:ok)]

    result = PipelineAggregateStatus.call(rows: rows)

    _(result).must_equal(
      status: :degraded,
      diagnosis: "1 of 3 events have warnings",
      counts: {
        ok: 2,
        warning: 1,
        error: 0
      }
    )
  end

  it "returns broken when any row is error" do
    rows = [pipeline_row(:ok), pipeline_row(:warning), pipeline_row(:error)]

    result = PipelineAggregateStatus.call(rows: rows)

    _(result).must_equal(
      status: :broken,
      diagnosis: "1 of 3 events have errors",
      counts: {
        ok: 1,
        warning: 1,
        error: 1
      }
    )
  end

  it "still treats legacy broken statuses as errors" do
    rows = [pipeline_row(:ok), pipeline_row(:broken)]

    result = PipelineAggregateStatus.call(rows: rows)

    _(result).must_equal(
      status: :broken,
      diagnosis: "1 of 2 events have errors",
      counts: {
        ok: 1,
        warning: 0,
        error: 1
      }
    )
  end

  def pipeline_row(status)
    {
      event: Object.new,
      status: {
        status: status,
        diagnosis: "#{status} diagnosis"
      }
    }
  end
end
