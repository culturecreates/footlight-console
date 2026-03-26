require "yaml"

class PipelineRuleYamlLoader
  DEFAULT_PATH = Rails.root.join("config/pipeline_rules.yml")

  def self.load(path: DEFAULT_PATH)
    new(path: path).load
  end

  def initialize(path: DEFAULT_PATH)
    @path = Pathname(path)
  end

  def load
    return [] unless File.exist?(path)

    raw = YAML.safe_load(File.read(path), aliases: false)
    rules = extract_rules(raw)
    return [] unless rules.is_a?(Array)

    rules.filter_map.with_index(1) do |entry, fallback_position|
      normalize_rule(entry, fallback_position)
    end
  rescue Psych::SyntaxError
    []
  end

  private

  attr_reader :path

  def extract_rules(raw)
    return raw if raw.is_a?(Array)
    return raw["rules"] if raw.is_a?(Hash)

    []
  end

  def normalize_rule(entry, fallback_position)
    unless entry.is_a?(Hash)
      warn_invalid_rule(nil)
      return nil
    end

    rule = entry.deep_stringify_keys
    name = rule["name"].to_s.strip
    status = rule["status"].to_s.strip
    diagnosis = rule["diagnosis"].to_s.strip
    conditions = normalize_hash(rule["conditions"])

    unless valid_rule?(name: name, status: status, diagnosis: diagnosis, conditions: conditions)
      warn_invalid_rule(name)
      return nil
    end

    {
      name: name,
      conditions: conditions,
      status: status,
      diagnosis: diagnosis,
      position: rule["position"].presence || fallback_position,
      source: :yaml
    }
  end

  def normalize_hash(value)
    value.is_a?(Hash) ? value.deep_stringify_keys : {}
  end

  def valid_rule?(name:, status:, diagnosis:, conditions:)
    name.present? &&
      status.present? &&
      diagnosis.present? &&
      PipelineRule::VALID_STATUSES.include?(status) &&
      conditions["metric"].present?
  end

  def warn_invalid_rule(name)
    Rails.logger.warn("Invalid pipeline rule skipped: #{name.presence || "unnamed"}")
  end
end
