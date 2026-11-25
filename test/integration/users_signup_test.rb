require 'test_helper'
require 'minitest/mock'

class UsersSignupTest < ActionDispatch::IntegrationTest

  # def setup
  #   ActionMailer::Base.deliveries.clear
  # end

  test "staging disables public signup and keeps sign in and password recovery" do
    Rails.env.stub(:staging?, true) do
      get signup_path
      assert_response :not_found
      get new_user_path
      assert_response :not_found

      assert_no_difference "User.count" do
        post users_path, params: { user: { name: "Staging User", email: "staging@example.com",
          password: "password", password_confirmation: "password" } }
      end
      assert_response :not_found

      get dashboard_path
      assert_response :success
      assert_select "a[href=?]", signup_path, count: 0
      assert_select "a[href=?]", login_path, minimum: 1
      get login_path
      assert_response :success
      assert_select "a[href=?]", signup_path, count: 0
      assert_select "a[href=?]", new_password_reset_path, text: "Forgot password"
    end
  end

  test "invalid signup information" do
    get signup_path
    assert_no_difference 'User.count' do
      post users_path, params: { user: { name:  "",
                                         email: "user@invalid",
                                         password:              "foo",
                                         password_confirmation: "bar" } }
    end
    assert_template 'users/new'
    # assert_select 'div#error_explanation'
    # assert_select 'div.field_with_errors'
  end

  test "valid signup information with account activation" do
    get signup_path
    assert_difference 'User.count', 1 do
      post users_path, params: { user: { name:  "Example User",
                                         email: "user@example.com",
                                         password:              "password",
                                         password_confirmation: "password" } }
    end
    # assert_equal 1, ActionMailer::Base.deliveries.size
    user = assigns(:user)
    assert_not user.activated?
    # Try to log in before activation.
    log_in_as(user)
    assert_not is_logged_in?
    # Invalid activation token
    get edit_account_activation_path("invalid token", email: user.email)
    assert_not is_logged_in?
    # Valid token, wrong email
    get edit_account_activation_path(user.activation_token, email: 'wrong')
    assert_not is_logged_in?
    # Valid activation token
    get edit_account_activation_path(user.activation_token, email: user.email)
    assert user.reload.activated?
    follow_redirect!
    assert_template 'websites/first_scrape'
    assert is_logged_in?
  end
end
