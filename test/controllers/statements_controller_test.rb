require "test_helper"
require "webmock/minitest"

class StatementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:michael)

    stub_request(:patch, %r{localhost:3000/statements/.*/activate_individual})
      .to_return(
        status: 200,
        body: {}.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  test "should activate individual statement with json format" do
    log_in_as(@user)

    get activate_individual_statement_path(id: "123"), as: :json

    assert_response :redirect
  end

  test "should activate individual statement with json accept header" do
    log_in_as(@user)

    get activate_individual_statement_path(id: "123"), headers: { "ACCEPT" => "application/json" }

    assert_response :redirect
  end

  test "should activate individual statement when logged in" do
    log_in_as(@user)

    get activate_individual_statement_path(id: "123")

    assert_response :redirect
  end
end

