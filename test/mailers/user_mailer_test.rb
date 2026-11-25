require 'test_helper'

class UserMailerTest < ActionMailer::TestCase
  setup do
    @user = users(:michael)
    @original_url_options = UserMailer.default_url_options&.dup

    UserMailer.default_url_options = {
      host: 'console.footlight.io',
      protocol: 'https'
    }
  end

  teardown do
    UserMailer.default_url_options = @original_url_options
  end

  test "account activation" do
    @user.activation_token = User.new_token
    mail = UserMailer.account_activation(@user)

    assert_equal "Account activation", mail.subject
    assert_equal [@user.email], mail.to
    assert_equal ["info@culturecreates.com"], mail.from

    [mail.html_part, mail.text_part].each do |part|
      assert_not_nil part

      body = part.body.decoded
      assert_includes body, @user.name
      assert_includes body, @user.activation_token
      assert_includes body, CGI.escape(@user.email)
      assert_includes body, "https://console.footlight.io/account_activations/"
    end
  end

  test "password reset" do
    @user.reset_token = User.new_token
    mail = UserMailer.password_reset(@user)

    assert_equal "Password reset", mail.subject
    assert_equal [@user.email], mail.to
    assert_equal ["info@culturecreates.com"], mail.from

    [mail.html_part, mail.text_part].each do |part|
      assert_not_nil part

      body = part.body.decoded
      assert_includes body, @user.reset_token
      assert_includes body, CGI.escape(@user.email)
      assert_includes body, "https://console.footlight.io/password_resets/"
    end
  end
end
