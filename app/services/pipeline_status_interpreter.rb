class PipelineStatusInterpreter
  DEFAULT_DIAGNOSIS = "No pipeline issues detected".freeze
  NO_RULES_EVALUATED_DIAGNOSIS = "No rules evaluated".freeze
  STATUS_MAP = {
    "ok" => :ok,
    "warning" => :warning,
    "critical" => :error,
    "error" => :error
  }.freeze

  def self.call(website:, metrics:, rules: nil)
    new(website, metrics, rules: rules).call
  end

  def initialize(website, metrics, rules: nil)
    @website = website
    @metrics = metrics
    @rules = rules
  end

  def call
    rules = evaluated_rules
    return no_rules_result if rules.blank?

    match = rules.find { |rule| rule[:triggered] }
    return default_result unless match

    {
      status: normalize_status(match[:status]),
      diagnosis: match[:diagnosis].to_s
    }
  end

  private

  attr_reader :website, :metrics, :rules

  def evaluated_rules
    resolved_rules = rules || PipelineRuleResolver.rules_for(website)
    PipelineRuleEvaluator.evaluate(rules: resolved_rules, metrics: metrics)
  end

  def normalize_status(status)
    STATUS_MAP[status.to_s] || :error
  end

  def default_result
    {
      status: :ok,
      diagnosis: DEFAULT_DIAGNOSIS
    }
  end

  def no_rules_result
    {
      status: :error,
      diagnosis: NO_RULES_EVALUATED_DIAGNOSIS
    }
  end
end
