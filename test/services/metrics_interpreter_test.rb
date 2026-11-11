require "test_helper"

class MetricsInterpreterTest < ActiveSupport::TestCase
  test "missing monitoring data stays unknown" do
    metrics = MetricsInterpreter.new({}, []).metrics_for("co-motion-ca", nil)

    %i[total_webpages publishable_ratio health_score days_overdue event_horizon_days event_horizon_label pipeline_health].each do |key|
      assert_nil metrics[key], "Expected #{key} to be unknown"
    end
    assert_not metrics[:pipeline_warning]
  end

  test "a known zero event count remains distinguishable from missing monitoring" do
    metrics = metrics_for("total_webpages" => 0, "publishable_ratio" => 0, "event_horizon_days" => 0)

    assert_equal 0, metrics[:total_webpages]
    assert_equal 0, metrics[:event_horizon_label]
    assert_nil metrics[:publishable_ratio]
    assert_nil metrics[:health_score]
  end

  test "a measured zero publishable ratio is retained when events exist" do
    metrics = metrics_for("total_webpages" => 203, "publishable_ratio" => 0)

    assert_equal 0.0, metrics[:publishable_ratio]
    assert_equal 0.0, metrics[:health_score]
    assert_nil metrics[:event_horizon_label]
  end

  test "available monitoring values retain their meaning" do
    metrics = metrics_for("total_webpages" => 203, "publishable_ratio" => 100.0, "event_horizon_days" => 916)

    assert_equal 203, metrics[:total_webpages]
    assert_equal 100.0, metrics[:publishable_ratio]
    assert_equal 916, metrics[:event_horizon_label]
  end

  private

  def metrics_for(raw)
    MetricsInterpreter.new({ "co-motion-ca" => raw }, []).metrics_for("co-motion-ca", nil)
  end
end
