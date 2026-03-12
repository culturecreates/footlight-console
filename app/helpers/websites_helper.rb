module WebsitesHelper

  class CcAPI
    include HTTParty

    BASE_URL =
      Rails.env.development? ?
        "http://127.0.0.1:3000" :
        "https://footlight-condenser.herokuapp.com"

    base_uri BASE_URL

    def base_url
      BASE_URL
    end

    def events(seedurl)
      self.class.get("/websites/#{seedurl}/events", timeout: 10)
    end

    def places(seedurl)
      self.class.get("/websites/places.json", query: { seedurl: seedurl }, timeout: 10)
    end

    def statements(rdf_uri)
      self.class.get("/statements/event.json", query: { rdf_uri: rdf_uri }, timeout: 10)
    end

    def dashboard_metrics
      self.class.get("/dashboard_metrics.json", timeout: 10)
    end
  end


  # ----------------------------
  # API client reuse
  # ----------------------------

  def condenser_api
    @condenser_api ||= CcAPI.new
  end


  # ----------------------------
  # API helpers
  # ----------------------------

  def get_events(seedurl)
    Rails.cache.fetch("condenser:events:#{seedurl}", expires_in: 10.minutes) do
      condenser_api.events(seedurl).parsed_response
    end
  rescue
    []
  end

  def get_places(seedurl)
    Rails.cache.fetch("condenser:places:#{seedurl}", expires_in: 30.minutes) do
      condenser_api.places(seedurl).parsed_response
    end
  rescue
    []
  end

  def get_dashboard_metrics
    Rails.cache.fetch("condenser:dashboard_metrics", expires_in: 10.minutes) do
      condenser_api.dashboard_metrics.parsed_response
    end
  rescue
    {}
  end

  def condenser_url
    condenser_api.base_url
  end

  def condenser_alive?
    safe_dashboard_metrics
    true
  rescue
    false
  end

end