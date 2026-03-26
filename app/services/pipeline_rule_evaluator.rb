class PipelineRuleEvaluator
  INVALID_RULE_DIAGNOSIS = "Invalid rule configuration".freeze
  DEPRECATED_METRICS = %w[
    wringer_failure_rate
    condenser_failure_rate
    console_review_rate
    artsdata_success_rate
  ].freeze

  def self.evaluate(rules:, metrics:)
    new(rules, metrics).evaluate
  end

  def initialize(rules, metrics)
    @rules = rules
    @metrics = metrics || {}
  end

  def evaluate
    Array(@rules).map { |rule| evaluate_rule(rule) }
  end

  private

  attr_reader :metrics

  def evaluate_rule(rule)
    normalized_rule = normalize_rule(rule)
    conditions = normalized_rule[:conditions]

    return invalid_rule_result(normalized_rule) unless valid_conditions?(conditions)

    metric_name = conditions["metric"]
    return deprecated_metric_result(normalized_rule, metric_name) if deprecated_metric?(metric_name)
    return missing_metric_result(normalized_rule, metric_name) if missing_metric?(metric_name)

    operator = normalize_operator(conditions["operator"])
    metric_value = normalize_value(metric_for(metric_name))
    expected_value = normalize_value(conditions["value"])

    {
      name: normalized_rule[:name],
      status: normalized_rule[:status],
      diagnosis: normalized_rule[:diagnosis],
      triggered: apply_operator(metric_value, operator, expected_value)
    }
  rescue StandardError
    invalid_rule_result(normalized_rule || rule)
  end

  def apply_operator(metric_value, operator, expected_value)
    case operator
    when "lt"
      return false if metric_value.nil? || expected_value.nil?

      metric_value < expected_value
    when "lte"
      return false if metric_value.nil? || expected_value.nil?

      metric_value <= expected_value
    when "gt"
      return false if metric_value.nil? || expected_value.nil?

      metric_value > expected_value
    when "gte"
      return false if metric_value.nil? || expected_value.nil?

      metric_value >= expected_value
    when "eq", "=="
      metric_value == expected_value
    else
      metric_value == expected_value
    end
  end

  def normalize_rule(rule)
    hash = rule.respond_to?(:deep_symbolize_keys) ? rule.deep_symbolize_keys : {}
    hash[:conditions] = normalize_conditions(hash[:conditions])
    hash
  end

  def normalize_conditions(conditions)
    return conditions.deep_stringify_keys if conditions.is_a?(Hash)

    conditions
  end

  def valid_conditions?(conditions)
    conditions.is_a?(Hash) && conditions["metric"].present?
  end

  def normalize_operator(operator)
    normalized = operator.to_s.downcase
    normalized.present? ? normalized : "eq"
  end

  def normalize_value(value)
    return value unless value.is_a?(String)

    case value.strip.downcase
    when "true"
      true
    when "false"
      false
    else
      Float(value, exception: false) || value
    end
  end

  def metric_for(metric_name)
    return nil if metric_name.nil?
    return metrics[metric_name.to_s] if metrics.key?(metric_name.to_s)
    return metrics[metric_name.to_sym] if metrics.key?(metric_name.to_sym)

    nil
  end

  def metric_present?(metric_name)
    metrics.key?(metric_name.to_s) || metrics.key?(metric_name.to_sym)
  end

  def missing_metric?(metric_name)
    !metric_present?(metric_name) || metric_for(metric_name).nil?
  end

  def deprecated_metric?(metric_name)
    DEPRECATED_METRICS.include?(metric_name.to_s)
  end

  def invalid_rule_result(rule)
    normalized_rule = rule.respond_to?(:deep_symbolize_keys) ? rule.deep_symbolize_keys : {}

    {
      name: normalized_rule[:name],
      status: "critical",
      diagnosis: INVALID_RULE_DIAGNOSIS,
      triggered: true,
      error: true
    }
  end

  def deprecated_metric_result(rule, metric_name)
    Rails.logger.warn("Deprecated metric used: #{metric_name}")

    {
      name: rule[:name],
      status: "warning",
      diagnosis: "Deprecated metric used: #{metric_name}",
      triggered: true,
      deprecated: true
    }
  end

  def missing_metric_result(rule, metric_name)
    {
      name: rule[:name],
      status: "warning",
      diagnosis: "Missing metric value: #{metric_name}",
      triggered: false,
      missing_metric: true
    }
  end
end
