require "test_helper"
require "minitest/mock"

class WebsitesControllerTest < ActionDispatch::IntegrationTest
  test "should redirect pipeline when not logged in" do
    website = create_website(user: users(:michael), slug: "pipeline-login-required", monitorable: true)

    get pipeline_website_url(id: website.id)

    assert_response :redirect
    assert_redirected_to login_url
  end

  test "should not access another users pipeline" do
    user = users(:michael)
    other_user = users(:archer)
    website = create_website(user: other_user, slug: "pipeline-other-owner", monitorable: true)

    log_in_as(user)

    get pipeline_website_url(id: website.id)

    assert_response :not_found
  end

  test "should return not found when website is not monitorable" do
    website = create_website(user: users(:michael), slug: "pipeline-not-monitorable", monitorable: false)

    log_in_as(users(:michael))

    get pipeline_website_url(id: website.id)

    assert_response :not_found
  end

  test "pipeline uses safe_events as source of truth" do
    website = create_website(user: users(:michael), slug: "pipeline-safe", monitorable: true)

    log_in_as(users(:michael))

    Condenser::API.stub :website_events, { "events" => [{ "id" => 1 }] } do
      get pipeline_website_url(id: website.id)
    end

    assert_response :success
    assert_select "tbody tr", 1
    assert_select "td", text: "1"
  end

  test "should render pipeline data for current users monitorable website" do
    website = create_website(user: users(:michael), slug: "pipeline-render", monitorable: true)
    source_events = [{ "id" => 11 }, { "id" => 22 }]
    pipeline_rows = [
      { event: source_events.first, status: { event_id: 11, status: :broken, diagnosis: "Wringer failed" } },
      { event: source_events.second, status: { event_id: 22, status: :degraded, diagnosis: "Console review is low" } }
    ]
    captured_website = nil
    captured_events = nil

    log_in_as(users(:michael))

    Condenser::API.stub :website_events, { "events" => source_events } do
      PipelineBuilder.stub :call, ->(events:, website:, trace: false) {
        captured_events = events
        captured_website = website
        pipeline_rows
      } do
        get pipeline_website_url(id: website.id)
      end
    end

    assert_response :success
    assert_equal website.id, captured_website.id
    assert_equal source_events, captured_events
    assert_select "h1", "Pipeline Status"
    assert_select "tbody tr", 2
    assert_select "tbody tr:nth-child(1) td:nth-child(1)", text: "11"
    assert_select "tbody tr:nth-child(1) td:nth-child(2)", text: "broken"
    assert_select "tbody tr:nth-child(1) td:nth-child(3)", text: "Wringer failed"
    assert_select "tbody tr:nth-child(2) td:nth-child(1)", text: "22"
    assert_select "tbody tr:nth-child(2) td:nth-child(2)", text: "degraded"
    assert_select "tbody tr:nth-child(2) td:nth-child(3)", text: "Console review is low"
  end

  test "should render empty pipeline data safely" do
    website = create_website(user: users(:michael), slug: "pipeline-empty", monitorable: true)

    log_in_as(users(:michael))

    Condenser::API.stub :website_events, { "events" => [] } do
      PipelineBuilder.stub :call, ->(events:, website:, trace: false) { [] } do
        get pipeline_website_url(id: website.id)
      end
    end

    assert_response :success
    assert_select "h1", "Pipeline Status"
    assert_select "p", text: "No events found"
    assert_select "tbody tr", 0
  end

  private

  def create_website(user:, slug:, monitorable:)
    Website.where(url: slug).delete_all
    Website.create!(user: user, url: slug, monitorable: monitorable)
  end
end
