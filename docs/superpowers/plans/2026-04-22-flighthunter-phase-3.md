# FlightHunter — Fase 3 (Autocomplete + Search skeleton) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Autocomplete de origem/destino funcionando end-to-end (J5 completa) + formulário de busca renderizado com campos corretos, mas backend de busca ainda vazio (J1 UI, J1 backend na Fase 4).

**Architecture:** `CLAUDE.base.md` — `Airport::Autocomplete` query object em `app/models/airport/`. `SearchFormComponent` ViewComponent. Sem services, sem providers ainda.

**Tech:** Rails 8.1, Hotwire (Turbo Frames + Stimulus), ViewComponent, Tailwind.

**Working directory:** `/home/lucas/RubymineProjects/seats/`
**Branch:** `feat/phase-3-autocomplete-search-skeleton` (criado a partir de main pós-merge da Fase 2).

**Reference spec:** `docs/superpowers/specs/2026-04-22-flighthunter-phase-3-autocomplete-search-skeleton.md`.

---

## Task 1: `Airport::Autocomplete` query object

**Files:**
- Create: `app/models/airport/autocomplete.rb`
- Create: `spec/models/airport/autocomplete_spec.rb`

- [ ] **Step 1.1: Escrever spec (falha)**

  Criar `spec/models/airport/autocomplete_spec.rb`:

  ```ruby
  require "rails_helper"

  RSpec.describe Airport::Autocomplete, type: :model do
    describe ".call" do
      it "returns empty array for query shorter than 2 chars" do
        expect(described_class.call("")).to eq([])
        expect(described_class.call("f")).to eq([])
      end

      it "finds airport by IATA prefix" do
        create(:airport, iata_code: "FOR", name: "Pinto Martins", city: "Fortaleza", country: "BR")
        results = described_class.call("for")
        expect(results.first.type).to eq("airport")
        expect(results.first.code).to eq("FOR")
        expect(results.first.display).to include("FOR")
      end

      it "finds airport by name substring" do
        create(:airport, iata_code: "GRU", name: "Guarulhos International", city: "São Paulo", country: "BR")
        results = described_class.call("guarulhos")
        expect(results.map(&:code)).to include("GRU")
      end

      it "aggregates cities with >= min_city_airports" do
        create(:airport, iata_code: "GRU", city: "São Paulo", country: "BR", name: "Guarulhos")
        create(:airport, iata_code: "CGH", city: "São Paulo", country: "BR", name: "Congonhas")
        create(:airport, iata_code: "VCP", city: "São Paulo", country: "BR", name: "Viracopos")

        results = described_class.call("são paulo")
        city = results.find { |r| r.type == "city" }
        expect(city).to be_present
        expect(city.code).to eq("São Paulo|BR")
        expect(city.display).to match(/São Paulo \(\d+ airports\)/)
      end

      it "does not aggregate city with single airport" do
        create(:airport, iata_code: "FOR", city: "Fortaleza", country: "BR", name: "Pinto Martins")
        results = described_class.call("fortaleza")
        expect(results.any? { |r| r.type == "city" }).to be false
      end

      it "ranks IATA prefix matches above name substring matches" do
        create(:airport, iata_code: "FOR", name: "Fortaleza airport", city: "Fortaleza", country: "BR")
        create(:airport, iata_code: "XXX", name: "Some Fort", city: "Other", country: "US")
        results = described_class.call("for")
        expect(results.first.code).to eq("FOR")
      end

      it "respects limit" do
        5.times { |i| create(:airport, iata_code: "A#{i}#{i}", name: "Airport #{i}", city: "City#{i}", country: "BR") }
        results = described_class.call("airport", limit: 2)
        expect(results.size).to be <= 2
      end

      it "returns Result with to_h usable as JSON" do
        create(:airport, iata_code: "FOR", name: "Pinto Martins", city: "Fortaleza", country: "BR")
        result = described_class.call("for").first
        expect(result.to_h.keys).to contain_exactly(:type, :code, :display, :secondary)
      end
    end
  end
  ```

- [ ] **Step 1.2: Rodar spec — falha**

  ```bash
  cd /home/lucas/RubymineProjects/seats
  bundle exec rspec spec/models/airport/autocomplete_spec.rb
  ```
  Expected: `NameError: uninitialized constant Airport::Autocomplete`.

- [ ] **Step 1.3: Implementar `app/models/airport/autocomplete.rb`**

  Conteúdo completo:

  ```ruby
  class Airport::Autocomplete
    Result = Data.define(:type, :code, :display, :secondary)
    DEFAULT_LIMIT = 10
    DEFAULT_MIN_CITY_AIRPORTS = 2
    MIN_QUERY_LENGTH = 2

    def self.call(query, limit: DEFAULT_LIMIT, min_city_airports: DEFAULT_MIN_CITY_AIRPORTS)
      new(query, limit: limit, min_city_airports: min_city_airports).call
    end

    def initialize(query, limit:, min_city_airports:)
      @query = query.to_s.strip.downcase
      @limit = limit
      @min_city_airports = min_city_airports
    end

    def call
      return [] if @query.length < MIN_QUERY_LENGTH

      matches = candidate_airports
      aggregate(matches).first(@limit)
    end

    private

    def candidate_airports
      prefix = "#{@query}%"
      substring = "%#{@query}%"
      escaped = @query.gsub("'", "''")

      Airport
        .where(
          "lower(iata_code) LIKE ? OR lower(icao_code) LIKE ? OR lower(name) LIKE ? OR lower(city) LIKE ?",
          prefix, prefix, substring, substring
        )
        .order(Arel.sql(<<~SQL))
          CASE
            WHEN lower(iata_code) LIKE '#{escaped}%' THEN 100
            WHEN lower(icao_code) LIKE '#{escaped}%' THEN 80
            WHEN lower(city) LIKE '#{escaped}%' THEN 60
            ELSE 50
          END DESC,
          CASE WHEN iata_code IS NOT NULL THEN 0 ELSE 1 END,
          name ASC
        SQL
        .limit(@limit * 3)
        .to_a
    end

    def aggregate(airports)
      grouped = airports.group_by { |a| [a.city, a.country] }
      results = []

      grouped.each do |(city, country), list|
        if city.present? && list.size >= @min_city_airports
          results << Result.new(
            type: "city",
            code: "#{city}|#{country}",
            display: "#{city} (#{list.size} airports)",
            secondary: country
          )
        else
          list.each do |airport|
            next unless airport.iata_code.present?
            results << Result.new(
              type: "airport",
              code: airport.iata_code,
              display: "#{airport.iata_code} — #{airport.name}",
              secondary: [airport.city, airport.country].compact.join(", ")
            )
          end
        end
      end

      results
    end
  end
  ```

  Nota: directory `app/models/airport/` já existe (Fase 2 importer). Crie só o arquivo.

- [ ] **Step 1.4: Rodar spec — verde**

  ```bash
  bundle exec rspec spec/models/airport/autocomplete_spec.rb
  ```
  Expected: 8 examples green.

- [ ] **Step 1.5: Rodar full suite + lint**

  ```bash
  bundle exec rspec
  bundle exec standardrb --fix app/models/airport/autocomplete.rb spec/models/airport/autocomplete_spec.rb
  bundle exec standardrb
  ```
  Expected: full suite green (75 + 8 = 83), zero offenses.

- [ ] **Step 1.6: Commit**

  ```bash
  git add -A
  git commit -m "feat(phase-3): Airport::Autocomplete query object com city aggregation"
  ```

---

## Task 2: `AirportsController` JSON endpoint + rota

**Files:**
- Create: `app/controllers/airports_controller.rb`
- Modify: `config/routes.rb`
- Create: `spec/requests/airports_spec.rb`

- [ ] **Step 2.1: Criar `app/controllers/airports_controller.rb`**

  ```ruby
  class AirportsController < ApplicationController
    def index
      results = Airport::Autocomplete.call(params[:q])
      render json: results.map(&:to_h)
    end
  end
  ```

- [ ] **Step 2.2: Atualizar `config/routes.rb`**

  Adicionar a rota abaixo de `delete "/logout", ...`:

  ```ruby
    get "/airports", to: "airports#index", as: :airports
  ```

  Mantém o resto do arquivo inalterado (root, session, logout).

- [ ] **Step 2.3: Criar `spec/requests/airports_spec.rb`**

  ```ruby
  require "rails_helper"

  RSpec.describe "Airports autocomplete", type: :request do
    let(:user) { create(:user, email: "owner@flighthunter.local", password: "owner-password-123") }

    before do
      post session_path, params: {email: user.email, password: "owner-password-123"}
      create(:airport, iata_code: "FOR", name: "Pinto Martins", city: "Fortaleza", country: "BR")
      create(:airport, iata_code: "GRU", name: "Guarulhos", city: "São Paulo", country: "BR")
    end

    it "returns JSON with matching airports" do
      get airports_path, params: {q: "for"}
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to match(%r{application/json})
      json = JSON.parse(response.body)
      expect(json.first).to include("type" => "airport", "code" => "FOR")
    end

    it "returns empty array for short queries" do
      get airports_path, params: {q: "f"}
      expect(JSON.parse(response.body)).to eq([])
    end

    it "requires authentication" do
      delete logout_path
      get airports_path, params: {q: "for"}
      expect(response).to redirect_to(login_path)
    end
  end
  ```

- [ ] **Step 2.4: Rodar spec**

  ```bash
  bundle exec rspec spec/requests/airports_spec.rb
  ```
  Expected: 3 examples green.

- [ ] **Step 2.5: Lint + full**

  ```bash
  bundle exec rspec
  bundle exec standardrb --fix
  bundle exec standardrb
  ```

- [ ] **Step 2.6: Commit**

  ```bash
  git add -A
  git commit -m "feat(phase-3): AirportsController JSON endpoint + request spec"
  ```

---

## Task 3: `SearchFormComponent` + preview + spec

**Files:**
- Create: `app/components/search_form_component.rb`
- Create: `app/components/search_form_component.html.erb`
- Create: `spec/components/search_form_component_spec.rb`
- Create: `spec/components/previews/search_form_component_preview.rb`

- [ ] **Step 3.1: Criar `app/components/search_form_component.rb`**

  ```ruby
  class SearchFormComponent < ViewComponent::Base
    CABIN_CLASSES = %w[economy premium_economy business first].freeze

    def initialize(autocomplete_url:, search_params: {})
      @autocomplete_url = autocomplete_url
      @search_params = search_params.to_h.with_indifferent_access
    end

    private

    attr_reader :autocomplete_url, :search_params

    def value_for(key, default = nil)
      search_params[key].presence || default
    end

    def round_trip?
      value_for(:trip_type) == "round_trip"
    end
  end
  ```

- [ ] **Step 3.2: Criar `app/components/search_form_component.html.erb`**

  ```erb
  <%= form_with url: "/searches", method: :post, local: true,
                data: {turbo_frame: "search_results"},
                class: "space-y-6 max-w-3xl mx-auto p-6 bg-white rounded-lg shadow" do |f| %>

    <h2 class="text-xl font-semibold text-gray-900">Buscar voos</h2>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <%= render_airport_field(f, :origin, "Origem", value_for(:origin_type), value_for(:origin_code)) %>
      <%= render_airport_field(f, :destination, "Destino", value_for(:destination_type), value_for(:destination_code)) %>
    </div>

    <fieldset class="flex gap-4 items-center">
      <legend class="sr-only">Tipo</legend>
      <label class="inline-flex items-center gap-2">
        <%= f.radio_button :trip_type, "one_way", checked: !round_trip?, class: "h-4 w-4" %>
        <span>Só ida</span>
      </label>
      <label class="inline-flex items-center gap-2">
        <%= f.radio_button :trip_type, "round_trip", checked: round_trip?, class: "h-4 w-4" %>
        <span>Ida e volta</span>
      </label>
    </fieldset>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <div>
        <%= f.label :departure_date_from, "Partida de", class: "block text-sm font-medium text-gray-700" %>
        <%= f.date_field :departure_date_from, required: true, value: value_for(:departure_date_from),
            class: "mt-1 block w-full rounded border-gray-300 shadow-sm" %>
      </div>
      <div>
        <%= f.label :departure_date_to, "Partida até", class: "block text-sm font-medium text-gray-700" %>
        <%= f.date_field :departure_date_to, required: true, value: value_for(:departure_date_to),
            class: "mt-1 block w-full rounded border-gray-300 shadow-sm" %>
      </div>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-4 <%= "hidden" unless round_trip? %>">
      <div>
        <%= f.label :return_date_from, "Volta de", class: "block text-sm font-medium text-gray-700" %>
        <%= f.date_field :return_date_from, value: value_for(:return_date_from),
            class: "mt-1 block w-full rounded border-gray-300 shadow-sm" %>
      </div>
      <div>
        <%= f.label :return_date_to, "Volta até", class: "block text-sm font-medium text-gray-700" %>
        <%= f.date_field :return_date_to, value: value_for(:return_date_to),
            class: "mt-1 block w-full rounded border-gray-300 shadow-sm" %>
      </div>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
      <div>
        <%= f.label :cabin_class, "Classe", class: "block text-sm font-medium text-gray-700" %>
        <%= f.select :cabin_class, CABIN_CLASSES, {selected: value_for(:cabin_class, "economy")},
            class: "mt-1 block w-full rounded border-gray-300 shadow-sm" %>
      </div>
      <div>
        <%= f.label :passengers, "Passageiros", class: "block text-sm font-medium text-gray-700" %>
        <%= f.number_field :passengers, min: 1, max: 9, value: value_for(:passengers, 1),
            class: "mt-1 block w-full rounded border-gray-300 shadow-sm" %>
      </div>
    </div>

    <%= f.submit "Buscar", class: "px-6 py-2 bg-indigo-600 text-white rounded hover:bg-indigo-700" %>
  <% end %>

  <turbo-frame id="search_results" class="mt-6 block max-w-3xl mx-auto"></turbo-frame>
  ```

  **IMPORTANTE: `render_airport_field` helper não existe ainda — precisamos definir como método privado do component.** Adicionar ao `search_form_component.rb`:

  ```ruby
    def render_airport_field(form_builder, prefix, label, preset_type, preset_code)
      render(
        AirportFieldTag.new(
          form_builder: form_builder,
          prefix: prefix,
          label: label,
          autocomplete_url: autocomplete_url,
          preset_type: preset_type,
          preset_code: preset_code
        )
      )
    end
  ```

  Plus criar `AirportFieldTag` como sub-component... **ou simplificar**: inline o markup do field no próprio template. Menos abstração, mais legível. **Decisão para esse plano: inline.**

  Substituir a linha `<%= render_airport_field(...) %>` por inline markup. Reescreva o template assim — remova a chamada `render_airport_field` e coloque markup direto:

  ```erb
      <div data-controller="airport-combobox"
           data-airport-combobox-url-value="<%= autocomplete_url %>"
           class="relative">
        <label class="block text-sm font-medium text-gray-700">Origem</label>
        <input type="text" autocomplete="off"
               data-airport-combobox-target="input"
               data-action="input->airport-combobox#search"
               value=""
               placeholder="IATA, cidade ou nome do aeroporto"
               class="mt-1 block w-full rounded border-gray-300 shadow-sm">
        <%= hidden_field_tag "origin_type", value_for(:origin_type),
            data: {airport_combobox_target: "typeInput"} %>
        <%= hidden_field_tag "origin_code", value_for(:origin_code),
            data: {airport_combobox_target: "codeInput"} %>
        <ul data-airport-combobox-target="dropdown"
            class="hidden absolute z-10 mt-1 w-full bg-white border border-gray-200 rounded shadow-md max-h-64 overflow-auto"></ul>
      </div>
  ```

  E repita para destino (trocando `origin` → `destination` e label "Origem" → "Destino").

  Resultado: o template tem 2 blocos inline `data-controller="airport-combobox"`, um para origem, outro para destino. Remove o helper `render_airport_field` e simplify o `.rb`.

  **Template final do component (resumo):** 2 comboboxes inline, radio trip_type, 4 date fields (2 partida + 2 volta com hide se one_way), select cabin, number passengers, submit button, turbo-frame#search_results.

- [ ] **Step 3.3: Simplificar o `.rb` para não ter o helper**

  Final `search_form_component.rb`:

  ```ruby
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
  end
  ```

  (Removido `render_airport_field`.)

- [ ] **Step 3.4: Criar spec `spec/components/search_form_component_spec.rb`**

  ```ruby
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
      # the container should NOT have class "hidden"
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
  ```

- [ ] **Step 3.5: Criar preview `spec/components/previews/search_form_component_preview.rb`**

  ```ruby
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
  ```

- [ ] **Step 3.6: Rodar spec**

  ```bash
  bundle exec rspec spec/components/search_form_component_spec.rb
  ```
  Expected: 4 examples green. Se `have_css` reclamar de `visible: :all` (inputs hidden), ajustar; hidden_field_tag gera `<input type="hidden">` que conta como não-visível.

- [ ] **Step 3.7: Lint + full**

  ```bash
  bundle exec rspec
  bundle exec standardrb --fix
  bundle exec standardrb
  ```

- [ ] **Step 3.8: Commit**

  ```bash
  git add -A
  git commit -m "feat(phase-3): SearchFormComponent + preview + spec"
  ```

---

## Task 4: `SearchesController` + views + root + remove Home

**Files:**
- Create: `app/controllers/searches_controller.rb`
- Create: `app/views/searches/new.html.erb`
- Modify: `config/routes.rb`
- Delete: `app/controllers/home_controller.rb`, `app/views/home/show.html.erb`, `spec/requests/home_spec.rb`
- Create: `spec/requests/searches_spec.rb`

- [ ] **Step 4.1: Criar `app/controllers/searches_controller.rb`**

  ```ruby
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
      params.permit(:origin_type, :origin_code, :destination_type, :destination_code,
                    :trip_type, :departure_date_from, :departure_date_to,
                    :return_date_from, :return_date_to, :cabin_class, :passengers)
    end
  end
  ```

  Nota de design: `create` por enquanto persiste os params na session e redirect pra `new`. A Fase 4 fará `create` disparar providers via background jobs e trocar session por Turbo Streams. Esse redirect é placeholder intencional.

- [ ] **Step 4.2: Criar `app/views/searches/new.html.erb`**

  ```erb
  <div class="py-8 px-4">
    <%= render SearchFormComponent.new(
          autocomplete_url: airports_path,
          search_params: @search_params
        ) %>
  </div>
  ```

- [ ] **Step 4.3: Atualizar `config/routes.rb` — adota `resources` e remove override de `airports`**

  Abrir o arquivo atual e:
  - Trocar `root "home#show"` → `root "searches#new"`.
  - Adicionar `resources :searches, only: %i[new create]`.
  - **Trocar** `get "/airports", to: "airports#index", as: :airports` (que foi introduzido na Task 2 mas viola a regra 4 de `CLAUDE.base.md` — route override via `to:`) → **por `resources :airports, only: %i[index]`**. Helper `airports_path` e URL `/airports` continuam idênticos; a diferença é que `resources` torna a rota derivável do nome do recurso.

  Estado final esperado de `config/routes.rb`:

  ```ruby
  Rails.application.routes.draw do
    get "up" => "rails/health#show", as: :rails_health_check

    # NOTA: sessions usa route overrides (to:) — dívida técnica herdada da Fase 2.
    # Proibido pela regra 4 de CLAUDE.base.md; manter por enquanto para evitar
    # colisão com `root` sem reescrever Phase 2. Revisar quando houver janela.
    get "/login", to: "sessions#new", as: :login
    post "/session", to: "sessions#create", as: :session
    delete "/logout", to: "sessions#destroy", as: :logout

    resources :airports, only: %i[index]
    resources :searches, only: %i[new create]

    root "searches#new"
  end
  ```

- [ ] **Step 4.4: Deletar HomeController e artefatos**

  ```bash
  rm app/controllers/home_controller.rb
  rm -rf app/views/home
  rm spec/requests/home_spec.rb
  ```

- [ ] **Step 4.5: Criar `spec/requests/searches_spec.rb`**

  ```ruby
  require "rails_helper"

  RSpec.describe "Searches", type: :request do
    let(:user) { create(:user, email: "owner@flighthunter.local", password: "owner-password-123") }

    before do
      post session_path, params: {email: user.email, password: "owner-password-123"}
    end

    describe "GET /searches/new (root)" do
      it "renders the search form" do
        get new_search_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Buscar voos")
      end

      it "is the root route" do
        get root_path
        expect(response.body).to include("Buscar voos")
      end
    end

    describe "POST /searches" do
      let(:valid_params) do
        {
          origin_type: "airport", origin_code: "FOR",
          destination_type: "airport", destination_code: "GRU",
          trip_type: "one_way",
          departure_date_from: Date.current + 10, departure_date_to: Date.current + 20,
          cabin_class: "economy", passengers: 1
        }
      end

      it "stores params in session and redirects to new" do
        post searches_path, params: valid_params
        expect(response).to redirect_to(new_search_path)
        follow_redirect!
        expect(response.body).to include("FOR")
      end
    end

    it "redirects to login when logged out" do
      delete logout_path
      get root_path
      expect(response).to redirect_to(login_path)
    end
  end
  ```

- [ ] **Step 4.6: Rodar specs**

  ```bash
  bundle exec rspec spec/requests/searches_spec.rb
  ```
  Expected: 4 examples green.

- [ ] **Step 4.7: Rodar full suite + lint**

  ```bash
  bundle exec rspec
  bundle exec standardrb --fix
  bundle exec standardrb
  ```
  Expected: todos verdes (home_spec.rb foi deletado; searches_spec.rb substitui).

- [ ] **Step 4.8: Commit**

  ```bash
  git add -A
  git commit -m "feat(phase-3): SearchesController esqueleto + rotas + root -> searches#new"
  ```

---

## Task 5: Stimulus `airport-combobox` controller

**Files:**
- Create: `app/javascript/controllers/airport_combobox_controller.js`
- Modify (maybe): `app/javascript/controllers/index.js`

- [ ] **Step 5.1: Verificar como controllers Stimulus são carregados**

  ```bash
  cd /home/lucas/RubymineProjects/seats
  cat app/javascript/controllers/index.js
  ```

  Rails 8 default: usa `eagerLoadControllersFrom("controllers", application)` que auto-carrega tudo em `app/javascript/controllers/`. Se for esse o caso, não precisa registrar manualmente.

- [ ] **Step 5.2: Criar `app/javascript/controllers/airport_combobox_controller.js`**

  ```javascript
  import { Controller } from "@hotwired/stimulus"

  export default class extends Controller {
    static targets = ["input", "dropdown", "codeInput", "typeInput"]
    static values = {
      url: String,
      debounce: { type: Number, default: 150 }
    }

    connect() {
      this._timer = null
      this._boundClickOutside = this._clickOutside.bind(this)
      document.addEventListener("click", this._boundClickOutside)
    }

    disconnect() {
      document.removeEventListener("click", this._boundClickOutside)
    }

    search() {
      clearTimeout(this._timer)
      this._timer = setTimeout(() => this._fetch(), this.debounceValue)
    }

    async _fetch() {
      const q = this.inputTarget.value.trim()
      if (q.length < 2) {
        this._clear()
        return
      }
      try {
        const res = await fetch(`${this.urlValue}?q=${encodeURIComponent(q)}`, {
          headers: { "Accept": "application/json" },
          credentials: "same-origin"
        })
        if (!res.ok) { this._clear(); return }
        const results = await res.json()
        this._render(results)
      } catch (_) {
        this._clear()
      }
    }

    _render(results) {
      if (results.length === 0) {
        this._clear()
        return
      }
      this.dropdownTarget.innerHTML = results.map((r) => `
        <li class="px-3 py-2 cursor-pointer hover:bg-gray-100"
            data-type="${this._escape(r.type)}"
            data-code="${this._escape(r.code)}"
            data-action="mousedown->airport-combobox#select">
          <div class="font-medium text-sm">${this._escape(r.display)}</div>
          ${r.secondary ? `<div class="text-xs text-gray-500">${this._escape(r.secondary)}</div>` : ""}
        </li>
      `).join("")
      this.dropdownTarget.classList.remove("hidden")
    }

    select(event) {
      const li = event.currentTarget
      this.typeInputTarget.value = li.dataset.type
      this.codeInputTarget.value = li.dataset.code
      this.inputTarget.value = li.querySelector(".font-medium").textContent
      this._clear()
    }

    _clear() {
      this.dropdownTarget.innerHTML = ""
      this.dropdownTarget.classList.add("hidden")
    }

    _clickOutside(event) {
      if (!this.element.contains(event.target)) {
        this._clear()
      }
    }

    _escape(str) {
      return String(str).replace(/[&<>"']/g, (m) => ({
        "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
      }[m]))
    }
  }
  ```

  Nota: `mousedown` (não `click`) no `_action` da `<li>` para que a seleção aconteça antes do `blur` do input. Sem isso, clicar na opção do dropdown às vezes perde o valor.

- [ ] **Step 5.3: Verificar se o auto-load está ativo**

  Se `app/javascript/controllers/index.js` tem `eagerLoadControllersFrom(...)`, não precisa fazer nada.

  Se tem registros manuais (`application.register(...)`), adicionar:
  ```javascript
  import AirportComboboxController from "./airport_combobox_controller"
  application.register("airport-combobox", AirportComboboxController)
  ```

- [ ] **Step 5.4: Precompilar JS para confirmar sintaxe**

  Rails importmap não precompila, mas podemos verificar sintaxe via Node ou deixar o browser validar.

  Fazer um smoke test: subir o server, abrir `/`, digitar no campo de origem, ver se autocomplete renderiza dropdown.

  **Manual smoke test (sem automação):**
  ```bash
  timeout 10 bin/rails server 2>&1 | head -10
  ```

  Usuário humano testa na browser. Para esse plano, o teste será verificado no Task 6 (smoke final).

- [ ] **Step 5.5: Rodar full rspec + lint**

  ```bash
  bundle exec rspec
  bundle exec standardrb --fix
  bundle exec standardrb
  ```
  Expected: full suite green. JS não tem lint configurado neste projeto (Standard é Ruby). Aceito.

- [ ] **Step 5.6: Commit**

  ```bash
  git add -A
  git commit -m "feat(phase-3): Stimulus airport-combobox controller com debounce e dropdown"
  ```

---

## Task 6: Smoke test final Fase 3

- [ ] **Step 6.1: Full suite**

  ```bash
  cd /home/lucas/RubymineProjects/seats
  bundle exec rspec
  ```
  Expected: ~90 examples (75 Fase 2 + ~15 Fase 3), 0 failures.

- [ ] **Step 6.2: Lint**

  ```bash
  bundle exec standardrb
  ```

- [ ] **Step 6.3: Server boot + manual smoke**

  ```bash
  timeout 8 bin/rails server 2>&1 | head -20
  ```
  Expected: Puma listening, no exceptions.

  **Manual step (usuário humano):**
  1. Abrir http://127.0.0.1:3000 → se deslogado, redireciona pra /login.
  2. Logar com credenciais do .env.
  3. Ver form de busca com campos Origem, Destino, radio one_way/round_trip, datas, classe, passageiros, botão "Buscar".
  4. Digitar "for" em Origem → ver dropdown com "FOR — Pinto Martins International Airport".
  5. Selecionar → campo visível preenchido com "FOR — ...", hidden inputs `origin_type=airport`, `origin_code=FOR`.
  6. Selecionar round_trip → campos de volta aparecem.
  7. Submit → redirect pra new; campos persistem (session_params).

- [ ] **Step 6.4: Tag**

  ```bash
  git tag phase-3-complete
  ```

---

## Resumo entrega Fase 3

- **J5 completa**: autocomplete de origem/destino por IATA, name, city; agregação de cidades com ≥2 airports.
- **J1 UI**: formulário completo renderizado, ViewComponent isolado com preview, persistência de params via session (placeholder para Fase 4).
- **6 commits** em `feat/phase-3-autocomplete-search-skeleton`.
- **Tag**: `phase-3-complete`.
