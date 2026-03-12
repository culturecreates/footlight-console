module CondenserSafe
  extend ActiveSupport::Concern
  require 'timeout'

  def safe_condenser_call(default:, timeout: 5, &block)
    Timeout.timeout(timeout) do
      result = block.call
      return default if result.nil?
      result
    end
  rescue Timeout::Error => e
    Rails.logger.error "[Condenser TIMEOUT] #{e.message}"
    default
  rescue StandardError => e
    Rails.logger.error "[Condenser ERROR] #{e.class}: #{e.message}"
    default
  end

  def safe_events(seedurl, start_date = nil)
    result = safe_condenser_call(default: { "events" => [] }) do
      helpers.condenser_get_website_events(seedurl, start_date)
    end

    result["events"] = Array(result["events"])
    result
  end

  def safe_property_statements(seed, property_id, start_date = nil)
    safe_condenser_call(default: {
      "property_labels" => [],
      "property_ids"    => [],
      "events"          => {}
    }) do
      helpers.condenser_get_property_statements(seed, property_id, start_date)
    end
  end

  def safe_website_resources(seed)
    result = safe_condenser_call(default: {}) do
      helpers.condenser_get_website_resources(seed)
    end

    result ||= {}
    result["resources_by_class"] ||= {}

    result
  end

  def safe_resource(uri)
    safe_condenser_call(default: {}) do
      helpers.condenser_get_resource(uri)
    end
  end

  def safe_search_statements(uri)
    safe_condenser_call(default: []) do
      helpers.condenser_search_statements(uri)
    end
  end

  def safe_mutation(&block)
    safe_condenser_call(default: nil, &block)
  end

  def call_condenser(action:, default: nil, &block)
    safe_condenser_call(default: default) do
      Rails.logger.info "[Condenser CALL] #{action}"
      block.call
    end
  end

  def process_mutation(action_name)
    data = yield

    unless data.is_a?(Hash)
      flash[:danger] = "Could not #{action_name}."
      redirect_back(fallback_location: root_path)
      return nil
    end

    data
  end
  
end