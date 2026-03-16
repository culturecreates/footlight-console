# app/services/condenser/client.rb
module Condenser
  class Client
    include HTTParty

    DEFAULT_TIMEOUT           = 10
    MAX_RETRIES               = 1
    SLOW_THRESHOLD            = 2.0
    CIRCUIT_BREAKER_THRESHOLD = 5
    CIRCUIT_BREAKER_TIMEOUT   = 30

    SERVICES = Rails.application.config_for(:services).freeze

    def base_url
      ENV.fetch("CONDENSER_URL", SERVICES.dig(:condenser, :url))
    end

    def request(method:, path:, query: nil, body: nil)
      return circuit_open_response(path) if circuit_open?

      req_id = SecureRandom.hex(3)
      url    = "#{base_url}#{path}"
      start  = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      with_retries(method, url, req_id, query, body) do
        response = HTTParty.send(method, url, **request_options(method, query, body))

        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
        status   = response&.code

        # Compact single-line log combining API + client info
        Rails.logger.info(" → [CondenserAPI] #{method.upcase} #{path}#{query ? "?#{query.to_query}" : ""} [#{req_id}] #{duration.round(2)}s status=#{status}")

        # Add a blank line after each request to separate blocks
        Rails.logger.info("")

        reset_failures if success?(response)
        parse_response(response, url)
      end
    end


    private

    def request_options(method, query, body)
      options = { headers: { "Content-Type" => "application/json" }, timeout: DEFAULT_TIMEOUT }
      options[:query] = query if method == :get && query.present?
      options[:body]  = body.to_json if method != :get && body.present?
      options
    end

    def with_retries(method, url, req_id, query, body)
      retries = 0
      begin
        yield
      rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::ECONNRESET => e
        retries += 1
        record_failure
        Rails.logger.warn "[Condenser #{req_id} RETRY #{retries}/#{MAX_RETRIES}] #{method.upcase} #{url} #{e.class}: #{e.message}"
        Rails.logger.debug(AppLogger.clean_backtrace(e).join("\n"))
        retry if retries <= MAX_RETRIES
        AppLogger.error("Condenser #{req_id} FAILED #{method.upcase} #{url}", e)
        nil
      rescue StandardError => e
        AppLogger.error("Condenser #{req_id} #{method.upcase} #{url}", e)
        nil
      end
    end

    def parse_response(response, url)
      return nil unless response
      begin
        if success?(response)
          response.parsed_response
        else
          Rails.logger.warn "[Condenser BAD RESPONSE] status=#{response.code} url=#{url} body=#{response.body&.slice(0,300)}"
          nil
        end
      rescue JSON::ParserError => e
        AppLogger.error("Condenser JSON parse #{url} body=#{response.body&.slice(0,300)}", e)
        nil
      end
    end

    def success?(response)
      response.code.to_s.start_with?("2")
    end

    def current_request_id
      SecureRandom.hex(3)
    end

    def circuit_open?
      opened_at = Rails.cache.read("condenser:circuit_opened_at")
      return false unless opened_at
      if Time.now - opened_at > CIRCUIT_BREAKER_TIMEOUT
        Rails.cache.delete("condenser:circuit_opened_at")
        false
      else
        true
      end
    end

    def circuit_open_response(path)
      Rails.logger.warn("[Condenser CIRCUIT OPEN] skipping request #{path}")
      nil
    end

    def record_failure
      failures = Rails.cache.read("condenser:failures").to_i + 1
      Rails.cache.write("condenser:failures", failures, expires_in: CIRCUIT_BREAKER_TIMEOUT)
      if failures >= CIRCUIT_BREAKER_THRESHOLD
        Rails.cache.write("condenser:circuit_opened_at", Time.now, expires_in: CIRCUIT_BREAKER_TIMEOUT)
        Rails.logger.error("[Condenser CIRCUIT OPENED]")
      end
    end

    def reset_failures
      Rails.cache.delete("condenser:failures")
      Rails.cache.delete("condenser:circuit_opened_at")
    end
  end
end
