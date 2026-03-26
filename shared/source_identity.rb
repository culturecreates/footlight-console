# IMPORTANT:
# This file must remain identical across:
# - Console
# - Condenser
# - Wringer
# Do not modify locally — update all copies together.

require "uri"
require "cgi"

class SourceIdentity
  def self.from_url(url)
    new(url)
  end

  def initialize(original_url)
    @original_url = original_url.to_s
  end

  def to_seedurl
    return nil if @original_url.strip.empty?

    cleaned = @original_url.downcase.strip
    cleaned = cleaned.gsub(%r{https?://}, "")
    cleaned = cleaned.gsub("/", "")
    cleaned = cleaned.gsub(".", "-")

    cleaned
  end

  def to_canonical_url
    return "" if @original_url.strip.empty?

    uri = URI.parse(@original_url)

    return "" unless uri.host

    scheme = uri.scheme ? uri.scheme.downcase : "http"
    host   = uri.host.downcase
    path   = uri.path && !uri.path.empty? ? uri.path : "/"

    "#{scheme}://#{host}#{path}"
  rescue URI::InvalidURIError
    ""
  end

  def to_wringer_key
    return "" if @original_url.strip.empty?

    uri = URI.parse(@original_url)

    return "" unless uri.host

    scheme = (uri.scheme || "http").downcase
    host   = uri.host.downcase
    path   = uri.path && !uri.path.empty? ? uri.path : "/"

    url = "#{scheme}://#{host}#{path}"
    url += "?#{uri.query}" if uri.query

    CGI.escape(url)
  rescue URI::InvalidURIError
    ""
  end
end
