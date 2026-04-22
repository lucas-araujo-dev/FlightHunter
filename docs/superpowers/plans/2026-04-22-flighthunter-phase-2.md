# FlightHunter — Fase 2 (Auth + Seed + OurAirports) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Single-user auth funcional (login/logout, current_user, require_owner!) + `Airport::Import::OurAirports` PORO + seed que popula banco com aeroportos e owner.

**Architecture:** CLAUDE.base.md prevalece — importer em `app/models/airport/import/our_airports.rb` (não `app/services/`, não `lib/`). Controller thin com apenas REST verbs. Sem signup público.

**Tech Stack:** Rails 8.1, has_secure_password, URI.open + CSV, upsert_all, SQLite.

**Working directory:** `/home/lucas/RubymineProjects/seats/`
**Branch:** `feat/phase-2-auth-seed` (criado a partir de main).

**Reference spec:** `docs/superpowers/specs/2026-04-22-flighthunter-phase-2-auth-seed.md`.

---

## Task 1: Adicionar unique index em `airports.icao_code`

**Files:**
- Create: `db/migrate/<ts>_add_unique_index_to_airports_icao_code.rb`

- [ ] **Step 1.1: Generate migration**

  ```bash
  cd /home/lucas/RubymineProjects/seats
  bin/rails g migration AddUniqueIndexToAirportsIcaoCode
  ```

- [ ] **Step 1.2: Edit migration body**

  Replace content:
  ```ruby
  class AddUniqueIndexToAirportsIcaoCode < ActiveRecord::Migration[8.1]
    def change
      add_index :airports, :icao_code, unique: true, where: "icao_code IS NOT NULL"
    end
  end
  ```

- [ ] **Step 1.3: Migrar**

  ```bash
  bin/rails db:migrate
  ```

- [ ] **Step 1.4: Rodar rspec (confirm nothing broke)**

  ```bash
  bundle exec rspec
  ```
  Expected: todos os specs da Fase 1 ainda verdes (57 examples, 0 failures).

- [ ] **Step 1.5: Commit**

  ```bash
  git add -A
  git commit -m "chore(phase-2): adiciona unique index em airports.icao_code para upsert idempotente"
  ```

---

## Task 2: Auth single-user (ApplicationController + SessionsController + rotas + views)

**Files:**
- Modify: `app/controllers/application_controller.rb`
- Create: `app/controllers/sessions_controller.rb`
- Create: `app/views/sessions/new.html.erb`
- Modify: `config/routes.rb`
- Modify: `app/models/user.rb` (adiciona `owner?`)
- Create: `spec/requests/sessions_spec.rb`

- [ ] **Step 2.1: Atualizar `app/models/user.rb`** — adicionar `owner?` predicate

  Após a linha `validates :email, presence: true, uniqueness: {case_sensitive: false}`, adicionar:

  ```ruby
    def owner?
      true
    end
  ```

  Single-user: todo User é o owner. Fica para uso semântico em controllers (`redirect unless current_user&.owner?`).

- [ ] **Step 2.2: Atualizar `app/controllers/application_controller.rb`**

  Conteúdo completo:

  ```ruby
  class ApplicationController < ActionController::Base
    allow_browser versions: :modern

    before_action :require_owner!

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

- [ ] **Step 2.3: Criar `app/controllers/sessions_controller.rb`**

  Conteúdo completo:

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

- [ ] **Step 2.4: Criar `app/views/sessions/new.html.erb`**

  Conteúdo completo (Tailwind classes):

  ```erb
  <div class="min-h-screen flex items-center justify-center bg-gray-50">
    <div class="max-w-md w-full space-y-6 p-8 bg-white shadow rounded-lg">
      <h1 class="text-2xl font-semibold text-gray-900">Entrar no FlightHunter</h1>

      <% if flash[:alert] %>
        <div class="rounded bg-red-50 text-red-700 px-4 py-3 text-sm"><%= flash[:alert] %></div>
      <% end %>
      <% if flash[:notice] %>
        <div class="rounded bg-green-50 text-green-700 px-4 py-3 text-sm"><%= flash[:notice] %></div>
      <% end %>

      <%= form_with url: session_path, method: :post, local: true, class: "space-y-4" do |f| %>
        <div>
          <%= f.label :email, class: "block text-sm font-medium text-gray-700" %>
          <%= f.email_field :email, required: true, autofocus: true,
              class: "mt-1 block w-full rounded border-gray-300 shadow-sm" %>
        </div>
        <div>
          <%= f.label :password, class: "block text-sm font-medium text-gray-700" %>
          <%= f.password_field :password, required: true,
              class: "mt-1 block w-full rounded border-gray-300 shadow-sm" %>
        </div>
        <%= f.submit "Entrar",
            class: "w-full px-4 py-2 bg-indigo-600 text-white rounded hover:bg-indigo-700" %>
      <% end %>
    </div>
  </div>
  ```

  Nota: `form_with url: session_path, method: :post` — `session_path` resolve para `/session` (POST) → `sessions#create`.

- [ ] **Step 2.5: Atualizar `config/routes.rb`**

  Conteúdo completo:

  ```ruby
  Rails.application.routes.draw do
    resource :session, only: %i[new create destroy],
      path: "", path_names: {new: "login"}

    delete "/logout", to: "sessions#destroy", as: :logout

    root "home#show"
  end
  ```

  Resolve para: `GET /login` → `sessions#new`, `POST /session` → `sessions#create`, `DELETE /logout` → `sessions#destroy`, `GET /` → `home#show`.

  **Nota:** `HomeController#show` ainda não existe — criaremos na Task 3. Se tentar rodar antes, Rails reclama — Task 3 cobre isso.

- [ ] **Step 2.6: Criar `spec/requests/sessions_spec.rb`**

  Conteúdo completo:

  ```ruby
  require "rails_helper"

  RSpec.describe "Sessions", type: :request do
    let(:user) { create(:user, email: "owner@flighthunter.local", password: "owner-password-123") }

    describe "GET /login" do
      it "renders the login form when logged out" do
        get login_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Entrar no FlightHunter")
      end

      it "redirects to root when already logged in" do
        post session_path, params: {email: user.email, password: "owner-password-123"}
        get login_path
        expect(response).to redirect_to(root_path)
      end
    end

    describe "POST /session" do
      it "logs in with valid credentials" do
        post session_path, params: {email: user.email, password: "owner-password-123"}
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(session[:user_id]).to eq(user.id)
      end

      it "is case-insensitive for email" do
        post session_path, params: {email: user.email.upcase, password: "owner-password-123"}
        expect(response).to redirect_to(root_path)
      end

      it "rejects wrong password" do
        post session_path, params: {email: user.email, password: "wrong"}
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Email ou senha inválidos.")
      end

      it "rejects unknown email" do
        post session_path, params: {email: "nobody@nowhere.com", password: "secret"}
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    describe "DELETE /logout" do
      it "clears session and redirects to login" do
        post session_path, params: {email: user.email, password: "owner-password-123"}
        delete logout_path
        expect(response).to redirect_to(login_path)
        expect(session[:user_id]).to be_nil
      end
    end
  end
  ```

- [ ] **Step 2.7: Rodar spec — após Task 3 estar em cima disso rodará verde**

  Sem HomeController ainda, `root_path` redirect vai dar erro 500. Aguarde Task 3 para completar.

  Por enquanto, rodar só esse spec individualmente com o stub:

  ```bash
  bundle exec rspec spec/requests/sessions_spec.rb
  ```
  Expected: alguns testes verdes (ex: "rejects wrong password"), mas os que fazem redirect para `root_path` falharão até HomeController existir. **Isso é esperado — commit mesmo assim**; a Task 3 fecha a suíte.

- [ ] **Step 2.8: Commit**

  ```bash
  git add -A
  git commit -m "feat(phase-2): auth single-user (SessionsController + current_user + require_owner!)"
  ```

---

## Task 3: Home placeholder + layout com navbar

**Files:**
- Create: `app/controllers/home_controller.rb`
- Create: `app/views/home/show.html.erb`
- Modify: `app/views/layouts/application.html.erb` (adiciona navbar + flash)
- Create: `app/views/layouts/_navbar.html.erb`
- Create: `spec/requests/home_spec.rb`

- [ ] **Step 3.1: Criar `app/controllers/home_controller.rb`**

  ```ruby
  class HomeController < ApplicationController
    def show
    end
  end
  ```

- [ ] **Step 3.2: Criar `app/views/home/show.html.erb`**

  Conteúdo:

  ```erb
  <div class="max-w-3xl mx-auto py-12 px-6">
    <h1 class="text-3xl font-bold text-gray-900">FlightHunter</h1>
    <p class="mt-4 text-gray-700">Olá, <%= current_user.email %>. Busca de voos chega na Fase 3.</p>
  </div>
  ```

- [ ] **Step 3.3: Criar `app/views/layouts/_navbar.html.erb`**

  ```erb
  <% if logged_in? %>
    <nav class="bg-white border-b border-gray-200">
      <div class="max-w-7xl mx-auto px-6 py-3 flex items-center justify-between">
        <%= link_to "FlightHunter", root_path, class: "text-lg font-semibold text-indigo-700" %>
        <div class="flex items-center gap-4 text-sm">
          <span class="text-gray-600"><%= current_user.email %></span>
          <%= button_to "Sair", logout_path, method: :delete,
              class: "text-gray-700 hover:text-red-700 underline" %>
        </div>
      </div>
    </nav>
  <% end %>
  ```

- [ ] **Step 3.4: Atualizar `app/views/layouts/application.html.erb`**

  Abrir o arquivo. Dentro de `<body>`, logo após `<body ...>`, inserir:

  ```erb
  <%= render "layouts/navbar" %>

  <% if flash[:notice] %>
    <div class="max-w-7xl mx-auto px-6 py-3 bg-green-50 text-green-700 text-sm rounded"><%= flash[:notice] %></div>
  <% end %>
  <% if flash[:alert] %>
    <div class="max-w-7xl mx-auto px-6 py-3 bg-red-50 text-red-700 text-sm rounded"><%= flash[:alert] %></div>
  <% end %>
  ```

  Antes do fechamento `</body>`. Manter o restante do layout intacto (Rails 8 gera header moderno com importmap, etc.).

- [ ] **Step 3.5: Criar `spec/requests/home_spec.rb`**

  ```ruby
  require "rails_helper"

  RSpec.describe "Home", type: :request do
    let(:user) { create(:user, email: "owner@flighthunter.local", password: "owner-password-123") }

    it "redirects to login when logged out" do
      get root_path
      expect(response).to redirect_to(login_path)
    end

    it "renders the home page when logged in" do
      post session_path, params: {email: user.email, password: "owner-password-123"}
      get root_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("FlightHunter")
      expect(response.body).to include(user.email)
    end
  end
  ```

- [ ] **Step 3.6: Rodar toda a suíte — tudo verde agora**

  ```bash
  bundle exec rspec
  bundle exec standardrb --fix
  bundle exec standardrb
  ```
  Expected: todos os specs verdes (57 da Fase 1 + ~5 sessions + 2 home = ~64 examples, 0 failures). Standard zero offenses.

- [ ] **Step 3.7: Commit**

  ```bash
  git add -A
  git commit -m "feat(phase-2): home placeholder controller + layout com navbar"
  ```

---

## Task 4: Airport::Import::OurAirports

**Files:**
- Create: `app/models/airport/import/our_airports.rb`
- Create: `spec/models/airport/import/our_airports_spec.rb`
- Create: `spec/fixtures/our_airports/airports_sample.csv`

- [ ] **Step 4.1: Criar fixture CSV `spec/fixtures/our_airports/airports_sample.csv`**

  Conteúdo (header + 20 linhas cobrindo cenários):

  ```csv
  id,ident,type,name,latitude_deg,longitude_deg,elevation_ft,continent,iso_country,iso_region,municipality,scheduled_service,gps_code,iata_code,local_code,home_link,wikipedia_link,keywords
  6523,SBFZ,large_airport,Pinto Martins International Airport,-3.776282,-38.532582,82,SA,BR,BR-CE,Fortaleza,yes,SBFZ,FOR,,,,
  3707,SBGR,large_airport,São Paulo-Guarulhos International Airport,-23.435556,-46.473056,2459,SA,BR,BR-SP,São Paulo,yes,SBGR,GRU,,,,
  3706,SBGL,large_airport,Rio de Janeiro-Galeão International Airport,-22.813,-43.250561,28,SA,BR,BR-RJ,Rio de Janeiro,yes,SBGL,GIG,,,,
  3703,SBCF,large_airport,Tancredo Neves International Airport,-19.624444,-43.971944,2715,SA,BR,BR-MG,Belo Horizonte,yes,SBCF,CNF,,,,
  3701,SBBR,large_airport,Brasília-President Juscelino Kubitschek International Airport,-15.869167,-47.920834,3497,SA,BR,BR-DF,Brasília,yes,SBBR,BSB,,,,
  14547,SSTR,small_airport,Torres Airport,-29.412899,-49.808998,30,SA,BR,BR-RS,Torres,no,SSTR,,,,,
  3700,SBBH,small_airport,Belo Horizonte-Pampulha Airport,-19.851944,-43.950556,2589,SA,BR,BR-MG,Belo Horizonte,yes,SBBH,PLU,,,,
  14521,SSRA,heliport,Rancho do Peixe Heliport,-5.0,-39.0,20,SA,BR,BR-CE,Somewhere,no,SSRA,,,,,
  14522,SNZZ,closed,Abandoned Airport,-4.0,-38.0,50,SA,BR,BR-CE,Nowhere,no,SNZZ,,,,,
  14523,SSEA,seaplane_base,Some Seaplane,-3.0,-37.0,0,SA,BR,BR-CE,Coast,no,SSEA,,,,,
  3501,KJFK,large_airport,John F Kennedy International Airport,40.639447,-73.779245,13,NA,US,US-NY,New York,yes,KJFK,JFK,,,,
  3511,KLAX,large_airport,Los Angeles International Airport,33.942501,-118.407997,125,NA,US,US-CA,Los Angeles,yes,KLAX,LAX,,,,
  3500,KORD,large_airport,Chicago O'Hare International Airport,41.9786,-87.9048,672,NA,US,US-IL,Chicago,yes,KORD,ORD,,,,
  2463,EGLL,large_airport,London Heathrow Airport,51.4706,-0.461941,83,EU,GB,GB-ENG,London,yes,EGLL,LHR,,,,
  2464,EGKK,large_airport,London Gatwick Airport,51.148056,-0.190278,202,EU,GB,GB-ENG,London,yes,EGKK,LGW,,,,
  2465,LFPG,large_airport,Charles de Gaulle International Airport,49.012779,2.55,392,EU,FR,FR-IDF,Paris,yes,LFPG,CDG,,,,
  2466,EHAM,large_airport,Amsterdam Airport Schiphol,52.308601,4.76389,-11,EU,NL,NL-NH,Amsterdam,yes,EHAM,AMS,,,,
  99991,,small_airport,Unregistered strip,0.0,0.0,0,AF,NG,NG-LA,Lagos,no,,,,,
  99992,XXXX,small_airport,No country,0.0,0.0,0,AF,,NG-LA,Nowhere,no,XXXX,,,,,
  2468,SBSP,medium_airport,São Paulo-Congonhas Airport,-23.626111,-46.655552,2631,SA,BR,BR-SP,São Paulo,yes,SBSP,CGH,,,,
  ```

  Tipos presentes: `large_airport` (12), `small_airport` (3), `medium_airport` (1), `heliport` (1), `closed` (1), `seaplane_base` (1), + 1 linha sem `iso_country` (deve ser pulada) + 1 linha sem `ident` (icao_code nil ok).

  **Resumo esperado ao importar:** 16 aeroportos (20 totais - 3 excluded types - 1 linha sem country).

- [ ] **Step 4.2: Criar `spec/models/airport/import/our_airports_spec.rb`**

  ```ruby
  require "rails_helper"

  RSpec.describe Airport::Import::OurAirports, type: :model do
    let(:fixture_path) { Rails.root.join("spec/fixtures/our_airports/airports_sample.csv") }

    describe ".call with local fixture" do
      it "imports the expected number of airports" do
        count_before = Airport.count
        File.open(fixture_path) do |io|
          described_class.call(io: io)
        end
        expect(Airport.count - count_before).to eq(16)
      end

      it "excludes heliport, closed and seaplane_base types" do
        File.open(fixture_path) { |io| described_class.call(io: io) }
        expect(Airport.where(airport_type: "heliport")).to be_empty
        expect(Airport.where(airport_type: "closed")).to be_empty
        expect(Airport.where(airport_type: "seaplane_base")).to be_empty
      end

      it "skips rows without iso_country" do
        File.open(fixture_path) { |io| described_class.call(io: io) }
        expect(Airport.where(name: "No country")).to be_empty
      end

      it "maps columns correctly" do
        File.open(fixture_path) { |io| described_class.call(io: io) }
        fortaleza = Airport.find_by(icao_code: "SBFZ")
        expect(fortaleza).to have_attributes(
          iata_code: "FOR",
          name: "Pinto Martins International Airport",
          city: "Fortaleza",
          country: "BR",
          airport_type: "large_airport"
        )
        expect(fortaleza.latitude).to be_within(0.001).of(-3.776282)
      end

      it "persists nil iata_code for airports without it" do
        File.open(fixture_path) { |io| described_class.call(io: io) }
        torres = Airport.find_by(icao_code: "SSTR")
        expect(torres).to be_present
        expect(torres.iata_code).to be_nil
      end

      it "is idempotent when run twice with same input" do
        File.open(fixture_path) { |io| described_class.call(io: io) }
        first_count = Airport.count
        File.open(fixture_path) { |io| described_class.call(io: io) }
        expect(Airport.count).to eq(first_count)
      end

      it "skips rows with empty ident (icao_code is the unique_by key)" do
        File.open(fixture_path) { |io| described_class.call(io: io) }
        expect(Airport.find_by(name: "Unregistered strip")).to be_nil
      end
    end
  end
  ```

- [ ] **Step 4.3: Rodar spec — expect failure (implementer doesn't exist)**

  ```bash
  bundle exec rspec spec/models/airport/import/our_airports_spec.rb
  ```
  Expected: `NameError: uninitialized constant Airport::Import`.

- [ ] **Step 4.4: Criar `app/models/airport/import/our_airports.rb`**

  Conteúdo completo:

  ```ruby
  require "open-uri"
  require "csv"

  class Airport::Import::OurAirports
    SOURCE_URL = "https://davidmegginson.github.io/ourairports-data/airports.csv"
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

      CSV.new(csv_io, headers: true).each do |row|
        next if EXCLUDED_TYPES.include?(row["type"])
        next if row["iso_country"].blank?
        next if row["ident"].blank?

        batch << map_row(row)
        if batch.size >= BATCH_SIZE
          imported += flush(batch)
          batch = []
        end
      end
      imported += flush(batch) if batch.any?
      imported
    end

    private

    def flush(batch)
      now = Time.current
      Airport.upsert_all(
        batch.map { |attrs| attrs.merge(created_at: now, updated_at: now) },
        unique_by: :icao_code
      )
      batch.size
    end

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

  Nota: `upsert_all` exige `created_at`/`updated_at` explícitos (Rails não os injeta em bulk).

- [ ] **Step 4.5: Rodar spec — verde**

  ```bash
  bundle exec rspec spec/models/airport/import/our_airports_spec.rb
  ```
  Expected: 7 examples green. Se uniqueness constraint reclamar, confirmar que migration da Task 1 está aplicada (`bin/rails db:schema:load` ou rodar `db:migrate`).

- [ ] **Step 4.6: Rodar suíte completa + lint**

  ```bash
  bundle exec rspec
  bundle exec standardrb --fix
  bundle exec standardrb
  ```
  Expected: todos verdes, zero offenses.

- [ ] **Step 4.7: Commit**

  ```bash
  git add -A
  git commit -m "feat(phase-2): Airport::Import::OurAirports com upsert_all batched"
  ```

---

## Task 5: Seeds (importer + owner)

**Files:**
- Modify: `db/seeds.rb`

- [ ] **Step 5.1: Substituir `db/seeds.rb`**

  Conteúdo completo (Rails 8 gera seeds.rb vazio ou com comentários; sobrescreva):

  ```ruby
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

- [ ] **Step 5.2: Smoke test manual em dev (dry-run)**

  ```bash
  # Fresh test DB sem network — só verifica que o código carrega
  bundle exec rspec
  ```

  Verificar que o importer pelo menos carrega sem erro de sintaxe:
  ```bash
  bin/rails runner 'puts Airport::Import::OurAirports.instance_method(:call).source_location'
  ```
  Expected: path do arquivo + linha.

  **Não rodar `bin/rails db:seed` aqui**, pois dispararia network real (download de 15MB + populate em dev DB). O seed só é validado de verdade em produção/primeiro deploy. O spec da Task 4 já cobriu a lógica do importer com fixture local.

- [ ] **Step 5.3: Commit**

  ```bash
  git add db/seeds.rb
  git commit -m "feat(phase-2): seeds roda importer + cria owner a partir de ENV"
  ```

---

## Task 6: Smoke test final Fase 2

- [ ] **Step 6.1: Suíte completa**

  ```bash
  cd /home/lucas/RubymineProjects/seats
  bundle exec rspec
  ```
  Expected: ~70 examples, 0 failures (57 Fase 1 + ~7 importer + ~5 sessions + 2 home).

- [ ] **Step 6.2: Lint**

  ```bash
  bundle exec standardrb
  ```
  Expected: zero offenses.

- [ ] **Step 6.3: Server boot + rota básica**

  ```bash
  timeout 8 bin/rails server 2>&1 | head -15
  ```
  Expected: Rails boota, não há NameError/RouteError.

- [ ] **Step 6.4: Tag phase-2-complete**

  ```bash
  git tag phase-2-complete
  ```

---

## Resumo do que a Fase 2 entrega

- Login funcionando em `/login`, logout em `/logout`.
- Root `/` mostra navbar com email do owner + botão Sair; redireciona para login se deslogado.
- `Airport::Import::OurAirports.call` importa ~80k aeroportos com idempotência.
- `db/seeds.rb` popula em primeiro run: airports + owner user via ENV.
- 6 commits na branch `feat/phase-2-auth-seed`, tag `phase-2-complete`.
