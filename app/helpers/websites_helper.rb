module WebsitesHelper

  class CcAPI
    include HTTParty

    base_uri  "https://footlight-condenser.herokuapp.com"  # "localhost:3000"

    def initialize
    end

    def events(seedurl)
      return self.class.get("/websites/#{seedurl}/events")
    end

    def places(seedurl)
      return self.class.get("/websites/places.json?seedurl=#{seedurl}")
    end

    def statements(rdf_uri)
      self.class.get("/statements/event.json?rdf_uri=#{rdf_uri}")
    end
  end


  def get_events(seedurl)
    api = CcAPI.new
    data = JSON.parse api.events(seedurl).body
    return data
  end

  def get_places(seedurl)
    api = CcAPI.new
    data = JSON.parse api.places(seedurl).body
    return data
  end
end
