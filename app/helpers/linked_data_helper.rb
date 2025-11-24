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

  # Google Place Details: builds the URL for the Places API (Legacy) Place Details
  # endpoint, including the required `fields` parameter introduced by Google.
  #
  # We request:
  #   - address_components: for street/city/region/country/postal_code
  #   - geometry: for lat/lng
  #   - url: deep link to Google Maps for the place
  #   - types: used to build a disambiguating description
  #   - formatted_address: full human-readable address
  #
  # Keeping this logic in a helper makes it unit-testable without hitting Google.
  def google_place_details_url_legacy(place_id)
    fields = %w[
      address_components
      geometry
      url
      types
      formatted_address
    ].join(',')

    "https://maps.googleapis.com/maps/api/place/details/json" \
      "?place_id=#{place_id}" \
      "&fields=#{fields}" \
      "&key=#{ENV['GOOGLE_MAPS_API']}"
  end

  # Build the Google Places API v1 Place Details URL.
  #
  # We now use the "Places API (New)" HTTP endpoint:
  #   https://places.googleapis.com/v1/places/{place_id}
  #
  # and specify the field mask using the `fields` query parameter.
  # For our use case we only request:
  #   - addressComponents: structured address parts (street, locality, region, country, postal code)
  #   - formattedAddress: single human-readable address string
  #   - location: lat/lng of the place
  #   - types: type list used to build a disambiguating description
  #
  # The API key is passed via the `key` query parameter using ENV['GOOGLE_MAPS_API'].
  #
  # NOTE: The unit test in LinkedDataHelperTest explicitly checks that we
  #       generate this new-style v1 URL, so any change here should be
  #       reflected in that test.
  def google_place_details_url(place_id)
    fields = %w[addressComponents formattedAddress location types googleMapsUri].join(',')
    "https://places.googleapis.com/v1/places/#{place_id}?fields=#{fields}&key=#{ENV['GOOGLE_MAPS_API']}"
  end

  # Normalize a Places API v1 "Place" object into the legacy shape that
  # create_resource previously used when it parsed the legacy /details/json
  # response. This lets us keep split_postal_address and the rest of the logic
  # unchanged.
  #
  # Returns a hash that looks like the old "details" value:
  #   {
  #     "address_components" => [ { "long_name", "short_name", "types" }, ... ],
  #     "formatted_address"  => "...",
  #     "geometry"           => { "location" => { "lat" => ..., "lng" => ... } },
  #     "types"              => [...],
  #     "url"                => "https://maps.google.com/..."
  #   }
  def normalize_place_details(place)
    address_components = (place["addressComponents"] || []).map do |component|
      {
        "long_name"  => component["longText"],
        "short_name" => component["shortText"] || component["longText"],
        "types"      => component["types"] || []
      }
    end

    geometry = {}
    if place["location"]
      geometry = {
        "location" => {
          "lat" => place["location"]["latitude"],
          "lng" => place["location"]["longitude"]
        }
      }
    end

    {
      "address_components" => address_components,
      "formatted_address"  => place["formattedAddress"],
      "geometry"           => geometry,
      "types"              => place["types"] || [],
      "url"                => place["googleMapsUri"]
    }
  end

end
