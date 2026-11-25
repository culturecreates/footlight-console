require 'test_helper'

class UsersSignupTest < ActionDispatch::IntegrationTest
  test "public signup page is disabled" do
    get signup_path
    assert_response :not_found
  end

  test "public registration cannot create an account" do
    assert_no_difference 'User.count' do
      post users_path, params: {
        user: {
          name: "Blocked Registration",
          email: "blocked@example.com",
          password: "password",
          password_confirmation: "password"
        }
      }
    end

    assert_response :not_found
  end

  test "login page does not advertise signup" do
    get login_path
    assert_response :success
    assert_select "a[href=?]", signup_path, count: 0
    assert_select "a[href=?]", new_password_reset_path, count: 1
  end
end
