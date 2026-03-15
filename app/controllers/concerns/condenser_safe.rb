# app/controllers/concerns/condenser_safe.rb
#
# Safe wrappers around Condenser API calls.
#
# Responsibilities:
#   • Normalize parameters
#   • Provide safe defaults
#   • Catch and log API errors
#
# IMPORTANT
#   All methods use keyword arguments.
#   Controllers should never call Condenser::API directly.

module CondenserSafe
  extend ActiveSupport::Concern

  private

  # ------------------------------------------------------------
  # Normalize parameters
  #
  # Ensures consistent types and removes nil values.
  # ------------------------------------------------------------
  def normalize_params(**params)
    normalized = params.compact

    normalized[:property_id] = normalized[:property_id].to_i if normalized[:property_id]

    normalized
  end

  # ------------------------------------------------------------
  # Core safety wrapper
  # ------------------------------------------------------------
  def safe_condenser(default:, action:)
    result = yield
    result.nil? ? default : result
  rescue StandardError => e
    AppLogger.error("Condenser #{action}", e)
    default
  end


  # ============================================================
  # EVENTS
  # ============================================================

  def safe_events(seedurl:, start_date: nil)
    params = normalize_params(seedurl: seedurl, start_date: start_date)

    safe_condenser(default: { "events" => [] }, action: "events #{seedurl}") do
      Condenser::API.website_events(**params)
    end.tap do |result|
      result["events"] = Array(result["events"])
    end
  end


  # ============================================================
  # PROPERTY STATEMENTS
  # ============================================================

  def safe_property_statements(seedurl:, property_id:, start_date: nil)
    params = normalize_params(
      seedurl: seedurl,
      property_id: property_id,
      start_date: start_date
    )

    safe_condenser(
      default: { "property_labels" => [], "property_ids" => [], "events" => {} },
      action: "property #{seedurl}/#{property_id}"
    ) do
      Condenser::API.property_statements(**params)
    end
  end


  # ============================================================
  # WEBSITE RESOURCES
  # ============================================================

  def safe_website_resources(seedurl:)
    params = normalize_params(seedurl: seedurl)

    safe_condenser(default: {}, action: "resources #{seedurl}") do
      Condenser::API.website_resources(**params)
    end.tap do |result|
      result["resources_by_class"] ||= {}
    end
  end


  # ============================================================
  # SINGLE RESOURCE (EVENT PAGE)
  # ============================================================

  def safe_resource(id:)
    safe_condenser(default: {}, action: "resource #{id}") do
      Condenser::API.resource(id: id)
    end
  end


  # ============================================================
  # SEARCH STATEMENTS
  # ============================================================

  def safe_search_statements(uri:)
    safe_condenser(default: [], action: "search #{uri}") do
      Condenser::API.search_statements(uri: uri)
    end
  end


  # ============================================================
  # GENERIC MUTATION
  # ============================================================

  def safe_mutation(action:)
    safe_condenser(default: nil, action: action) do
      yield
    end
  end

end
