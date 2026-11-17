require "test_helper"
require "minitest/mock"

class MonitoringControllerTest < ActionDispatch::IntegrationTest
  test "requires login" do
    get monitoring_path
    assert_redirected_to login_url
  end

  test "requires administrator role" do
    log_in_as(users(:archer))
    get monitoring_path
    assert_response :forbidden
  end

  test "administrator can filter and inspect flagged issues" do
    log_in_as(users(:michael))
    payload = { "issues" => [{ "seedurl" => "gatineau-cloud-RList", "message" => "Audience mapping is stale", "source_id" => 4606,
      "statement_id" => 663745, "occurrences" => 2, "kind" => "stale_inputs", "preprocessing_policy_id" => 7 }], "sites" => ["gatineau-cloud-RList"],
      "pagination" => { "page" => 1, "total_pages" => 2, "total_entries" => 101 } }
    MonitoringFeed.stub(:call, payload) do
      get monitoring_path, params: { seedurl: "gatineau-cloud-RList" }
      assert_response :success
      assert_select "td", text: "Audience mapping is stale"
      assert_select "a[href*='page=2']", text: "Next"
      assert_select "a[href*='/preprocessing_policies/7/edit']", text: "Policy"
    end
  end

  test "feed outage has an explicit unavailable state" do
    log_in_as(users(:michael))
    MonitoringFeed.stub(:call, ->(**_) { raise MonitoringFeed::Unavailable, "Monitoring is unavailable" }) do
      get monitoring_path
      assert_response :service_unavailable
      assert_select ".notification", text: /Monitoring is unavailable/
      assert_select "p", text: "No monitored issues match these filters.", count: 0
    end
  end
end
