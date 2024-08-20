class StaticPagesController < ApplicationController
  before_action :logged_in_user, only: :export
  
  def dashboard
    if logged_in?
      #@micropost  = current_user.microposts.build
      #@feed_items = current_user.feed.paginate(page: params[:page])
      @websites = Website.where(user: current_user).order(:url)
      @condenser_websites = helpers.condenser_get_websites
    end
  end


  def about
  end

  def contact
  end

  def export
    data = helpers.condenser_get_website_events(cookies[:seedurl])
    test_event = data['events'].select {|e| e["statements_status"]["publishable"] ==  true}.last
    if test_event
      event = helpers.condenser_get_resource(test_event["rdf_uri"])
      webpages = event["statements"].select {|_k,v| v["label"] == "Webpage link"}
      @url_to_test_code_snippet = webpages.map {|_k,v| v["value"]}.first
      begin
        # http://footlight-wringer.herokuapp.com/websites/wring?uri=https%3A%2F%2Fsignelaval.com%2Ffr%2Fevenements%2F12161%2Fvisite-gratuite-incroyable-mais-vrai&use_phantomjs=true&format=raw
        wringer_query = '&use_phantomjs=true&format=raw&force_scrape_every_hrs=2'
        wringer_base_url = 'http://footlight-wringer.herokuapp.com/websites/wring'
        wring_url = "#{wringer_base_url}?uri=#{CGI.escape(@url_to_test_code_snippet)}#{wringer_query}"
        result = HTTParty.get(wring_url)
        if result.response.code[0] == '2'
          if result.body
            @website_check = { message:  result.body }
          else
            @website_check = { message: "Response body empty." }
          end
        else
          @website_check = { error: result.response.inspect }
        end
      rescue
        @website_check = { error: "Failed to call condensor" }
      end
    else
      @website_check = { message: "No pages with a publishable event." }
      @url_to_test_code_snippet = "No pages with a publishable event."
    end
  end
end
