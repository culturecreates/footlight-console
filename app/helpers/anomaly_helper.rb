#/app/helpers/anomaly_helper.rb
module AnomalyHelper

  Metric = Struct.new(:mean, :std)

  def compute_source_statistics(events, props)
    stats = {}

    props.each do |prop|
      if prop.to_s.downcase == "price"
        numeric_values = []

        events.each do |_uri, statements|
          [:fr, :en, nil].each do |lang|
            key = make_key(prop, lang&.to_s)
            st = statements[key]
            next unless st

            value = st.is_a?(Hash) ? st["value"] : st

            result = extract_numeric_prices(value)
            numeric_values.concat(result[:prices])
          end
        end

        stats[prop] = compute_metric(numeric_values)

      else
        values = []

        events.each do |_uri, statements|
          [:fr, :en, nil].each do |lang|
            key = make_key(prop, lang&.to_s)
            st = statements[key]
            next unless st

            value = st.is_a?(Hash) ? st["value"] : st
            values << value.to_s.length if value.present?
          end
        end

        stats[prop] = compute_metric(values)
      end
    end

    stats
  end

  def compute_metric(values)
    return Metric.new(0, 0) if values.empty?

    mean = values.sum.to_f / values.size
    variance = values.map { |v| (v - mean) ** 2 }.sum / values.size
    std = Math.sqrt(variance)

    Metric.new(mean, std)
  end

  def extract_title(statements)
    value =
      statements["title_fr"]&.dig("value") ||
      statements["title_en"]&.dig("value")

    value.to_s.strip
  end

  def extract_description(statements)
    key = statements.keys.find { |k| k.start_with?("description") }
    value = statements[key]&.dig("value")
    value.to_s.strip
  end

  def extract_dates(statements)
    key = statements.keys.find { |k| k.start_with?("dates") }
    val = statements[key]

    return [] unless val

    if val.is_a?(Array)
      val
    else
      [val]
    end
  end

  def extract_numeric_prices(value)
    arr = value.is_a?(Array) ? value : [value]

    parsed = []
    malformed = false

    arr.each do |v|
      str = v.to_s.strip

      # Accept valid numeric formats like 45.00 or 45,00
      if str.match?(/\A\d+([.,]\d{1,2})?\z/)
        parsed << str.gsub(",", ".").to_f
      else
        malformed = true unless str.empty?
      end
    end

    { prices: parsed, malformed: malformed }
  end

  def analyze_dates(statements, timeline:)
    flags = []
    return flags if timeline.to_s == "all"

    now = Time.zone.now.beginning_of_day

    start_dates = []
    end_dates   = []
    all_dates   = []

    date_keys = statements.keys.select { |k| k.downcase.include?("date") }

    date_keys.each do |key|
      raw = statements[key]&.dig("value")
      next unless raw

      values = raw.is_a?(Array) ? raw : [raw]

      values.each do |v|
        begin
          parsed = Time.parse(v.to_s)
          all_dates << parsed

          if key.downcase.include?("start")
            start_dates << parsed
          elsif key.downcase.include?("end")
            end_dates << parsed
          end

        rescue
          flags << :invalid_date_format
        end
      end
    end

    return flags if all_dates.empty?

    latest = all_dates.max

    # --- Interval logic ---
    if start_dates.any? && end_dates.any?
      if end_dates.max < now
        flags << :event_finished
      end
    else
      # --- Multiple or single dates ---
      if latest < now
        flags << :event_finished
      end
    end

    # --- Far future sanity check (1 year threshold) ---
    if latest > now + 1.year
      flags << :far_future_date
    end

    flags
  end

  def compute_event_health(statements, stats, timeline:)
    health = {
      properties: {},
      event_severity: :ok
    }

    stats.each do |prop, metric|
      [:fr, :en, nil].each do |lang|
        key = make_key(prop, lang&.to_s)
        st = statements[key]
        next unless st

        value = st.is_a?(Hash) ? st["value"] : st
        condenser_status = st.is_a?(Hash) ? st["status"] : nil

        property_health = {
          condenser_status: condenser_status,
          semantic_flags: [],
          statistical_flag: false,
          severity: :ok
        }

        prop_name = prop.to_s.downcase

        case prop_name

        # -------------------
        # TITLE
        # -------------------
        when "title"
          cleaned = value.to_s.gsub(/[[:punct:]]/, "").strip
          if cleaned.length < 2
            property_health[:semantic_flags] << :too_short
          end

        # -------------------
        # DATES
        # -------------------
        when "dates"
          property_health[:semantic_flags] += analyze_dates(statements, timeline: timeline)

        # -------------------
        # DESCRIPTION
        # -------------------
        when "description"
          length = value.to_s.length
          z = z_score(length, metric)
          if z.abs > 3
            property_health[:statistical_flag] = true
          end

        # -------------------
        # PRICE
        # -------------------
        when "price"
          result = extract_numeric_prices(value)
          property_health[:semantic_flags] << :malformed if result[:malformed]

        # -------------------
        # LOCATION
        # -------------------
        when "location"
          if value.to_s.strip.length < 3
            property_health[:semantic_flags] << :too_short
          end
        end

        # -------------------
        # Determine severity (pure anomaly level)
        # -------------------

        if condenser_status == "problem"
          property_health[:severity] = :critical

        elsif condenser_status == "missing"
          property_health[:severity] = :critical

        elsif property_health[:semantic_flags].any?
          property_health[:severity] = :warning

        elsif property_health[:statistical_flag]
          property_health[:severity] = :warning
        end

        health[:properties][key] = property_health
      end
    end

    severities = health[:properties].values.map { |p| p[:severity] }

    if severities.include?(:critical)
      health[:event_severity] = :critical
    elsif severities.include?(:warning)
      health[:event_severity] = :warning
    end

    health
  end

  def z_score(value, metric)
    return 0 if metric.nil?
    return 0 if metric.std.zero?
    return 0 if metric.std < 5
    (value - metric.mean) / metric.std
  end

end