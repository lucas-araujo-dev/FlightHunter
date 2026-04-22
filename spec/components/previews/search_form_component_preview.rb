class SearchFormComponentPreview < ViewComponent::Preview
  def default
    render SearchFormComponent.new(autocomplete_url: "/airports")
  end

  def pre_filled_round_trip
    render SearchFormComponent.new(
      autocomplete_url: "/airports",
      search_params: {
        origin_type: "airport", origin_code: "FOR",
        destination_type: "city", destination_code: "São Paulo|BR",
        trip_type: "round_trip",
        departure_date_from: (Date.current + 30).to_s,
        departure_date_to: (Date.current + 45).to_s,
        return_date_from: (Date.current + 50).to_s,
        return_date_to: (Date.current + 65).to_s,
        cabin_class: "business",
        passengers: 2
      }
    )
  end
end
