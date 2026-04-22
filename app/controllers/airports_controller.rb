# frozen_string_literal: true

class AirportsController < ApplicationController
  def index
    results = Airport::Autocomplete.call(params[:q])
    render json: results.map(&:to_h)
  end
end
