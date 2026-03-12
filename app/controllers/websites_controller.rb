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

  # ---------------------------------------------------------------------------
  # Filters
  # ---------------------------------------------------------------------------

  # Ensures user authentication before performing actions that modify data.
  before_action :logged_in_user, only: [:edit, :first_scrape, :create, :destroy]

  # Loads the website belonging to the current user for relevant actions.
  before_action :set_website, only: [:show, :edit, :update, :destroy]


  # ---------------------------------------------------------------------------
  # Dashboard / Website List
  # ---------------------------------------------------------------------------

  # Displays the list of websites owned by the current user.
  #
  # For each website, dashboard metrics are computed via DashboardBuilder.
  #
  # DashboardBuilder collects:
  #   - condenser statistics
  #   - event health metrics
  #   - anomaly detection results
  #
  # The resulting rows are sorted and rendered in the dashboard table.
  #
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


  # ---------------------------------------------------------------------------
  # Website Resource View
  # ---------------------------------------------------------------------------

  # Displays normalized resources belonging to a website.
  #
  # Data is fetched from Condenser via `safe_website_resources`.
  #
  # If no resources are available (e.g. scraping has not yet succeeded),
  # the "closed_beta" page is rendered.
  #
  # The selected website seedurl is stored in a cookie so that other parts
  # of the application can reference the currently active source.
  #
  def show
    @data = safe_website_resources @website.url

    if @data.blank? || @data["resources_by_class"].values.flatten.empty?
      render "closed_beta"
    else
      cookies[:seedurl] = @website.url
    end
  end


  # ---------------------------------------------------------------------------
  # Website Configuration
  # ---------------------------------------------------------------------------

  # Displays the website configuration form.
  #
  # Configuration parameters influence event ingestion behaviour,
  # including timezone normalization, iframe rendering options,
  # and scoring weights for event quality metrics.
  #
  def edit
  end


  # Updates website configuration parameters.
  #
  # After updating:
  #   • dashboard-related caches are invalidated
  #   • user is redirected back to the dashboard
  #
  # Cache invalidation ensures that changes affecting event scoring
  # are reflected immediately in dashboard metrics.
  #
  def update
    if @website.update(website_params)

      cookies.delete :event_timezone
      flash[:success] = "Website settings updated."

      # Clear cached condenser data
      Rails.cache.delete("condenser:dashboard_metrics")
      Rails.cache.delete("condenser:events:#{@website.url}")
      Rails.cache.delete("condenser:places:#{@website.url}")

      redirect_to dashboard_path
    else
      render 'edit'
    end
  end


  # ---------------------------------------------------------------------------
  # Website Creation
  # ---------------------------------------------------------------------------

  # Displays initial scraping setup page.
  #
  # Used when onboarding a new website into the system.
  #
  def first_scrape
    @website = Website.new
  end


  # Displays closed-beta placeholder when resources are unavailable.
  #
  # This view explains that the website has not yet been successfully
  # processed by the ingestion pipeline.
  #
  def closed_beta
    @websites = current_user.websites
  end


  # Creates a new website associated with the current user.
  #
  # After creation the user is redirected to the website page
  # where scraping and ingestion status can be inspected.
  #
  def create
    @website = current_user.websites.build(website_params)

    if @website.save
      flash[:success] = "Website added!"
      redirect_to @website
    else
      render 'static_pages/dashboard'
    end
  end


  # ---------------------------------------------------------------------------
  # Website Deletion
  # ---------------------------------------------------------------------------

  # Deletes a website owned by the current user.
  #
  # Associated cookies are cleared to avoid referencing removed sources.
  #
  def destroy
    @website.destroy
    cookies.delete :seedurl

    flash[:success] = "Website removed."

    redirect_to request.referrer || root_url
  end


private


  # ---------------------------------------------------------------------------
  # Utility Methods
  # ---------------------------------------------------------------------------

  # Finds the website belonging to the current user.
  #
  # Prevents users from accessing or modifying websites belonging
  # to other accounts.
  #
  def set_website
    @website = current_user.websites.find(params[:id])
  end


  # Strong parameters for website configuration.
  #
  # Limits which fields may be modified through forms.
  #
  def website_params
    params.require(:website).permit(
      :url,
      :timezone,
      :iframe,
      :image_ratio,
      :far_future_years,
      :old_past_years,

      # Monitoring thresholds used by DashboardBuilder
      :min_publishable_ratio,
      :warning_days_since_last_webpage,
      :critical_days_since_last_webpage,
      :warning_event_horizon_days,
      :critical_event_horizon_days,

      weight_overrides: {}
    )
  end

end