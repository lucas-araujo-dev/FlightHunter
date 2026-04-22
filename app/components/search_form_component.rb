class SearchFormComponent < ViewComponent::Base
  CABIN_CLASSES = %w[economy premium_economy business first].freeze

  def initialize(autocomplete_url:, search_params: {})
    @autocomplete_url = autocomplete_url
    @search_params = search_params.to_h.with_indifferent_access
  end

  attr_reader :autocomplete_url

  def value_for(key, default = nil)
    @search_params[key].presence || default
  end

  def round_trip?
    value_for(:trip_type) == "round_trip"
  end

  def cabin_options
    CABIN_CLASSES.map { |key| [I18n.t("enums.flight_offer.cabin_class.#{key}"), key] }
  end
end
