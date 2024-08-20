module LinkedDataHelper

   # Google Place Details: {"html_attributions"=>[], "result"=>{"address_components"=>[{"long_name"=>"4145", "short_name"=>"4145", "types"=>["street_number"]}, {"long_name"=>"Avenue Beaconsfield", "short_name"=>"Av. Beaconsfield", "types"=>["route"]}, {"long_name"=>"Côte-Des-Neiges—Notre-Dame-De-Grâce", "short_name"=>"Côte-Des-Neiges—Notre-Dame-De-Grâce", "types"=>["sublocality_level_1", "sublocality", "political"]}, {"long_name"=>"Montréal", "short_name"=>"Montréal", "types"=>["locality", "political"]}, {"long_name"=>"Montréal", "short_name"=>"Montréal", "types"=>["administrative_area_level_3", "political"]}, {"long_name"=>"Communauté-Urbaine-de-Montréal", "short_name"=>"Communauté-Urbaine-de-Montréal", "types"=>["administrative_area_level_2", "political"]}, {"long_name"=>"Québec", "short_name"=>"QC", "types"=>["administrative_area_level_1", "political"]}, {"long_name"=>"Canada", "short_name"=>"CA", "types"=>["country", "political"]}, {"long_name"=>"H4A 2H4", "short_name"=>"H4A 2H4", "types"=>["postal_code"]}], "adr_address"=>"<span class=\"street-address\">4145 Av. Beaconsfield</span>, <span class=\"locality\">Montréal</span>, <span class=\"region\">QC</span> <span class=\"postal-code\">H4A 2H4</span>, <span class=\"country-name\">Canada</span>", "formatted_address"=>"4145 Av. Beaconsfield, Montréal, QC H4A 2H4, Canada", "geometry"=>{"location"=>{"lat"=>45.469074, "lng"=>-73.6258608}, "viewport"=>{"northeast"=>{"lat"=>45.47033858029149, "lng"=>-73.6245876697085}, "southwest"=>{"lat"=>45.4676406197085, "lng"=>-73.62728563029151}}}, "icon"=>"https://maps.gstatic.com/mapfiles/place_api/icons/v1/png_71/geocode-71.png", "icon_background_color"=>"#7B9EB0", "icon_mask_base_uri"=>"https://maps.gstatic.com/mapfiles/place_api/icons/v2/generic_pinlet", "name"=>"4145 Av. Beaconsfield", "place_id"=>"ChIJnWHJM0sXyUwRBNA5S4k_b3I", "reference"=>"ChIJnWHJM0sXyUwRBNA5S4k_b3I", "types"=>["premise"], "url"=>"https://maps.google.com/?q=4145+Av.+Beaconsfield,+Montr%C3%A9al,+QC+H4A+2H4,+Canada&ftid=0x4cc9174b33c9619d:0x726f3f894b39d004", "utc_offset"=>-240, "vicinity"=>"Côte-Des-Neiges—Notre-Dame-De-Grâce"}
  def split_postal_address(result)
    address_parts = result["address_components"]  
    street_number = extract_type(address_parts, "street_number") 
    route = extract_type(address_parts, "route") 
    street_address = "#{street_number if street_number} #{route}".strip
    postal_code = extract_type(address_parts, "postal_code") 
    address_locality = extract_type(address_parts, "locality" )
    address_locality = extract_type(address_parts, "administrative_area_level_3" ) unless address_locality.present?
    address_region = extract_type(address_parts, "administrative_area_level_1") 
    address_country = extract_type(address_parts, "country")  
    return street_address, postal_code, address_locality, address_region, address_country 
  end

  def extract_type(data, type)
    result = data.select { |component| component["types"].include?(type) }&.first
    if result
      return result["short_name"]
    else
      return ""
    end
  end

end
