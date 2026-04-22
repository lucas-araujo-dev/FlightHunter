# FlightHunter — Fase 2: Auth single-user + Seed + OurAirports Importer

> Sub-spec da Fase 2. Master: `docs/superpowers/specs/2026-04-22-flighthunter-design.md` §8 (fase 2). Data: 2026-04-22.

## 1. Escopo

Três entregáveis independentes mas complementares:

1. **Auth single-user** — login/logout com `has_secure_password` + cookie session. Sem signup público. Toda rota protegida por default.
2. **OurAirports importer** — baixa CSV público do OurAirports, filtra aeroportos ativos, faz `upsert_all` idempotente.
3. **Seeds** — primeiro `db:seed` popula `airports` (via importer) e cria o owner User a partir de ENV.

Após a fase: é possível logar com o owner e ver ~80k aeroportos no banco. Não há UI funcional além do formulário de login (o formulário de busca vem na Fase 3).

## 2. Jornada coberta

Nenhuma jornada nova do REQUIREMENTS.md está completa, mas a Fase 2 é pré-requisito para todas (J1-J5 precisam do owner logado e da base de aeroportos).

## 3. Decisões arquiteturais

Seguindo `CLAUDE.base.md`:

- **Sem `app/services/`, sem `lib/our_airports/`.** Importer vive em `app/models/airport/import/our_airports.rb` como `Airport::Import::OurAirports`. Classe PORO com método `.call` (orquestração nomeada).
- **Controller thin.** `SessionsController` com apenas `new`, `create`, `destroy`. 5-7 linhas por action.
- **Autoridade no model.** `User` ganha predicado `owner?` (para uso futuro; redundante em single-user mas mantém o vocabulário).
- **Sem skip_before_action acrobático.** `ApplicationController` tem `before_action :require_owner!`. `SessionsController#new,create` precisam ser públicos — são as duas únicas exceções, declaradas em `skip_before_action :require_owner!, only: %i[new create]` **no próprio SessionsController** (regra 4 de base.md é sobre split por audiência; aqui não faz sentido dividir login autenticado/público porque login é inerentemente a ponte entre os dois estados).

## 4. Arquivos (o que cria/modifica)

### Novos
- `app/models/airport/import/our_airports.rb` — `Airport::Import::OurAirports.call` (PORO, ~40 linhas).
- `app/controllers/sessions_controller.rb` — 3 actions.
- `app/views/sessions/new.html.erb` — form simples Tailwind.
- `app/views/layouts/_navbar.html.erb` — partial com email + logout.
- `spec/models/airport/import/our_airports_spec.rb` — specs com fixture CSV local.
- `spec/requests/sessions_spec.rb` — request spec login/logout.
- `spec/fixtures/our_airports/airports_sample.csv` — ~20 linhas reais do OurAirports para testes.

### Modificados
- `app/controllers/application_controller.rb` — adiciona `require_owner!` + `current_user` + `logged_in?`.
- `app/views/layouts/application.html.erb` — inclui navbar + slot para flash.
- `config/routes.rb` — `resource :session, only: %i[new create destroy]` + root.
- `db/seeds.rb` — roda importer + cria owner.
- `app/models/user.rb` — adiciona predicado `owner?` (trivial em single-user, mas mantém vocabulário).

## 5. Data model — sem mudanças

Nenhuma migration nova. `User` e `Airport` já existem da Fase 1.

## 6. Endpoints / rotas

| Método | Path | Action | Protegida? |
|---|---|---|---|
| GET | `/login` | `sessions#new` | não |
| POST | `/login` | `sessions#create` | não |
| DELETE | `/logout` | `sessions#destroy` | sim (só faz sentido logado) |
| GET | `/` | aplicação autenticada — por enquanto redireciona para `/login` se deslogado, senão renderiza layout com navbar e mensagem "em breve busca" | sim |

`/` aponta para um controller esqueleto `HomeController#show` (será substituído pela busca na Fase 3). Por enquanto só renderiza uma view placeholder.

**Rotas finais em `config/routes.rb`:**

```ruby
Rails.application.routes.draw do
  resource :session, only: %i[new create destroy],
    path: "", path_names: {new: "login"}

  # Observação: NÃO é route override para dois controllers diferentes — é apenas
  # mapear /login -> sessions#new e /session (DELETE) -> sessions#destroy usando
  # path_names. Compatível com a regra 4 de CLAUDE.base.md (nenhum `controller:`
  # custom, nenhum `module:`, nenhum split em dois controllers necessário).
  delete "/logout", to: "sessions#destroy", as: :logout

  root "home#show"
end
```

Nota de design: `resource :session` (singular) com `path_names: {new: "login"}` dá GET `/login` → `sessions#new`. Adicionamos `delete "/logout"` como alias semântico. Não há `controller:` override, nenhum módulo custom, e o recurso fica inteiramente em `SessionsController`.

## 7. Auth flow detalhado

### SessionsController

```ruby
class SessionsController < ApplicationController
  skip_before_action :require_owner!, only: %i[new create]

  def new
    redirect_to root_path if logged_in?
  end

  def create
    user = User.find_by("lower(email) = ?", params[:email].to_s.downcase.strip)
    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      redirect_to root_path, notice: "Bem-vindo, #{user.email}."
    else
      flash.now[:alert] = "Email ou senha inválidos."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to login_path, notice: "Sessão encerrada."
  end
end
```

### ApplicationController

```ruby
class ApplicationController < ActionController::Base
  before_action :require_owner!

  allow_browser versions: :modern

  helper_method :current_user, :logged_in?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def logged_in?
    current_user.present?
  end

  def require_owner!
    redirect_to login_path, alert: "Faça login para continuar." unless logged_in?
  end
end
```

## 8. Importer detalhado

### Fonte
- URL: `https://davidmegginson.github.io/ourairports-data/airports.csv`
- Formato: CSV com header. Colunas relevantes: `id, ident, type, name, latitude_deg, longitude_deg, iso_country, iso_region, municipality, iata_code, icao_code, scheduled_service`
- Tamanho: ~80k linhas, ~15MB.

### Filtros
Excluir linhas onde `type` ∈ `%w[heliport closed seaplane_base balloonport]`. Manter `small_airport`, `medium_airport`, `large_airport`.

### Mapeamento
| CSV column | Airport column | Notas |
|---|---|---|
| `ident` | `icao_code` | limitado a 4 chars; se vazio, nil |
| `iata_code` | `iata_code` | limitado a 3 chars; se vazio ou whitespace, nil |
| `name` | `name` | obrigatório |
| `municipality` | `city` | opcional |
| `iso_country` | `country` | ISO 2 — obrigatório; skip linha se vazio |
| `latitude_deg` | `latitude` | float |
| `longitude_deg` | `longitude` | float |
| `type` | `airport_type` | string direto |
| — | `timezone` | não vem nesse CSV; deixar nil (outra fonte poderia completar no futuro) |

### Algoritmo (PORO)

```ruby
# app/models/airport/import/our_airports.rb
class Airport::Import::OurAirports
  SOURCE_URL = "https://davidmegginson.github.io/ourairports-data/airports.csv".freeze
  EXCLUDED_TYPES = %w[heliport closed seaplane_base balloonport].freeze
  BATCH_SIZE = 1000

  def self.call(source: SOURCE_URL, io: nil)
    new(source: source, io: io).call
  end

  def initialize(source:, io: nil)
    @source = source
    @io = io
  end

  def call
    csv_io = @io || URI.open(@source)
    imported = 0
    batch = []

    CSV.foreach(csv_io, headers: true) do |row|
      next if EXCLUDED_TYPES.include?(row["type"])
      next if row["iso_country"].blank?

      batch << map_row(row)
      if batch.size >= BATCH_SIZE
        Airport.upsert_all(batch, unique_by: :icao_code)
        imported += batch.size
        batch.clear
      end
    end
    Airport.upsert_all(batch, unique_by: :icao_code) if batch.any?
    imported + batch.size
  end

  private

  def map_row(row)
    {
      icao_code: row["ident"].presence,
      iata_code: row["iata_code"].to_s.strip.presence,
      name: row["name"],
      city: row["municipality"].presence,
      country: row["iso_country"],
      latitude: row["latitude_deg"]&.to_f,
      longitude: row["longitude_deg"]&.to_f,
      airport_type: row["type"]
    }
  end
end
```

### Idempotência
Unique index em `icao_code`? Olhando Fase 1 migration: temos unique partial em `iata_code` (where not null) e sem unique em `icao_code`. Problema: `upsert_all(unique_by: :icao_code)` exige unique index em icao_code.

**Ajuste necessário (nova migration na Fase 2):** adicionar `add_index :airports, :icao_code, unique: true, where: "icao_code IS NOT NULL"`. Isso faz o upsert funcionar e evita duplicatas entre execuções.

Alternativa sem migration: usar `find_or_initialize_by` + save em vez de upsert_all. Mais lento (~80k queries). **Decisão: migration.**

### Specs

Com fixture local (`spec/fixtures/our_airports/airports_sample.csv`, ~20 linhas reais):

- Importa N aeroportos válidos.
- Filtra heliport/closed.
- Parseia IATA vazio como nil.
- É idempotente (rodar 2x com o mesmo input não duplica).
- Aceita IO customizado (para testar sem rede).

Fixture pode ser um subset real do OurAirports, com 20 linhas cobrindo os casos (um com IATA, outro sem, um heliport, um closed, vários países).

## 9. Seeds detalhado

```ruby
# db/seeds.rb

if Airport.count.zero?
  puts "Seeding airports from OurAirports..."
  count = Airport::Import::OurAirports.call
  puts "Imported #{count} airports."
end

if User.count.zero?
  email = ENV.fetch("OWNER_EMAIL")
  password = ENV.fetch("OWNER_PASSWORD")
  User.create!(email: email, password: password)
  puts "Created owner user #{email}."
end
```

Se ENV vars não estiverem setadas, `fetch` raise `KeyError` — falha rápida, que é o que queremos no primeiro deploy. Em dev, o engenheiro sempre roda `OWNER_EMAIL=... OWNER_PASSWORD=... bin/rails db:seed`.

## 10. Testes

### Adapter spec (`spec/models/airport/import/our_airports_spec.rb`)
- Carregando fixture local via `File.open`.
- Assertions: conta de imports; campos mapeados; idempotência.

### Request spec (`spec/requests/sessions_spec.rb`)
- `GET /login` renderiza form.
- `POST /login` com credenciais válidas → redirect para `/` + session com user_id.
- `POST /login` com credenciais inválidas → re-render com status 422.
- `DELETE /logout` → session limpa + redirect para `/login`.
- Acesso a `/` deslogado → redirect para `/login`.

### Home spec (`spec/requests/home_spec.rb`) — pequeno
- `GET /` logado → 200 (placeholder view).
- `GET /` deslogado → 302 para `/login`.

## 11. Out of scope

- "Remember me" / expiração de sessão
- Esqueci a senha / reset
- 2FA, OAuth
- Signup público — **proibido**, enforce em `SessionsController`/routes
- Mudar senha (pode vir em fase futura)
- Completar timezone dos airports via outra fonte
- Progress bar na importação (dev roda uma vez no seed)

## 12. Risco / notas

- **Download de 15MB no seed** — em produção Hetzner, roda uma única vez no primeiro deploy. Sem retry sofisticado; se cair, rodar seed de novo (é idempotente).
- **Unique index em icao_code** — muda schema existente. Commit separado antes da implementação do importer.
- **`URI.open`** em Ruby 3.4 exige `require "open-uri"`. Incluir no arquivo.

## 13. Commits esperados (ordem)

1. `chore(phase-2): adiciona unique index em airports.icao_code para upsert idempotente`
2. `feat(phase-2): auth single-user (SessionsController + current_user + require_owner!)`
3. `feat(phase-2): home placeholder controller + layout com navbar`
4. `feat(phase-2): Airport::Import::OurAirports com upsert_all batched`
5. `feat(phase-2): seeds roda importer + cria owner a partir de ENV`
