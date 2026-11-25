class PasswordResetsController < ApplicationController
  before_action :get_user,         only: [:edit, :update]
  before_action :valid_user,       only: [:edit, :update]
  before_action :check_expiration, only: [:edit, :update]    # Case (1)

  def new
  end

  def create
    email = params.dig(:password_reset, :email).to_s.strip.downcase
    @user = User.find_by(email: email)

    if @user&.activated?
      @user.create_reset_digest
      @user.send_password_reset_email
    end

    flash[:info] = "If the account is active, password reset instructions will be sent."
    redirect_to root_url
  end

  def edit
  end

  def update
    if params.dig(:user, :password).to_s.empty?                                         # Case (3)
      @user.errors.add(:password, :blank)
      render 'edit'
    elsif @user.update(user_params.merge(reset_digest: nil, reset_sent_at: nil))        # Case (4)
      log_in @user
      flash[:success] = "Password has been reset."
      redirect_to @user
    else
      render 'edit'                                                                     # Case (2)
    end
  end

  private

    def user_params
      params.require(:user).permit(:password, :password_confirmation)
    end

    # Before filters

    def get_user
      @user = User.find_by(email: params[:email])
    end

    # Confirms a valid user.
    def valid_user
      unless (@user && @user.activated? &&
              @user.authenticated?(:reset, params[:id]))

        flash[:danger] = "User account has not been activated or there was a problem with the link."
        redirect_to root_url
      end
    end

    # Checks expiration of reset token.
    def check_expiration
      if @user.password_reset_expired?
        flash[:danger] = "Password reset has expired."
        redirect_to new_password_reset_url
      end
    end
end
