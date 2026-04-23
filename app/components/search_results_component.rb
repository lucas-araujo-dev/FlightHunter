class SearchResultsComponent < ViewComponent::Base
  PROVIDERS = FlightOffer::Search::Dispatch::PROVIDERS

  def initialize(search_id:)
    @search_id = search_id
  end

  attr_reader :search_id
end
