class StaticPagesController < ApplicationController
  before_action :logged_in_user, only: :export
 
  def dashboard
    return unless logged_in?

    sort = params[:sort].presence || cookies[:dashboard_sort] || "website"
    dir  = params[:dir].presence  || cookies[:dashboard_dir]  || "asc"

    cookies[:dashboard_sort] = sort
    cookies[:dashboard_dir]  = dir

    @current_sort = sort
    @current_dir  = dir

    @websites = current_user.websites

    @dashboard_rows =
      DashboardBuilder.new(
        websites: @websites,
        helpers: helpers,
        sort: sort,
        dir: dir
      ).build
  end

  def about
  end

  def contact
  end

  def export
    result = WringerCheckService.new(
      seedurl: cookies[:seedurl]
    ).run

    @website_check = result
    @url_to_test_code_snippet = result[:url] || "No URL available"
  end
end
