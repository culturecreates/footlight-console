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
      redirect_to "#{Condenser::API.base_url}/graphs/webpage/event-artsdata.jsonld?rdf_uri=footlight:#{params[:id]}", status: 303
    else
      redirect_to resource_index_path(uri: "footlight:" + params[:id]), status: 303
    end
  end

  # GET /resource?uri=
  # GET /resource 
  def index 
    if params[:uri] 
      @resource = safe_resource(id: params[:uri])

      unless @resource["uri"].present?
        flash[:danger] = "Could not load resource."
        redirect_to root_path and return
      end

      @seedurl = @resource["seedurl"]
      @statements = @resource["statements"] || {}
      @webpage_url =
        @statements.dig('webpage_link_en','value') ||
        @statements.dig('webpage_link_fr','value') ||
        @statements.dig('url','value')
      @webpage_url_fr = @statements.dig('webpage_link_fr','value')

      @subject_uri = @resource["uri"]

      @microposts_all_statements = {
        params[:uri] => helpers.get_resource_microposts(@resource, @subject_uri)
      }

      @links = safe_search_statements(@subject_uri)
      render 'show'
    else
      seedurl = params[:seedurl] || cookies[:seedurl]
      @resources = safe_website_resources(seedurl: seedurl)
    end
  end

  # POST /resource/refresh_uri?uri=
  def refresh_uri
    uri = params[:uri]

    unless uri.present?
      flash[:danger] = "Missing resource URI."
      redirect_to resource_index_path and return
    end

    Condenser::API.refresh_rdf_uri_statements(rdf_uri: uri)

    redirect_to resource_index_path(uri: uri)
  end

  def delete_uri
    Condenser::API.delete_resource_uri(uri: CGI.unescape(params[:id]))
    flash[:success] = "Resource deleted. Attention: events may still be linked to this resource. Please delete individual links manually."
    redirect_to resource_index_url
  end

  def destroy
    Condenser::API.delete_resource_uri(uri: params[:id])
    flash[:success] = "Resource deleted. Attention: events may still be linked to this resource. Please delete individual links manually."
    redirect_to resource_index_url
  end
end
