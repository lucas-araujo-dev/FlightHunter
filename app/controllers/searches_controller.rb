class SearchesController < ApplicationController
  def new
    @search_params = session.delete(:search_params) || {}
  end

  def create
    session[:search_params] = search_params.to_h
    redirect_to new_search_path
  end

  private

  def search_params
    params.permit(
      :origin_type, :origin_code,
      :destination_type, :destination_code,
      :trip_type,
      :departure_date_from, :departure_date_to,
      :return_date_from, :return_date_to,
      :cabin_class, :passengers
    )
  end
end
