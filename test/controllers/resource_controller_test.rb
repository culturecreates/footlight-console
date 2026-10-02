require 'test_helper'
require 'minitest/mock'

class ResourcesControllerTest < ActionDispatch::IntegrationTest
  class FakeHttpResponse
    attr_reader :body, :code

    def initialize(body:, code:)
      @body = body
      @code = code
    end

    def response
      self
    end
  end

  test "renders an unavailable resource as an external resource" do
    uri = "http://schema.org/EventScheduled"
    response = FakeHttpResponse.new(body: '{"error":"Not Found"}', code: "404")

    HTTParty.stub :get, response do
      get resource_index_path(uri: uri)
    end

    assert_response :success
    assert_select "h1.title", text: /External resource/
    assert_select "a[href=?]", uri
  end

  test "uses the seedurl parameter and renders an empty list for a Condenser error" do
    seedurl = "sandersoncentre-ca"
    request_url = nil
    response = FakeHttpResponse.new(body: '{"error":"Not Found"}', code: "404")
    response_stub = ->(url, **_options) { request_url = url; response }

    HTTParty.stub :get, response_stub do
      get resource_index_path(seedurl: seedurl)
    end

    assert_includes request_url, "/websites/#{seedurl}/resources.json"
    assert_response :success
    assert_select "h2.title", text: "Places"
    assert_select "p.has-text-grey", text: "No resources found.", count: 4
  end

  test "renders people places and organizations from flat Condenser resource collections" do
    resources = {
      "person" => [{ "uri" => "footlight:person-1", "name" => "Louise Pitre" }],
      "place" => [{ "uri" => "footlight:place-1", "name" => "Sanderson Centre" }],
      "organization" => [{ "uri" => "footlight:organization-1", "name" => "Brantford Symphony" }],
      "event_type" => [{ "uri" => "footlight:event-type-1", "name" => "Performing Arts Event" }],
      "resource_list" => []
    }
    response = FakeHttpResponse.new(body: resources.to_json, code: "200")

    HTTParty.stub :get, response do
      get resource_index_path(seedurl: "sandersoncentre-ca")
    end

    assert_response :success
    assert_select "h2.title", text: "Places"
    assert_select "h2.title", text: "People"
    assert_select "h2.title", text: "Organizations"
    assert_select "h2.title", text: "Event Types"
    assert_select "a", text: "Louise Pitre"
    assert_select "a", text: "Sanderson Centre"
    assert_select "a", text: "Brantford Symphony"
    assert_select "a", text: "Performing Arts Event"
  end

  test "links resource detail to its website resources list" do
    uri = "footlight:event-type-1"
    seedurl = "gatineau-cloud"
    resource_response = FakeHttpResponse.new(
      body: { "uri" => uri, "seedurl" => seedurl, "statements" => {} }.to_json,
      code: "200"
    )
    links_response = FakeHttpResponse.new(body: "[]", code: "200")
    response_stub = lambda do |url, **_options|
      url.include?("/resources.json?") ? resource_response : links_response
    end

    HTTParty.stub :get, response_stub do
      get resource_index_path(uri: uri)
    end

    assert_response :success
    assert_select "h2.subtitle a[href=?]", resource_index_path(seedurl: seedurl), text: seedurl
  end
end
