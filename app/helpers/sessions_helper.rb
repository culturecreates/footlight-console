module SessionsHelper
  include ApplicationHelper

  # Logs in the given user, prevents session fixation
  def log_in(user, notify: true)
    reset_session

    if notify
      user.update(login_at: Time.current)
      notify_login(user)
    end

    session[:user_id] = user.id
  end

  def notify_login(user)
    return unless Rails.env.production?

    HTTParty.post(
      slack_url_per_environment,
      body: { text: "#{user.name} (#{user.email}) started a new session on Footlight!" }.to_json,
      headers: { "Content-Type": "application/json" },
      timeout: 3
    )
  rescue StandardError => e
    AppLogger.error("Slack notification", e)
  end

  # Remembers a user in a persistent session.
  def remember(user)
    user.remember

    cookie_options = {
      httponly: true,
      secure: Rails.env.production?
    }

    cookies.permanent.signed[:user_id] = cookie_options.merge(value: user.id)

    cookies.permanent[:remember_token] = cookie_options.merge(value: user.remember_token)
  end

  # Returns true if the given user is the current user.
  def current_user?(user)
    current_user == user
  end

  # Returns the user corresponding to the remember token cookie.
  def current_user
    return @current_user if defined?(@current_user)

    if (user_id = session[:user_id])
      @current_user = User.find_by(id: user_id)

    elsif (user_id = cookies.signed[:user_id])
      user = User.find_by(id: user_id)

      if user&.authenticated?(:remember, cookies[:remember_token])
        log_in(user, notify: false)
        @current_user = user
      end
    end

    @current_user
  end

  # Returns true if the user is logged in, false otherwise.
  def logged_in?
    current_user.present?
  end

  # Forgets a persistent session.
  def forget(user)
    user.forget
    cookies.delete(:user_id)
    cookies.delete(:remember_token)
  end

  # Logs out the current user.
  def log_out
    forget(current_user) if current_user
    session.delete(:user_id)
    @current_user = nil
  end

  # Redirects to stored location (or to the default).
  def redirect_back_or(default)
    redirect_to(session[:forwarding_url] || default)
    session.delete(:forwarding_url)
  end

  # Stores the URL trying to be accessed.
  def store_location
    session[:forwarding_url] = request.original_url if request.get?
  end
end