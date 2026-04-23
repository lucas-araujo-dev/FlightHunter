class ProviderStatusComponent < ViewComponent::Base
  def initialize(provider:, result:)
    @provider = provider.to_s
    @result = result
  end

  def css_classes
    base = "px-4 py-2 rounded text-sm"
    case @result.status
    when "success" then "#{base} bg-green-50 text-green-800"
    when "empty" then "#{base} bg-gray-100 text-gray-600"
    when "cached" then "#{base} bg-indigo-50 text-indigo-700"
    when "failure", "timeout" then "#{base} bg-red-50 text-red-700"
    else "#{base} bg-gray-100 text-gray-700"
    end
  end

  def label
    case @result.status
    when "success"
      t("searches.providers.#{@provider}.success", count: @result.offer_ids.size)
    when "failure", "timeout"
      t("searches.providers.#{@provider}.#{@result.status}", error: @result.error_message.to_s.truncate(60))
    when "cached"
      t("searches.providers.#{@provider}.success", count: @result.offer_ids.size) + " · " + t("searches.cached_badge")
    else
      t("searches.providers.#{@provider}.#{@result.status}")
    end
  end
end
