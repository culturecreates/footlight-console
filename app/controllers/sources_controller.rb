class SourcesController < ApplicationController
  include AnomalyHelper
  before_action :logged_in_user, only: :update

  OLDEST_DATE = "2015-01-01"

  def index
    cookies[:seedurl] = params[:seedurl] if params[:seedurl].present?
    @sources = Condenser::API.sources(seedurl: cookies[:seedurl])

    allowed_domains = %w[
      Event
      WebPage
      Offer
      AggregateOffer
      ContactPoint
      VirtualLocation
    ]

    @sources.select! do |source|
      allowed_domains.include?(source["domain"]) && source["selected"]
    end
  end

  # Call safe_property_statements seedurl, property, startDate = nil, endDate = nil
  def show
    @property_id = params[:id]
    cookies[:seedurl] = params[:seedurl] if params[:seedurl].present?
    @seedurl = cookies[:seedurl]
    cookies[:timeline] = params[:timeline] if params[:timeline].present?

    raw =
      if cookies[:timeline] == "all"
        safe_property_statements(
          seedurl: @seedurl,
          property_id: @property_id,
          start_date: OLDEST_DATE
        )
      else
        safe_property_statements(
          seedurl: @seedurl,
          property_id: @property_id
        )
      end

    # 🔴 HARD STOP if property does not exist
    unless raw && raw["property_labels"].present?
      raise ActiveRecord::RecordNotFound
    end

    @statements = raw || {}

    @statements["property_labels"] ||= []
    @statements["property_ids"] ||= []
    @statements["events"] ||= {}

    @property_labels = @statements["property_labels"] ||= []
    @property_ids = @statements["property_ids"] ||= []
    @events = @statements["events"] ||= []
    @events = (@events || {}).sort_by do |_, v|
      v.dig("archive_date", "archive_date") || Date.new(1900)
    end

    props = @property_labels.drop(1).reject { |p| p.to_s.strip.downcase == "title" }
    @stats = compute_source_statistics(@events, props)

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
    data = Condenser::API.review_all_statements_by_property params[:id], current_user.name, params[:seedurl]
    if data[:error]
      flash[:danger] = "Failed to review all! #{CGI.escape(data.to_s)}"
    else
      flash[:success] = "All properties reviewed."
    end
    redirect_to source_path(params[:id])
  end
end
