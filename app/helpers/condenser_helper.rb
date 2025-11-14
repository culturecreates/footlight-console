module CondenserHelper
  def condenser_get_websites
    return call_condenser "/websites.json"
  end

  def condenser_get_website_resources seedurl
    return call_condenser "/websites/#{seedurl}/resources.json"
  end

  def condenser_get_website_events seedurl, startDate = nil, endDate = nil
    return call_condenser "/websites/#{seedurl}/events.json?startDate=#{startDate}&endDate=#{endDate}"
  end

  def condenser_get_property_statements seedurl, property, startDate = nil, endDate = nil
    return call_condenser "/websites/#{seedurl}/events_by_property.json?property=#{property}&startDate=#{startDate}&endDate=#{endDate}"
  end

  def condenser_get_property_id source_id
    response = call_condenser "/sources/#{source_id}.json"
    return response["property_id"]
  end

  def condenser_get_resource id
    return call_condenser "/resources.json?uri=#{CGI.escape(id)}"
  end

  def condenser_delete_resource id
    return call_condenser "/resources/delete_uri.json?uri=#{CGI.escape(id)}", :delete
  end

  def condenser_review_all_statements event_id, user_name, review_next = "false", seedurl = ""
    return call_condenser "/resources/#{CGI.escape(event_id)}/reviewed_all.json", :patch, { "event": {"status_origin": user_name}, "review_next": review_next, "seedurl": seedurl}
  end
  def condenser_refresh_rdf_uri_statements id
   # http://localhost:3000/statements/refresh_rdf_uri?rdf_uri=footlight%3A0dd3f982-f9b1-421c-893a-91b75bc14ad2
   return call_condenser "/statements/refresh_rdf_uri.json?rdf_uri=#{CGI.escape(id)}", :patch
  end

  def condenser_search_statements cache
    return call_condenser "/statements.json?cache=#{cache}"
  end

  def condenser_activate_statement statement_id
    return call_condenser "/statements/#{statement_id}/activate.json", :patch
  end

  def condenser_activate_individual_statement statement_id
    return call_condenser "/statements/#{statement_id}/activate_individual.json", :patch
  end

  def condenser_deactivate_individual_statement statement_id
    return call_condenser "/statements/#{statement_id}/deactivate_individual.json", :patch
  end

  def condenser_save_individual_statement statement_id, value, user_name
    return call_condenser "/statements/#{statement_id}.json", :patch, { "statement": {"cache": value.to_s,"status": "ok", "status_origin": user_name} }
  end

  def condenser_review_statement statement_id, user_name
    return call_condenser "/statements/#{statement_id}.json", :patch, { "statement": {"status": "ok", "status_origin": user_name} }
  end

  def condenser_flag_statement statement_id, user_name
    return call_condenser "/statements/#{statement_id}.json", :patch, { "statement": {"status": "problem", "status_origin": user_name} }
  end

  def condenser_reconnect_feed_statement statement_id, user_name
    return call_condenser "/statements/#{statement_id}.json", :patch, { "statement": {"manual": false, "status_origin": user_name} }
  end

  def condenser_update_linked_data statement_id, user_name, options={}
    return call_condenser "/statements/#{statement_id}.json", :patch, { "statement": {"cache": "[\"#{options[:name]}\",\"#{options[:rdfs_class]}\",\"#{options[:uri]}\"]", "status": "ok", "status_origin": user_name} }
  end

  def condenser_add_linked_data statement_id, user_name, options={}
    return call_condenser "/statements/#{statement_id}/add_linked_data.json", :patch, { "statement": {"cache": "[\"#{options[:name]}\",\"#{options[:rdfs_class]}\",\"#{options[:uri]}\"]", "status": "ok", "status_origin": user_name} }
  end

  def condenser_create_linked_resource rdfs_class, seedurl, options={}
    return call_condenser "/resources.json", :post, { rdfs_class: rdfs_class, seedurl: seedurl, statements: options }
  end
  
  def condenser_remove_linked_data statement_id, user_name, options={}
    return call_condenser "/statements/#{statement_id}/remove_linked_data.json", :patch, { "statement": {"cache": "[\"#{options[:name]}\",\"#{options[:rdfs_class]}\",\"#{options[:uri]}\"]", "status": "ok", "status_origin": user_name} }
  end

  def condenser_get_sources seedurl
    return call_condenser "/sources.json?seedurl=#{seedurl}"
  end

  def condenser_review_all_statements_by_property property_id, user_name, seedurl
    return call_condenser "/properties/#{property_id}/review_all_statements.json", :patch, { "status": "ok", "status_origin": user_name, "seedurl": seedurl }
  end

  def condenser_url_per_environment
    if Rails.env.development? || Rails.env.test?
      'https://footlight-condenser.herokuapp.com'
      #'http://localhost:3000'
    else
      'https://footlight-condenser.herokuapp.com'
    end
  end
  
  private

  def call_condenser(path, method = :get, body = {})
    auth = {
      username: "kim", # Rails.application.credentials.basic_authentication[:username], 
      password: "footlight" #Rails.application.credentials.basic_authentication[:password]
    }
    
    begin
      if method == :get
        puts "Calling condenser GET #{condenser_url_per_environment + path}"
        result = HTTParty.get(condenser_url_per_environment + path, basic_auth: auth)
      elsif method == :patch
        result = HTTParty
                 .patch(condenser_url_per_environment + path,
                        body: body.to_json,
                        headers: { 'Content-Type' => 'application/json' },
                        basic_auth: auth)
      elsif method == :post
        result = HTTParty
                  .post(condenser_url_per_environment + path,
                        body: body.to_json,
                        headers: { 'Content-Type' => 'application/json' },
                        basic_auth: auth)
      elsif method == :delete
        result = HTTParty
                 .delete(condenser_url_per_environment + path,
                         body: body.to_json,
                         headers: { 'Content-Type' => 'application/json' },
                         basic_auth: auth)
      end
      if result.response.code[0] != '2'
        return { error: result.response.inspect }
      end

      data = if result.body
               JSON.parse(result.body)
             else
               { message: 'Response body empty.' }
             end
    rescue => e
      data = { error: "Failed to call condensor. #{e}" }
    end
    data
  end





end
