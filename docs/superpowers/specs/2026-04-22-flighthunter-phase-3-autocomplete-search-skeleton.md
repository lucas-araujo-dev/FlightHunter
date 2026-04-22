# FlightHunter — Fase 3: Autocomplete de origem/destino + esqueleto de busca

> Sub-spec da Fase 3. Master: `docs/superpowers/specs/2026-04-22-flighthunter-design.md` §8. Cobre J5 completa e J1 apenas na UI (backend de busca fica para Fase 4). Data: 2026-04-22.

## 1. Escopo

Três entregáveis:

1. **`Airport::Autocomplete` query object** — busca em `iata_code`, `name`, `city`; agrega cidades com ≥2 aeroportos; retorna top 10 resultados.
2. **Endpoint JSON de autocomplete** — `GET /airports?q=...` via `AirportsController#index`.
3. **Form de busca** — `SearchesController#{new,create}` + `SearchFormComponent` (ViewComponent) + Stimulus controller `airport-combobox`. `create` por enquanto só valida params e renderiza placeholder vazio (Fase 4 liga adapters).

Root da aplicação passa a apontar para `searches#new` (antes era `home#show`, placeholder que some).

## 2. Jornadas cobertas

- **J5 (escolha origem/destino)** — completa. Usuário digita "FOR" → vê Fortaleza; digita "são p" → vê "São Paulo (3 airports)" como opção agregada.
- **J1 (busca ad-hoc)** — UI completa. Backend (dispatch de providers) na Fase 4.

## 3. Decisões arquiteturais

Seguindo `CLAUDE.base.md`:

- **Query object em `app/models/airport/autocomplete.rb`** (`Airport::Autocomplete`). Não `app/services/`.
- **Controllers thin.** `AirportsController#index` responde só JSON (4-5 linhas). `SearchesController#new` renderiza form; `#create` por enquanto re-renderiza com estado "searching..." e lista vazia.
- **ViewComponent para o form** — `SearchFormComponent` encapsula markup + lógica de render. Preview em `spec/components/previews/`.
- **Stimulus single-purpose controller** — `airport-combobox` debounces, busca, renderiza dropdown, submete hidden inputs. Sem frameworks front-end adicionais.
- **Turbo Frames** — o form inteiro vive num frame; `#create` retorna um frame com resultados (vazios por enquanto).

## 4. Arquivos

### Novos
- `app/models/airport/autocomplete.rb` — query object.
- `app/controllers/airports_controller.rb` — endpoint JSON.
- `app/controllers/searches_controller.rb` — form + placeholder.
- `app/views/searches/new.html.erb` — monta o form + frame de resultados.
- `app/components/search_form_component.rb` + `search_form_component.html.erb` — ViewComponent.
- `app/components/search_results_component.rb` + `search_results_component.html.erb` — placeholder/empty state ("Fase 4 liga adapters").
- `app/javascript/controllers/airport_combobox_controller.js` — Stimulus.
- `spec/models/airport/autocomplete_spec.rb`
- `spec/requests/airports_spec.rb`
- `spec/requests/searches_spec.rb`
- `spec/components/search_form_component_spec.rb`
- `spec/components/previews/search_form_component_preview.rb`

### Modificados
- `config/routes.rb` — nova root + `/airports` + `/searches`.
- `app/javascript/controllers/index.js` — registra novo controller Stimulus.
- `spec/requests/home_spec.rb` — renomeado para `spec/requests/root_spec.rb` OU atualizado para asserar `searches#new`. **Decisão:** atualizar o arquivo existente pra apontar pra `searches#new` (semanticamente é o mesmo teste de "root funciona logado e bloqueia deslogado"), renomeado para `spec/requests/root_spec.rb`.

### Deletados
- `app/controllers/home_controller.rb`
- `app/views/home/show.html.erb`
- `spec/requests/home_spec.rb` (substituído por root_spec.rb)

## 5. Data model

Sem mudanças. Reusa `Airport` da Fase 1.

## 6. `Airport::Autocomplete` — especificação

### Input
- `query` — string digitada pelo usuário. Pode estar em qualquer case; pode ter acentos ou não.
- `limit` — opcional, default 10.
- `min_city_airports` — opcional, default 2. Se `Airport.where(city: X).count >= min_city_airports`, a cidade aparece como resultado agregado único.

### Output
`Array` de `Result` (`Data.define(:type, :code, :display, :secondary)`):
- `type` — `"airport"` ou `"city"`
- `code` — IATA (3 chars) se airport; `"<city>|<country>"` se city (para usar como `origin_code` no alert, já que o enum do Alert é `airport`/`city`)
- `display` — string exibida no dropdown: `"FOR — Pinto Martins International Airport"` (airport) ou `"São Paulo (3 airports)"` (city)
- `secondary` — texto auxiliar (ex: país, região). Mostrado menor no dropdown.

### Matching rules
1. Normaliza query: `.strip.downcase`. Remove acentos via `I18n.transliterate`.
2. Busca em paralelo:
   - `iata_code ILIKE query%` (prefix) — peso 100.
   - `icao_code ILIKE query%` — peso 80.
   - `name ILIKE %query%` (substring) — peso 50.
   - `city ILIKE %query%` — peso 50 (alimenta também o agregador de cidade).
3. Agrega cidades: se ≥2 airports com o mesmo `(city, country)` aparecem nos matches, cria um Result `type: "city"` com `code: "<city>|<country>"` e substitui os aeroportos dessa cidade no output final.
4. Ordena por peso decrescente; desempate por `iata_code.present?` (prefere aeroportos com IATA) e depois alfabético.
5. Limita a `limit` resultados.

### Implementação (esboço)

```ruby
class Airport::Autocomplete
  Result = Data.define(:type, :code, :display, :secondary)
  DEFAULT_LIMIT = 10
  DEFAULT_MIN_CITY_AIRPORTS = 2

  def self.call(query, limit: DEFAULT_LIMIT, min_city_airports: DEFAULT_MIN_CITY_AIRPORTS)
    new(query, limit:, min_city_airports:).call
  end

  def initialize(query, limit:, min_city_airports:)
    @query = query.to_s.strip.downcase
    @limit = limit
    @min_city_airports = min_city_airports
  end

  def call
    return [] if @query.length < 2

    matches = base_scope.order(
      Arel.sql(ranking_sql)
    ).limit(@limit * 3).to_a   # pega mais, agregador corta abaixo

    aggregate_cities(matches).first(@limit)
  end

  private

  def base_scope
    pattern_prefix = "#{@query}%"
    pattern_sub    = "%#{@query}%"
    Airport.where(
      "lower(iata_code) LIKE ? OR lower(icao_code) LIKE ? OR lower(name) LIKE ? OR lower(city) LIKE ?",
      pattern_prefix, pattern_prefix, pattern_sub, pattern_sub
    )
  end

  def ranking_sql
    # Retorna um score numérico; ordenamos desc.
    <<~SQL
      CASE
        WHEN lower(iata_code) LIKE '#{@query.gsub("'", "''")}%' THEN 100
        WHEN lower(icao_code) LIKE '#{@query.gsub("'", "''")}%' THEN 80
        WHEN lower(city) LIKE '#{@query.gsub("'", "''")}%' THEN 60
        ELSE 50
      END DESC,
      iata_code IS NOT NULL DESC,
      name ASC
    SQL
  end

  def aggregate_cities(airports)
    # Agrupa por (city, country); se >= min, emite Result :city; senão, Result :airport.
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

    results.first(@limit)
  end
end
```

**Nota sobre o ranking SQL:** usamos `lower(...)` + `LIKE` para portabilidade SQLite; em Postgres futuro basta trocar para `ILIKE`. Query injection prevenida ao escapar single quote em `@query.gsub("'", "''")`.

### Testes
- Query vazia ou `length < 2` → `[]`.
- `"for"` retorna Fortaleza com type=airport, code=FOR.
- `"são p"` retorna "São Paulo (3 airports)" (se fixture tiver ≥2 SP airports).
- `"são p"` retorna airport com type=airport e code=IATA se houver apenas 1 airport em SP (testar min_city_airports comportamento).
- Transliteration: `"sao"` retorna São Paulo mesmo sem acento. (Opcional v1; pode ficar para depois se SQLite dificultar.)
- IATA match tem prioridade sobre name match.
- Respeita limit.

## 7. `AirportsController#index` — endpoint JSON

```ruby
class AirportsController < ApplicationController
  def index
    results = Airport::Autocomplete.call(params[:q])
    render json: results.map(&:to_h)
  end
end
```

Rota: `get "/airports", to: "airports#index", as: :airports`.

Request spec: dado airports criados, `GET /airports?q=for` retorna JSON com chave `type`, `code`, `display`.

## 8. `SearchesController` — esqueleto

```ruby
class SearchesController < ApplicationController
  def new
    # Renderiza form
  end

  def create
    # Por enquanto: só valida presença dos campos obrigatórios e re-renderiza new com
    # uma seção de resultados vazia (ou mensagem "Fase 4 liga adapters").
    # Não chama providers (eles não existem ainda).
    @search_params = search_params
    render :new, status: :ok
  end

  private

  def search_params
    params.permit(:origin_type, :origin_code, :destination_type, :destination_code,
                  :trip_type, :departure_date_from, :departure_date_to,
                  :return_date_from, :return_date_to, :cabin_class, :passengers)
  end
end
```

Rotas:
```ruby
resources :searches, only: %i[new create]
root "searches#new"
```

## 9. `SearchFormComponent` — ViewComponent

### Props (via initializer)

```ruby
class SearchFormComponent < ViewComponent::Base
  def initialize(search_params: {}, autocomplete_url:)
    @search_params = search_params
    @autocomplete_url = autocomplete_url
  end
end
```

### Template (`search_form_component.html.erb`)

Form com:
- Origem (combobox Stimulus)
- Destino (combobox Stimulus)
- Tipo: radio one_way / round_trip
- Data de partida (from / to)
- Data de volta (from / to; só aparece se round_trip — Turbo Frame conditional OK, ou apenas CSS/JS hide)
- Classe: select economy/premium_economy/business/first
- Passageiros: number input, default 1
- Submit: "Buscar"

Usa `form_with url: searches_path, method: :post, local: true, data: { turbo_frame: "search_results" }`.

Campos de combobox têm duas inputs: um visível (autocomplete, desejo do usuário) e um hidden (`origin_type`, `origin_code` — enviados ao controller).

### Preview

```ruby
class SearchFormComponentPreview < ViewComponent::Preview
  def default
    render(SearchFormComponent.new(autocomplete_url: "/airports"))
  end

  def pre_filled_round_trip
    render(SearchFormComponent.new(
      search_params: {
        origin_type: "airport", origin_code: "FOR",
        destination_type: "city", destination_code: "São Paulo|BR",
        trip_type: "round_trip",
        departure_date_from: Date.current + 30, departure_date_to: Date.current + 45,
        return_date_from: Date.current + 50, return_date_to: Date.current + 65,
        cabin_class: "economy", passengers: 2
      },
      autocomplete_url: "/airports"
    ))
  end
end
```

### Spec
- Renderiza com defaults (autocomplete_url presente).
- Renderiza campos hidden para origin_type/origin_code.
- Pré-preenchimento funciona (round_trip, datas, classe).

## 10. Stimulus `airport_combobox_controller.js`

### Comportamento
- Listen no `input` do campo visível.
- Debounce 150ms.
- Fetch ao `autocomplete_url` com `?q=<value>`.
- Renderiza dropdown com resultados JSON.
- ArrowUp/ArrowDown navega; Enter seleciona; Escape fecha.
- Ao selecionar: preenche hidden `*_type` e `*_code`, fecha dropdown, foca próximo input.
- Blur (com delay para permitir click) fecha dropdown.

### Estrutura

```javascript
// app/javascript/controllers/airport_combobox_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "dropdown", "codeInput", "typeInput"]
  static values = { url: String, debounce: { type: Number, default: 150 } }

  connect() { this.timer = null }

  search() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this._fetch(), this.debounceValue)
  }

  async _fetch() {
    const q = this.inputTarget.value.trim()
    if (q.length < 2) { this._clear(); return }
    const res = await fetch(`${this.urlValue}?q=${encodeURIComponent(q)}`)
    const results = await res.json()
    this._render(results)
  }

  _render(results) {
    this.dropdownTarget.innerHTML = results.map((r, i) => `
      <li class="px-3 py-2 cursor-pointer hover:bg-gray-100" data-index="${i}"
          data-type="${r.type}" data-code="${r.code}"
          data-action="click->airport-combobox#select">
        <div class="font-medium">${r.display}</div>
        ${r.secondary ? `<div class="text-xs text-gray-500">${r.secondary}</div>` : ""}
      </li>
    `).join("")
    this.dropdownTarget.classList.toggle("hidden", results.length === 0)
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
}
```

Registra em `app/javascript/controllers/index.js`:
```javascript
import AirportComboboxController from "./airport_combobox_controller"
application.register("airport-combobox", AirportComboboxController)
```

(Se o projeto usa `eagerLoadControllersFrom` — Rails 8 default — o registro é automático. Verificar.)

### Testes de JS
Não faremos system tests com browser nesta fase (Capybara + headless Chrome) — custo alto pro que cobre. Cobrimos via:
- Component spec renderiza os data-attributes corretos (se `data-controller="airport-combobox"` está presente, os inputs têm data-airport-combobox-target, etc.).
- Request spec do endpoint JSON garante o backend.

Se quiser confiança extra, pode-se rodar manualmente `bin/rails s` e testar no browser. Deixa pra mais tarde se virar dor.

## 11. Out of scope

- Busca reversa de city → IATA no backend (Fase 4 fará isso via `City::Resolver`).
- Disparar providers (Fase 4).
- Persistir a search em tabela própria (cache via Solid Cache virá na Fase 4 também).
- Validações cross-field de datas no form (JS-side). Por enquanto só required attributes no browser.
- i18n/l10n dos labels — hardcode em PT.

## 12. Risco / notas

- **SQLite vs Postgres no ranking SQL:** usamos `lower(...) LIKE` em vez de `ILIKE`. Portável. Se migrarmos para PG no futuro, trocar por `ILIKE` é trivial.
- **Performance do autocomplete em 47k airports:** `LIKE '%q%'` com sqlite sequencial é ~15ms em 47k linhas. Aceitável para single-user. Futuro: adicionar full-text index se precisar.
- **Stimulus controller não tem teste automatizado:** aceito. Component spec cobre o markup gerado; endpoint spec cobre o backend. A fiação JS é simples e testada manualmente.

## 13. Commits esperados (ordem)

1. `feat(phase-3): Airport::Autocomplete query object com city aggregation`
2. `feat(phase-3): AirportsController JSON endpoint + request spec`
3. `feat(phase-3): SearchFormComponent + preview + spec`
4. `feat(phase-3): SearchesController esqueleto + rotas + root -> searches#new`
5. `feat(phase-3): Stimulus airport-combobox controller`
6. `chore(phase-3): remove HomeController (substituído por SearchesController)`
