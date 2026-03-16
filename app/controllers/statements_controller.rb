# =============================================================================
# StatementsController
# -----------------------------------------------------------------------------
# Handles activation, review, and manual editing of statements attached to
# events. These actions communicate with the Condenser service and update the
# UI asynchronously using JS partial rendering.
#
# Responsibilities
# - Call Condenser API endpoints through helper layer
# - Validate responses and extract event data
# - Build micropost structures for the UI
# - Render updated statements via JS partials
#
# Notes
# - Condenser calls are wrapped by `call_condenser`
# - `validate_statement_response` ensures safe processing
# - `condenser_service` allows dependency injection for testing
# =============================================================================

class StatementsController < ApplicationController
  before_action :logged_in_user

  # ===========================================================================
  # Activate a statement
  #
  # Activates the selected statement through the Condenser and refreshes the
  # corresponding event display.
  # ===========================================================================
  def activate
    perform_statement_action(:activate_statement) do
      condenser_service.condenser_activate_statement(params[:id])
    end
  end

  # ===========================================================================
  # Activate a specific individual statement
  #
  # Unlike `activate`, this targets only a single statement instance.
  # ===========================================================================
  def activate_individual
    perform_statement_action(:activate_individual_statement) do
      condenser_service.condenser_activate_individual_statement(params[:id])
    end
  end

  # ===========================================================================
  # Deactivate an individual statement
  # ===========================================================================
  def deactivate_individual
    perform_statement_action(:deactivate_individual_statement) do
      condenser_service.condenser_deactivate_individual_statement(params[:id])
    end
  end

  # ===========================================================================
  # Reconnect a statement to its feed
  #
  # Turns a manual statement back into an automatically managed feed statement.
  # ===========================================================================
  def reconnect_feed
    data = call_condenser(action: :reconnect_feed_statement) do
      condenser_service.condenser_reconnect_feed_statement(params[:id], current_user.name)
    end

    return unless validate_statement_response(data, "reconnect feed")

    @event = data["statements"]

    if @event.blank?
      flash[:danger] = "Could not update statement #{params[:id]}."
      redirect_back(fallback_location: root_path)
      return
    end

    stat = helpers.get_top_statement_to_display(@event, params[:id])

    @subject_uri = data["uri"]
    @microposts_all_statements = build_microposts(@event, @subject_uri)

    respond_to do |format|
      format.html { redirect_back fallback_location: root_path }

      format.js do
        render partial: "events/render_statement",
               locals: { stat: stat }
      end
    end
  end

  # ===========================================================================
  # Review a statement
  #
  # Delegates processing to Statements::Reviewer service object.
  # ===========================================================================
  def review_statement
    result = Statements::Reviewer.call(
      statement_id: params[:id],
      user_name: current_user.name
    )

    unless result.success?
      flash[:danger] = "Could not update statement #{params[:id]}."
      redirect_back(fallback_location: root_path) and return
    end

    @event = result.event
    @subject_uri = result.subject_uri
    @microposts_all_statements = result.microposts
    stat = result.stat

    respond_to do |format|
      format.html { redirect_back fallback_location: root_path }
      format.js   { render partial: "events/render_statement", locals: { stat: stat } }
    end
  end

  # ===========================================================================
  # Manual statement editing UI
  # ---------------------------------------------------------------------------

  # Display form for manual statement editing
  def edit_manual_statement
    @statement_id = params[:statement_id]
    @manual_statement_id = params[:manual_statement_id]
  end

  # Cancel manual editing
  def cancel_edit_manual_statement
    @statement_id = params[:statement_id]
  end

  # ===========================================================================
  # Save manual statement
  #
  # Handles manual edits to statements and activates the statement if needed.
  # ===========================================================================
  def save_manual_statement
    value = normalize_statement_value

    id = params[:id]
    @old_statement_id = params[:old_statement_id]

    data = call_condenser(action: :save_manual_statement) do
      Condenser::API.save_individual_statement(
        id: id,
        value: value,
        user_name: current_user.name
      )
    end

    return unless validate_statement_response(data, "save statement")

    activation_data = activate_statement_if_needed(id, @old_statement_id)
    data = activation_data if activation_data.present?

    if data["statements"].blank?
      flash[:danger] = "Could not update statement #{params[:id]}."
      redirect_back(fallback_location: root_path)
      return
    end

    render_statement_update(data, params[:id])

    seedurl = data["seedurl"] || cookies[:seedurl]
    Rails.cache.delete("dashboard_metrics:#{seedurl}") if seedurl
  end

  # ===========================================================================
  # PRIVATE METHODS
  # ===========================================================================

  private

  # ---------------------------------------------------------------------------
  # Perform a generic statement action
  #
  # This method centralizes logic used by activate/deactivate endpoints.
  # ---------------------------------------------------------------------------
  def perform_statement_action(action_name)
    @old_statement_id = params[:old_statement_id]

    data = call_condenser(action: action_name) { yield }

    return unless validate_statement_response(data, action_name.to_s.tr("_", " "))

    if multiple_events?
      render template: "force_page_reload"
    else
      render_statement_update(data, params[:id])
    end
  end

  # ---------------------------------------------------------------------------
  # Detect if multiple events were updated and a full page reload is required
  # ---------------------------------------------------------------------------
  def multiple_events?
    ActiveModel::Type::Boolean.new.cast(params[:multiple_events])
  end

  # ---------------------------------------------------------------------------
  # Normalize statement value before saving
  #
  # Handles timezone adjustments when adding or removing datetime values.
  # ---------------------------------------------------------------------------
  def normalize_statement_value
    return params[:value] unless params[:timezone]

    if params[:del?]
      helpers.remove_dateTime(params[:value], params[:timezone], params[:merge_with])
    else
      helpers.add_dateTime(params[:value], params[:timezone], params[:merge_with])
    end
  end

  # ---------------------------------------------------------------------------
  # Activate a statement if the ID has changed
  # ---------------------------------------------------------------------------
  def activate_statement_if_needed(id, old_id)
    return nil if id == old_id

    data = call_condenser(action: :activate_statement) do
      Condenser::API.activate_statement(id: id)
    end

    return nil unless validate_statement_response(data, "activate statement")

    data
  end

  # ---------------------------------------------------------------------------
  # Render updated statement after condenser action
  #
  # Centralizes event extraction, micropost construction, and UI rendering.
  # ---------------------------------------------------------------------------
  def render_statement_update(data, statement_id, partial: "events/render_statement")
    @event = data["statements"]
    @subject_uri = data["uri"]

    stat = helpers.get_top_statement_to_display(@event, statement_id)
    @microposts_all_statements = build_microposts(@event, @subject_uri)

    respond_to do |format|
      format.js   { render partial: partial, locals: { stat: stat } }
      format.html { redirect_to event_path(id: @subject_uri) }
    end
  end

  # ---------------------------------------------------------------------------
  # Dependency injection wrapper for condenser helpers
  #
  # Allows easy stubbing during controller tests.
  #
  # Example:
  # allow(controller).to receive(:condenser_service).and_return(mock_condenser)
  # ---------------------------------------------------------------------------
  def condenser_service
    helpers
  end

  # ============================================================================
  # Condenser HTTP wrapper
  #
  # Supports two call styles used in Console:
  #
  # Style 1 (legacy helper style)
  #   call_condenser "/statements/123.json", :patch, payload
  #
  # Style 2 (controller block style)
  #   call_condenser(action: :activate_statement) { ... }
  # ============================================================================
  def call_condenser(path = nil, method = :get, params = {}, action: nil)

    # --- BLOCK STYLE ----------------------------------------------------------
    if block_given?
      result = yield
      Rails.logger.debug("[Condenser] #{action} executed")
      return result
    end

    # --- HTTP STYLE -----------------------------------------------------------
    url = condenser_url_per_environment(path)

    response =
      case method.to_sym
      when :patch
        HTTP.patch(url, json: params)
      when :post
        HTTP.post(url, json: params)
      when :delete
        HTTP.delete(url)
      else
        HTTP.get(url)
      end

    JSON.parse(response.body.to_s)

  rescue => e
    Rails.logger.error("[Condenser] #{path || action} failed: #{e.message}")
    nil
  end

end