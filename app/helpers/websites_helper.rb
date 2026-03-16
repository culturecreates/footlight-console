module WebsitesHelper

  # ----------------------------
  # Service client reuse
  # ----------------------------

  def condenser_client
    @condenser_client ||= CondenserClient.new
  end


  # ----------------------------
  # API helpers (cached)
  # ----------------------------

  def get_events(seedurl)
    Rails.cache.fetch("condenser:events:#{seedurl}", expires_in: 10.minutes) do
      condenser_client.events(seedurl).parsed_response
    end
  rescue StandardError
    []
  end

  def get_places(seedurl)
    Rails.cache.fetch("condenser:places:#{seedurl}", expires_in: 30.minutes) do
      condenser_client.places(seedurl).parsed_response
    end
  rescue StandardError
    []
  end

  def get_dashboard_metrics
    Rails.cache.fetch("condenser:dashboard_metrics", expires_in: 10.minutes) do
      condenser_client.dashboard_metrics.parsed_response
    end
  rescue StandardError
    {}
  end


  # ----------------------------
  # Utility helpers
  # ----------------------------

  def condenser_url
    Rails.application.config_for(:services).dig("condenser","url")
  end

  def condenser_alive?
    get_dashboard_metrics
    true
  rescue StandardError
    false
  end

end