require "test_helper"

class WebsitesPipelineTest < ActionDispatch::IntegrationTest
  test "pipeline renders rows from safe events" do
    website = create_website(user: users(:michael), slug: "pipeline-rows", monitorable: true)

    log_in_as(users(:michael))

    Condenser::API.stub :website_events, { "events" => [{ "id" => 1 }] } do
      get pipeline_website_url(id: website.id)
    end

    assert_response :success
    assert_select "tbody tr", 1
    assert_select "tbody tr td:nth-child(1)", text: "1"
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

  private

  def create_website(user:, slug:, monitorable:)
    Website.where(url: slug).delete_all
    Website.create!(user: user, url: slug, monitorable: monitorable)
  end
end
