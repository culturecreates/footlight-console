require 'test_helper'
require 'minitest/mock'

class SourcesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    payload = [
      {
        'domain' => 'Event',
        'selected' => true,
        'property' => 'Title',
        'property_id' => 1,
        'language' => 'en',
        'label' => 'Event'
      },
      {
        'domain' => 'Ignored',
        'selected' => true,
        'property' => 'Ignored',
        'property_id' => 2,
        'language' => 'en',
        'label' => 'Ignored'
      }
    ]

    Condenser::API.stub(:sources, payload) do
      get sources_url(seedurl: 'fass-ca')
    end

    assert_response :success
  end

  test "should get show" do
    payload = {
      'property_labels' => ['', 'Title'],
      'property_ids' => [1],
      'events' => {}
    }

    Condenser::API.stub(:property_statements, payload) do
      get source_url(id: 1, seedurl: 'fass-ca')
    end

    assert_response :success
  end
end
