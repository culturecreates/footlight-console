class EventsController < ApplicationController
  require 'will_paginate/array'
  before_action :logged_in_user, only: [:review_event, :destroy]

  OLDEST_DATE = "2015-01-01"

  def index
    cookies[:page] = params[:page] if !params[:page].blank?
    cookies[:view] = params[:view] if !params[:view].blank?
    cookies[:timeline] = params[:timeline] if !params[:timeline].blank?
    cookies[:seedurl] = params[:seedurl] if !params[:seedurl].blank?
    cookies[:image_ratio] = Website.where(url: cookies[:seedurl], user_id: current_user).pluck(:image_ratio).first
    cookies[:filter] = params[:filter] if !params[:filter].blank?

    if cookies[:timeline] == "all"
      data = helpers.condenser_get_website_events(cookies[:seedurl],OLDEST_DATE )
    else
      data = helpers.condenser_get_website_events(cookies[:seedurl])
      if data["events"]
        if  data["events"].count == 0
          cookies[:timeline] = "all"
          data = helpers.condenser_get_website_events(cookies[:seedurl],OLDEST_DATE )
          flash.now[:danger] = "No upcoming events."
        end
      end
    end

    if data["events"]
      @event_count = data["events"].count

      @events_to_review = helpers.events_by_status(data["events"], "to_review")
      @events_with_updates = helpers.events_by_status(data["events"], "updated")
      @events_with_issues = helpers.events_by_status(data["events"], "problem")
      @events_publishable = helpers.events_by_status(data["events"], "publishable")
      @events_with_comments = helpers.events_with_comments(data["events"])
      @events = data["events"]

      ## set filter
      if cookies[:filter]  == "new"
        @events = @events_to_review
      elsif cookies[:filter]  == "updated"
        @events = @events_with_updates
      elsif cookies[:filter]  == "flagged"
        @events = @events_with_issues
      elsif cookies[:filter]  == "commented"
        @events = @events_with_comments
      elsif cookies[:filter]  == "publishable"
        @events = @events_publishable
      end
      ## prevent 0 results in a filter
      if  @events.count == 0
        cookies[:filter] = 'all'
        @events = data["events"]  
      end

      # paginate
      if  cookies[:view] != "list"
        per_page = 15
      else
        per_page = 1000
      end

      if @events.count <= per_page * (cookies[:page].to_i - 1)
        cookies[:page] = 1
      end
      @events = @events.paginate(page: cookies[:page], per_page: per_page)

      @events.each do |event|
        microposts = Micropost.where(related_subject_uri: event["rdf_uri"])
        event[:microposts] =  microposts.present?
      end
    end

    if !@events.blank?
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
    data = helpers.condenser_get_resource(params[:id])
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

      if @archive_date.to_date <= Date.today
        flash.now[:info] = "Footlight is no longer automatically updating this event daily (#{@archive_date.to_date})."
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
      # msg = data.dig("statements","title_fr","value") if msg.blank?
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
