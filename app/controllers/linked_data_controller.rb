class LinkedDataController < ApplicationController
  before_action :logged_in_user

  def linker
    params[:statement_id]
    params[:key] 
    params[:expected_class]
    params[:recon_name]

    @expected_class = params[:expected_class]
    @recon_name, @recon_url, @recon_type, @recon_prefix = setup_recon_variables(params[:expected_class],params[:recon_name])
    @statement_id = params[:statement_id]
    @key = params[:key]
    @link_auto_complete = setup_linkables(params[:expected_class])
  end


  def add_linked_data
    params[:rdfs_class]
    params[:uri]
    params[:statement_id]
    uri = params[:uri].split('---').first
    name = if params[:name]
        params[:name] # passed by dropdown
      else 
        params[:uri].split('---').second # passed by select2 autocomplete
      end

    data = helpers.condenser_add_linked_data  params[:statement_id], current_user.name,
               {rdfs_class: params[:rdfs_class],
                uri: uri,
                name: name}
   
    @event = data["statements"]
    stat = @event.select{ |_n,v| v["id"] == params[:statement_id].to_i }.flatten[1]
    if @event.blank?
      flash[:danger] = "Error linking data to #{params[:name]}"
      redirect_back(fallback_location: root_path)
    else
      @subject_uri = data["uri"]
      @microposts_all_statements = { @subject_uri => helpers.get_event_microposts(@event, @subject_uri) }
      render partial: "events/render_statement", locals: { stat: stat }
    end
  end


  def remove_linked_data
    params[:rdfs_class]
    params[:uri]
    params[:name]
    params[:statement_id]
 
    data = helpers.condenser_remove_linked_data params[:statement_id], current_user.name,
               {rdfs_class: params[:rdfs_class],
                uri: params[:uri],
                name: params[:name]}
    @event = data["statements"]
    stat = @event.select{ |_n,v| v["id"] == params[:statement_id].to_i }.flatten[1]

    if @event.blank?
      flash[:danger] = "Error removing linked data from #{params[:name]}"
      redirect_back(fallback_location: root_path)
    else
      @subject_uri = data["uri"]
      @microposts_all_statements = { @subject_uri => helpers.get_event_microposts(@event, @subject_uri) }
      render partial: "events/render_statement", locals: {stat: stat }
    end
  end


  def new_resource 
    @statement_id = params[:statement_id]
    @expected_class = params[:expected_class]
  end


  # PATCH /resource
  # params:
  #   rdfs_class
  #   seedurl
  #   address - a Google Place ID
  #   name
  #   occupation
  #   url
  def create_resource
    if params[:rdfs_class] == "Place"
      if params[:address].present?
        # Get Place details from Google
        result = HTTParty.get("https://maps.googleapis.com/maps/api/place/details/json?place_id=#{params[:address]}&key=#{ENV['GOOGLE_MAPS_API']}")
        if result.response.code[0] == '2'
          if result.body
            details = JSON.parse(result.body)["result"]
            @street_address, @postal_code, @address_locality, @address_region, @address_country = helpers.split_postal_address(details)
            @address = details["formatted_address"]
            @longitude = details["geometry"]["location"]["lng"]
            @latitude = details["geometry"]["location"]["lat"]
            @same_as = ["Google Place #{params[:address]}","Place",["Google Place #{params[:address]}","#{details["url"]}"]]
            @disambiguating_description = "#{details["types"].join(', ')} at #{details["formatted_address"]}"
          end
        end
      end
    elsif params[:rdfs_class] == "Person" && params[:occupation].present?
      @disambiguating_description = "#{params[:occupation]}"
    else
      @disambiguating_description = params[:rdfs_class]
    end
  
    # Load all options
    options = { 
      name: { value: params[:name], language: params[:name_lang] },
      occupation: { value: params[:occupation], language: params[:name_lang]  },
      url: { value: params[:url], language: ""  },
    }
    if @disambiguating_description
      options[:disambiguating_description] = { value: @disambiguating_description, language: "en"} 
    end
    if @address.present?
      options.merge!({
        street_address: { value: @street_address, language: params[:name_lang], rdfs_class_name: "PostalAddress" },
        postal_code: { value: @postal_code, language: "", rdfs_class_name: "PostalAddress" },
        address_locality: { value: @address_locality, language: params[:name_lang], rdfs_class_name: "PostalAddress" },
        address_region: { value: @address_region, language: params[:name_lang], rdfs_class_name: "PostalAddress" },
        address_country: { value: @address_country, language: params[:name_lang], rdfs_class_name: "PostalAddress" },
        address: { value: @address, language: params[:name_lang]},
        longitude: { value: @longitude, language: "" },
        latitude: { value: @latitude, language: "" },
        same_as: { value: @same_as, language: "" }
      })
    end

    # call condenser condenser_create_linked_resource 
    new_entity = helpers.condenser_create_linked_resource params[:rdfs_class], params[:seedurl], options
   
    puts "new_entity: #{new_entity.inspect}"

    # Link to new resource and returns the event 
    if new_entity["statements"].present?
      data = helpers.condenser_add_linked_data params[:statement_id], current_user.name, 
        { 
          rdfs_class: params[:rdfs_class],
          uri: new_entity["uri"],
          name: new_entity["statements"]["name_#{params[:name_lang]}"]["value"]
        }
      
      @event = data["statements"]
      stat = @event.select{ |_n,v| v["id"] == params[:statement_id].to_i }.flatten[1]
    end

    if @event.blank?
      flash[:danger] = "Error linking newly created resource #{params[:name]}"
      redirect_back(fallback_location: root_path)
    else
      @subject_uri = data["uri"]
      @microposts_all_statements = { @subject_uri => helpers.get_event_microposts(@event, @subject_uri) }
      render partial: "events/render_statement", locals: {stat: stat }
    end
  end


  def  artsdata_recon_url_per_environment
    if Rails.env.development?  || Rails.env.test? 
        'http://localhost:3003/recon';
    else
        'https://api.artsdata.ca/recon';
    end
  end

  def footlight_recon_url_per_environment
    if Rails.env.development?  || Rails.env.test? 
      'http://localhost:3000/recon';
    else
      'https://footlight-condenser.herokuapp.com/recon';
    end
  end

  def setup_recon_variables(expected_class, recon_name)
    recon_name = "Artsdata" unless ["Artsdata","Wikidata","Footlight"].include?(recon_name)
    
    if recon_name == "Artsdata"
      recon_url = artsdata_recon_url_per_environment
      recon_type =  if expected_class == "EventType"
                      "ado:EventType" 
                    else
                      expected_class
                    end
      recon_prefix = 'http://kg.artsdata.ca/resource/'
    elsif recon_name == "Wikidata"
      recon_url = "https://wikidata.reconci.link/en/api"
      recon_type =  if expected_class == "Person"
                      "Q5"
                    elsif expected_class == "Organization"
                      "Q43229"
                    elsif expected_class == "Place"
                      "Q17350442"
                    end
      recon_prefix = 'http://www.wikidata.org/entity/'
    else 
      recon_url =  footlight_recon_url_per_environment
      recon_type = expected_class
      recon_prefix = 'footlight:'
    end
    return [recon_name, recon_url, recon_type, recon_prefix]
  end

  def setup_linkables(expected_class)

    if expected_class == "EventTypeEnumeration"

      # Workshop, Exhibition names have been changed to accomodate the arts sector
      # Performance is a temporary Class created by Culture Creates
      linkables = [
        {"name"=>{"value"=>"BroadcastEvent"}, "uri"=>{"value"=>"http://schema.org/BroadcastEvent"}},
        {"name"=>{"value"=>"BusinessEvent"}, "uri"=>{"value"=>"http://schema.org/BusinessEvent"}},
        {"name"=>{"value"=>"ChildrensEvent"}, "uri"=>{"value"=>"http://schema.org/ChildrensEvent"}},
        {"name"=>{"value"=>"ComedyEvent"}, "uri"=>{"value"=>"http://schema.org/ComedyEvent"}},
        {"name"=>{"value"=>"CourseInstance"}, "uri"=>{"value"=>"http://schema.org/CourseInstance"}},
        {"name"=>{"value"=>"DanceEvent"}, "uri"=>{"value"=>"http://schema.org/DanceEvent"}},
        {"name"=>{"value"=>"EducationEvent"}, "uri"=>{"value"=>"http://schema.org/EducationEvent"}},
        {"name"=>{"value"=>"EventSeries"}, "uri"=>{"value"=>"http://schema.org/EventSeries"}},
        {"name"=>{"value"=>"Exhibition"}, "uri"=>{"value"=>"http://schema.org/ExhibitionEvent"}},
        {"name"=>{"value"=>"Festival"}, "uri"=>{"value"=>"http://schema.org/Festival"}},
        {"name"=>{"value"=>"FoodEvent"}, "uri"=>{"value"=>"http://schema.org/FoodEvent"}},
        {"name"=>{"value"=>"LiteraryEvent"}, "uri"=>{"value"=>"http://schema.org/LiteraryEvent"}},
        {"name"=>{"value"=>"MusicEvent"}, "uri"=>{"value"=>"http://schema.org/MusicEvent"}},
        {"name"=>{"value"=>"OnDemandEvent"}, "uri"=>{"value"=>"http://schema.org/OnDemandEvent"}},
        {"name"=>{"value"=>"Performance"}, "uri"=>{"value"=>"http://ontology.artsdata.ca/Performance"}},
        {"name"=>{"value"=>"PublicationEvent"}, "uri"=>{"value"=>"http://schema.org/PublicationEvent"}},
        {"name"=>{"value"=>"SaleEvent"}, "uri"=>{"value"=>"http://schema.org/SaleEvent"}},
        {"name"=>{"value"=>"Screening"}, "uri"=>{"value"=>"http://schema.org/ScreeningEvent"}},
        {"name"=>{"value"=>"SocialEvent"}, "uri"=>{"value"=>"http://schema.org/SocialEvent"}},
        {"name"=>{"value"=>"SportsEvent"}, "uri"=>{"value"=>"http://schema.org/SportsEvent"}},
        {"name"=>{"value"=>"TheaterEvent"}, "uri"=>{"value"=>"http://schema.org/TheaterEvent"}},
        {"name"=>{"value"=>"VisualArtsEvent"}, "uri"=>{"value"=>"http://schema.org/VisualArtsEvent"}},
        {"name"=>{"value"=>"Workshop"}, "uri"=>{"value"=>"http://schema.org/EducationEvent"}}
      ]
    elsif expected_class == "EventStatusType"
      linkables = [
        {"name"=>{"value"=>"Scheduled"}, "uri"=>{"value"=>"http://schema.org/EventScheduled"}},
        {"name"=>{"value"=>"Rescheduled (new date)"}, "uri"=>{"value"=>"http://schema.org/EventRescheduled"}},
        {"name"=>{"value"=>"Postponed (date TBD)"}, "uri"=>{"value"=>"http://schema.org/EventPostponed"}},
        {"name"=>{"value"=>"Cancelled"}, "uri"=>{"value"=>"http://schema.org/EventCancelled"}}
      ]
    elsif expected_class == "EventAttendanceModeEnumeration"
      linkables = [
        {"name"=>{"value"=>"Online"}, "uri"=>{"value"=>"http://schema.org/OnlineEventAttendanceMode"}},
        {"name"=>{"value"=>"In-person"}, "uri"=>{"value"=>"http://schema.org/OfflineEventAttendanceMode"}},
        {"name"=>{"value"=>"Mixed"}, "uri"=>{"value"=>"http://schema.org/MixedEventAttendanceMode"}}
      ]
    else
      linkables = [] # leave empty to trigger reconciliation API auto-complete
    end
    
    linkables.map {|l| {:label => l["name"]["value"], :value => l["uri"]["value"]}}
  end

end

