require 'test_helper'
require 'minitest/mock'

class EventsControllerTest < ActionDispatch::IntegrationTest
  test "list view evaluates pipeline in a single batch call" do
    website = create_website(user: users(:michael), slug: "events-pipeline-batch")
    log_in_as(users(:michael))

    batch_calls = []
    events = [event_payload(id: 7), event_payload(id: 8)]

    Condenser::API.stub :website_events, { "events" => events } do
      PipelineEvaluator.stub :batch, ->(events:) {
        batch_calls << events.map { |event| [event.key, event.website] }
        {
          "event:7" => { status: :ok, diagnosis: "ok", metrics: {} },
          "event:8" => { status: :warning, diagnosis: "warn", metrics: {} }
        }
      } do
        get events_path(seedurl: website.url, view: "list")
      end
    end

    assert_response :success
    assert_equal 1, batch_calls.size
    assert_equal [["event:7", website], ["event:8", website]], batch_calls.first
    assert_select "td.pipeline-cell .pipeline-badge.is-success", text: "OK"
    assert_select "td.pipeline-cell .pipeline-badge.is-warning", text: "Warning"
  end

  test "list view shows pipeline column and ok badge" do
    website = create_website(user: users(:michael), slug: "events-pipeline-ok")
    log_in_as(users(:michael))

    evaluated_events = []

    Condenser::API.stub :website_events, { "events" => [event_payload(id: 1)] } do
      PipelineEvaluator.stub :call, ->(event:) {
        evaluated_events << [event.website, event.id]
        [
          { status: :healthy, diagnosis: "No pipeline issues detected" },
          {},
          []
        ]
      } do
        get events_path(seedurl: website.url, view: "list")
      end
    end

    assert_response :success
    assert_equal [[website, 1]], evaluated_events
    assert_select "th", text: "Pipeline"
    assert_select "td.pipeline-cell .pipeline-badge.is-success", text: "OK"
    assert_select "td.pipeline-cell .pipeline-badge.bg-success", 0
  end

  test "list view shows warning badge for degraded pipeline result" do
    website = create_website(user: users(:michael), slug: "events-pipeline-warning")
    log_in_as(users(:michael))

    Condenser::API.stub :website_events, { "events" => [event_payload(id: 2)] } do
      PipelineEvaluator.stub :call, [
        { status: :degraded, diagnosis: "Low publishable ratio" },
        {},
        []
      ] do
        get events_path(seedurl: website.url, view: "list")
      end
    end

    assert_response :success
    assert_select "td.pipeline-cell .pipeline-badge.is-warning", text: "Warning"
    assert_select "td.pipeline-cell .pipeline-badge.bg-warning", 0
  end

  test "list view normalizes broken pipeline result to error badge" do
    website = create_website(user: users(:michael), slug: "events-pipeline-broken")
    log_in_as(users(:michael))

    Condenser::API.stub :website_events, { "events" => [event_payload(id: 33)] } do
      PipelineEvaluator.stub :call, [
        { status: :broken, diagnosis: "Pipeline is broken" },
        {},
        []
      ] do
        get events_path(seedurl: website.url, view: "list")
      end
    end

    assert_response :success
    assert_select "td.pipeline-cell .pipeline-badge.is-danger", text: "Error"
  end

  test "list view shows error badge when pipeline evaluation fails" do
    website = create_website(user: users(:michael), slug: "events-pipeline-error")
    log_in_as(users(:michael))

    Condenser::API.stub :website_events, { "events" => [event_payload(id: 3)] } do
      PipelineEvaluator.stub :call, ->(event:) { raise StandardError, "boom" } do
        get events_path(seedurl: website.url, view: "list")
      end
    end

    assert_response :success
    assert_select "td.pipeline-cell .pipeline-badge.is-danger", text: "Error"
    assert_select "td.pipeline-cell .pipeline-badge.bg-danger", 0
  end

  test "list view shows n slash a when pipeline status is missing" do
    website = create_website(user: users(:michael), slug: "events-pipeline-na")
    log_in_as(users(:michael))

    Condenser::API.stub :website_events, { "events" => [event_payload(id: 4)] } do
      PipelineEvaluator.stub :call, [
        { status: nil, diagnosis: nil },
        {},
        []
      ] do
        get events_path(seedurl: website.url, view: "list")
      end
    end

    assert_response :success
    assert_select "td.pipeline-cell .pipeline-badge.is-light", text: "N/A"
    assert_select "td.pipeline-cell .pipeline-badge.bg-secondary", 0
  end

  private

  def create_website(user:, slug:)
    Website.where(url: slug).delete_all
    Website.create!(user: user, url: slug)
  end

  def event_payload(id:)
    {
      "id" => id,
      "rdf_uri" => "event:#{id}",
      "title" => "Event #{id}",
      "archive_date" => 1.week.from_now.to_date.iso8601,
      "statements_status" => {
        "publishable" => false,
        "updated" => false,
        "problem" => false,
        "to_review" => false
      }
    }
  end
end
