require "test_helper"
require "minitest/mock"

class CondenserSafeTest < ActiveSupport::TestCase
  setup do
    @consumer = Class.new { include CondenserSafe }.new
  end

  test "accepts a complete event collection beyond API page limits" do
    events = Array.new(198) { |id| { "rdf_uri" => "event:#{id}" } }
    result = fetch_events("events" => events, "total_events" => 198)

    assert_equal events, result["events"]
    assert_not result["unavailable"]
  end

  test "rejects a partial collection rather than treating it as every event" do
    result = fetch_events("events" => Array.new(25) { {} }, "total_events" => 198)

    assert result["unavailable"]
    assert_empty result["events"]
  end

  test "accepts a genuinely empty collection" do
    result = fetch_events("events" => [], "total_events" => 0)

    assert_empty result["events"]
    assert_not result["unavailable"]
  end

  test "preserves compatibility with event responses without a total" do
    event = { "rdf_uri" => "event:1" }
    assert_equal [event], fetch_events("events" => [event])["events"]
  end

  test "invalid payloads and malformed totals are unavailable rather than empty datasets" do
    [nil, [], {}, { "events" => nil }, { "events" => [], "total_events" => "0" }].each do |payload|
      assert fetch_events(payload)["unavailable"], "Expected unavailable response for #{payload.inspect}"
    end
  end

  private

  def fetch_events(payload)
    AppLogger.stub :error, nil do
      Condenser::API.stub :website_events, payload do
        @consumer.send(:safe_events, seedurl: "co-motion-ca")
      end
    end
  end
end
