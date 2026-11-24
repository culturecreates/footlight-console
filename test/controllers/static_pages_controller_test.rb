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

  test "dashboard offers on demand diagnostics without fetching or evaluating every website" do
    user = create_user("dashboard-monitorable-user")
    website = create_website(user: user, slug: "dashboard-monitorable", monitorable: true)

    log_in_as(user)

    with_dashboard_config do
      Condenser::API.stub :website_events, ->(**) { flunk "Dashboard must not fetch per website events" } do
        DashboardBuilder.stub :new, ->(**) { FakeDashboardBuilder.new([dashboard_row(website)]) } do
          PipelineAggregateStatus.stub :call, ->(**) { flunk "Dashboard must not aggregate pipelines" } do
            get dashboard_path
          end
        end
      end
    end

    assert_response :success
    assert_select "td.pipeline-column a[href=?]", pipeline_website_path(website), text: "Check"
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
    assert_select "td.pipeline-column a", 0
    assert_select "td.pipeline-column", text: "—", count: 1
    assert_select "td.dashboard-inventory", text: "—"
  end

  test "missing monitoring does not imply zero events or zero publishability" do
    user = create_user("dashboard-link-user")
    website = create_website(user: user, slug: "dashboard-link", monitorable: true)

    log_in_as(user)

    row = dashboard_row(website).merge(
      condenser_available: true,
      condenser: { "webpages" => 262, "statements_refreshed_24hr" => 228, "statements_updated_24hr" => 211 },
      metrics: MetricsInterpreter.new({}, []).metrics_for(website.url, website)
    )
    render_dashboard_row(row)

    assert_response :success
    assert_select ".dashboard-site .tag", 0
    assert_select "tbody td:nth-child(4)", text: /228\s*\/\s*211/
    assert_select "tbody td:nth-child(7)", text: "—"
    assert_select "tbody td:nth-child(8)", text: "—"
    assert_select "tbody td:nth-child(10)", text: "—"
  end

  test "known zero event count displays the zero badge" do
    user = create_user("dashboard-zero-user")
    website = create_website(user: user, slug: "dashboard-zero", monitorable: true)
    log_in_as(user)
    row = dashboard_row(website).merge(condenser_available: true, metrics: { total_webpages: 0 })

    render_dashboard_row(row)

    assert_response :success
    assert_select ".dashboard-site .tag", text: "⚠️ 0"
    assert_select "tbody td:nth-child(8)", text: "—"
  end

  test "dashboard displays Condenser's inventory freshness and a measured zero" do
    user = create_user("dashboard-inventory-user")
    website = create_website(user: user, slug: "dashboard-inventory", monitorable: true)
    log_in_as(user)
    website_payload = [{ "seedurl" => website.url, "inventory_freshness" => { "status" => "confirmed_discovery",
      "label" => "Verified", "latest_list_refresh_at" => "2026-11-23T13:25:00Z",
      "new_event_age_days" => 0, "selected_event_urls_missing" => 0 } }]
    requests = []
    with_dashboard_config do
      Condenser::API.stub :websites, ->(**params) { requests << params; website_payload } do
        Condenser::API.stub :dashboard_metrics, {} do
          get dashboard_path
        end
      end
    end

    assert_response :success
    assert_equal [{ inventory_freshness: "true" }], requests
    assert_select "[data-inventory-status='confirmed_discovery']", text: "Verified"
    assert_select "td.dashboard-inventory time[datetime]", count: 1
    assert_select "td.dashboard-inventory small", text: "New event 0d"
    assert_select "td.dashboard-inventory small", text: "0 outside lists"
  end

  test "dashboard retains event age for an older Condenser without freshness metrics" do
    user = create_user("dashboard-older-inventory")
    website = create_website(user: user, slug: "dashboard-older", monitorable: true)
    log_in_as(user)
    render_dashboard_row(dashboard_row(website).merge(condenser_available: true, metrics: { days_since_last_webpage_label: 17 }))

    assert_response :success
    assert_select "td.dashboard-inventory small", text: "New event 17d · Inventory unavailable"
  end

  test "measured zero publishability remains visible when events exist" do
    user = create_user("dashboard-unpublishable-user")
    website = create_website(user: user, slug: "dashboard-unpublishable", monitorable: true)
    log_in_as(user)
    row = dashboard_row(website).merge(
      condenser_available: true, metrics: { total_webpages: 10, health_score: 0, publishable_ratio: 0 }
    )

    render_dashboard_row(row)

    assert_response :success
    assert_select ".dashboard-site .tag", 0
    assert_select "tbody td:nth-child(8)", text: "0%"
  end

  private

  def render_dashboard_row(row)
    with_dashboard_config do
      DashboardBuilder.stub :new, ->(**) { FakeDashboardBuilder.new([row]) } do
        get dashboard_path
      end
    end
  end

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
