class SourcesController < ApplicationController
  before_action :logged_in_user, only: :update

  OLDEST_DATE = "2015-01-01"

  def index
    cookies[:seedurl] = params[:seedurl] if params[:seedurl].present?
    @sources = helpers.condenser_get_sources(cookies[:seedurl])
    @sources.select! {|source| 
     (source["domain"] == "Event" || 
      source["domain"] == "WebPage" || 
      source["domain"] == "Offer"  || 
      source["domain"] == "AggregateOffer"  || 
      source["domain"] == "ContactPoint"  || 
      source["domain"] == "VirtualLocation") &&  
      source["selected"]}
      
  end

  def source_id
    source_id = params[:source_id]
    property_id = helpers.condenser_get_property_id(source_id)
    redirect_to source_path(id: property_id)
  end

  # Call condenser_get_property_statements seedurl, property, startDate = nil, endDate = nil
  def show
    @property_id = params[:id]
    cookies[:seedurl] = params[:seedurl] if params[:seedurl].present?
    @seedurl = cookies[:seedurl]
    cookies[:timeline] = params[:timeline] if !params[:timeline].blank?

    if cookies[:timeline] == "all"
      @statements = helpers.condenser_get_property_statements(cookies[:seedurl], @property_id, OLDEST_DATE )
    else
      @statements = helpers.condenser_get_property_statements(cookies[:seedurl], @property_id)
     
      if @statements.count == 0
        cookies[:timeline] = "all"
        @statements = helpers.condenser_get_property_statements(cookies[:seedurl], @property_id, OLDEST_DATE )
        flash.now[:danger] = "No upcoming events."
      end
    end

    @property_labels = @statements["property_labels"] ||= []
    @property_ids = @statements["property_ids"] ||= []
    @events = @statements["events"] ||= []
    @events = @events.sort_by {|n,v| v["archive_date"]["archive_date"]}


     property_title = @property_labels[1] ||= ""
     #TO DO: make one language only
     property_language = ['','en','fr'] #  @statements["events"].first[1]["language"]
     #create list of URIs
     uris =  @events&.map {|statement| statement[0]}


     #  @microposts_all_statements = {"adr:spec-qc-ca_neuf-titre-provisoire"=>{"title_fr"=>[#<Micropost id: 142, ...>]}}

     microposts = helpers.get_property_microposts(uris, property_title, property_language)
     
     @microposts_all_statements = Hash.new { |h,k| h[k] = {} }
     if microposts.count > 0 
      ##key = helpers.make_key(property_title, property_language)
       # @microposts_all_statements = microposts.group_by(&:related_subject_uri)
       microposts.each do |mp|
          key = helpers.make_key(mp.related_statement_property, mp.related_statement_language)
          @microposts_all_statements[mp.related_subject_uri][key] = [] if @microposts_all_statements[mp.related_subject_uri][key].nil?
          @microposts_all_statements[mp.related_subject_uri][key] << mp
       end
     else
      @microposts_all_statements = {}
     end
     @website = Website.where(url: cookies[:seedurl], user_id: current_user).first
  end

  # Review all statements by property (can include en and fr sources)
  # PATCH /sources/1?seedurl=
  def update
    data = helpers.condenser_review_all_statements_by_property params[:id], current_user.name, params[:seedurl]
    if data[:error]
      flash[:danger] = "Failed to review all! #{CGI.escape(data.to_s)}"
    else
      flash[:success] = "All properties reviewed."
    end
    redirect_to source_path(params[:id])
  end
end
