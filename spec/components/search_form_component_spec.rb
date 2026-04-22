require "rails_helper"

RSpec.describe SearchFormComponent, type: :component do
  it "renders origin and destination combobox with correct data attributes" do
    render_inline(described_class.new(autocomplete_url: "/airports"))

    expect(page).to have_css("[data-controller='airport-combobox'][data-airport-combobox-url-value='/airports']", count: 2)
    expect(page).to have_css("input[name='origin_type']", visible: :all)
    expect(page).to have_css("input[name='origin_code']", visible: :all)
    expect(page).to have_css("input[name='destination_type']", visible: :all)
    expect(page).to have_css("input[name='destination_code']", visible: :all)
  end

  it "defaults to one_way and hides return dates" do
    render_inline(described_class.new(autocomplete_url: "/airports"))
    expect(page).to have_css("input[type='radio'][value='one_way'][checked]", visible: :all)
    expect(page).to have_css(".hidden input[name='return_date_from']", visible: :all)
  end

  it "renders round_trip with return dates visible when preset" do
    render_inline(described_class.new(
      autocomplete_url: "/airports",
      search_params: {trip_type: "round_trip"}
    ))
    expect(page).to have_css("input[type='radio'][value='round_trip'][checked]", visible: :all)
    expect(page).not_to have_css(".hidden input[name='return_date_from']", visible: :all)
  end

  it "pre-fills values when search_params provided" do
    render_inline(described_class.new(
      autocomplete_url: "/airports",
      search_params: {
        origin_type: "airport", origin_code: "FOR",
        destination_type: "city", destination_code: "São Paulo|BR",
        trip_type: "round_trip",
        departure_date_from: "2026-05-01",
        cabin_class: "business", passengers: 2
      }
    ))
    expect(page).to have_css("input[name='origin_code'][value='FOR']", visible: :all)
    expect(page).to have_css("input[name='destination_code'][value='São Paulo|BR']", visible: :all)
    expect(page).to have_css("input[name='departure_date_from'][value='2026-05-01']", visible: :all)
    expect(page).to have_css("select[name='cabin_class'] option[value='business'][selected]", visible: :all)
    expect(page).to have_css("input[name='passengers'][value='2']", visible: :all)
  end
end
