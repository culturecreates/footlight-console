class PipelineRuleResolver
  def self.rules_for(website)
    new(website).rules
  end

  def initialize(website)
    @website = website
  end

  def rules
    scoped_website_rules = website_rules
    return scoped_website_rules if scoped_website_rules.any?

    scoped_global_rules = global_rules
    return scoped_global_rules if scoped_global_rules.any?

    PipelineRuleYamlLoader.load
  end

  private

  attr_reader :website

  def website_rules
    return [] if website_id.blank?

    database_rules_for(website_id)
  end

  def global_rules
    database_rules_for(nil)
  end

  def website_id
    return nil unless website.respond_to?(:id)

    website.id
  end

  def database_rules_for(id)
    scope = PipelineRule.active.ordered
    scope = id.nil? ? scope.where(website_id: nil) : scope.where(website_id: id)
    scope.map(&:to_resolved_rule)
  end
end
