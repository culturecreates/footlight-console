# frozen_string_literal: true

class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  include SessionsHelper
  default_form_builder BulmaFormBuilder

  before_action :set_cache_headers, :set_event_timezone

  private

  def set_event_timezone
    if !cookies[:event_timezone]
      if cookies[:seedurl] && logged_in?
        website = Website.where(url: cookies[:seedurl], user_id: current_user).first
        cookies[:event_timezone] = website.timezone
      else
        cookies[:event_timezone] = 'Eastern Time (US & Canada)'
      end
    end
    @event_timezone ||= cookies[:event_timezone] 
  end
 
  # Confirms a logged-in user.
  def logged_in_user
    unless logged_in?
      store_location
      flash[:danger] = 'Please log in.'
      redirect_to login_url
    end
  end

  def set_cache_headers
    response.headers['Cache-Control'] = 'no-cache, no-store, max-age=0, must-revalidate'
    response.headers['Pragma'] = 'no-cache'
    response.headers['Expires'] = 'Fri, 01 Jan 1990 00:00:00 GMT'
  end

end
