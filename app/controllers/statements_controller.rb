class StatementsController < ApplicationController
  before_action :logged_in_user
  
  def activate
    params[:id]
    @old_statement_id = params[:old_statement_id]
    data = helpers.condenser_activate_statement params[:id]
    @event = data["statements"]
    #find statement_id in @event 
    stat = helpers.get_top_statment_to_display(@event, params[:id])
    if @event.blank?
      flash[:danger] = "Error activating statement."
      redirect_back(fallback_location: root_path)
    else
      if params[:multiple_events] == "true"
        render "force_page_reload.js"
      else
        @subject_uri = data["uri"]
        @microposts_all_statements = { @subject_uri => helpers.get_event_microposts(@event, @subject_uri) }
        render partial: "events/render_alternative_statement", locals: { stat: stat }
      end
      
    end
  end

  def activate_individual
    params[:id]
    @old_statement_id = params[:old_statement_id]
    data = helpers.condenser_activate_individual_statement params[:id]
    @event = data["statements"]
    #find statement_id in @event 
    stat = helpers.get_top_statment_to_display(@event, params[:id])
    # REPLACED stat = @event.select{ |n,v| v["id"] == params[:id].to_i }.flatten[1]
    if @event.blank?
      flash[:danger] = "Error activating individual statement."
      redirect_back(fallback_location: root_path)
    else
      @subject_uri = data["uri"]
      @microposts_all_statements = { @subject_uri => helpers.get_event_microposts(@event, @subject_uri) }
      render partial: "events/render_alternative_statement", locals: { stat: stat }
    end
  end

  def deactivate_individual
    params[:id]
    @old_statement_id = params[:old_statement_id]
    data = helpers.condenser_deactivate_individual_statement params[:id]
    @event = data["statements"]
    #find statement_id in @event 
    stat = helpers.get_top_statment_to_display(@event, params[:id])
    if @event.blank?
      flash[:danger] = "Error deactivating individual statement."
      redirect_back(fallback_location: root_path)
    else
      @subject_uri = data["uri"]
      @microposts_all_statements = { @subject_uri => helpers.get_event_microposts(@event, @subject_uri) }
      render partial: "events/render_alternative_statement", locals: { stat: stat }
    end
  end

  ## 
  # Use to reconnect a statement to a feed bu turning statement manual: to false 
  def reconnect_feed
    data = helpers.condenser_reconnect_feed_statement params[:id], current_user.name
    @event = data["statements"]
    stat = helpers.get_top_statment_to_display(@event, params[:id])
    if @event.blank?
      flash[:danger] = "Could not update statement #{params[:id]}."
      redirect_back(fallback_location: root_path)
    else
      @subject_uri = data["uri"]
      @microposts_all_statements = { @subject_uri => helpers.get_event_microposts(@event, @subject_uri) }
      render partial: "events/render_statement", locals: { stat: stat }
    end
  end

  def review_statement
    params[:id]
    data = helpers.condenser_review_statement params[:id], current_user.name
    @event = data["statements"]
    #find statement_id in @event 
    stat = helpers.get_top_statment_to_display(@event, params[:id])
    if @event.blank?
      flash[:danger] = "Could not update statement #{params[:id]}."
      redirect_back(fallback_location: root_path)
    else
      ## delete statement issues
      @subject_uri = data["uri"]
      key = helpers.make_key(stat['label'],stat['language'])
      helpers.delete_posts_belonging_statement_property @event, @subject_uri, key
      @microposts_all_statements = { @subject_uri => helpers.get_event_microposts(@event, @subject_uri) }
      render partial: "events/render_statement", locals: { stat: stat }
    end
  end

  # Initialize field for manual data entry
  def edit_manual_statement
    @statement_id = params[:statement_id]
    @manual_statement_id = params[:manual_statement_id]
  end

  # Cancel manual data entry
  def cancel_edit_manual_statement
    @statement_id = params[:statement_id]
  end

  # Save manual data entry
  # params: old_statement_id, id, value, merge_with, del?, timezone = Eastern+Time+%28US+%26+Canada%29
  def save_manual_statement
    
    value = if params[:timezone] 
              if params[:del?]
                helpers.remove_dateTime(params[:value], params[:timezone], params[:merge_with])
              else
                helpers.add_dateTime(params[:value], params[:timezone], params[:merge_with])
              end
            else
              params[:value]
            end
    id = params[:id]
    @old_statement_id = params[:old_statement_id]
    data = helpers.condenser_save_individual_statement(id, value, current_user.name)
    
    if id != @old_statement_id
      # make edited statement active
      data =  helpers.condenser_activate_individual_statement(id) 
    end
    @event = data["statements"]

    # set view variables
    stat = helpers.get_top_statment_to_display(@event, id)
    if @event.blank?
      flash[:danger] = "Could not update statement #{params[:id]}."
      redirect_back(fallback_location: root_path)
    else
      @subject_uri = data["uri"]
      @microposts_all_statements = { @subject_uri => helpers.get_event_microposts(@event, @subject_uri) }
      render partial: "events/render_alternative_statement", locals: { stat: stat }
    end
  end

end
