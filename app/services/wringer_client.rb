# WringerClient is a normalization layer for Wringer responses.
# It does NOT change how Wringer is called.
# It is NOT yet integrated in main flow.
# It prepares for future observability and DSL trace integration.
class WringerClient
  def self.fetch(url)
    new(url).fetch
  end

  def initialize(url = nil)
    @url = url
  end

  def fetch
    start_time = Time.now

    response = call_wringer

    {
      url: @url,
      status: extract_status(response),
      html: extract_html(response),
      final_url: extract_final_url(response),
      redirect_chain: extract_redirect_chain(response),
      signals: extract_signals(response),
      error: extract_error(response),
      duration_ms: ((Time.now - start_time) * 1000).to_i
    }
  rescue StandardError => e
    {
      url: @url,
      status: :error,
      html: nil,
      final_url: nil,
      redirect_chain: [],
      signals: {},
      error: {
        type: e.class.name,
        message: e.message
      },
      duration_ms: ((Time.now - start_time) * 1000).to_i
    }
  end

  private

  def call_wringer
    CcWringerHelper.use_wringer(@url)
  end

  def extract_status(response)
    return :error if response.nil?

    if response.is_a?(Array) && response.first == "abort_update"
      :error
    else
      :ok
    end
  end

  def extract_html(response)
    return nil if error_response?(response)

    response
  end

  def extract_final_url(_response)
    nil
  end

  def extract_redirect_chain(_response)
    []
  end

  def extract_signals(_response)
    {}
  end

  def extract_error(response)
    return nil unless error_response?(response)

    payload = response[1] rescue nil

    {
      type: payload && payload[:error_type] ? payload[:error_type].to_s : "unknown",
      message: payload && payload[:error] ? payload[:error].to_s : "unknown error"
    }
  end

  def error_response?(response)
    response.is_a?(Array) && response.first == "abort_update"
  end
end
