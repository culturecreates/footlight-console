require "test_helper"
require "minitest/spec"
require "minitest/mock"
require "ostruct"

describe PipelineBuilder do
  it "builds rows from provided events only" do
    website = OpenStruct.new(url: "test")
    events = [{ "id" => 1 }, { "id" => 2 }]
    evaluator = ->(event:) { [{ status: :ok, diagnosis: "ok" }, {}, []] }

    rows = nil
    PipelineEvaluator.stub :call, evaluator do
      rows = PipelineBuilder.call(events: events, website: website)
    end

    _(rows.size).must_equal 2
  end

  it "does not attempt to fetch events internally" do
    website = WebsiteThatRejectsEvents.new("test")

    rows = PipelineBuilder.call(events: [], website: website)

    _(rows).must_equal []
  end

  it "builds non trace rows from provided events" do
    website = OpenStruct.new(url: "test")
    events = [{ "id" => 11 }, { "id" => 22 }]
    evaluations = {
      11 => [{ status: :error, diagnosis: "Event has statement problems" }, {}, []],
      22 => [{ status: :warning, diagnosis: "Event needs statement review" }, {}, []]
    }
    captured = []
    evaluator = lambda do |event:|
      captured << event.id
      evaluations.fetch(event.id)
    end

    rows = nil
    PipelineEvaluator.stub :call, evaluator do
      rows = PipelineBuilder.call(events: events, website: website)
    end

    _(captured).must_equal [11, 22]
    _(rows.map { |row| [row[:event].id, row[:status]] }).must_equal [
      [11, { status: :error, diagnosis: "Event has statement problems" }],
      [22, { status: :warning, diagnosis: "Event needs statement review" }]
    ]
  end

  it "returns empty rows when provided events are empty" do
    website = OpenStruct.new(url: "test")

    rows = PipelineBuilder.call(events: [], website: website)

    _(rows).must_equal []
  end

  it "captures per event status failures without crashing" do
    website = OpenStruct.new(url: "test")
    events = [{ "id" => 11 }, { "id" => 22 }]
    evaluator = lambda do |event:|
      if event.id == 22
        raise PipelineBuilder::EvaluationError.new(
          error: RuntimeError.new("status failed"),
          metrics: {},
          rules: []
        )
      end

      [{ status: :ok, diagnosis: "ok" }, {}, []]
    end

    rows = nil
    PipelineEvaluator.stub :call, evaluator do
      rows = PipelineBuilder.call(events: events, website: website)
    end

    _(rows.map { |row| [row[:event].id, row[:status]] }).must_equal [
      [11, { status: :ok, diagnosis: "ok" }],
      [22, { event_id: 22, status: :error, diagnosis: "status failed" }]
    ]
  end

  it "includes trace when trace is true" do
    website = OpenStruct.new(url: "test")
    events = [{ "id" => 11 }]
    evaluation = [
      { status: :error, diagnosis: "Event has statement problems" },
      { has_problem: true },
      [{ name: "critical_rule", status: "critical" }]
    ]
    evaluator = ->(event:) { evaluation }

    rows = nil
    PipelineEvaluator.stub :call, evaluator do
      rows = PipelineBuilder.call(events: events, website: website, trace: true)
    end

    _(rows.first[:status]).must_equal evaluation[0]
    _(rows.first[:trace][:metrics]).must_equal evaluation[1]
    _(rows.first[:trace][:rules_applied]).must_equal evaluation[2]
    _(rows.first[:trace][:error]).must_be_nil
  end

  it "includes duration when trace is true" do
    website = OpenStruct.new(url: "test")
    events = [{ "id" => 11 }]
    evaluator = ->(event:) { [{ status: :ok, diagnosis: "ok" }, {}, []] }

    rows = nil
    PipelineEvaluator.stub :call, evaluator do
      rows = PipelineBuilder.call(events: events, website: website, trace: true)
    end

    _(rows.first[:trace][:duration_ms]).must_be_kind_of Numeric
    _(rows.first[:trace][:duration_ms]).must_be :>=, 0
  end

  it "captures trace errors when traced evaluation fails" do
    website = OpenStruct.new(url: "test")
    events = [{ "id" => 22 }]
    evaluator = lambda do |event:|
      raise PipelineBuilder::EvaluationError.new(
        error: ArgumentError.new("trace failed"),
        metrics: { publishable: false },
        rules: [{ name: "warning_rule", status: "warning" }]
      )
    end

    rows = nil
    PipelineEvaluator.stub :call, evaluator do
      rows = PipelineBuilder.call(events: events, website: website, trace: true)
    end

    _(rows.first[:status]).must_equal(
      event_id: 22,
      status: :error,
      diagnosis: "trace failed"
    )
    _(rows.first[:trace][:metrics]).must_equal(publishable: false)
    _(rows.first[:trace][:rules_applied]).must_equal([{ name: "warning_rule", status: "warning" }])
    _(rows.first[:trace][:error]).must_equal(
      message: "trace failed",
      class: "ArgumentError"
    )
  end

  it "keeps the return shape unchanged when trace is false" do
    website = OpenStruct.new(url: "test")
    events = [{ "id" => 11 }]
    evaluator = ->(event:) { [{ status: :ok, diagnosis: "ok" }, {}, []] }

    rows = nil
    PipelineEvaluator.stub :call, evaluator do
      rows = PipelineBuilder.call(events: events, website: website, trace: false)
    end

    _(rows.first.keys).must_equal [:event, :status]
  end

  it "returns the same status for trace and non trace modes" do
    website = OpenStruct.new(url: "test")
    events = [{ "id" => 11 }]
    evaluator = ->(event:) { [{ status: :warning, diagnosis: "Shared path" }, {}, []] }

    trace_row = nil
    normal_row = nil
    PipelineEvaluator.stub :call, evaluator do
      trace_row = PipelineBuilder.call(events: events, website: website, trace: true).first
      normal_row = PipelineBuilder.call(events: events, website: website, trace: false).first
    end

    _(normal_row[:status]).must_equal trace_row[:status]
  end

  it "delegates public evaluation to the pipeline evaluator" do
    event = OpenStruct.new(id: 11)
    evaluation = [{ status: :warning, diagnosis: "Shared path" }, { needs_review: true }, [{ name: "shared rule" }]]
    captured = {}
    evaluator = lambda do |event:|
      captured[:event] = event
      evaluation
    end

    result = nil
    PipelineEvaluator.stub :call, evaluator do
      result = PipelineBuilder.evaluate(event: event)
    end

    _(captured[:event]).must_equal event
    _(result).must_equal evaluation
  end

  class WebsiteThatRejectsEvents < Struct.new(:url)
    def events
      raise "website.events should not be called"
    end
  end
end
