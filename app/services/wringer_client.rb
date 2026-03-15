class WringerClient
  include HTTParty

  base_uri Rails.application.config_for(:services).dig("wringer","url")

  def wring(uri)
    Rails.logger.info("[Wringer] wringing #{uri}")

    response = self.class.get(
      "/websites/wring",
      query: {
        uri: uri,
        use_phantomjs: true,
        format: "raw",
        force_scrape_every_hrs: 2
      }
    )

    Rails.logger.info("[Wringer] status=#{response.code}")

    response
  end
end