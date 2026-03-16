module SourcesHelper

  # Returns the property path for a given source_id
  def property_path_from_source(source_id)
    property_id = condenser_get_property_id(source_id)
    return nil unless property_id

    source_path(property_id)
  end


  # Resolve property_id for a given source_id
  # Uses Condenser API and caches results per request
  def condenser_get_property_id(source_id)

    return nil if source_id.blank?

    @source_property_cache ||= {}

    return @source_property_cache[source_id] if @source_property_cache.key?(source_id)

    response = Condenser::API.source(id: source_id)

    property_id = response&.dig("property_id")

    @source_property_cache[source_id] = property_id

  rescue => e
    Rails.logger.warn "[SourcesHelper] property lookup failed for #{source_id}: #{e.message}"
    nil
  end

end
