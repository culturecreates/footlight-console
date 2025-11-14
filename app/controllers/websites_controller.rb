class WebsitesController < ApplicationController
  before_action :logged_in_user, only: [:edit, :first_scrape, :create, :destroy ]

  def index
      @websites = current_user.websites
  end

  def show
      @website = Website.find(params[:id])

      @data = helpers.condenser_get_website_resources @website.url
      if @data.blank? || @data["resources_by_class"].values.flatten.empty?
        render "closed_beta"
      else
        cookies[:seedurl] = @website.url
      end
  end

  def edit
      
      @website = Website.find(params[:id])
  end

  def update
    @website = Website.find(params[:id])
    if @website.update(website_params)
      cookies.delete :event_timezone
      flash[:success] = "Website settings updated."
      redirect_to dashboard_path
    else
      render 'edit'
    end
  end


  def first_scrape
    @website = Website.new
  end

  def closed_beta
    @websites = current_user.websites
  end

  def create
    @website = current_user.websites.build(website_params)
    #replace .com with -com
    @website.url = @website.url.gsub(".","-")
    if @website.save
      flash[:success] = "Website added!"
      redirect_to @website
    else
      render 'static_pages/dashboard'
    end
  end

  def destroy
    Website.find(params[:id]).destroy
    cookies.delete :seedurl
    flash[:success] = "Website removed."
    redirect_to request.referrer || root_url
  end


  private
    def website_params
      params.require(:website).permit(:url,:image_ratio, :timezone, :iframe)
    end


end
