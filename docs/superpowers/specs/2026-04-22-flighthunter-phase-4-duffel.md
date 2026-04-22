# FlightHunter — Fase 4: Primeiro search adapter (Duffel) + J1 completa

> Sub-spec da Fase 4. Master: `docs/superpowers/specs/2026-04-22-flighthunter-design.md` §8. Cobre J1 end-to-end com um único provider (Duffel cash). Pré-requisito: Fase 3 (autocomplete + form esqueleto). Data: 2026-04-22.

## 1. Escopo

Cinco entregáveis acoplados que, juntos, fazem J1 funcionar de ponta a ponta:

1. **`FlightOffer::Search::Query`** — PORO (`Data.define`) que wrappea params normalizados, valida invariantes e expõe `cache_key` determinístico.
2. **`FlightOffer::Search::Base` + `::Duffel`** — interface abstrata + adapter concreto chamando Duffel API via HTTParty. Persiste resultados como `FlightOffer` com dedup por `(provider, provider_offer_id)`.
3. **`FlightOffer::Search::Dispatch`** — orquestração que checa Solid Cache e enfileira jobs por provider (Fase 4: só Duffel).
4. **`FlightOffer::Search::DuffelJob`** — casca ActiveJob na queue `:flight_offers`.
5. **`FlightOffer::Search::Broadcast`** — PORO que converte `Result` em `turbo_stream.append` / `turbo_stream.replace` via Solid Cable, renderizando `FlightOfferCardComponent`. `SearchesController#create` responde com `turbo_stream.erb` que inicia a subscription.

Após a fase: submeter o form de busca dispara uma busca real na Duffel sandbox e as ofertas aparecem na tela progressivamente via Turbo Stream. Cache hit (mesma busca em <30min) retorna instantâneo com badge "cached".

## 2. Jornadas cobertas

- **J1 — busca ad-hoc** — completa com um provider. REQUIREMENTS.md §3.1 menciona "sistema dispara jobs paralelos a todos os providers aplicáveis"; Fase 4 entrega o pipeline paralelizável com `Duffel` como primeiro plug. Fase 5 acrescenta Amadeus/seats.aero/Smiles reutilizando as mesmas classes de orquestração.

Edge cases cobertos nesta fase:
- Cache hit (<30min) → resultados instantâneos com badge.
- Provider falha / timeout → ProviderCheck `failure`, UI mostra "Duffel falhou" sem bloquear.
- Zero ofertas retornadas → mensagem clara "Nenhuma oferta encontrada" + botão "Criar alerta com esses critérios".

## 3. Decisões arquiteturais

Autoridade: `CLAUDE.base.md`.

- **Vocabulário unificado.** `grep FlightOffer::Search` retorna Query + Base + Duffel + Dispatch + Result + Broadcast em um único resultado. Todos sob `app/models/flight_offer/search/`.
- **Sem `app/services/`, sem `lib/duffel/`, sem `app/providers/`.** Adapter Duffel vive em `app/models/flight_offer/search/duffel.rb`, HTTP client embutido (HTTParty direto — sem wrapper de gem externo).
- **Autoridade no model dono.** `FlightOffer` permanece dono do dado; scopes como `.fresh_for(query)` (cache-hit query) moram no próprio `flight_offer.rb`. Adapters operam sobre atributos, persistem via `upsert_all`.
- **Controller thin.** `SearchesController#create` continua com 5-7 linhas: normaliza params → delega pra `Dispatch` → renderiza `create.turbo_stream.erb`.
- **Orquestração nomeada.** `Dispatch` é um PORO (não callback, não `after_commit`). `Broadcast` idem. Nenhum side-effect escondido.
- **Zero route overrides.** Rotas `/searches` já resolvidas na Fase 3 sem custom mapping. Mantém.
- **i18n obrigatório em toda string user-facing.** Zero hardcode em views, components, flash messages, error messages de `Query#validate!` e labels de `ProviderStatusComponent`. Tudo via `t("...")` com `pt-BR` + `en` espelhados (espelhamento é invariante: se a key existe em um locale, existe no outro). Specs usam `I18n.t(...)` nas assertions, nunca string literal em PT. Mensagens de `ArgumentError` em `Query#validate!` carregam o key i18n no `message` e o controller traduz antes de `flash.now[:alert]`. Regra do projeto: toda PR que introduza string literal user-facing é bloqueada.

## 4. Arquivos

### Novos — models/orquestrações

- `app/models/flight_offer/search/query.rb` — `FlightOffer::Search::Query` (Data.define).
- `app/models/flight_offer/search/result.rb` — `FlightOffer::Search::Result` (Data.define).
- `app/models/flight_offer/search/base.rb` — superclasse abstrata.
- `app/models/flight_offer/search/duffel.rb` — adapter HTTParty.
- `app/models/flight_offer/search/dispatch.rb` — orquestração cache + fan-out.
- `app/models/flight_offer/search/broadcast.rb` — Turbo Streams renderer.

### Novos — jobs

- `app/jobs/flight_offer/search/duffel_job.rb`

### Novos — views/components

- `app/components/flight_offer_card_component.rb` + `.html.erb`
- `app/components/search_results_component.rb` + `.html.erb` (substitui o placeholder criado na Fase 3; vira o container de status + subscription)
- `app/components/provider_status_component.rb` + `.html.erb`
- `app/views/searches/create.turbo_stream.erb` — resposta inicial do `create` com turbo_stream.replace do frame `search_results`
- `spec/components/previews/flight_offer_card_component_preview.rb`
- `spec/components/previews/provider_status_component_preview.rb`

### Novos — migration

- `db/migrate/<ts>_add_provider_offer_id_to_flight_offers.rb`
  - Adiciona `provider_offer_id` (string, not null) + índice unique composto `(provider, provider_offer_id)`.
  - Backfill não é problema: tabela `flight_offers` está vazia pós-Fase 1 (nenhum provider rodou ainda).

### Novos — i18n

- `config/locales/flight_offer.pt-BR.yml` (ou incluir em `pt-BR.yml` existente)
- `config/locales/flight_offer.en.yml` (espelhado)

### Novos — specs

- `spec/models/flight_offer/search/query_spec.rb`
- `spec/models/flight_offer/search/duffel_spec.rb` — VCR cassette contra Duffel sandbox
- `spec/models/flight_offer/search/dispatch_spec.rb` — cache hit / miss + enqueue
- `spec/models/flight_offer/search/broadcast_spec.rb`
- `spec/jobs/flight_offer/search/duffel_job_spec.rb`
- `spec/requests/searches_spec.rb` — atualizado pra cobrir `POST /searches` happy path (enfileira + responde turbo_stream)
- `spec/components/flight_offer_card_component_spec.rb`
- `spec/components/search_results_component_spec.rb`
- `spec/components/provider_status_component_spec.rb`
- `spec/cassettes/flight_offer/search/duffel/offers_for_for_gru.yml` — cassette VCR

### Modificados

- `app/controllers/searches_controller.rb` — `create` delega pra `Dispatch`.
- `app/components/search_form_component.html.erb` — ajustar o `<turbo-frame>` pra `turbo_stream_from` após create (ou manter frame + overlay stream, ver §10).
- `config/credentials.yml.enc` (development) — add `duffel: { api_key: "duffel_test_..." }`. Prod vem depois via Kamal secrets.
- `config/routes.rb` — nada.
- `spec/requests/searches_spec.rb` — ampliado.

### Deletados

- Nenhum.

## 5. Data model

### 5.1 Migration — `provider_offer_id` em FlightOffer

```ruby
class AddProviderOfferIdToFlightOffers < ActiveRecord::Migration[8.1]
  def change
    add_column :flight_offers, :provider_offer_id, :string

    # Backfill: tabela vazia, basta mudar pra not null logo após add_column.
    change_column_null :flight_offers, :provider_offer_id, false

    add_index :flight_offers, [:provider, :provider_offer_id],
              unique: true, name: "idx_flight_offers_provider_offer_unique"
  end
end
```

**Por que:** Duffel (e todos os providers) emitem um ID próprio por offer. Persistir esse ID permite `upsert_all(unique_by: [:provider, :provider_offer_id])`, evitando lixo acumulando em cada ciclo de alerta de 2h (Fase 6). Sem isso, teríamos 10 buscas/dia × 30 dias = 300 offers redundantes por rota.

### 5.2 Sem outras mudanças de schema

`Alert`, `AlertMatch`, `ProviderCheck`, `User`, `Airport` intocados.

## 6. `FlightOffer::Search::Query`

PORO via `Data.define`. Responsável por:
- Normalizar params do controller
- Validar invariantes de domínio
- Expor `cache_key` determinístico
- Resolver `origin_airports` / `destination_airports` quando `*_type == "city"`

### 6.1 Contrato

```ruby
# app/models/flight_offer/search/query.rb
class FlightOffer::Search::Query < Data.define(
  :origin_type, :origin_code,
  :destination_type, :destination_code,
  :trip_type,
  :departure_date_from, :departure_date_to,
  :return_date_from, :return_date_to,
  :cabin_class, :passengers
)
  TRIP_TYPES   = %w[one_way round_trip].freeze
  LOCATION_TYPES = %w[airport city].freeze
  CABIN_CLASSES = FlightOffer::CABIN_CLASSES

  def self.from_params(params)
    new(
      origin_type: params[:origin_type],
      origin_code: params[:origin_code],
      destination_type: params[:destination_type],
      destination_code: params[:destination_code],
      trip_type: params[:trip_type].presence || "one_way",
      departure_date_from: Date.parse(params[:departure_date_from].to_s),
      departure_date_to:   Date.parse((params[:departure_date_to].presence || params[:departure_date_from]).to_s),
      return_date_from: params[:return_date_from].presence && Date.parse(params[:return_date_from]),
      return_date_to:   params[:return_date_to].presence   && Date.parse(params[:return_date_to]),
      cabin_class: params[:cabin_class].presence || "economy",
      passengers:  (params[:passengers].presence || 1).to_i
    )
  end

  def round_trip?    = trip_type == "round_trip"
  def one_way?       = trip_type == "one_way"

  def origin_airports
    @origin_airports ||= resolve_airports(origin_type, origin_code)
  end

  def destination_airports
    @destination_airports ||= resolve_airports(destination_type, destination_code)
  end

  def cache_key
    @cache_key ||= begin
      payload = to_h.except(:return_date_from, :return_date_to).merge(
        return_from: return_date_from&.iso8601,
        return_to:   return_date_to&.iso8601,
        dep_from:    departure_date_from.iso8601,
        dep_to:      departure_date_to.iso8601
      ).sort.to_h
      "flight_offer:search:#{Digest::SHA1.hexdigest(payload.to_json)}"
    end
  end

  # Raise InvalidError.new(i18n_key, **interpolations). Controller traduz antes
  # de exibir. Mensagem em inglês pura só em log (via #to_s do InvalidError).
  class InvalidError < StandardError
    attr_reader :i18n_key, :interpolations

    def initialize(i18n_key, **interpolations)
      @i18n_key = i18n_key
      @interpolations = interpolations
      super("Invalid search query: #{i18n_key}")
    end
  end

  def validate!
    raise InvalidError.new("searches.errors.invalid_origin_type")      unless LOCATION_TYPES.include?(origin_type)
    raise InvalidError.new("searches.errors.invalid_destination_type") unless LOCATION_TYPES.include?(destination_type)
    raise InvalidError.new("searches.errors.invalid_trip_type")        unless TRIP_TYPES.include?(trip_type)
    raise InvalidError.new("searches.errors.invalid_cabin_class")      unless CABIN_CLASSES.include?(cabin_class)
    raise InvalidError.new("searches.errors.invalid_passengers")       unless (1..9).cover?(passengers)
    raise InvalidError.new("searches.errors.departure_range_invalid")  if departure_date_from > departure_date_to
    raise InvalidError.new("searches.errors.departure_in_past")        if departure_date_from < Date.current
    if round_trip?
      raise InvalidError.new("searches.errors.return_date_required") if return_date_from.blank?
      raise InvalidError.new("searches.errors.return_before_departure") if return_date_from < departure_date_from
    end
    raise InvalidError.new("searches.errors.origin_has_no_airports")      if origin_airports.empty?
    raise InvalidError.new("searches.errors.destination_has_no_airports") if destination_airports.empty?
    self
  end

  private

  def resolve_airports(type, code)
    case type
    when "airport" then Airport.where(iata_code: code).to_a
    when "city"
      city, country = code.to_s.split("|", 2)
      Airport.where(city: city, country: country).to_a
    else []
    end
  end
end
```

### 6.2 Testes
- `from_params` constrói com defaults (trip_type "one_way", cabin "economy", passengers 1).
- `validate!` raise `InvalidError` em cada invariante; asserir `e.i18n_key` (string de chave), nunca a tradução. Matriz completa cobrindo todos os 11 keys de `searches.errors.*`.
- `cache_key` determinístico: mesmo input → mesma chave; inputs diferentes → chaves diferentes.
- `round_trip?` / `one_way?` refletem `trip_type`.
- `origin_airports` resolve por IATA e por city|country.

## 7. `FlightOffer::Search::Result`

```ruby
# app/models/flight_offer/search/result.rb
class FlightOffer::Search::Result < Data.define(:status, :offer_ids, :duration_ms, :error_message, :provider)
  STATUSES = %w[success empty failure timeout cached].freeze

  def success?  = status == "success"
  def empty?    = status == "empty"
  def cached?   = status == "cached"
  def failed?   = %w[failure timeout].include?(status)
end
```

`cached` é um status sintético emitido apenas por `Dispatch#deliver_cached` pra sinalizar na UI que o resultado veio do Solid Cache. Adapters nunca emitem `cached`.

## 8. `FlightOffer::Search::Base`

```ruby
# app/models/flight_offer/search/base.rb
class FlightOffer::Search::Base
  TIMEOUT_SECONDS = 15

  def self.call(query) = new(query).call

  def initialize(query)
    @query = query
  end

  def call
    raise NotImplementedError
  end

  def provider_name
    raise NotImplementedError
  end

  protected

  def timed
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield.tap { @duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round }
  end

  def log_check(status:, offers_count: 0, error_message: nil)
    ProviderCheck.create!(
      provider: provider_name,
      origin_code: @query.origin_code,
      destination_code: @query.destination_code,
      status: status,
      error_message: error_message&.truncate(1000),
      offers_count: offers_count,
      duration_ms: @duration_ms || 0,
      ran_at: Time.current
    )
  end

  def build_result(status:, offer_ids: [], error_message: nil)
    FlightOffer::Search::Result.new(
      status: status,
      offer_ids: offer_ids,
      duration_ms: @duration_ms || 0,
      error_message: error_message,
      provider: provider_name
    )
  end
end
```

**Nota:** `ProviderCheck` aceita `status` enum `success`/`failure`/`rate_limited`. Mapear: `success`/`empty` → `success`; `failure` → `failure`; `timeout` → `failure`. Adicionar `rate_limited` no Duffel quando HTTP 429. Ver §9.3.

## 9. `FlightOffer::Search::Duffel` — adapter

### 9.1 Integração Duffel — referência

- **Base URL:** `https://api.duffel.com`
- **Header obrigatório:** `Duffel-Version: v2`
- **Auth:** `Authorization: Bearer <api_key>`
- **Content-Type:** `application/json`
- **Endpoint:** `POST /air/offer_requests?return_offers=true&supplier_timeout=10000`
  - Request body shape:
    ```json
    {
      "data": {
        "slices": [
          { "origin": "FOR", "destination": "GRU", "departure_date": "2026-05-15" }
        ],
        "passengers": [{"type": "adult"}],
        "cabin_class": "economy"
      }
    }
    ```
  - Round-trip: adicionar segunda slice com origin/destination invertidos.
  - Response: `data.offers` array.
- **Rate limit:** 60 req/min tier grátis. HTTP 429 quando exceder.
- **Sandbox vs live:** chave com prefixo `duffel_test_` vai pro ambiente de teste automaticamente; `duffel_live_` vai pra produção. Sem flag separado.

### 9.2 Mapeamento payload → `FlightOffer`

Para cada `offer` no response:

| Duffel field | FlightOffer column | Notas |
|---|---|---|
| `id` | `provider_offer_id` | Usado para dedup |
| — | `provider` | `"duffel"` constante |
| — | `offer_type` | `"cash"` constante |
| `slices[0].origin.iata_code` | → resolve Airport.iata_code → `origin_airport_id` | Se não achar, skip offer com log |
| `slices[0].destination.iata_code` | → `destination_airport_id` | idem |
| `slices[0].segments[0].departing_at` | `departure_at` | Already ISO8601 |
| `slices[0].segments[-1].arriving_at` | `arrival_at` | |
| `slices[1].segments[0].departing_at` | `return_departure_at` | Só se round_trip |
| `slices[1].segments[-1].arriving_at` | `return_arrival_at` | idem |
| `slices[0].segments[0].marketing_carrier.iata_code` | `airline_iata` | Carrier da 1ª perna |
| `slices.flat_map { |s| s.segments.map { |seg| seg.marketing_carrier_flight_number } }` | `flight_numbers` (JSON) | |
| `slices[0].segments.length - 1` | `stops` | 0 = direto; 1 = 1 conexão |
| `cabin_class` do request | `cabin_class` | |
| `total_amount` (string) | `price_cents` | `(BigDecimal(total_amount) * 100).to_i` |
| `total_currency` | `currency` | |
| — | `miles`, `taxes_cents`, `program` | nil (cash offer) |
| `https://app.duffel.com/offers/<id>` | `deep_link` | pattern Duffel padrão; fallback para home Duffel |
| — | `raw_payload` | `offer.to_json` (full payload) |
| — | `found_at` | `Time.current` |
| `expires_at` (Duffel field) | `expires_at` | Já ISO8601 |

### 9.3 Implementação

```ruby
# app/models/flight_offer/search/duffel.rb
require "httparty"

class FlightOffer::Search::Duffel < FlightOffer::Search::Base
  include HTTParty

  BASE_URL = "https://api.duffel.com".freeze
  API_VERSION = "v2".freeze
  DEEP_LINK_BASE = "https://app.duffel.com/offers".freeze
  SUPPLIER_TIMEOUT_MS = 10_000

  def provider_name = "duffel"

  def call
    timed { fetch_and_persist }
  rescue Net::OpenTimeout, Net::ReadTimeout, HTTParty::Error => e
    log_check(status: "failure", error_message: e.message)
    build_result(status: "timeout", error_message: e.message)
  rescue StandardError => e
    Sentry.capture_exception(e) if defined?(Sentry)
    log_check(status: "failure", error_message: e.message)
    build_result(status: "failure", error_message: e.message)
  end

  private

  def fetch_and_persist
    response = self.class.post(
      "#{BASE_URL}/air/offer_requests",
      query: {return_offers: true, supplier_timeout: SUPPLIER_TIMEOUT_MS},
      headers: {
        "Authorization" => "Bearer #{api_key}",
        "Duffel-Version" => API_VERSION,
        "Content-Type" => "application/json",
        "Accept" => "application/json"
      },
      body: request_body.to_json,
      timeout: TIMEOUT_SECONDS
    )

    return rate_limited_result if response.code == 429
    raise "Duffel HTTP #{response.code}: #{response.body.to_s[0, 500]}" unless response.success?

    offers = response.parsed_response.dig("data", "offers") || []
    return empty_result if offers.empty?

    records = offers.filter_map { |offer| build_record(offer) }
    return empty_result if records.empty?

    FlightOffer.upsert_all(
      records,
      unique_by: [:provider, :provider_offer_id],
      returning: [:id]
    )
    offer_ids = FlightOffer.where(
      provider: "duffel",
      provider_offer_id: records.map { |r| r[:provider_offer_id] }
    ).pluck(:id)

    log_check(status: "success", offers_count: offer_ids.size)
    build_result(status: "success", offer_ids: offer_ids)
  end

  def rate_limited_result
    log_check(status: "rate_limited", error_message: "HTTP 429")
    build_result(status: "failure", error_message: "Duffel rate limit")
  end

  def empty_result
    log_check(status: "success", offers_count: 0)
    build_result(status: "empty")
  end

  def api_key
    Rails.application.credentials.dig(:duffel, :api_key) ||
      raise("Duffel credentials ausentes (credentials.duffel.api_key)")
  end

  def request_body
    {
      data: {
        slices: slices,
        passengers: Array.new(@query.passengers) { {type: "adult"} },
        cabin_class: @query.cabin_class
      }
    }
  end

  def slices
    origin      = @query.origin_airports.first.iata_code
    destination = @query.destination_airports.first.iata_code

    out = [{origin: origin, destination: destination, departure_date: @query.departure_date_from.iso8601}]
    if @query.round_trip?
      out << {origin: destination, destination: origin, departure_date: @query.return_date_from.iso8601}
    end
    out
  end

  def build_record(offer)
    origin_iata      = offer.dig("slices", 0, "origin", "iata_code")
    destination_iata = offer.dig("slices", 0, "destination", "iata_code")
    origin_airport      = Airport.find_by(iata_code: origin_iata)
    destination_airport = Airport.find_by(iata_code: destination_iata)
    return nil unless origin_airport && destination_airport

    now = Time.current
    first_slice  = offer["slices"][0]
    first_segment = first_slice["segments"].first
    last_segment  = first_slice["segments"].last
    second_slice = offer["slices"][1]

    {
      provider: "duffel",
      provider_offer_id: offer.fetch("id"),
      offer_type: "cash",
      origin_airport_id: origin_airport.id,
      destination_airport_id: destination_airport.id,
      departure_at: first_segment["departing_at"],
      arrival_at: last_segment["arriving_at"],
      return_departure_at: second_slice&.dig("segments", 0, "departing_at"),
      return_arrival_at:   second_slice&.dig("segments", -1, "arriving_at"),
      airline_iata: first_segment.dig("marketing_carrier", "iata_code"),
      flight_numbers: first_slice["segments"]
        .map { |s| s["marketing_carrier_flight_number"] }.compact.to_json,
      stops: first_slice["segments"].length - 1,
      cabin_class: @query.cabin_class,
      price_cents: (BigDecimal(offer["total_amount"]) * 100).to_i,
      currency: offer["total_currency"],
      deep_link: "#{DEEP_LINK_BASE}/#{offer.fetch("id")}",
      raw_payload: offer.to_json,
      found_at: now,
      expires_at: offer["expires_at"],
      created_at: now,
      updated_at: now
    }
  end
end
```

### 9.4 Testes (VCR)

Cassette real contra Duffel sandbox (token `duffel_test_...` em `config/credentials.yml.enc` de development). Uma cassette cobre:
- `spec/cassettes/flight_offer/search/duffel/offers_for_for_gru.yml` — busca FOR → GRU 2026-05-15 one-way economy 1 pax, retornando ≥1 offer.

Specs:
1. **success path** — query FOR→GRU → `Result(status: "success", offer_ids: [...])`. FlightOffer persistido; ProviderCheck criado com `status: success`, `offers_count > 0`.
2. **empty path** — cassette com `data.offers: []` → `Result(status: "empty")`, ProviderCheck `success` + `offers_count: 0`.
3. **HTTP 429** — cassette mockada → `Result(status: "failure")`, ProviderCheck `rate_limited`.
4. **Timeout** — WebMock `to_timeout` → `Result(status: "timeout")`, ProviderCheck `failure`.
5. **HTTP 500** — cassette → `Result(status: "failure")` com error_message preenchido.
6. **Idempotência** — rodar 2x com mesma cassette → mesmo conjunto de offers, sem duplicatas (graças ao unique index).
7. **Round-trip** — query round_trip popula `return_departure_at`/`return_arrival_at`.
8. **Sem credenciais** — raise com mensagem explícita.
9. **Airport desconhecido** — se response traz offer com IATA que não existe em `airports`, essa offer é pulada (log), restante persiste.

Filter de secrets no VCR (`spec/support/vcr.rb` já configurado da Fase 0): redigir `Authorization` header.

## 10. `FlightOffer::Search::Dispatch` — orquestração

### 10.1 Contrato

```ruby
# app/models/flight_offer/search/dispatch.rb
class FlightOffer::Search::Dispatch
  CACHE_TTL_SUCCESS = 30.minutes
  CACHE_TTL_EMPTY   = 5.minutes

  def self.call(query:, search_id:) = new(query: query, search_id: search_id).call

  def initialize(query:, search_id:)
    @query = query
    @search_id = search_id
  end

  def call
    cached = Rails.cache.read(@query.cache_key)
    return deliver_cached(cached) if cached.present?

    enqueue_providers
    :enqueued
  end

  private

  def deliver_cached(offer_ids)
    # Itera sobre providers conhecidos (Fase 4: só duffel) para atualizar cada
    # provider_status_<provider> na UI com badge "em cache". Sem target inexistente
    # no DOM.
    SearchResultsComponent::PROVIDERS.each do |provider|
      FlightOffer::Search::Broadcast.cached(
        search_id: @search_id,
        provider: provider,
        offer_ids: offer_ids
      )
    end
    :cache_hit
  end

  def enqueue_providers
    # Fase 4: só Duffel. Fase 5 itera sobre um registry.
    FlightOffer::Search::DuffelJob.perform_later(@query.to_h, @search_id)
  end
end
```

**Nota sobre serialização:** `Data` instances não são serializáveis por Active Job por default (Rails 8.1 aceita via GlobalID-like wrapping, mas `Data.define` requer custom serializer). Estratégia: passar `query.to_h` no job e reconstruir via `FlightOffer::Search::Query.new(**hash)` no `perform`. Trade-off: perde tipo estrito na serialização, ganha simplicidade.

### 10.2 Cache write

Quem escreve no cache: **o job**, após sucesso (ver §11). Dispatch só lê. Regra: cache fica sempre consistente com Result final.

### 10.3 Testes

- Cache miss → enfileira `DuffelJob` + retorna `:enqueued`.
- Cache hit → chama `Broadcast.cached` + **não** enfileira + retorna `:cache_hit`.
- Cache hit com `offer_ids: []` → broadcast de empty state (sem cards).

## 11. `FlightOffer::Search::DuffelJob`

```ruby
# app/jobs/flight_offer/search/duffel_job.rb
class FlightOffer::Search::DuffelJob < ApplicationJob
  queue_as :flight_offers

  def perform(query_hash, search_id)
    query  = FlightOffer::Search::Query.new(**query_hash.symbolize_keys)
    result = FlightOffer::Search::Duffel.call(query)

    FlightOffer::Search::Broadcast.call(
      search_id: search_id,
      provider: :duffel,
      result: result
    )

    cache_ttl = result.empty? ? FlightOffer::Search::Dispatch::CACHE_TTL_EMPTY
                              : FlightOffer::Search::Dispatch::CACHE_TTL_SUCCESS
    Rails.cache.write(query.cache_key, result.offer_ids, expires_in: cache_ttl)
  end
end
```

### 11.1 Testes
- Delega pra `Duffel.call(query)` (stub; não hita rede).
- Chama `Broadcast.call` com o Result retornado.
- Grava cache com TTL correto baseado em `empty?`.
- Enfileira em `:flight_offers` queue.

## 12. `FlightOffer::Search::Broadcast`

### 12.1 Contrato

```ruby
# app/models/flight_offer/search/broadcast.rb
class FlightOffer::Search::Broadcast
  def self.call(search_id:, provider:, result:)
    new(search_id: search_id, provider: provider, result: result).call
  end

  def self.cached(search_id:, provider:, offer_ids:)
    result = FlightOffer::Search::Result.new(
      status: "cached", offer_ids: offer_ids,
      duration_ms: 0, error_message: nil, provider: provider.to_s
    )
    new(search_id: search_id, provider: provider, result: result).call
  end

  def initialize(search_id:, provider:, result:)
    @search_id = search_id
    @provider = provider.to_s
    @result = result
  end

  def call
    stream_key = "flight_offer_search_#{@search_id}"

    if @result.success? || @result.status == "cached"
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

  # ApplicationController view context pra ViewComponent render_in (necessário
  # fora de request — jobs rodam sem controller).
  def view_context
    @view_context ||= ApplicationController.new.tap { |c| c.request = ActionDispatch::Request.new({}) }.view_context
  end
end
```

### 12.2 `ProviderStatusComponent`

```ruby
# app/components/provider_status_component.rb
class ProviderStatusComponent < ViewComponent::Base
  def initialize(provider:, result:)
    @provider = provider.to_s
    @result = result
  end

  def css_classes
    base = "px-4 py-2 rounded text-sm"
    case @result.status
    when "success"  then "#{base} bg-green-50 text-green-800"
    when "empty"    then "#{base} bg-gray-100 text-gray-600"
    when "cached"   then "#{base} bg-indigo-50 text-indigo-700"
    when "failure", "timeout" then "#{base} bg-red-50 text-red-700"
    else "#{base} bg-gray-100 text-gray-700"
    end
  end

  def label
    i18n_key = "searches.providers.#{@provider}.#{@result.status}"
    case @result.status
    when "success" then t(i18n_key, count: @result.offer_ids.size)
    when "failure", "timeout" then t(i18n_key, error: @result.error_message.to_s.truncate(60))
    when "cached"  then t("searches.providers.#{@provider}.success", count: @result.offer_ids.size) + " · " + t("searches.cached_badge")
    else t(i18n_key)
    end
  end
end
```

```erb
<%# app/components/provider_status_component.html.erb %>
<div id="provider_status_<%= @provider %>" class="<%= css_classes %>"><%= label %></div>
```

ID estável (`provider_status_<provider>`) é o target de `broadcast_replace_to`. Partials tradicionais Rails (`render partial: ...`) não são usados — toda renderização vai por ViewComponent.

### 12.3 Testes
- Success + 3 offer_ids → 3 `broadcast_append_to` + 1 `broadcast_replace_to`.
- Empty → 0 appends + 1 replace com status "empty".
- Failure → 0 appends + 1 replace com status "failure" e error_message.

## 13. `SearchesController#create` atualizado

```ruby
# app/controllers/searches_controller.rb
class SearchesController < ApplicationController
  def new
    @search_params = session.delete(:search_params) || {}
  end

  def create
    query = FlightOffer::Search::Query.from_params(search_params).validate!
    @search_id = SecureRandom.uuid_v7
    FlightOffer::Search::Dispatch.call(query: query, search_id: @search_id)
    respond_to do |format|
      format.turbo_stream # renderiza app/views/searches/create.turbo_stream.erb
    end
  rescue FlightOffer::Search::Query::InvalidError => e
    flash.now[:alert] = t(e.i18n_key, **e.interpolations)
    @search_params = search_params.to_h
    render :new, status: :unprocessable_entity
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
```

**Mudança vs Fase 3:** antes `create` só guardava params e redirecionava pra `new` (placeholder). Agora valida, enfileira job e responde com turbo_stream.

### 13.1 `create.turbo_stream.erb`

```erb
<%= turbo_stream.replace "search_results" do %>
  <%= render SearchResultsComponent.new(search_id: @search_id) %>
<% end %>
```

### 13.2 Testes (request spec)

- **POST /searches** happy path:
  - Stub `Dispatch.call` (ou enfileira via `have_enqueued_job`)
  - Response 200, content-type `text/vnd.turbo-stream.html`
  - Body contém `turbo-stream action="replace" target="search_results"`
  - Body contém `turbo-cable-stream-source` apontando pra `flight_offer_search_<id>`
- **POST /searches** invalid params → 422 + flash.alert + re-render form. Asserir `I18n.t("searches.errors.<key>")` (tradução) no body, nunca string literal.
- **POST /searches** sem `origin_code` → 422 com `I18n.t("searches.errors.origin_has_no_airports")` no body.

## 14. `SearchResultsComponent`

```ruby
# app/components/search_results_component.rb
class SearchResultsComponent < ViewComponent::Base
  PROVIDERS = %w[duffel].freeze # Fase 5 expande

  def initialize(search_id:)
    @search_id = search_id
  end

  attr_reader :search_id
end
```

```erb
<%# app/components/search_results_component.html.erb %>
<div id="search_results" class="mt-6 max-w-3xl mx-auto space-y-4">
  <%= turbo_stream_from "flight_offer_search_#{search_id}" %>

  <div class="grid grid-cols-1 gap-2">
    <% SearchResultsComponent::PROVIDERS.each do |provider| %>
      <div id="provider_status_<%= provider %>"
           class="px-4 py-2 rounded bg-gray-100 text-sm text-gray-700">
        <%= t("searches.providers.#{provider}.searching") %>
      </div>
    <% end %>
  </div>

  <div id="flight_offer_cards" class="space-y-3"></div>

  <div id="no_results" class="hidden px-4 py-6 text-center text-gray-600">
    <p><%= t("searches.no_results.title") %></p>
    <%= link_to t("searches.no_results.create_alert"), "#", class: "underline text-indigo-600" %>
  </div>
</div>
```

**Nota:** `#no_results` é controlado futuramente por uma broadcast extra quando todos os providers reportarem empty — ou manualmente via Stimulus ao observar DOM. Fase 4: deixar hidden sempre (cobrimos na Fase 5/6).

## 15. `FlightOfferCardComponent`

```ruby
# app/components/flight_offer_card_component.rb
class FlightOfferCardComponent < ViewComponent::Base
  def initialize(offer:, provider: nil)
    @offer = offer
    @provider_override = provider
  end

  def provider_label
    (@provider_override || @offer.provider).to_s
  end

  def price_display
    return nil unless @offer.price_cents
    number_to_currency(@offer.price_cents / 100.0, unit: @offer.currency || "BRL")
  end

  def stops_label
    @offer.stops.zero? ? t("flight_offer.direct") : t("flight_offer.stops", count: @offer.stops)
  end

  def departure_display
    I18n.l(@offer.departure_at, format: :short)
  end
end
```

```erb
<%# app/components/flight_offer_card_component.html.erb %>
<article class="rounded-lg border border-gray-200 bg-white p-4 shadow-sm flex items-center justify-between">
  <div>
    <div class="text-sm text-gray-500"><%= provider_label.upcase %> · <%= @offer.airline_iata %></div>
    <div class="font-semibold"><%= @offer.origin_airport.iata_code %> → <%= @offer.destination_airport.iata_code %></div>
    <div class="text-xs text-gray-500"><%= departure_display %> · <%= stops_label %></div>
  </div>
  <div class="text-right">
    <div class="text-lg font-bold text-indigo-700"><%= price_display %></div>
    <%= link_to t("flight_offer.view"), @offer.deep_link, target: "_blank", rel: "noopener",
          class: "text-xs text-indigo-600 underline" %>
  </div>
</article>
```

### 15.1 Testes
- Renderiza origin/destination IATA.
- Renderiza preço formatado BRL.
- "direct" quando stops=0; "N conexões" quando stops=N.
- Respeita `provider_override`.

## 16. i18n

Novos keys (pt-BR + en espelhados):

Os keys `success`/`empty`/`failure`/`timeout` devem bater 1-para-1 com `FlightOffer::Search::Result::STATUSES` (menos `cached`, que reusa o copy de `success` + badge).

```yaml
# pt-BR
pt-BR:
  searches:
    providers:
      duffel:
        searching: "Buscando Duffel…"
        success:
          one: "Duffel: %{count} oferta"
          other: "Duffel: %{count} ofertas"
        empty: "Duffel: nenhuma oferta"
        failure: "Duffel falhou (%{error})"
        timeout: "Duffel demorou demais"
    no_results:
      title: "Nenhuma oferta encontrada."
      create_alert: "Criar alerta com esses critérios"
    cached_badge: "em cache"
    errors:
      invalid_origin_type: "Origem inválida."
      invalid_destination_type: "Destino inválido."
      invalid_trip_type: "Tipo de viagem inválido."
      invalid_cabin_class: "Classe de cabine inválida."
      invalid_passengers: "Número de passageiros fora do range 1–9."
      departure_range_invalid: "Data inicial de ida maior que a final."
      departure_in_past: "Data de ida não pode estar no passado."
      return_date_required: "Ida e volta exige data de retorno."
      return_before_departure: "Retorno antes da ida."
      origin_has_no_airports: "Nenhum aeroporto encontrado na origem."
      destination_has_no_airports: "Nenhum aeroporto encontrado no destino."
  flight_offer:
    direct: "direto"
    stops:
      one: "%{count} conexão"
      other: "%{count} conexões"
    view: "ver oferta"
```

```yaml
# en
en:
  searches:
    providers:
      duffel:
        searching: "Searching Duffel…"
        success:
          one: "Duffel: %{count} offer"
          other: "Duffel: %{count} offers"
        empty: "Duffel: no offers"
        failure: "Duffel failed (%{error})"
        timeout: "Duffel timed out"
    no_results:
      title: "No offers found."
      create_alert: "Create alert with these criteria"
    cached_badge: "cached"
    errors:
      invalid_origin_type: "Invalid origin."
      invalid_destination_type: "Invalid destination."
      invalid_trip_type: "Invalid trip type."
      invalid_cabin_class: "Invalid cabin class."
      invalid_passengers: "Passenger count must be between 1 and 9."
      departure_range_invalid: "Departure window end is before start."
      departure_in_past: "Departure date cannot be in the past."
      return_date_required: "Round-trip requires a return date."
      return_before_departure: "Return cannot be before departure."
      origin_has_no_airports: "No airports found at origin."
      destination_has_no_airports: "No airports found at destination."
  flight_offer:
    direct: "direct"
    stops:
      one: "%{count} stop"
      other: "%{count} stops"
    view: "view offer"
```

Em `config/application.rb` já tem `available_locales = %i[pt-BR en]` e `default_locale = :"pt-BR"`.

## 17. Out of scope

- **Amadeus, seats.aero, Smiles, Latam Pass, TudoAzul** — Fase 5.
- **Circuit breaker F-026** — Fase 8.
- **Filtros client-side (F-005) e ordenação (F-006)** — Fase 5 (quando houver >1 provider).
- **Dashboard admin `/admin` (F-040)** — Fase 7.
- **Export CSV (F-041)** — Fase 8 ou nunca.
- **Persistência de `SearchRun` como entidade** — não precisa; cache + ofertas persistidas cobrem.
- **Cleanup de FlightOffers expiradas** — Fase 7.
- **Click-out `/offers/:id/redirect` (J4)** — Fase 7. Nesta fase, `deep_link` vai direto para Duffel.

## 18. Risco / notas

- **Credenciais Duffel em dev/CI:** dev usa chave `duffel_test_...` em `credentials.yml.enc` (encrypted). CI não roda cassettes VCR contra rede — VCR replay é offline. Primeira gravação do cassette exige chave válida na máquina do dev.
- **`Data.define` + ActiveJob:** não serializa nativamente. Passamos `query.to_h` e reconstruímos; testar explicitamente. Não usar `Data` diretamente em `perform_later`.
- **Solid Queue worker precisa rodar:** `bin/dev` sobe worker (Procfile.dev). Em specs, `perform_enqueued_jobs` / `have_enqueued_job` matchers (já configurado via `rspec-rails` + ActiveJob).
- **Solid Cable em dev:** `turbo_stream_from` sobre Action Cable; Solid Cable em SQLite já configurado na Fase 0. Smoke test deve confirmar que `bin/rails s` com `bin/dev` entrega o broadcast.
- **HTTP 429:** Duffel tem rate limit 60/min. Fase 4 não adiciona lógica de backoff; só loga. Backoff/retry é Fase 6 (scheduler de alertas).
- **Payload Duffel grande** (~30KB por offer): `raw_payload` guarda JSON cru; tabela `flight_offers` pode crescer. Cleanup automático é Fase 7. Em pico (1k offers/dia), 30MB/dia = aceitável.
- **Airport IATA match strict:** se Duffel retorna IATA que não existe na nossa `airports` (ex: aeroporto recém-inaugurado), a offer é silenciosamente pulada. Log fica em Sentry via `message` (adicionar em fase de observability). Por ora, aceitar.
- **`supplier_timeout=10000`** + timeout total 15s HTTParty: garante que Duffel responde em até 10s no fornecedor; sobra 5s de rede. Se subir mais, ajustar.
- **ViewComponent preview:** rodar `bin/rails s` e acessar `/rails/view_components` para conferir card visualmente.
- **Renderização de ViewComponent fora de request (jobs):** `Broadcast#view_context` instancia um `ApplicationController` com request vazio pra obter `view_context` válido — permite `component.render_in(view_context)` no job. Solução pragmática; se virar atrito (ex: helpers que dependem de `current_user`), mover pra um `ActionView::Base.with_empty_template_cache` explícito.

## 19. Commits esperados (ordem)

1. `chore(phase-4): add provider_offer_id + unique index em flight_offers`
2. `feat(phase-4): FlightOffer::Search::Query com cache_key e validate!`
3. `feat(phase-4): FlightOffer::Search::Base + Result abstract interface`
4. `feat(phase-4): FlightOffer::Search::Duffel adapter com VCR cassette`
5. `feat(phase-4): FlightOffer::Search::Broadcast para Turbo Streams`
6. `feat(phase-4): FlightOffer::Search::Dispatch com Solid Cache fan-out`
7. `feat(phase-4): FlightOffer::Search::DuffelJob casca ActiveJob`
8. `feat(phase-4): FlightOfferCardComponent + SearchResultsComponent`
9. `feat(phase-4): SearchesController#create liga pipeline + turbo_stream.erb`
10. `feat(phase-4): i18n pt-BR + en para providers/flight_offer`
11. `chore(phase-4): credentials development com duffel sandbox key`

Tag final: `phase-4-duffel-complete`.
