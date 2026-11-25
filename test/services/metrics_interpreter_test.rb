require "test_helper"

class MetricsInterpreterTest < ActiveSupport::TestCase
  test "missing monitoring data stays unknown" do
    metrics = MetricsInterpreter.new({}, []).metrics_for("co-motion-ca", nil)

    %i[total_webpages publishable_ratio days_overdue schedule_risk_level event_horizon_days event_horizon_label pipeline_health].each do |key|
      assert_nil metrics[key], "Expected #{key} to be unknown"
    end
    assert_not metrics[:pipeline_warning]
  end

  test "a known zero event count remains distinguishable from missing monitoring" do
    metrics = metrics_for("total_webpages" => 0, "publishable_ratio" => 0, "event_horizon_days" => 0)

    assert_equal 0, metrics[:total_webpages]
    assert_equal 0, metrics[:event_horizon_label]
    assert_nil metrics[:publishable_ratio]
  end

  test "a measured zero publishable ratio is retained when events exist" do
    metrics = metrics_for("total_webpages" => 203, "publishable_ratio" => 0)

    assert_equal 0.0, metrics[:publishable_ratio]
    assert_nil metrics[:event_horizon_label]
  end

  test "available monitoring values retain their meaning" do
    metrics = metrics_for("total_webpages" => 203, "publishable_ratio" => 100.0, "event_horizon_days" => 916)

    assert_equal 203, metrics[:total_webpages]
    assert_equal 100.0, metrics[:publishable_ratio]
    assert_equal 916, metrics[:event_horizon_label]
  end

  test "schedule risk preserves confirmed on-time results and rejects invalid lateness" do
    { 0 => :ok, "2" => :warning, 4 => :critical }.each do |days, risk|
      metrics = metrics_for("days_overdue" => days)
      assert_equal days.to_i, metrics[:days_overdue]
      assert_equal risk, metrics[:schedule_risk_level]
    end

    [nil, -1, "", "invalid", "1.5"].each do |days|
      metrics = metrics_for("days_overdue" => days)
      assert_nil metrics[:days_overdue]
      assert_nil metrics[:schedule_risk_level]
    end
  end

  private

  def metrics_for(raw)
    MetricsInterpreter.new({ "co-motion-ca" => raw }, []).metrics_for("co-motion-ca", nil)
  end
end
