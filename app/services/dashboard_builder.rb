class DashboardBuilder
  SORT_COLUMNS = {
    "website"     => ->(w,_,_) { w.url },
    "webpages"    => ->(w,m,c) { c["webpages"].to_i },
    "statements"  => ->(w,m,c) { c["statements_grouped"].to_i },
    "flags"       => ->(w,m,c) { c["flags"].to_i },
    "updates"     => ->(w,m,c) { c["updates"].to_i },
    "pipeline"    => ->(w,m,c) { m[:pipeline_health].to_i },
    "activity"    => ->(w,m,c) { c["statements_refreshed_24hr"].to_i },
    "health"      => ->(w,m,c) { m[:health_score].to_i },
    "publishable" => ->(w,m,c) { m[:publishable_ratio].to_i },
    "horizon"     => ->(w,m,c) { m[:event_horizon_days].to_i },
    "overdue"     => ->(w,m,c) { m[:days_overdue].to_i }
  }.freeze

  def initialize(websites:, helpers:, sort:, dir:)
    @websites = websites
    @sort     = sort
    @dir      = dir

    condenser = CondenserStatusService.new(Condenser::API)

    @condenser_websites = condenser.websites
    @metrics_index      = condenser.metrics
    @condenser_available = condenser.available?

    @condenser_index = @condenser_websites.index_by { |c| c["seedurl"] }
    @metrics_index   = @metrics_index.with_indifferent_access

    @metrics_interpreter =
      MetricsInterpreter.new(@metrics_index, @condenser_websites)
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

    rows = rows.sort_by do |row|
      w = row[:website]
      m = row[:metrics]
      c = row[:condenser]

      value = sort_proc.call(w, m, c)
      [value, w.url]
    end

    rows.reverse! if @dir == "desc"
    rows
  end
end