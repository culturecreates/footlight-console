class EventsController < ApplicationController
  require 'will_paginate/array'
  require 'set'
  before_action :logged_in_user, only: [:review_event, :destroy]

  # ==========================================
  # CONSTANTS
  # ==========================================
  # OLDEST_DATE defines the earliest date to request events for.
  OLDEST_DATE = "2015-01-01"

  # ==========================================
  # GET /events
  # Lists events for the selected website (seedurl).
  #
  # Query Parameters (via URL or cookies):
  #   - seedurl: The unique identifier of the website (required).
  #   - filter: Optional event filter ('all', 'new', 'updated', 'flagged', 'commented', 'publishable').
  #   - timeline: Optional, 'all' to fetch past events; default fetches upcoming only.
  #   - page: Optional, current pagination page.
  #   - view: Optional, either 'list' (show all events in one page) or default pagination.
  #
  # Behavior:
  #   - Uses `safe_events` to fetch events from Condenser API.
  #   - Applies filter and pagination to the event collection.
  #   - Includes micropost information for each event.
  #
  # Example Calls:
  #   GET /events?seedurl=theatregranada-com
  #   GET /events?seedurl=theatregranada-com&timeline=all
  #
  # Returns:
  #   @events -> Array of event hashes, each including :rdf_uri, :title, :date, :archive_date, :microposts
  #   @event_count -> Total events before filtering/pagination
  #
  # Note:
  #   - To fetch all past events, use timeline='all' and start_date=OLDEST_DATE
  #   - Filters are applied after fetching events; empty filter resets to 'all'
  # ==========================================
  def index
    # -------------------------------
    # Load and persist user preferences in cookies
    # -------------------------------
    cookies[:page]     = params[:page]     if params[:page].present?
    cookies[:view]     = params[:view]     if params[:view].present?
    cookies[:timeline] = params[:timeline] if params[:timeline].present?
    cookies[:seedurl]  = params[:seedurl]  if params[:seedurl].present?
    cookies[:filter]   = params[:filter]   if params[:filter].present?

    # Store image_ratio for website if seedurl is present
    if cookies[:seedurl].present?
      cookies[:image_ratio] =
        Website.where(url: cookies[:seedurl], user_id: current_user)
               .pluck(:image_ratio)
               .first
    end

    # -------------------------------
    # Fetch events from Condenser API
    # -------------------------------
    if cookies[:timeline] == "all"
      # Include all events from OLDEST_DATE to today
      data = safe_events(seedurl: cookies[:seedurl], start_date: OLDEST_DATE)
    else
      # Only upcoming events
      data = safe_events(seedurl: cookies[:seedurl])
    end

    # -------------------------------
    # Flash notifications
    # -------------------------------
    if data["events"].empty?
      if cookies[:timeline] == "all"
        flash.now[:info] = "No events found."
      else
        flash.now[:info] = "No upcoming events."
      end
    end

    events = data["events"] || []
    @event_count = events.count

    # -------------------------------
    # Prepare filtered collections
    # -------------------------------
    @events_to_review   = helpers.events_by_status(events, "to_review")
    @events_with_updates = helpers.events_by_status(events, "updated")
    @events_with_issues  = helpers.events_by_status(events, "problem")
    @events_publishable  = helpers.events_by_status(events, "publishable")
    @events_with_comments = helpers.events_with_comments(events)

    @events = events

    # Apply filter if present
    case cookies[:filter]
    when "new"
      @events = @events_to_review
    when "updated"
      @events = @events_with_updates
    when "flagged"
      @events = @events_with_issues
    when "commented"
      @events = @events_with_comments
    when "publishable"
      @events = @events_publishable
    end

    # Reset filter if no events match
    @events = events if @events.empty? && cookies[:filter] != "all"

    # -------------------------------
    # Pagination
    # -------------------------------
    per_page = cookies[:view] == "list" ? 1000 : 15
    page = cookies[:page].to_i
    page = 1 if page <= 0
    page = 1 if @events.count <= per_page * (page - 1)
    @events = @events.paginate(page: page, per_page: per_page)

    # -------------------------------
    # Attach micropost info
    # -------------------------------
    uris = @events.map { |e| e["rdf_uri"] }
    uris_with_posts = Micropost.where(related_subject_uri: uris)
                               .distinct
                               .pluck(:related_subject_uri)
                               .to_set
    @events.each do |event|
      event[:microposts] = uris_with_posts.include?(event["rdf_uri"])
    end

    # -------------------------------
    # Render
    # -------------------------------
    if @events.present?
      render(cookies[:view] == "list" ? 'index_list' : 'index')
    else
      flash[:danger] = "Error getting events."
      redirect_to root_path
    end
  end

  def show
    data = data = safe_resource(id: params[:id])

    unless data.present?
      flash[:danger] = "Error getting Event."
      redirect_to root_path and return
    end

    @seedurl = data["seedurl"]
    cookies[:seedurl] = @seedurl
    @subject_uri = data["uri"]
    @event = data["statements"]
    @archive_date = data["archive_date"]
    

    if @event.present?
      @website = Website.where(url: @seedurl, user_id: current_user).first
      @webpage_url = @event.dig('webpage_link_en','value') || @event.dig('webpage_link_fr','value')
      @webpage_url_fr = @event.dig('webpage_link_fr','value') 
      if @website&.iframe 
        url = @webpage_url 
        url ||= @webpage_url_fr
        if url.present? && url.start_with?("http")
          @iframe_url = url.gsub("http://","https://")  
        end
        #####################################################
        ## START of hard coded exceptions for cohort member

        if @seedurl == "radarts-ca" 
          url = @webpage_url 
          url ||= @webpage_url_fr
          escaped_url = CGI.escape(url)
          path = "/websites/wring?uri=#{escaped_url}&format=raw&include_fragment=true&absolute_src=true"
          if Rails.env.development?
            @iframe_url =  "http://localhost:3009#{path}" 
          else
            @iframe_url =  "https://footlight-wringer.herokuapp.com#{path}" 
          end
        end
        ## END of Hard coded exceptions for cohort members
        #####################################################
      end

      ## add microposts
      @microposts_all_statements = { params[:id] => helpers.get_event_microposts(@event, @subject_uri) } 

      if @archive_date.present?
        begin
          if Date.parse(@archive_date.to_s) <= Date.today
            flash.now[:info] = "Footlight is no longer automatically updating this event daily (#{@archive_date})."
          end
        rescue
          Rails.logger.warn "Invalid archive_date format: #{@archive_date}"
        end
      end
    else 
      flash[:danger] = "Error getting Event."
      redirect_to root_path
    end
  end

  def review_event
    data = Condenser::API.review_all_statements params[:event_id], current_user.name, params[:review_next], params[:seedurl]
    if data.blank?
      flash[:danger] = "Failed to update!"
      redirect_back(fallback_location: root_path)
    else
      if params[:review_next] == "true"
        flash[:success] = %Q[Event reviewed successfully. Displaying next event...]
        redirect_to event_path(id: data["uri"])
      else
        flash[:success] = %Q[Event reviewed successfully. #{view_context.link_to('Back to events', events_path)}.]
        redirect_back(fallback_location: root_path)
      end

      # # micro post
      # msg = data.dig("statements","title_en","value")
      # msg = data.dig("statements","title_fr","value") if msg.present?
      # helpers.add_micropost "Reviewed Event #{msg}"
    end
  end

  def destroy
    #add call to condenser to destroy
    data = Condenser::API.delete_resource params[:event_id]

    if data[:error] then
      flash[:danger] = "Failed to unlink event."
      redirect_to root_path
    else
      @event_to_delete = params[:event_id].split(':')[1]
    end
  end
end
