module MicropostsHelper

  def add_micropost msg
    current_user.microposts.create!(content: msg)
  end

  def get_event_microposts(event, subject_uri)
    return {} if event.blank?

    # ONE query only
    microposts = Micropost
                  .where(related_subject_uri: subject_uri)
                  .order(created_at: :desc)
                  .to_a

    # Group in memory
    grouped = microposts.group_by do |m|
      [m.related_statement_property, m.related_statement_language]
    end

    microposts_all_statements = {}

    event.each do |k, _statement|
      statement_property = extract_property_from_key(k)
      statement_language = extract_language_from_key(k)

      posts = grouped[[statement_property, statement_language]]

      microposts_all_statements[k] = posts if posts.present?
    end

    microposts_all_statements
  end

  def get_resource_microposts(resource, subject_uri)
    return {} unless resource["statements"].present?

    microposts = Micropost
                  .where(related_subject_uri: subject_uri)
                  .order(created_at: :desc)
                  .to_a

    grouped = microposts.group_by do |m|
      [m.related_statement_property, m.related_statement_language]
    end

    microposts_all_statements = {}

    resource["statements"].each do |k, _statement|
      statement_property = extract_property_from_key(k)
      statement_language = extract_language_from_key(k)

      posts = grouped[[statement_property, statement_language]]

      microposts_all_statements[k] = posts if posts.present?
    end

    microposts_all_statements
  end

  def get_property_microposts(uri_list = [], property = "", language = "")
    Micropost.where(
      related_statement_property: property.sub(" ","_").downcase,
      related_statement_language: language,
      related_subject_uri: uri_list)
  end


  def delete_posts_belonging_statement_property event, subject_uri, key
    statement_property =  extract_property_from_key key
    statement_language = extract_language_from_key key

    cleanup_posts = Micropost.where(
          related_statement_property: statement_property,
          related_statement_language: statement_language,
          related_subject_uri: subject_uri)

    puts "deleting posts #{cleanup_posts.inspect}"
    cleanup_posts.destroy_all

  end

  def extract_property_from_key key
      if key.include?("_en") || key.include?("_fr")
        return key.gsub(/^(.*)_.*/,'\1')
      else
        return key
      end

  end

  def extract_language_from_key key
    if key.include?("_en") || key.include?("_fr")
      return key.gsub(/^.*_(.*)/,'\1')
    else
      return ""
    end
  end

end
