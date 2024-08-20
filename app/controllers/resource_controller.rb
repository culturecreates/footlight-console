class ResourceController < ApplicationController

  # GET /resource/{id} --> For calls coming outside of Footlight (dereferencing)
  def show
    # Do content negotiation
    # Use request header 'Accept'
    # TODO: Try to replace this with rack/content_netgotiation
    format =  if request.headers['Accept'].include?('application/ld+json')
                :jsonld 
              else
                :html
              end

    if format == :jsonld || params[:format] == 'jsonld'
      redirect_to "#{helpers.condenser_url_per_environment}/graphs/webpage/event-artsdata.jsonld?rdf_uri=footlight:#{params[:id]}", status: 303
    else
      redirect_to resource_index_path(uri: "footlight:" + params[:id]), status: 303
    end
  end

  # GET /resource?uri=
  # GET /resource 
  def index 
    if params[:uri] 
      @resource = helpers.condenser_get_resource(params[:uri])
      @seedurl = @resource["seedurl"]
      @statements =  @resource["statements"]
      @webpage_url = @statements.dig('webpage_link_en','value') || @statements.dig('webpage_link_fr','value')
      @webpage_url_fr = @statements.dig('webpage_link_fr','value') 

      @subject_uri = @resource["uri"]

      # microposts
      if @statements
        @microposts_all_statements = { params[:uri] => helpers.get_resource_microposts(@resource, @subject_uri) }
      end
      # derived links
      @links = helpers.condenser_search_statements(@subject_uri)  
      render 'show'
    else
      @resources = helpers.condenser_get_website_resources(cookies[:seedurl])
    end
  end

  # POST /resource/refresh)uri_uri=
  def refresh_uri
    helpers.condenser_refresh_rdf_uri_statements(params[:uri])
    redirect_to resource_index_path(uri: params[:uri])
  end

  def delete_uri
    helpers.condenser_delete_resource(CGI.unescape(params[:id]))
    flash[:success] = "Resource deleted. Attention: events may still be linked to this resource. Please delete individual links manually."
    redirect_to resource_index_url
  end

  def destroy
    helpers.condenser_delete_resource(params[:id])
    flash[:success] = "Resource deleted. Attention: events may still be linked to this resource. Please delete individual links manually."
    redirect_to resource_index_url
  end
end
