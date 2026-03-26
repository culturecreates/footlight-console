require 'test_helper'
require 'minitest/mock'

class StaticPagesControllerTest < ActionDispatch::IntegrationTest
  test "should get home" do
    get root_path
    assert_response :success
    assert_select "title", "Footlight Console"
  end

  test "should check code snippet" do
    get export_path(seedurl: "crowstheatre-com")
    assert_response :found
  end

  test "dashboard shows pipeline aggregate status for a monitorable website" do
    user = create_user("dashboard-monitorable-user")
    website = create_website(user: user, slug: "dashboard-monitorable", monitorable: true)

    log_in_as(user)

    with_dashboard_config do
      Condenser::API.stub :website_events, { "events" => [] } do
        DashboardBuilder.stub :new, ->(**) { FakeDashboardBuilder.new([dashboard_row(website)]) } do
          PipelineAggregateStatus.stub :call, ->(rows:) {
            {
              status: :broken,
              diagnosis: "2 of 10 events are broken",
              stats: {}
            }
          } do
            get dashboard_path
          end
        end
      end
    end

    assert_response :success
    assert_select "td.pipeline-status-cell span.pipeline-status.broken", text: /Broken/
    assert_select "td.pipeline-status-cell .pipeline-diagnosis", text: "2 of 10 events are broken"
  end

  test "dashboard shows dash for a non monitorable website" do
    user = create_user("dashboard-non-monitorable-user")
    website = create_website(user: user, slug: "dashboard-non-monitorable", monitorable: false)

    log_in_as(user)

    with_dashboard_config do
      DashboardBuilder.stub :new, ->(**) { FakeDashboardBuilder.new([dashboard_row(website)]) } do
        PipelineAggregateStatus.stub :call, ->(rows:) { raise "should not aggregate non monitorable website" } do
          get dashboard_path
        end
      end
    end

    assert_response :success
    assert_select "td.pipeline-status-cell", text: "—"
  end

  test "dashboard links the pipeline status cell to the events page" do
    user = create_user("dashboard-link-user")
    website = create_website(user: user, slug: "dashboard-link", monitorable: true)

    log_in_as(user)

    with_dashboard_config do
      Condenser::API.stub :website_events, { "events" => [] } do
        DashboardBuilder.stub :new, ->(**) { FakeDashboardBuilder.new([dashboard_row(website)]) } do
          PipelineAggregateStatus.stub :call, ->(rows:) {
            {
              status: :degraded,
              diagnosis: "1 of 3 events are degraded",
              stats: {}
            }
          } do
            get dashboard_path
          end
        end
      end
    end

    assert_response :success
    assert_select "td.pipeline-status-cell a.pipeline-status-link[href=?]", events_path(seedurl: website.url, view: "list")
  end

  private

  FakeDashboardBuilder = Struct.new(:rows) do
    def build
      rows
    end
  end

  def with_dashboard_config
    Rails.application.stub :config_for, { "condenser" => { "url" => "http://example.test" } } do
      yield
    end
  end

  def dashboard_row(website)
    {
      website: website,
      condenser: {},
      metrics: {},
      condenser_available: false
    }
  end

  def create_user(slug)
    User.where(email: "#{slug}@example.com").delete_all

    User.create!(
      name: slug.tr("-", " ").capitalize,
      email: "#{slug}@example.com",
      password: "password",
      password_confirmation: "password",
      activated: true,
      activated_at: Time.zone.now
    )
  end

  def create_website(user:, slug:, monitorable:)
    Website.where(url: slug).delete_all

    Website.create!(user: user, url: slug, monitorable: monitorable)
  end
end
