require "test_helper"
require "minitest/mock"

class MonitoringFeedTest < ActiveSupport::TestCase
  test "requests the selected site status and page" do
    payload = { "issues" => [], "sites" => ["gatineau-cloud-RList"], "pagination" => { "page" => 2, "total_pages" => 2, "total_entries" => 101 } }
    request = ->(**args) do
      assert_equal({ seedurl: "gatineau-cloud-RList", status: "open", page: 2 }, args)
      payload
    end
    Condenser::API.stub(:monitoring_issues, request) do
      assert_equal payload, MonitoringFeed.call(seedurl: "gatineau-cloud-RList", page: 2)
    end
  end

  test "unavailable and malformed feeds cannot appear as an empty successful result" do
    [nil, {}, { "issues" => [], "sites" => [], "pagination" => {} },
      { "issues" => ["bad"], "sites" => [], "pagination" => { "page" => 1, "total_pages" => 1, "total_entries" => 1 } }].each do |payload|
      Condenser::API.stub(:monitoring_issues, payload) do
        assert_raises(MonitoringFeed::Unavailable) { MonitoringFeed.call }
      end
    end
  end
  test "API wrapper uses the authenticated monitoring endpoint with unchanged filters" do
    expected = { method: :get, path: "/monitoring.json", query: { seedurl: "gatineau-cloud-RList", status: "resolved", page: 2 }, body: nil }
    payload = { "issues" => [] }
    test_case = self
    request = ->(**arguments) do
      test_case.assert_equal expected, arguments
      payload
    end
    client = Object.new
    client.define_singleton_method(:request, &request)
    Condenser::API.stub(:client, client) do
      assert_equal payload, Condenser::API.monitoring_issues(seedurl: "gatineau-cloud-RList", status: "resolved", page: 2)
    end
  end

end
