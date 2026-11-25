
require 'test_helper'

class PasswordResetsTest < ActionDispatch::IntegrationTest
  def setup
    ActionMailer::Base.deliveries.clear
    @user = users(:michael)
  end

  test "password reset complete journey" do
    get new_password_reset_path
    assert_template 'password_resets/new'

    # Request a password reset
    assert_difference 'ActionMailer::Base.deliveries.size', 1 do
      post password_resets_path,
           params: { password_reset: { email: @user.email } }
    end

    assert_redirected_to root_url
    assert_not_nil @user.reload.reset_digest

    # Obtain the token from the actual email, not controller assigns
    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail.text_part

    body = mail.text_part.body.decoded
    token = body[%r{/password_resets/([^/?\s]+)/edit}, 1]

    assert_not_nil token

    user = @user.reload

    # Wrong email
    get edit_password_reset_path(token, email: "")
    assert_redirected_to root_url

    # Inactive user
    user.toggle!(:activated)
    get edit_password_reset_path(token, email: user.email)
    assert_redirected_to root_url
    user.toggle!(:activated)

    # Right email, wrong token
    get edit_password_reset_path("wrong-token", email: user.email)
    assert_redirected_to root_url

    # Right email, right token
    get edit_password_reset_path(token, email: user.email)
    assert_template 'password_resets/edit'
    assert_select "input[name=email][type=hidden][value=?]", user.email

    # Invalid password confirmation
    patch password_reset_path(token),
          params: { email: user.email,
                    user: { password: "foobaz",
                            password_confirmation: "barquux" } }

    assert_select 'div#error_explanation'

    # Empty password
    patch password_reset_path(token),
          params: { email: user.email,
                    user: { password: "",
                            password_confirmation: "" } }

    assert_select 'div#error_explanation'

    # Valid password
    patch password_reset_path(token),
          params: { email: user.email,
                    user: { password: "foobaz",
                            password_confirmation: "foobaz" } }

    assert is_logged_in?
    assert_redirected_to user
    assert user.reload.authenticate("foobaz")

    # Reset credentials must be invalidated after use
    assert_nil user.reset_digest
    assert_nil user.reset_sent_at

    # A used link must no longer work
    get edit_password_reset_path(token, email: user.email)
    assert_redirected_to root_url
  end

  test "unknown and inactive accounts do not receive recovery emails" do
    message = "If the account is active, password reset instructions will be sent."

    ["", "unknown@example.com", users(:inactive).email].each do |email|
      assert_no_difference 'ActionMailer::Base.deliveries.size' do
        post password_resets_path,
             params: { password_reset: { email: email } }
      end

      assert_redirected_to root_url
      assert_equal message, flash[:info]
    end

    assert_nil users(:inactive).reload.reset_digest
  end

  test "inactive user cannot use a valid reset token" do
    user = users(:inactive)
    user.create_reset_digest

    get edit_password_reset_path(user.reset_token, email: user.email)

    assert_redirected_to root_url
  end
end
