require "test_helper"
require "minitest/mock"

class WebsitesPipelineTest < ActionDispatch::IntegrationTest
  test "pipeline renders rows from safe events" do
    website = create_website(user: users(:michael), slug: "pipeline-rows", monitorable: true)

    log_in_as(users(:michael))

    data = { "total_events" => 1, "events" => [{ "rdf_uri" => "footlight:event-1", "title" => '["An evening of music"]' }] }
    Condenser::API.stub :website_events, data do
      get pipeline_website_url(id: website.id)
    end

    assert_response :success
    assert_select "tbody tr", 1
    assert_select "tbody tr a[href=?]", event_path(id: "footlight:event-1"), text: "An evening of music"
    assert_select "tbody tr td", text: "Missing statements_status"
    assert_no_match(/ActionController::Parameters/, response.body)
  end

  test "pipeline renders empty state when safe events are empty" do
    website = create_website(user: users(:michael), slug: "pipeline-no-events", monitorable: true)

    log_in_as(users(:michael))

    Condenser::API.stub :website_events, { "events" => [] } do
      get pipeline_website_url(id: website.id)
    end

    assert_response :success
    assert_select "p", text: "No events found"
  end

  test "pipeline offers a retry when Condenser returns a partial list" do
    website = create_website(user: users(:michael), slug: "pipeline-unavailable", monitorable: true)
    log_in_as(users(:michael))

    Condenser::API.stub :website_events, { "total_events" => 2, "events" => [{ "id" => 1 }] } do
      get pipeline_website_url(website)
    end

    assert_response :service_unavailable
    assert_select "p[role='alert'] a[href=?]", pipeline_website_path(website), text: "Retry diagnostics"
    assert_select "tbody tr", 0
  end

  private

  def create_website(user:, slug:, monitorable:)
    Website.where(url: slug).delete_all
    Website.create!(user: user, url: slug, monitorable: monitorable)
  end
end
