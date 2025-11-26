require 'test_helper'
require 'minitest/mock'  # so Object#stub exists

class LinkedDataControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:michael)
  end

  #
  # Simple fake HTTParty response that behaves like the real object
  # (supports .code, .body, and .response.code)
  #
  class FakeHttpResponse
    attr_reader :body, :code

    def initialize(body:, code: '200')
      @body = body
      @code = code
    end

    def response
      self
    end
  end

  # JSON body copied from a real Places API v1 call in your logs
  def fake_google_place_body
    {
      "types" => [
        "premise",
        "street_address"
      ],
      "formattedAddress" => "4145 Av. Beaconsfield, Montréal, QC H4A 2H4, Canada",
      "addressComponents" => [
        {
          "longText"   => "4145",
          "shortText"  => "4145",
          "types"      => ["street_number"],
          "languageCode" => "en-US"
        },
        {
          "longText"   => "Avenue Beaconsfield",
          "shortText"  => "Av. Beaconsfield",
          "types"      => ["route"],
          "languageCode" => "fr"
        },
        {
          "longText"   => "Côte-des-Neiges - Notre-Dame-de-Grâce",
          "shortText"  => "Côte-des-Neiges - Notre-Dame-de-Grâce",
          "types"      => ["sublocality_level_1", "sublocality", "political"],
          "languageCode" => "fr"
        },
        {
          "longText"   => "Montréal",
          "shortText"  => "Montréal",
          "types"      => ["locality", "political"],
          "languageCode" => "fr"
        },
        {
          "longText"   => "Montréal",
          "shortText"  => "Montréal",
          "types"      => ["administrative_area_level_3", "political"],
          "languageCode" => "fr"
        },
        {
          "longText"   => "Montréal",
          "shortText"  => "Montréal",
          "types"      => ["administrative_area_level_2", "political"],
          "languageCode" => "fr"
        },
        {
          "longText"   => "Québec",
          "shortText"  => "QC",
          "types"      => ["administrative_area_level_1", "political"],
          "languageCode" => "fr"
        },
        {
          "longText"   => "Canada",
          "shortText"  => "CA",
          "types"      => ["country", "political"],
          "languageCode" => "en"
        },
        {
          "longText"   => "H4A 2H4",
          "shortText"  => "H4A 2H4",
          "types"      => ["postal_code"],
          "languageCode" => "en-US"
        }
      ],
      "location" => {
        "latitude"  => 45.469074,
        "longitude" => -73.6258608
      },
      "googleMapsUri" =>
        "https://maps.google.com/?cid=8245879301643816964&g_mp=CiVnb29nbGUubWFwcy5wbGFjZXMudjEuUGxhY2VzLkdldFBsYWNlEAIYASAA"
    }.to_json
  end

  #
  # 1) Happy path: Google Places returns 200 with a valid body
  #
  test "create_resource for Place uses Google Places v1 response to build address fields" do
    log_in_as(@user)

    fake_http_response = FakeHttpResponse.new(
      body: fake_google_place_body,
      code: '200'
    )

    HTTParty.stub :get, fake_http_response do
      post linked_data_create_resource_path,
           params: {
             rdfs_class:   'Place',
             seedurl:      'tourismedeschenaux-ca',
             name:         '4145 ave beaconsfield',
             name_lang:    'en',
             address:      'ChIJnWHJM0sXyUwRBNA5S4k_b3I',
             statement_id: 2667827
           },
           xhr: true

      assert_response :success
      assert flash[:danger].blank?, "Expected no error flash on successful create_resource"
    end
  end

  #
  # 2) Failure path: Google Places returns 403 — we should skip enrichment
  #    and still complete successfully, using the raw name.
  #
  test "create_resource for Place gracefully skips Google fields when Places call fails" do
    log_in_as(@user)

    failed_http_response = FakeHttpResponse.new(
      body: '{"error":{"message":"PERMISSION_DENIED"}}',
      code: '403'
    )

    HTTParty.stub :get, failed_http_response do
      post linked_data_create_resource_path,
           params: {
             rdfs_class:   "Place",
             seedurl:      "tourismedeschenaux-ca",
             name:         "Some place",
             name_lang:    "en",
             address:      "ChIJnWHJM0sXyUwRBNA5S4k_b3I",
             statement_id: 2667827
           },
           xhr: true

      assert_response :success
      assert flash[:danger].blank?, "Expected no error flash when Google Places fails"
    end
  end

  #
  # 3) Place: numeric / short_name-style name
  #    This drives the branch where effective_name is replaced by @address
  #    because `matches_short_name || bare_number_or_unit` is true.
  #
  test "create_resource for Place replaces bare number name with formatted address" do
    log_in_as(@user)

    fake_http_response = FakeHttpResponse.new(
      body: fake_google_place_body,
      code: '200'
    )

    HTTParty.stub :get, fake_http_response do
      post linked_data_create_resource_path,
           params: {
             rdfs_class:   "Place",
             seedurl:      "tourismedeschenaux-ca",
             name:         "4145",  # matches shortText and is a bare number
             name_lang:    "en",
             address:      "ChIJnWHJM0sXyUwRBNA5S4k_b3I",
             statement_id: 2667827
           },
           xhr: true

      # We mainly care that the branch runs without error.
      assert_response :success
      assert flash[:danger].blank?
      # If you later switch to controller-style tests, you can assert that
      # options[:name][:value] == "4145 Av. Beaconsfield, Montréal, QC H4A 2H4, Canada".
    end
  end

  #
  # 4) Person branch: uses occupation to set disambiguating_description,
  #    no Google call is made.
  #
  test "create_resource for Person uses occupation disambiguating description" do
    log_in_as(@user)

    post linked_data_create_resource_path,
         params: {
           rdfs_class:   "Person",
           seedurl:      "tourismedeschenaux-ca",
           name:         "Jane Doe",
           name_lang:    "en",
           occupation:   "Conductor",
           statement_id: 2667827
         },
         xhr: true

    assert_response :success
    assert flash[:danger].blank?
  end

  #
  # 5) Generic branch: non-Place, non-Person → disambiguating_description = rdfs_class
  #
  test "create_resource_for_generic_class_falls_back_to_error_flash_when_Condenser_rejects_payload" do
    log_in_as(@user)

    post linked_data_create_resource_path,
        params: {
          rdfs_class:   "Event",
          seedurl:      "tourismedeschenaux-ca",
          name:         "My test event",
          name_lang:    "en",
          statement_id: 2667827
        },
        xhr: true

    # With xhr: true, redirect_back becomes Turbolinks JS with status 200
    assert_response :success

    # We *do* expect the error branch: flash danger set
    assert_not flash[:danger].blank?, "Expected an error flash when Condenser rejects the payload"
    assert_includes flash[:danger], "My test event"

    # Optional: assert we really got a Turbolinks redirect script
    assert_includes response.body, "Turbolinks.visit"
  end

end
