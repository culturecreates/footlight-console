module MicropostsHelper

  def add_micropost msg
    current_user.microposts.create!(content: msg)
  end

  def get_event_microposts event, subject_uri
    microposts_all_statements = {}
    if !event.blank?
      event.each do |k,statement|
        statement_property = extract_property_from_key k
        statement_language = extract_language_from_key k
        microposts_relation = Micropost.where(
              related_statement_property: statement_property,
              related_statement_language: statement_language,
              related_subject_uri: subject_uri)
        microposts_all_statements[k] = microposts_relation if microposts_relation.count > 0
      end
    end
    return microposts_all_statements
  end

  def get_resource_microposts resource, subject_uri
    microposts_all_statements = {}
    if resource["statements"].present?
      resource["statements"].each do |k,statement|
        statement_property = extract_property_from_key k
        statement_language = extract_language_from_key k
        microposts_relation = Micropost.where(
              related_statement_property: statement_property,
              related_statement_language: statement_language,
              related_subject_uri: subject_uri)
        microposts_all_statements[k] = microposts_relation if microposts_relation.count > 0
      end
    end
    return microposts_all_statements
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
