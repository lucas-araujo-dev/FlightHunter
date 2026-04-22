class SessionsController < ApplicationController
  skip_before_action :require_owner!, only: %i[new create]

  def new
    redirect_to root_path if logged_in?
  end

  def create
    user = User.find_by("lower(email) = ?", params[:email].to_s.downcase.strip)
    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      redirect_to root_path, notice: "Bem-vindo, #{user.email}."
    else
      flash.now[:alert] = "Email ou senha inválidos."
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    reset_session
    redirect_to login_path, notice: "Sessão encerrada."
  end
end
