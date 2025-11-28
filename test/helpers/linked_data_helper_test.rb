require 'test_helper'

class LinkedDataHelperTest < ActionView::TestCase
  test "split regular address" do
    expected = ["4145 Av. Beaconsfield", "H4A 2H4", "Montréal", "QC", "CA"]
    input = {"address_components"=>[{"long_name"=>"4145", "short_name"=>"4145", "types"=>["street_number"]}, {"long_name"=>"Avenue Beaconsfield", "short_name"=>"Av. Beaconsfield", "types"=>["route"]}, {"long_name"=>"Côte-Des-Neiges—Notre-Dame-De-Grâce", "short_name"=>"Côte-Des-Neiges—Notre-Dame-De-Grâce", "types"=>["sublocality_level_1", "sublocality", "political"]}, {"long_name"=>"Montréal", "short_name"=>"Montréal", "types"=>["locality", "political"]}, {"long_name"=>"Montréal", "short_name"=>"Montréal", "types"=>["administrative_area_level_3", "political"]}, {"long_name"=>"Communauté-Urbaine-de-Montréal", "short_name"=>"Communauté-Urbaine-de-Montréal", "types"=>["administrative_area_level_2", "political"]}, {"long_name"=>"Québec", "short_name"=>"QC", "types"=>["administrative_area_level_1", "political"]}, {"long_name"=>"Canada", "short_name"=>"CA", "types"=>["country", "political"]}, {"long_name"=>"H4A 2H4", "short_name"=>"H4A 2H4", "types"=>["postal_code"]}], "adr_address"=>"<span class=\"street-address\">4145 Av. Beaconsfield</span>, <span class=\"locality\">Montréal</span>, <span class=\"region\">QC</span> <span class=\"postal-code\">H4A 2H4</span>, <span class=\"country-name\">Canada</span>", "formatted_address"=>"4145 Av. Beaconsfield, Montréal, QC H4A 2H4, Canada", "geometry"=>{"location"=>{"lat"=>45.469074, "lng"=>-73.6258608}, "viewport"=>{"northeast"=>{"lat"=>45.47033858029149, "lng"=>-73.6245876697085}, "southwest"=>{"lat"=>45.4676406197085, "lng"=>-73.62728563029151}}}, "icon"=>"https://maps.gstatic.com/mapfiles/place_api/icons/v1/png_71/geocode-71.png", "icon_background_color"=>"#7B9EB0", "icon_mask_base_uri"=>"https://maps.gstatic.com/mapfiles/place_api/icons/v2/generic_pinlet", "name"=>"4145 Av. Beaconsfield", "place_id"=>"ChIJnWHJM0sXyUwRBNA5S4k_b3I", "reference"=>"ChIJnWHJM0sXyUwRBNA5S4k_b3I", "types"=>["premise"], "url"=>"https://maps.google.com/?q=4145+Av.+Beaconsfield,+Montr%C3%A9al,+QC+H4A+2H4,+Canada&ftid=0x4cc9174b33c9619d:0x726f3f894b39d004", "utc_offset"=>-240, "vicinity"=>"Côte-Des-Neiges—Notre-Dame-De-Grâce"}
    assert_equal expected, split_postal_address(input)
  end

  test "split address missing street number" do
    expected = ["Av. Beaconsfield", "H4A 2H4", "Montréal", "QC", "CA"]
    input = {"address_components"=>[ {"long_name"=>"Avenue Beaconsfield", "short_name"=>"Av. Beaconsfield", "types"=>["route"]}, {"long_name"=>"Côte-Des-Neiges—Notre-Dame-De-Grâce", "short_name"=>"Côte-Des-Neiges—Notre-Dame-De-Grâce", "types"=>["sublocality_level_1", "sublocality", "political"]}, {"long_name"=>"Montréal", "short_name"=>"Montréal", "types"=>["locality", "political"]}, {"long_name"=>"Montréal", "short_name"=>"Montréal", "types"=>["administrative_area_level_3", "political"]}, {"long_name"=>"Communauté-Urbaine-de-Montréal", "short_name"=>"Communauté-Urbaine-de-Montréal", "types"=>["administrative_area_level_2", "political"]}, {"long_name"=>"Québec", "short_name"=>"QC", "types"=>["administrative_area_level_1", "political"]}, {"long_name"=>"Canada", "short_name"=>"CA", "types"=>["country", "political"]}, {"long_name"=>"H4A 2H4", "short_name"=>"H4A 2H4", "types"=>["postal_code"]}], "adr_address"=>"<span class=\"street-address\">4145 Av. Beaconsfield</span>, <span class=\"locality\">Montréal</span>, <span class=\"region\">QC</span> <span class=\"postal-code\">H4A 2H4</span>, <span class=\"country-name\">Canada</span>", "formatted_address"=>"4145 Av. Beaconsfield, Montréal, QC H4A 2H4, Canada", "geometry"=>{"location"=>{"lat"=>45.469074, "lng"=>-73.6258608}, "viewport"=>{"northeast"=>{"lat"=>45.47033858029149, "lng"=>-73.6245876697085}, "southwest"=>{"lat"=>45.4676406197085, "lng"=>-73.62728563029151}}}, "icon"=>"https://maps.gstatic.com/mapfiles/place_api/icons/v1/png_71/geocode-71.png", "icon_background_color"=>"#7B9EB0", "icon_mask_base_uri"=>"https://maps.gstatic.com/mapfiles/place_api/icons/v2/generic_pinlet", "name"=>"4145 Av. Beaconsfield", "place_id"=>"ChIJnWHJM0sXyUwRBNA5S4k_b3I", "reference"=>"ChIJnWHJM0sXyUwRBNA5S4k_b3I", "types"=>["premise"], "url"=>"https://maps.google.com/?q=4145+Av.+Beaconsfield,+Montr%C3%A9al,+QC+H4A+2H4,+Canada&ftid=0x4cc9174b33c9619d:0x726f3f894b39d004", "utc_offset"=>-240, "vicinity"=>"Côte-Des-Neiges—Notre-Dame-De-Grâce"}
    assert_equal expected, split_postal_address(input)
  end

  test "split address missing locality" do
    expected = ["4145 Av. Beaconsfield", "H4A 2H4", "administrative_area_level_3", "QC", "CA"]
    input = {"address_components"=>[{"long_name"=>"4145", "short_name"=>"4145", "types"=>["street_number"]}, {"long_name"=>"Avenue Beaconsfield", "short_name"=>"Av. Beaconsfield", "types"=>["route"]}, {"long_name"=>"Côte-Des-Neiges—Notre-Dame-De-Grâce", "short_name"=>"Côte-Des-Neiges—Notre-Dame-De-Grâce", "types"=>["sublocality_level_1", "sublocality", "political"]}, {"long_name"=>"Montréal", "short_name"=>"Montréal", "types"=>["political"]}, {"long_name"=>"administrative_area_level_3", "short_name"=>"administrative_area_level_3", "types"=>["administrative_area_level_3", "political"]}, {"long_name"=>"Communauté-Urbaine-de-Montréal", "short_name"=>"Communauté-Urbaine-de-Montréal", "types"=>["administrative_area_level_2", "political"]}, {"long_name"=>"Québec", "short_name"=>"QC", "types"=>["administrative_area_level_1", "political"]}, {"long_name"=>"Canada", "short_name"=>"CA", "types"=>["country", "political"]}, {"long_name"=>"H4A 2H4", "short_name"=>"H4A 2H4", "types"=>["postal_code"]}], "adr_address"=>"<span class=\"street-address\">4145 Av. Beaconsfield</span>, <span class=\"locality\">Montréal</span>, <span class=\"region\">QC</span> <span class=\"postal-code\">H4A 2H4</span>, <span class=\"country-name\">Canada</span>", "formatted_address"=>"4145 Av. Beaconsfield, Montréal, QC H4A 2H4, Canada", "geometry"=>{"location"=>{"lat"=>45.469074, "lng"=>-73.6258608}, "viewport"=>{"northeast"=>{"lat"=>45.47033858029149, "lng"=>-73.6245876697085}, "southwest"=>{"lat"=>45.4676406197085, "lng"=>-73.62728563029151}}}, "icon"=>"https://maps.gstatic.com/mapfiles/place_api/icons/v1/png_71/geocode-71.png", "icon_background_color"=>"#7B9EB0", "icon_mask_base_uri"=>"https://maps.gstatic.com/mapfiles/place_api/icons/v2/generic_pinlet", "name"=>"4145 Av. Beaconsfield", "place_id"=>"ChIJnWHJM0sXyUwRBNA5S4k_b3I", "reference"=>"ChIJnWHJM0sXyUwRBNA5S4k_b3I", "types"=>["premise"], "url"=>"https://maps.google.com/?q=4145+Av.+Beaconsfield,+Montr%C3%A9al,+QC+H4A+2H4,+Canada&ftid=0x4cc9174b33c9619d:0x726f3f894b39d004", "utc_offset"=>-240, "vicinity"=>"Côte-Des-Neiges—Notre-Dame-De-Grâce"}
    assert_equal expected, split_postal_address(input)
  end

  test "builds Google Places API v1 Place Details URL" do
    place_id = "ChIJnWHJM0sXyUwRBNA5S4k_b3I"
    
    expected = "https://places.googleapis.com/v1/places/#{place_id}?fields=addressComponents,formattedAddress,location,types,googleMapsUri&key=#{ENV['GOOGLE_MAPS_API']}"

    assert_equal expected, google_place_details_url(place_id)
  end

  test "normalizes v1 Place response fixture and splits postal address" do
    path    = Rails.root.join("test/fixtures/files/google_place_details_v1.json")
    place   = JSON.parse(File.read(path))
    details = normalize_place_details(place)

    # This should now look like the legacy shape we already test:
    # {
    #   "address_components" => [...],
    #   "formatted_address"  => "...",
    #   "geometry"           => { "location" => { "lat", "lng" } },
    #   "types"              => [...],
    #   "url"                => "https://maps.google.com/..."
    # }

    expected_address_parts = [
      "4145 Av. Beaconsfield",
      "H4A 2H4",
      "Montréal",
      "QC",
      "CA"
    ]

    assert_equal expected_address_parts, split_postal_address(details)

    # And we can also sanity-check some of the other normalized fields:
    assert_equal "4145 Av. Beaconsfield, Montréal, QC H4A 2H4, Canada",
                 details["formatted_address"]

    assert_in_delta 45.469074, details.dig("geometry", "location", "lat"), 1e-6
    assert_in_delta(-73.6258608, details.dig("geometry", "location", "lng"), 1e-6)

    assert_equal "https://maps.google.com/?q=4145+Av.+Beaconsfield,+Montréal,+QC+H4A+2H4",
                 details["url"]
  end

end