class EventsController < ApplicationController
  require 'will_paginate/array'
  require 'set'
  before_action :logged_in_user, only: [:review_event, :destroy]

  OLDEST_DATE = "2015-01-01"

  def index
    cookies[:page] = params[:page] if params[:page].present?
    cookies[:view] = params[:view] if params[:view].present?
    cookies[:timeline] = params[:timeline] if params[:timeline].present?
    cookies[:seedurl] = params[:seedurl] if params[:seedurl].present?
    if cookies[:seedurl].present?
      cookies[:image_ratio] =
        Website.where(url: cookies[:seedurl], user_id: current_user)
              .pluck(:image_ratio)
              .first
    end
    cookies[:filter] = params[:filter] if params[:filter].present?

    if cookies[:timeline] == "all"
      data = safe_events(cookies[:seedurl],OLDEST_DATE )
    else
      data = safe_events(cookies[:seedurl])
      if data["events"].empty?
        cookies[:timeline] = "all"
        data = safe_events(cookies[:seedurl], OLDEST_DATE)
        flash.now[:danger] = "No upcoming events."
      end
    end

    events = data["events"] || []
    @event_count = events.count

      @events_to_review = helpers.events_by_status(events, "to_review")
      @events_with_updates = helpers.events_by_status(events, "updated")
      @events_with_issues = helpers.events_by_status(events, "problem")
      @events_publishable = helpers.events_by_status(events, "publishable")
      @events_with_comments = helpers.events_with_comments(events)

      @events = events
      
      ## set filter
      if cookies[:filter] == "new"
        @events = @events_to_review
      elsif cookies[:filter] == "updated"
        @events = @events_with_updates
      elsif cookies[:filter] == "flagged"
        @events = @events_with_issues
      elsif cookies[:filter] == "commented"
        @events = @events_with_comments
      elsif cookies[:filter] == "publishable"
        @events = @events_publishable
      end
      
      ## prevent 0 results in a filter
      if @events.empty?
        cookies[:filter] = 'all'
        @events = events
      end

      # paginate
      if  cookies[:view] != "list"
        per_page = 15
      else
        per_page = 1000
      end

      page = cookies[:page].to_i
      page = 1 if page <= 0
      if @events.count <= per_page * (page - 1)
        page = 1
      end
      @events = @events.paginate(page: page, per_page: per_page)

      uris = @events.map { |e| e["rdf_uri"] }

      uris_with_posts = Micropost
        .where(related_subject_uri: uris)
        .distinct
        .pluck(:related_subject_uri)
        .to_set

      @events.each do |event|
        event[:microposts] = uris_with_posts.include?(event["rdf_uri"])
      end

    if @events.present?
      if cookies[:view] == "list"
        render 'index_list'
      else
        render 'index'
      end
    else
      flash[:danger] = "Error getting events."
      redirect_to root_path
    end
  end

  def show
    data = safe_resource(params[:id])
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
    data = helpers.condenser_review_all_statements params[:event_id], current_user.name, params[:review_next], params[:seedurl]
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
    data = helpers.condenser_delete_resource params[:event_id]

    if data[:error] then
      flash[:danger] = "Failed to unlink event."
      redirect_to root_path
    else
      @event_to_delete = params[:event_id].split(':')[1]
    end
  end
end
