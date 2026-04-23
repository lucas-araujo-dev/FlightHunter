class SearchesController < ApplicationController
  def new
    @search_params = session.delete(:search_params) || {}
  end

  def create
    query = FlightOffer::Search::Query.from_params(search_params).validate!
    @search_id = SecureRandom.uuid_v7
    FlightOffer::Search::Dispatch.call(query: query, search_id: @search_id)
    respond_to do |format|
      format.turbo_stream
    end
  rescue FlightOffer::Search::Query::InvalidError => e
    flash.now[:alert] = t(e.i18n_key, **e.interpolations)
    @search_params = search_params.to_h
    render :new, status: :unprocessable_content
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
