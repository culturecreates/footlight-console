class DashboardBuilder
  SORT_COLUMNS = {
    "website"     => ->(w,_,_) { w.url },
    "webpages"    => ->(w,m,c) { c["event_pages"] },
    "statements"  => ->(w,m,c) { c["statements_grouped"].to_i },
    "flags"       => ->(w,m,c) { c["flags"].to_i },
    "updates"     => ->(w,m,c) { c["updates"].to_i },
    "activity"    => ->(w,m,c) { c["statements_refreshed_24hr"].to_i },
    "inventory_age" => ->(w,m,c) { c.dig("inventory_freshness", "new_event_age_days") || m[:days_since_last_webpage] || Float::INFINITY },
    "publishable" => ->(w,m,c) { c["publishable_event_percentage"] },
    "horizon"     => ->(w,m,c) { m[:event_horizon_days] },
    "overdue"     => ->(w,m,c) { m[:days_overdue] }
  }.freeze

  def initialize(websites:, helpers:, sort:, dir:)
    @websites = websites
    @sort     = sort
    @dir      = dir

    condenser = CondenserStatusService.new(Condenser::API)

    @condenser_websites = condenser.websites
    @metrics_index      = condenser.metrics
    @condenser_available = @condenser_websites.present?

    @condenser_index = @condenser_websites.index_by { |c| c["seedurl"] }
    @bulk_metrics = @metrics_index.values
    @metrics_index   = @metrics_index.with_indifferent_access
    @condenser_index.each do |seedurl, site|
      next unless site.key?("event_pages")

      @metrics_index[seedurl] = (@metrics_index[seedurl] || {}).merge(
        "total_webpages" => site["event_pages"],
        "publishable_ratio" => site["publishable_event_percentage"]
      )
    end

    @metrics_interpreter =
      MetricsInterpreter.new(@metrics_index, @condenser_websites)
  end

  def data_as_of
    timestamps = (@condenser_websites + @bulk_metrics).map do |row|
      stamp = row["data_as_of"] if row.is_a?(Hash)
      Time.iso8601(stamp) if stamp.is_a?(String)
    rescue ArgumentError
      nil
    end
    timestamps.min if timestamps.any? && timestamps.none?(&:nil?)
  end

  def build
    rows = @websites.map do |website|
      condenser = @condenser_index[website.url] || {}
      metrics =
        if @condenser_available
          @metrics_interpreter.metrics_for(website.url, website) || {}
        else
          {}
        end

      {
        website: website,
        condenser: condenser,
        metrics: metrics,
        condenser_available: @condenser_available
      }
    end

    sort_rows(rows)
  end

  private

  def sort_rows(rows)
    sort_proc = SORT_COLUMNS[@sort] || SORT_COLUMNS["website"]

    valued_rows = rows.map do |row|
      [sort_proc.call(row[:website], row[:metrics], row[:condenser]), row]
    end
    known, unknown = valued_rows.partition { |value, _row| !value.nil? }
    known.sort_by! { |value, row| [value, row[:website].url] }
    known.reverse! if @dir == "desc"
    (known + unknown).map(&:last)
  end
end
