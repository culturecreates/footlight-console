class WringerCheckService
  def initialize(seedurl:)
    @seedurl = seedurl
    @condenser = CondenserClient.new
    @wringer = WringerClient.new
  end

  def run
    events = fetch_events
    event  = find_publishable_event(events)

    return no_event unless event

    resource = safe_resource(event["rdf_uri"])
    url = extract_webpage(resource)

    return no_url unless url

    wringer_result(url)
  rescue StandardError => e
    { error: "Wringer check failed: #{e.message}" }
  end

  private

  def fetch_events
    data = @condenser.events(@seedurl).parsed_response
    data["events"] || []
  end

  def find_publishable_event(events)
    events
      .select { |e| e.dig("statements_status","publishable") }
      .last
  end

  def extract_webpage(resource)
    resource["statements"]
      .values
      .find { |s| s["label"] == "Webpage link" }
      &.dig("value")
  end

  def wringer_result(url)
    result = @wringer.wring(url)

    if result.response.code.start_with?("2")
      if result.body.present?
        { message: result.body, url: url }
      else
        { message: "Response body empty.", url: url }
      end
    else
      { error: result.response.inspect, url: url }
    end
  end

  def no_event
    { message: "No pages with a publishable event." }
  end

  def no_url
    { message: "Publishable event found but no webpage link." }
  end
end