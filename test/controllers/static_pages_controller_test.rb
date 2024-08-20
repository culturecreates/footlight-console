require 'test_helper'

class StaticPagesControllerTest < ActionDispatch::IntegrationTest

  test "should get home" do
    get root_path
    assert_response :success
    assert_select "title", "Footlight Console"
  end

  test "should check code snippet" do
    get export_path(seedurl: "crowstheatre-com")
    assert_response :found
  end

end
