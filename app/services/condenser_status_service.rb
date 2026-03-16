#app/services/condenser_status_service.rb
class CondenserStatusService
  CACHE_TTL = 30.seconds

  def initialize(client = Condenser::API)
    @client = client
  end

  def websites
    Rails.cache.fetch("condenser:websites", expires_in: CACHE_TTL) do
      fetch_websites
    end
  end

  def metrics
    Rails.cache.fetch("condenser:metrics", expires_in: CACHE_TTL) do
      fetch_metrics
    end
  end

  def available?
    websites.present?
  end

  private

  def fetch_websites
    result = @client.websites
    return result if result.is_a?(Array)

    Rails.logger.warn("Condenser returned invalid websites payload")
    []
  rescue StandardError => e
    AppLogger.error("CondenserStatusService websites", e)
    []
  end

  def fetch_metrics
    result = @client.dashboard_metrics
    return result if result.is_a?(Hash)

    Rails.logger.warn("Condenser returned invalid metrics payload")
    {}
  rescue StandardError => e
    Rails.logger.warn("Condenser metrics fetch failed: #{e.message}")
    {}
  end
end