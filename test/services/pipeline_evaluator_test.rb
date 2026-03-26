require "test_helper"
require "minitest/spec"
require "minitest/mock"

describe PipelineEvaluator do
  PipelineEvaluatorEvent = Struct.new(:id, :website, :statements_status, :archive_date)

  it "returns status metrics and rules" do
    website = Object.new
    event = build_event(id: 11, website: website)
    metrics = { publishable: false, has_problem: false, needs_review: true, updated: true, archive_date: nil }
    rules = [{ name: "warning rule" }]
    status = { status: :warning, diagnosis: "Event needs statement review" }

    result = nil
    PipelineMetricsBuilder.stub :call, metrics do
      PipelineRuleResolver.stub :rules_for, rules do
        PipelineStatusInterpreter.stub :call, status do
          result = PipelineEvaluator.call(event: event)
        end
      end
    end

    _(result).must_equal [status, metrics, rules]
  end

  it "passes metrics to the interpreter" do
    website = Object.new
    event = build_event(id: 22, website: website)
    metrics = { publishable: false, has_problem: true, needs_review: false, updated: true, archive_date: nil }
    captured = {}
    interpreter = lambda do |website:, metrics:, rules:|
      captured[:metrics] = metrics
      { status: :error, diagnosis: "Event has statement problems" }
    end

    PipelineMetricsBuilder.stub :call, metrics do
      PipelineRuleResolver.stub :rules_for, [] do
        PipelineStatusInterpreter.stub :call, interpreter do
          PipelineEvaluator.call(event: event)
        end
      end
    end

    _(captured[:metrics]).must_equal metrics
  end

  it "passes rules to the interpreter" do
    website = Object.new
    event = build_event(id: 33, website: website)
    rules = [{ name: "critical rule", status: "critical" }]
    captured = {}
    interpreter = lambda do |website:, metrics:, rules:|
      captured[:rules] = rules
      { status: :error, diagnosis: "Critical issue" }
    end

    PipelineMetricsBuilder.stub :call, PipelineMetricsBuilder::METRICS.index_with { nil } do
      PipelineRuleResolver.stub :rules_for, rules do
        PipelineStatusInterpreter.stub :call, interpreter do
          PipelineEvaluator.call(event: event)
        end
      end
    end

    _(captured[:rules]).must_equal rules
  end

  it "raises an evaluation error with metrics and rules context" do
    website = Object.new
    event = build_event(id: 55, website: website)
    metrics = { publishable: false, has_problem: false, needs_review: true, updated: true, archive_date: nil }
    rules = [{ name: "failing rule" }]

    error = nil
    PipelineMetricsBuilder.stub :call, metrics do
      PipelineRuleResolver.stub :rules_for, rules do
        PipelineStatusInterpreter.stub :call, ->(website:, metrics:, rules:) { raise ArgumentError, "boom" } do
          error = assert_raises(PipelineBuilder::EvaluationError) do
            PipelineEvaluator.call(event: event)
          end
        end
      end
    end

    _(error.error).must_be_instance_of ArgumentError
    _(error.error.message).must_equal "boom"
    _(error.metrics).must_equal metrics
    _(error.rules).must_equal rules
  end

  it "returns an error when statements_status is missing" do
    website = Object.new
    event = PipelineEvaluatorEvent.new(66, website, nil, nil)

    result = nil
    PipelineRuleResolver.stub :rules_for, ->(_website) { raise "should not resolve rules" } do
      result = PipelineEvaluator.call(event: event)
    end

    _(result).must_equal [
      { status: :error, diagnosis: "Missing statements_status" },
      {
        publishable: nil,
        has_problem: nil,
        needs_review: nil,
        updated: nil,
        archive_date: nil,
        days_until_archive: nil,
        recently_updated: false
      },
      []
    ]
  end

  it "returns an error when no rules are evaluated even if fields are incomplete" do
    website = Object.new
    event = PipelineEvaluatorEvent.new(
      77,
      website,
      {
        "publishable" => true,
        "problem" => false,
        "to_review" => false
      },
      nil
    )

    result = nil
    PipelineRuleResolver.stub :rules_for, [] do
      result = PipelineEvaluator.call(event: event)
    end

    _(result.first[:status]).must_equal :error
    _(result.first[:diagnosis]).must_equal "No rules evaluated"
  end

  it "keeps a triggered error when fields are incomplete" do
    website = Object.new
    event = PipelineEvaluatorEvent.new(
      88,
      website,
      {
        "publishable" => false,
        "problem" => true,
        "to_review" => false
      },
      nil
    )
    rules = [
      {
        name: "problem_rule",
        conditions: {
          "metric" => "has_problem",
          "operator" => "eq",
          "value" => true
        },
        status: "critical",
        diagnosis: "Event has statement problems"
      }
    ]

    result = nil
    PipelineRuleResolver.stub :rules_for, rules do
      result = PipelineEvaluator.call(event: event)
    end

    _(result.first).must_equal(
      status: :error,
      diagnosis: "Event has statement problems"
    )
  end

  it "batch returns normalized results keyed by event key" do
    website = Object.new
    first_event = PipelineBuilder::PipelineEvent.new({ "id" => 1, "rdf_uri" => "event:1" }, website)
    second_event = PipelineBuilder::PipelineEvent.new({ "id" => 2 }, website)

    evaluator = lambda do |event:|
      case event.key
      when "event:1"
        [{ status: :ok, diagnosis: "Healthy" }, { publishable: true }, []]
      when 2
        [{ status: :error, diagnosis: "Broken" }, { publishable: false }, []]
      else
        raise "unexpected event"
      end
    end

    result = nil
    PipelineEvaluator.stub :call, evaluator do
      result = PipelineEvaluator.batch(events: [first_event, second_event])
    end

    _(result).must_equal(
      "event:1" => { status: :ok, diagnosis: "Healthy", metrics: { publishable: true } },
      2 => { status: :error, diagnosis: "Broken", metrics: { publishable: false } }
    )
  end

  it "batch returns an error result when one event evaluation fails" do
    website = Object.new
    first_event = PipelineBuilder::PipelineEvent.new({ "id" => 11, "rdf_uri" => "event:11" }, website)
    second_event = PipelineBuilder::PipelineEvent.new({ "id" => 12, "rdf_uri" => "event:12" }, website)

    evaluator = lambda do |event:|
      if event.key == "event:11"
        [{ status: :warning, diagnosis: "Warning" }, { publishable: false }, []]
      else
        raise StandardError, "boom"
      end
    end

    result = nil
    PipelineEvaluator.stub :call, evaluator do
      result = PipelineEvaluator.batch(events: [first_event, second_event])
    end

    _(result).must_equal(
      "event:11" => { status: :warning, diagnosis: "Warning", metrics: { publishable: false } },
      "event:12" => { status: :error, diagnosis: "boom", metrics: {} }
    )
  end

  it "normalizes both legacy and current status vocabularies" do
    _(PipelineEvaluator.normalize_status(:healthy)).must_equal :ok
    _(PipelineEvaluator.normalize_status(:degraded)).must_equal :warning
    _(PipelineEvaluator.normalize_status(:broken)).must_equal :error
    _(PipelineEvaluator.normalize_status(:ok)).must_equal :ok
    _(PipelineEvaluator.normalize_status(:warning)).must_equal :warning
    _(PipelineEvaluator.normalize_status(:error)).must_equal :error
  end

  it "skips events with missing keys" do
    event = Struct.new(:key, :website).new(nil, Object.new)
    log_messages = []

    result = nil
    Rails.logger.stub :error, ->(message) { log_messages << message } do
      PipelineEvaluator.stub :call, ->(event:) { raise "should not evaluate event without key" } do
        result = PipelineEvaluator.batch(events: [event])
      end
    end

    _(result).must_equal({})
    _(log_messages.first).must_match(/missing key/)
  end

  it "logs an error when event evaluation fails" do
    website = Object.new
    event = PipelineBuilder::PipelineEvent.new({ "id" => 21, "rdf_uri" => "event:21" }, website)
    log_messages = []

    result = nil
    Rails.logger.stub :error, ->(message) { log_messages << message } do
      PipelineEvaluator.stub :call, ->(event:) { raise StandardError, "boom" } do
        result = PipelineEvaluator.batch(events: [event])
      end
    end

    _(result).must_equal(
      "event:21" => { status: :error, diagnosis: "boom", metrics: {} }
    )
    _(log_messages.first).must_match(/key=event:21/)
    _(log_messages.first).must_match(/StandardError/)
    _(log_messages.first).must_match(/boom/)
  end

  def build_event(id:, website: Object.new, statements_status: nil, archive_date: nil)
    statements_status ||= {
      "publishable" => true,
      "problem" => false,
      "to_review" => false,
      "updated" => true
    }

    PipelineEvaluatorEvent.new(id, website, statements_status, archive_date)
  end
end
