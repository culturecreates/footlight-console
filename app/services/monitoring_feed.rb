class MonitoringFeed
  class Unavailable < StandardError; end

  def self.call(seedurl: "all", status: "open", page: 1)
    data = Condenser::API.monitoring_issues(seedurl: seedurl, status: status, page: page)
    valid = data.is_a?(Hash) && data["issues"].is_a?(Array) && data["sites"].is_a?(Array) && data["pagination"].is_a?(Hash)
    raise Unavailable, "Monitoring is unavailable. No current status can be confirmed." unless valid
    valid = data["issues"].all? { |issue| issue.is_a?(Hash) && issue["seedurl"].is_a?(String) && issue["message"].is_a?(String) } &&
      data["sites"].all? { |site| site.is_a?(String) } &&
      %w[page total_pages total_entries].all? { |key| data["pagination"][key].is_a?(Integer) } &&
      data["pagination"]["page"] > 0 && data["pagination"]["total_pages"] >= 0 && data["pagination"]["total_entries"] >= 0
    raise Unavailable, "Monitoring returned an invalid response. No current status can be confirmed." unless valid
    data
  end
end
