require 'test_helper'

class SourcesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get sources_index_url(seedurl: "fass-ca")
    assert_response :success
  end

  test "should get show" do
    get sources_show_url(id: 1)
    assert_response :success
  end

end
