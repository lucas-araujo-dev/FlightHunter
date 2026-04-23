class FlightOffer::Search::Broadcast
  def self.call(search_id:, provider:, result:)
    new(search_id: search_id, provider: provider, result: result).call
  end

  def initialize(search_id:, provider:, result:)
    @search_id = search_id
    @provider = provider.to_s
    @result = result
  end

  def call
    stream_key = "flight_offer_search_#{@search_id}"

    if @result.success?
      FlightOffer.where(id: @result.offer_ids).find_each do |offer|
        Turbo::StreamsChannel.broadcast_append_to(
          stream_key,
          target: "flight_offer_cards",
          html: FlightOfferCardComponent.new(offer: offer, provider: @provider).render_in(view_context)
        )
      end
    end

    Turbo::StreamsChannel.broadcast_replace_to(
      stream_key,
      target: "provider_status_#{@provider}",
      html: ProviderStatusComponent.new(provider: @provider, result: @result).render_in(view_context)
    )
  end

  private

  def view_context
    @view_context ||= begin
      controller = ApplicationController.new
      controller.request = ActionDispatch::Request.new({})
      controller.response = ActionDispatch::Response.new
      controller.view_context
    end
  end
end
