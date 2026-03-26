require "test_helper"
require "minitest/spec"

describe EventPipelineStatus do
  it "returns the expected structure" do
    website = Object.new
    event = EventPipelineStatusEvent.new(101, website)
    evaluation = [{ status: :warning, diagnosis: "Interpreter diagnosis" }, {}, []]

    result = nil
    PipelineBuilder.stub :evaluate, evaluation do
      result = EventPipelineStatus.call(event: event)
    end

    _(result[:event_id]).must_equal event.id
    _(result[:status]).must_be_kind_of Symbol
    _(result[:diagnosis]).must_be_kind_of String
  end

  it "uses the pipeline builder public api" do
    website = Object.new
    event = EventPipelineStatusEvent.new(202, website)
    captured = {}
    evaluator = lambda do |event:|
      captured[:event] = event
      [{ status: :error, diagnosis: "fail" }, { has_problem: true }, [{ name: "shared rule" }]]
    end

    result = nil
    PipelineBuilder.stub :evaluate, evaluator do
      result = EventPipelineStatus.call(event: event)
    end

    _(captured[:event]).must_equal event
    _(result[:status]).must_equal :error
  end

  it "propagates the evaluated status result" do
    event = EventPipelineStatusEvent.new(303, Object.new)
    evaluation = [{ status: :ok, diagnosis: "No pipeline issues detected" }, {}, []]

    result = nil
    PipelineBuilder.stub :evaluate, evaluation do
      result = EventPipelineStatus.call(event: event)
    end

    _(result).must_equal(
      event_id: 303,
      status: :ok,
      diagnosis: "No pipeline issues detected"
    )
  end

  it "ignores metrics and rules in the evaluation payload" do
    event = EventPipelineStatusEvent.new(404, Object.new)
    evaluation = [
      { status: :error, diagnosis: "Event has statement problems" },
      { has_problem: true },
      [{ name: "critical rule" }]
    ]

    result = nil
    PipelineBuilder.stub :evaluate, evaluation do
      result = EventPipelineStatus.call(event: event)
    end

    _(result).must_equal(
      event_id: 404,
      status: :error,
      diagnosis: "Event has statement problems"
    )
  end

  EventPipelineStatusEvent = Struct.new(:id, :website)
end
