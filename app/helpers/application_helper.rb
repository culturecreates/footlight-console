module ApplicationHelper

  def escape_uri(uri)
    # escape period for rails routes
    CGI.escape(uri).gsub(".","%2E")
  end

  # Returns the full title on a per-page basis.
  def full_title(page_title = '')
    base_title = "Footlight Console"
    base_title += " DEV" if Rails.env.development?
    if page_title.empty?
      base_title
    else
      page_title + " | " + base_title
    end
  end

  def image_helper by_ratio = "", url = ""
    valid_image_url = "https://via.placeholder.com/480x320"  # 3x2 is 480x320
    valid_image_url = "https://via.placeholder.com/640x360" if by_ratio == "16by9"
    valid_image_url = "https://via.placeholder.com/800x480" if by_ratio == "5by3"
    valid_image_url = "https://via.placeholder.com/400x400" if by_ratio == "1by1"
    valid_image_url = "https://via.placeholder.com/1200x400" if by_ratio == "3by1"
    if !url.blank?
      begin
        encoded_url = URI.encode(url)
        uri = URI.parse(encoded_url)
        file_extension = ''
        uri_path = uri.path # check the path for a file extension
        file_extension = uri_path.split(".").last if uri_path.include?(".")
        file_extension.downcase!
        if ["jpg" ,"png" ,"jpeg" ,"jfif", "ashx", "webp"].include?(file_extension) || file_extension.empty?
          valid_image_url = url
        end
      rescue => exception
        logger.error exception
      end
    end
    return valid_image_url
  end

  def check_for_manual_deletion complete_array, uri
    #get the list of manually deleted URIs
    uris_to_delete = []
    complete_array.each do |arr|
      if arr['search'] == "Manually deleted"
        arr['links'].each do |uri_arr|
          uris_to_delete << uri_arr['uri']
        end
      end
    end
    return uris_to_delete.include?(uri)
  end

  def make_key prop, lang
    begin
      _prop = prop.sub(" ", "_").downcase
      _lang = lang.downcase
      key = _prop
      if lang.present?
        key += "_#{_lang}"
      end
    rescue => exception
      key = "failed to make key"
    end
    return key
  end

  # Safely display a statement value (cache)
  # Parse string to JSON if possible
  def display_statement(statement, *mode)
    return unless statement.present?

    return statement.to_s if mode.include?('raw')
    
    html = ''

    begin
      JSON.parse(statement).each do |v|
        html += "#{format_http_link(sanitize(v.to_s))} <br>"
      end
    rescue
      html = format_http_link(sanitize(statement.to_s))
    end
    
    html.html_safe
  end

  def format_http_link(statement)
    if statement.squish.start_with?('http')
      "<a href='#{statement}'>#{statement.truncate(100, omission: "[...]", separator: '/')}</a>"
    elsif statement.include?("abort_update")
      statement.truncate(100, omission: "[...]")
    else
      statement
    end
  end

  def slack_url_per_environment
    slack_base = 'https://hooks.slack.com/services/'
    # Test webhook https://webhook.site/#!/2529f440-39ba-4092-a6e0-f42d3adb3b4e
    Rails.env.development? || Rails.env.test? ? 'https://webhook.site/fe8b509e-3c4c-47d3-9287-e8f6bdb8bd70' : slack_base + ENV['SLACK_NOTIFICATION']
  end


  def display_website_url(seedurl)
    return "" if seedurl.blank?
    seedurl.gsub("-com",".com").gsub("-ca",".ca").gsub("-qc",".qc").gsub("-org",".org")
  end

  def datetime_field_default(str)
    begin
      DateTime.parse(str).strftime("%FT%R")
    rescue
      ''
    end
  end

  def date_field_default(str)
    begin
      Date.parse(str)
    rescue
      ''
    end
  end

  def dereferenceable_link(uri)
    return "/resource?uri=" + CGI.escape(uri)
  end
end
