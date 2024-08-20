module StatementsHelper

  def attempt_json_pretty json_str
    begin
      website_json = JSON.parse(json_str)
    rescue => e
      website_json = {"@type" => "ERROR", "error" => e}
    end

    return JSON.pretty_generate(website_json)
  end

  def get_help_tip property,lang

    property ||= "blank"

    tips = {
      title: "What is the name of the performance, evening or event? <br><br>Note: sometimes the name of the event is not the same as the work being performed.",
      photo: "What main image are you using to promote the performance?",
      description: "How is the event described? <br><br>Note: alternatives with an asterix (*) in the label will appear here for easy comparison. <br><br><span class='content'>Best practice: shorter is better. Listings will often cut off the description after 2 or 3 sentences.</span>",
      organizedby: "Who is responsible for selling tickets?  <br><br>Note: Usually the presenter or promoter.",
      producedby: "Is this the organization(s) responsible for producing the work?",
      performedby: "Is this the company and/or person responsible for performing the work?",
      eventtype: "Additional types from the Artsdata controlled vocabulary",
      dates: "Please verify calendar dates and times.",
      location: "Is this where the event is happening? One location or virtual location is required.",
      virtuallocation: "URL to the event? One location or virtual location is required.",
      duration: "How long is the event? <br><br>Note: Add a DIV with class 'duration' anywhere to your page.",
      webpagelink: "Is this the right ticket buying page?",
      ticketslink: "Is this the right webpage for the event?",
      price: "Is this the lowest price for the general public (not members only) including sales taxes and service fees?",
      video: "Is this the link to the video of the event?",
      eventstatus: "Is your event scheduled, cancelled, postponed without a date, or rescheduled with a new date?",
      movedonline: "Has your live event moved to an online event?",
      attendancemode: "Do people attend your event in-person or online or mixed with a bit of both?",
      blank: "Missing tip: #{property}"
    }
    tip = tips.dig(property.gsub(/\s+/, "").downcase.to_sym)
    tip = "No tip for this statement: #{property.downcase.to_sym}" if tip.nil?
    return tip
  end


  def build_calendar datetime_str
    begin
      #check if datestime_str is not in an array when only a single date
      datetime_str = "[\"#{datetime_str}\"]" if datetime_str[0] != "["
      datetime_array = JSON.parse(datetime_str)
    rescue
      datetime_array = ["Parse Error in datetime array: #{datetime_str}"]
    end
    #build list of objects to sort
    datetime_objects = []
    datetime_array.each do |t|
      begin
        datetime_objects << DateTime.iso8601(t)
      rescue
        logger.error "invalid date in iso8601 parse for date: #{t}"
      end
    end
    datetime_objects.sort!
    week_objects = []
    datetime_objects.each do |t|
      week_objects <<  t.to_date.beginning_of_week #rhandle the weeks of daylight savings
    end
    week_objects.uniq!

    return [week_objects, datetime_objects]
  end

  def time_of_event_on_date calendar_datetime, datetime_objects, website_timezone = 'Eastern Time (US & Canada)'
    event_times = []
    begin
      datetime_objects[0].in_time_zone(website_timezone)
    rescue => e
      logger.error e
      website_timezone = 'Eastern Time (US & Canada)'
    end

    datetime_objects.each do |dt|
      if dt.to_date == calendar_datetime.to_date
        if dt == dt.midnight
          event_times << "Time unknown"
        else
          event_times << dt.in_time_zone(website_timezone).strftime('%-I:%M %p') 
        end
      end
    end
    return event_times
  end

  def build_duration_array duration_str
    if duration_str[0] == "["
      duration_array = JSON.parse(duration_str)
    else
      duration_array = [] << duration_str
    end

    #validate that Durations are in ISO8601 format PTnS and convert to human readable format
    duration_array.each_with_index do |duration,index|
      if duration[0..1] != "PT"
        duration_array[index] = ""
      else
        duration_array[index] = ChronicDuration.output(duration.delete_prefix("PT").delete_suffix("S").to_i)
      end
    end
    return duration_array.join(", ")
  end

  def display_price(price)
    if !price.blank?
      price[0] != "[" ? sprintf("%.2f", price.to_f) :  price 
    end
  end

  # using a statement id which could be nested, find the top most statement
  def get_top_statment_to_display(stats, id)

    stat = stats.select{ |n,v| v["id"] == id.to_i }.flatten[1]
    return stat unless stat.nil?

    stats.each do |n,v|
      if v["alternatives"]
        v["alternatives"].each do |alt_stat|
          if alt_stat["id"] == id.to_i
            return v
          end
        end
      end
    end
  end

  def has_manual_source_available(stat)
    return true if stat["manual"] == true

    if stat["alternatives"]
      stat["alternatives"].each do |s|
        return true if s["manual"] == true  
      end
    end
    false
  end

  def get_manual_statement_id(stat)
    return stat["id"] if stat["manual"] == true
    if stat["alternatives"]
      stat["alternatives"].each do |s|
        return s["id"] if s["manual"] == true  
      end
    end
    return {error: "no manual statements found."}
  end

  # Count alternatives excluding manual statements that are empty
  def count_alternatives(alt)
    return 0 if alt.nil?

    alt.select { |a| !a["manual"] || (a["manual"] && a["value"].present?) }.count
  end

  # Add a dateTime or date to the list of dates/dateTimes
  def add_dateTime(date_to_add, website_timezone, dates)
    if date_to_add.length < 12 # Date without time
      dates_array = ensure_array(dates) << Date.parse(date_to_add).iso8601.to_s 
    else # DateTime
      current_timezone = Time.zone # stash the system timezone
      website_timezone = 'Eastern Time (US & Canada)' if website_timezone.blank?
      Time.zone = website_timezone
      adjusted_date = Time.zone.parse(date_to_add).iso8601
      dates_array = ensure_array(dates) <<  adjusted_date
      Time.zone = current_timezone # restore the system timezone
    end
    return dates_array
  end

  # Remove a dateTime or date from a list of dates/dateTimes
  def remove_dateTime(date_to_remove,  website_timezone, dates)
    # stash the system timezone
    current_timezone = Time.zone
    website_timezone = 'Eastern Time (US & Canada)' if website_timezone.blank?
    # set to website's timezone
    Time.zone = website_timezone
    dateTime = Time.zone.parse(date_to_remove).iso8601.to_s
    dates_array = []
    ensure_array(dates).map do |d|
      begin
        dates_array << Time.zone.parse(d).beginning_of_minute.iso8601.to_s
      rescue
        # do not add invalid dates
      end
    end
    dates_array.delete(dateTime)
    # set dateTimes at midnight back to Date only so we don't have false time
    dates_array.map! {|d|  Time.zone.parse(d) == Time.zone.parse(d).midnight ? Date.parse(d).iso8601.to_s : d }
    # set back the system timezone
    Time.zone = current_timezone
    return dates_array
  end


  # Ensure an unknown parameter is an Array
  # "one" => ["one"]
  # "[\"one\"],[\"two\"]" => ["one","two"]
  # ["one","two"] => ["one","two"]
  def ensure_array(unknown)
    return unknown if unknown.class == Array
    begin
      # try to convert unknown string to array
      JSON.parse(unknown.to_s)
    rescue JSON::ParserError
      # make string or existing array to array
      Array(unknown)
    end
  end

end
