# =============================================================================
# WebsitesController
# =============================================================================
#
# Purpose
# -------
# Manages user-owned websites within the Console application.
#
# A "website" represents an external source of cultural event data that is
# processed through the Footlight ecosystem:
#
#     Website → Wringer (scraping) → Condenser (normalization) → Console UI
#
# This controller handles:
#
#   • CRUD operations on websites owned by the current user
#   • Display of normalized resources coming from Condenser
#   • Editing configuration parameters affecting event ingestion
#   • Cache invalidation when website configuration changes
#
#
# Dashboard Architecture
# ----------------------
# The dashboard view aggregates metrics for each website.
# Metrics are retrieved via DashboardBuilder which queries Condenser APIs
# and applies local analysis.
#
# Request flow:
#
#     Browser
#        ↓
#     WebsitesController#index
#        ↓
#     DashboardBuilder
#        ↓
#     WebsitesHelper (CcAPI client)
#        ↓
#     Condenser API
#        ↓
#     Cached results returned to view
#
#
# Cache Strategy
# --------------
# Dashboard data fetched from Condenser is cached locally in Rails to avoid
# excessive API calls.
#
# Example cache keys:
#
#   condenser:dashboard_metrics
#   condenser:events:<seedurl>
#   condenser:places:<seedurl>
#
# Cache is invalidated when a website configuration is updated.
#
# =============================================================================
class WebsitesController < ApplicationController

  before_action :logged_in_user, only: [:edit, :first_scrape, :create, :destroy, :pipeline]
  before_action :set_website, only: [:show, :edit, :update, :destroy]

  def index
    @websites = current_user.websites

    @dashboard_rows =
      DashboardBuilder.new(
        websites: @websites,
        helpers: helpers,
        sort: "website",
        dir: "asc"
      ).build
  end

  def show
    @data = safe_website_resources @website.url

    if @data.blank? || @data["resources_by_class"].values.flatten.empty?
      render "closed_beta"
    else
      cookies[:seedurl] = @website.url
    end
  end

  def pipeline
    @website = current_user.websites.find(params[:id])

    return head :not_found unless @website.monitorable?

    events_data = safe_events(
      seedurl: @website.url,
      start_date: EventsController::OLDEST_DATE
    )
    events = Array(events_data["events"])

    @rows = PipelineBuilder.call(
      events: events,
      website: @website
    )
    @pipeline_data = @rows
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def edit
  end

  def update
    if @website.update(website_params)
      cookies.delete :event_timezone
      flash[:success] = "Website settings updated."

      Rails.cache.delete("condenser:dashboard_metrics")
      Rails.cache.delete("condenser:events:#{@website.url}")
      Rails.cache.delete("condenser:places:#{@website.url}")

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

    if @website.save
      flash[:success] = "Website added!"
      redirect_to @website
    else
      render 'static_pages/dashboard'
    end
  end

  def destroy
    @website.destroy
    cookies.delete :seedurl

    flash[:success] = "Website removed."

    redirect_to request.referrer || root_url
  end

private

  def set_website
    @website = current_user.websites.find(params[:id])
  end

  def website_params
    params.require(:website).permit(
      :url,
      :scrape,
      :iframe,
      :compress,
      :strict,
      :enabled,
      :archived,
      :theme,
      :exclude_keywords,
      :include_keywords,
      :language,
      :country,
      :timezone,
      :score_damage_problem,
      :score_damage_not_publishable,
      :score_damage_to_review,
      :score_damage_stale,
      :score_damage_overdue_archive,
      :score_health_damage_weight,
      :score_health_anomaly_weight,
      :score_health_schedule_weight,
      :monitorable
    )
  end
end
