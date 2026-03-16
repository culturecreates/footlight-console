module EventsHelper
  require 'set'

  def calculate_thumbnail_icon event
    icon_name = ''
    status = event["statements_status"]
    return '' unless status

    return PROBLEM_ICON if status["problem"]
    return OK_ICON if status["to_review"] == false

    ''
  end

  def events_by_status(events, status)
    events.select do |event|
      event["statements_status"]&.[](status)
    end
  end

  def events_with_comments(events)
    rdf_url_list = events.map { |e| e["rdf_uri"] }.compact.uniq
    return [] if rdf_url_list.empty?

    uris_with_comments = Micropost
      .where(related_subject_uri: rdf_url_list)
      .distinct
      .pluck(:related_subject_uri)
      .to_set

    events.select { |e| uris_with_comments.include?(e["rdf_uri"]) }
  end


  STATUS_ICON_MAP = {
    "problem" => PROBLEM_ICON,
    "missing" => MISSING_ICON,
    "initial" => INITIAL_ICON,
    "updated" => UPDATED_ICON,
    "ok"      => OK_ICON
  }.freeze

  def set_status_icon(status)
    STATUS_ICON_MAP[status]
  end

  CLASS_COLOURS = {
    "city"         => "is-primary",
    "place"        => "is-primary",
    "organization" => "is-info",
    "category"     => "is-link"
  }.freeze

  def tag_colour(rdfs_class)
    CLASS_COLOURS[rdfs_class.to_s.downcase] || "is-danger"
  end


  def is_valid_condensor_uri(link_array)
    link_array.present? && link_array.first&.[]('class').present?
  end


  def get_local_uri_label(link)
    parsed =
      link.is_a?(String) ? (JSON.parse(link) rescue link) : link

    case parsed
    when Array
      parsed.first.to_s
    when Hash
      (parsed[:search] || parsed["search"] || parsed).to_s
    else
      parsed.to_s
    end
  end


  def is_bilingual_event(event)
    event["title_fr"].present? && event["title_en"].present?
  end

  def is_francophone_event(event)
    event["title_en"].blank?
  end


  RATIO_MAP = {
    "16:9" => "16by9",
    "3:2"  => "3by2",
    "1:1"  => "1by1",
    "5:3"  => "5by3",
    "3:1"  => "3by1"
  }.freeze

  def image_ratio
    RATIO_MAP[cookies[:image_ratio]] || ""
  end

end
