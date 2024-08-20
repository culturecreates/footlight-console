module EventsHelper

  def calculate_thumbnail_icon event
    icon_name = ''
    if !event["statements_status"].blank?
      if event["statements_status"]["problem"] == true
        icon_name = PROBLEM_ICON
      elsif event["statements_status"]["to_review"] == false
        icon_name = OK_ICON
      end
    end
    return icon_name
  end

  def events_by_status events, status
    events_by_status = []
    events.each do |event|
      if !event["statements_status"].blank?
        events_by_status << event if event["statements_status"][status]
      end
    end
    return events_by_status
  end

  def events_with_comments events
    events_with_comments = []
    rdf_url_list = events.map {|e| e["rdf_uri"]}
    uris_with_comments = Micropost.where(related_subject_uri: [rdf_url_list]).pluck(:related_subject_uri).uniq
    events.each do |event|
      if uris_with_comments.include?(event["rdf_uri"])
        events_with_comments << event
      end
    end
    return events_with_comments
  end


  def set_status_icon status
    if status == "problem"
      PROBLEM_ICON
    elsif status == "missing"
      MISSING_ICON
    elsif status == "initial"
      INITIAL_ICON
    elsif status == "updated"
      UPDATED_ICON
    elsif status == "ok"
      OK_ICON
    end
  end

  def tag_colour rdfs_class
    class_colours = {"city" => "is-primary", "place" => "is-primary", "organization" => "is-info", "category" => "is-link"}
    tag = class_colours[rdfs_class.downcase]
    tag = "is-danger" if class_colours[rdfs_class.downcase].nil?
    return tag
  end


  def is_valid_condensor_uri link_array
    if link_array.present?
      if link_array[0]['class']
        return true 
      end
    end
    return false
  end



  def get_local_uri_label link
    if link.class == String
      begin
        link = JSON.parse(link)
      rescue
        return link  #not parsable
      end
    end
    if link.class == Array
      link = link.first
    end
    if link.class == Hash && link[:search]
      link = link[:search]
    else
      link = "#{link}"
    end
    return link
  end

  def is_bilingual_event event
    if event["title_fr"].blank?
      return false
    else
      if event["title_en"].blank?
        return false
      else
        return true
      end
    end
  end

  def is_francophone_event event
    if event["title_en"].blank?
      return true
    else
      return false
    end
  end


  def image_ratio
    ratio = ""
    if cookies[:image_ratio]
      db_ratio = cookies[:image_ratio]
      ratio = "16by9" if db_ratio == "16:9"
      ratio = "3by2" if db_ratio == "3:2"
      ratio = "1by1" if db_ratio == "1:1"
      ratio = "5by3" if db_ratio == "5:3"
      ratio = "3by1" if db_ratio == "3:1"

    end
    return ratio
  end

end
