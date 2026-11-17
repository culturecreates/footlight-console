class MonitoringController < ApplicationController
  before_action :logged_in_user
  before_action :admin_user

  def index
    @seedurl = params[:seedurl].presence || "all"
    @status = params[:status].in?(%w[open resolved all]) ? params[:status] : "open"
    @page = params[:page].to_i.clamp(1, 100_000)
    @feed = MonitoringFeed.call(seedurl: @seedurl, status: @status, page: @page)
  rescue MonitoringFeed::Unavailable => error
    @monitoring_error = error.message
    render :index, status: :service_unavailable
  end

  private

  def admin_user
    head :forbidden unless current_user&.admin?
  end
end
