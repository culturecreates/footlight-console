class MicropostsController < ApplicationController
  before_action :logged_in_user, only: [:create, :destroy, :new]



  def index
    @seedurl = params[:seedurl] || cookies[:seedurl] 
    if @seedurl
      data = helpers.condenser_get_website_events(@seedurl)
      if data["events"]
        events = data["events"]
        rdf_url_list = events.map {|e| e["rdf_uri"]}
        @microposts = Micropost.where(related_subject_uri: [rdf_url_list])
      else
        flash[:danger] = "No events available to check for comments on."
        redirect_back(fallback_location: root_path)
      end
    else
      flash[:danger] = "Please select a website first."
      redirect_back(fallback_location: root_path)
    end
  end

  def new
    params[:key]
    params[:statement_id]
    params[:subject_uri]
    params[:statement_id]

    @micropost = current_user.microposts.build
    @statement_property = helpers.extract_property_from_key params[:key]
    @statement_language = helpers.extract_language_from_key params[:key]
    @subject_uri = params[:subject_uri]
    @statement_id = params[:statement_id]
  end

  def create
    @micropost = current_user.microposts.build(micropost_params)
    if @micropost.save
      ##FLAG work goes here
      data = helpers.condenser_flag_statement @micropost.related_statement_id, current_user.name
      @event = data["statements"]
      @seedurl = data["seedurl"]
      @website = Website.where(url: @seedurl, user_id: current_user).first
      @subject_uri = data["uri"]

      @microposts_all_statements = { @subject_uri => helpers.get_event_microposts(@event, @subject_uri) }

      key = helpers.make_key(@micropost.related_statement_property,@micropost.related_statement_language )

      resource_url = if @subject_uri.starts_with?("footlight:")
        resource_index_url(uri: @subject_uri)
      else
        event_url(id: @subject_uri )
      end
      HTTParty.post(
        helpers.slack_url_per_environment,
        body: { 'text' => "#{current_user.name} (#{current_user.email}): added flag on property #{micropost_params[:related_statement_property]} -> '#{micropost_params[:content]}' (#{resource_url})" }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

      render partial: "events/render_statement", locals: {stat: @event[key] }
    else
      flash[:danger] = "Could not save."
      redirect_back(fallback_location: root_path)
    end
  end

  def destroy
    @micropost = Micropost.find(params[:id])
    @micropost.destroy
  end

  private

    def micropost_params
      params.require(:micropost).permit(:content, :picture, :related_subject_uri, :related_statement_property, :related_statement_language, :related_statement_id)
    end


end
