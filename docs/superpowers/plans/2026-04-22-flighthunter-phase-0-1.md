# FlightHunter — Fase 0 (Bootstrap) + Fase 1 (Schema & Models) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Subir o projeto Rails 8 do zero com todo o toolchain (Hotwire, ViewComponent, Solid trio, RSpec, VCR, Standard, ActiveRecord::Encryption) e criar as 6 entidades do domínio com migrations, models, validações, enums string-backed, factories e specs verdes.

**Architecture:** Family 6 do "Rails Whey" (CLAUDE.base.md): tudo de domínio em `app/models/<entity>/`. Sem `app/services/`, sem `app/providers/`. Enums sempre string-backed. Encryption via ActiveRecord::Encryption (Rails 8 nativo).

**Tech Stack:** Ruby 3.3+, Rails 8+, SQLite 3 (WAL), Hotwire, ViewComponent, Tailwind standalone, Solid Queue/Cache/Cable, RSpec + FactoryBot + VCR + WebMock, Standard (linter), Ferrum, HTTParty, telegram-bot-ruby, sentry-ruby.

**Working directory:** `/home/lucas/RubymineProjects/seats/`. O nome do diretório permanece `seats` (o nome do **produto** é FlightHunter; o **módulo Rails** será renomeado para `Flighthunter` na Task 2).

**Reference spec:** `docs/superpowers/specs/2026-04-22-flighthunter-design.md` (seções §4 estrutura, §6 data model, §8 fases).

**Commit prefix convention:** `feat(phase-0): ...` para Fase 0, `feat(phase-1): ...` para Fase 1.

---

## Fase 0 — Bootstrap

### Task 1: Rails new no diretório atual

**Files:**
- Create: todo o esqueleto Rails 8 em `/home/lucas/RubymineProjects/seats/`

- [ ] **Step 1.1: Verificar versões**

Run:
```bash
ruby -v
rails -v
```
Expected: Ruby 3.3+ (ex: `ruby 3.3.x`), Rails 8.0+ (ex: `Rails 8.0.x`). Se Rails não estiver em 8+, `gem install rails -v '~> 8.0'` antes de prosseguir.

- [ ] **Step 1.2: Rodar rails new no diretório**

Os 3 arquivos existentes (`CLAUDE.base.md`, `CLAUDE_CODE_GUIDE.md`, `REQUIREMENTS.md`) + pasta `docs/` já criada devem ser preservados. `rails new .` pergunta antes de sobrescrever; usaremos `--force` só se necessário.

Run:
```bash
rails new . --database=sqlite3 --css=tailwind --skip-jbuilder --skip-docker --skip-test --skip-git
```

Notas:
- `--skip-test` pula Minitest (usaremos RSpec).
- `--skip-git` evita sobrescrever `.git` (vamos inicializar depois manualmente).
- `--css=tailwind` já instala `tailwindcss-rails` standalone.
- `--skip-docker` porque Kamal gerará seu próprio Dockerfile na Fase 8.
- Aceitar com `Y` qualquer prompt de sobrescrita — os 3 .md serão preservados (rails new não cria arquivos com esses nomes).

Expected: diretório populado com `app/`, `config/`, `db/`, `bin/`, `Gemfile`, etc.

- [ ] **Step 1.3: Verificar que os 3 .md e docs/ sobreviveram**

Run:
```bash
ls /home/lucas/RubymineProjects/seats/ | grep -E 'CLAUDE.base.md|CLAUDE_CODE_GUIDE.md|REQUIREMENTS.md|docs'
```
Expected: os 4 itens listados.

- [ ] **Step 1.4: Inicializar git**

Run:
```bash
git init
git add -A
git status --short | head -5
```
Expected: muitos arquivos `A ` listados (esqueleto Rails).

- [ ] **Step 1.5: Primeiro commit do esqueleto**

```bash
git commit -m "chore(phase-0): rails new flighthunter com Hotwire + Tailwind"
```

Expected: commit criado. O próximo trabalho segue sobre esse skeleton.

---

### Task 2: Renomear módulo Rails de `Seats` para `Flighthunter`

**Files:**
- Modify: `config/application.rb`
- Modify: `config/environment.rb`
- Modify: `config.ru`

Rails gera o módulo raiz a partir do nome do diretório (`seats` → `module Seats`). Vamos forçar `Flighthunter`.

- [ ] **Step 2.1: Substituir em config/application.rb**

Abra `config/application.rb`. Substitua:
```ruby
module Seats
  class Application < Rails::Application
```
por:
```ruby
module Flighthunter
  class Application < Rails::Application
```

- [ ] **Step 2.2: Substituir em config/environment.rb**

Abra `config/environment.rb`. Substitua:
```ruby
Rails.application.initialize!
```
Se aparecer `Seats::Application.initialize!`, trocar por `Rails.application.initialize!` (forma mais moderna). Geralmente Rails 8 já escreve `Rails.application.initialize!` — se for esse o caso, **nada a mudar**.

- [ ] **Step 2.3: Substituir em config.ru**

Abra `config.ru`. Se aparecer `run Seats::Application`, trocar por `run Rails.application`. Rails 8 já usa `Rails.application` — se for esse o caso, **nada a mudar**.

- [ ] **Step 2.4: grep final**

Run:
```bash
grep -rn "Seats" --include="*.rb" --include="*.ru" --include="*.yml" --include="*.erb" .
```
Expected: zero ocorrências. Se aparecer em locais inesperados (ex: `db/schema.rb` ou comentários), substituir.

- [ ] **Step 2.5: Configurar timezone e locale default**

Em `config/application.rb`, dentro de `class Application < Rails::Application`, adicionar:

```ruby
config.time_zone = "America/Fortaleza"
config.active_record.default_timezone = :utc
config.i18n.default_locale = :"pt-BR"
config.i18n.available_locales = [:"pt-BR", :en]
```

Notas: armazenar em UTC no banco, renderizar em America/Fortaleza na app. Locale `pt-BR` requer arquivos de tradução que serão adicionados conforme necessário nas fases seguintes (Rails aceita o locale sem os arquivos existirem, apenas cai para `en`).

- [ ] **Step 2.6: Verificar que Rails carrega**

Run:
```bash
bin/rails runner 'puts Flighthunter::Application.name; puts Time.zone.name'
```
Expected: `Flighthunter::Application` e `America/Fortaleza`.

- [ ] **Step 2.7: Commit**

```bash
git add -A
git commit -m "chore(phase-0): renomeia módulo Seats -> Flighthunter + timezone America/Fortaleza"
```

---

### Task 3: Adicionar gems ao Gemfile

**Files:**
- Modify: `Gemfile`
- Modify: `Gemfile.lock` (via bundle)

- [ ] **Step 3.1: Adicionar gems de runtime**

No `Gemfile`, dentro do bloco principal (fora de `group`), adicionar após a linha do `rails`:

```ruby
gem "view_component", "~> 3.0"
gem "ferrum", "~> 0.15"
gem "nokogiri", "~> 1.16"
gem "httparty", "~> 0.22"
gem "telegram-bot-ruby", "~> 2.0"
gem "sentry-ruby", "~> 5.17"
gem "sentry-rails", "~> 5.17"
gem "csv"
```

Notas: versões aproximadas do momento; bundle vai resolver. `csv` é explícito porque virou gem separada no Ruby 3.4+.

- [ ] **Step 3.2: Adicionar gems de dev/test**

No bloco `group :development, :test do ... end` do `Gemfile`, adicionar:

```ruby
gem "rspec-rails", "~> 7.0"
gem "factory_bot_rails", "~> 6.4"
gem "faker", "~> 3.3"
gem "standard", "~> 1.35"
```

No bloco `group :test do ... end` (criar se não existir), adicionar:

```ruby
gem "vcr", "~> 6.2"
gem "webmock", "~> 3.23"
gem "capybara"
gem "selenium-webdriver"
gem "shoulda-matchers", "~> 6.2"
```

Nota: Rails 8 com `--skip-test` NÃO inclui capybara/selenium automaticamente. Adicionamos explícito porque ViewComponent test helpers usam Capybara para matchers e request specs futuros usam system tests.

- [ ] **Step 3.3: Verificar gems Rails 8 default (solid trio + kamal)**

Run:
```bash
grep -E "solid_queue|solid_cache|solid_cable|kamal" Gemfile
```
Expected: 4 linhas (uma por gem). Se alguma estiver faltando, adicionar manualmente:

```ruby
gem "solid_queue"
gem "solid_cache"
gem "solid_cable"
gem "kamal", require: false
```

- [ ] **Step 3.4: bundle install**

Run:
```bash
bundle install
```
Expected: `Bundle complete!`. Se der conflito de versão, relaxar constraints (`"~> X"` → sem constraint) e rerun.

- [ ] **Step 3.5: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "chore(phase-0): adiciona gems ViewComponent, RSpec, VCR, HTTParty, Ferrum, Telegram, Sentry, Standard"
```

---

### Task 4: Instalar RSpec e remover qualquer resquício de Minitest

**Files:**
- Create: `spec/spec_helper.rb`, `spec/rails_helper.rb`, `.rspec`
- Delete: `test/` se existir (não deveria, `--skip-test` pulou)

- [ ] **Step 4.1: Verificar que test/ não existe**

Run:
```bash
ls test 2>&1 || echo "NO TEST DIR"
```
Expected: `NO TEST DIR`. Se `test/` existir, remover: `rm -rf test`.

- [ ] **Step 4.2: Instalar RSpec**

Run:
```bash
bin/rails generate rspec:install
```
Expected: cria `.rspec`, `spec/spec_helper.rb`, `spec/rails_helper.rb`.

- [ ] **Step 4.3: Verificar que RSpec roda**

Run:
```bash
bundle exec rspec
```
Expected: `0 examples, 0 failures`.

- [ ] **Step 4.4: Commit**

```bash
git add -A
git commit -m "chore(phase-0): instala RSpec"
```

---

### Task 5: Configurar VCR + WebMock

**Files:**
- Modify: `spec/rails_helper.rb`
- Create: `spec/support/vcr.rb`
- Create: `spec/cassettes/.gitkeep`

- [ ] **Step 5.1: Criar pasta cassettes**

Run:
```bash
mkdir -p spec/cassettes
touch spec/cassettes/.gitkeep
```

- [ ] **Step 5.2: Criar spec/support/vcr.rb**

Conteúdo completo:

```ruby
require "vcr"
require "webmock/rspec"

VCR.configure do |config|
  config.cassette_library_dir = Rails.root.join("spec/cassettes")
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.ignore_localhost = true
  config.default_cassette_options = {
    record: :once,
    match_requests_on: [:method, :uri, :body]
  }

  %w[
    duffel_api_key
    amadeus_client_id
    amadeus_client_secret
    seats_aero_api_key
    telegram_bot_token
    telegram_owner_chat_id
    sentry_dsn
  ].each do |secret|
    config.filter_sensitive_data("<#{secret.upcase}>") do
      Rails.application.credentials.dig(secret.to_sym).to_s
    end
  end
end

WebMock.disable_net_connect!(allow_localhost: true)
```

- [ ] **Step 5.3: Habilitar support/ em rails_helper.rb**

Em `spec/rails_helper.rb`, descomentar (ou adicionar) a linha:
```ruby
Dir[Rails.root.join("spec/support/**/*.rb")].sort.each { |f| require f }
```

- [ ] **Step 5.4: Rodar rspec pra confirmar que nada quebrou**

Run:
```bash
bundle exec rspec
```
Expected: `0 examples, 0 failures`.

- [ ] **Step 5.5: Commit**

```bash
git add -A
git commit -m "chore(phase-0): configura VCR + WebMock com filter de secrets"
```

---

### Task 6: Configurar ViewComponent

**Files:**
- Create: `spec/components/.gitkeep`, `spec/components/previews/.gitkeep`
- Modify: `config/application.rb`
- Create: `spec/support/view_component.rb`

- [ ] **Step 6.1: Criar pastas**

Run:
```bash
mkdir -p app/components spec/components/previews
touch app/components/.gitkeep spec/components/.gitkeep spec/components/previews/.gitkeep
```

- [ ] **Step 6.2: Registrar preview path**

Em `config/application.rb`, dentro do bloco `class Application`, adicionar:

```ruby
config.view_component.preview_paths << Rails.root.join("spec/components/previews").to_s
config.view_component.default_preview_layout = "component_preview"
```

- [ ] **Step 6.3: Criar helper de teste para ViewComponent**

Conteúdo completo de `spec/support/view_component.rb`:

```ruby
require "view_component/test_helpers"
require "view_component/system_test_helpers"

RSpec.configure do |config|
  config.include ViewComponent::TestHelpers, type: :component
  config.include ViewComponent::SystemTestHelpers, type: :component
  config.include Capybara::RSpecMatchers, type: :component
end
```

- [ ] **Step 6.4: Rodar rspec**

Run:
```bash
bundle exec rspec
```
Expected: `0 examples, 0 failures`. Se `Capybara` não estiver disponível, adicionar `gem "capybara"` no group `:test` do Gemfile e rodar `bundle install`.

- [ ] **Step 6.5: Commit**

```bash
git add -A
git commit -m "chore(phase-0): configura ViewComponent com preview path"
```

---

### Task 7: Confirmar Solid trio instalado

**Files:**
- Verify: `config/queue.yml`, `config/cable.yml`, `config/cache.yml`
- Verify: `db/queue_schema.rb`, `db/cache_schema.rb`, `db/cable_schema.rb`

- [ ] **Step 7.1: Verificar que os três arquivos de config existem**

Run:
```bash
ls config/queue.yml config/cable.yml config/cache.yml
```
Expected: 3 arquivos listados. Se algum faltar:

```bash
bin/rails solid_queue:install    # se faltar queue
bin/rails solid_cache:install    # se faltar cache
bin/rails solid_cable:install    # se faltar cable
```

- [ ] **Step 7.2: Confirmar que cada solid_* aponta pra SQLite separado**

Abra `config/database.yml` e confirme que há 4 databases em production/development: `primary`, `queue`, `cache`, `cable`, cada um apontando para seu próprio arquivo (`storage/*.sqlite3` ou similar).

Exemplo esperado (Rails 8 default):
```yaml
production:
  primary: &primary_production
    <<: *default
    database: storage/production.sqlite3
  cache:
    <<: *primary_production
    database: storage/production_cache.sqlite3
    migrations_paths: db/cache_migrate
  queue:
    <<: *primary_production
    database: storage/production_queue.sqlite3
    migrations_paths: db/queue_migrate
  cable:
    <<: *primary_production
    database: storage/production_cable.sqlite3
    migrations_paths: db/cable_migrate
```

Se `config/database.yml` não tiver isso (ex: só um banco), editar para adicionar os 3 extras em `development` e `production`.

- [ ] **Step 7.3: Rodar db:prepare para criar os 4 bancos**

Run:
```bash
bin/rails db:prepare
```
Expected: cria os 4 `.sqlite3` em `storage/`. Sem erros.

- [ ] **Step 7.4: Rodar rspec**

Run:
```bash
bundle exec rspec
```
Expected: `0 examples, 0 failures`.

- [ ] **Step 7.5: Commit (se houve mudança em database.yml)**

```bash
git add -A
git commit -m "chore(phase-0): confirma Solid Queue/Cache/Cable com SQLite separado"
```

Se nada mudou, pular o commit.

---

### Task 8: Configurar ActiveRecord::Encryption

**Files:**
- Modify: `config/credentials.yml.enc` (via rails credentials:edit)

- [ ] **Step 8.1: Gerar chaves de encryption**

Run:
```bash
bin/rails db:encryption:init
```
Expected: imprime 3 chaves no formato:
```
active_record_encryption:
  primary_key: <64-char hex>
  deterministic_key: <64-char hex>
  key_derivation_salt: <64-char hex>
```

**Copiar todo o bloco** pra usar no próximo step.

- [ ] **Step 8.2: Adicionar chaves a credentials**

Run:
```bash
EDITOR='cat > /tmp/credentials_update.yml' bin/rails credentials:edit
```

Ou (mais simples): abrir editor interativo e colar as chaves:
```bash
bin/rails credentials:edit
```

Adicionar no final do arquivo de credentials:
```yaml
active_record_encryption:
  primary_key: <VALOR DO STEP 8.1>
  deterministic_key: <VALOR DO STEP 8.1>
  key_derivation_salt: <VALOR DO STEP 8.1>
```

Salvar e fechar.

- [ ] **Step 8.3: Verificar que ActiveRecord::Encryption carrega**

Run:
```bash
bin/rails runner 'puts ActiveRecord::Encryption.config.primary_key.present?'
```
Expected: `true`.

- [ ] **Step 8.4: Commit**

```bash
git add config/credentials.yml.enc
git commit -m "chore(phase-0): configura chaves de ActiveRecord::Encryption"
```

> **Importante:** `config/master.key` JÁ está no `.gitignore` (Rails gera assim). Nunca comite.

---

### Task 9: Criar /CLAUDE.md do repo (conventions para futuras sessões)

**Files:**
- Create: `/CLAUDE.md` (raiz do repo, não confundir com `CLAUDE.base.md`)

- [ ] **Step 9.1: Escrever CLAUDE.md**

Criar arquivo `/home/lucas/RubymineProjects/seats/CLAUDE.md` com o conteúdo a seguir (exato):

```markdown
# FlightHunter — conventions for Claude Code

Ferramenta pessoal single-user em Rails 8 + Hotwire que busca promoções de passagens (cash) e disponibilidade award de qualquer origem, com alertas automáticos via Telegram.

> **Arquitetura canônica: `CLAUDE.base.md`** (Family 6 do "Rails Whey"). Design master: `docs/superpowers/specs/2026-04-22-flighthunter-design.md`. Conflitos entre arquivos resolvem-se a favor de `CLAUDE.base.md`.

## Stack
- Ruby 3.3+, Rails 8+, SQLite 3 (WAL), Hotwire (Turbo + Stimulus), ViewComponent, Tailwind standalone
- Solid Queue (jobs), Solid Cache (cache 30min), Solid Cable (Turbo Streams)
- Ferrum (Chrome headless) para scrapers, HTTParty para APIs REST
- RSpec + FactoryBot + VCR + WebMock; Standard para lint
- Deploy via Kamal 2 para Hetzner VPS
- Módulo Rails: `Flighthunter`

## Commands
- `bin/dev` — server + worker Solid Queue + Tailwind watch + Telegram bot (Procfile.dev — criado na Fase 7)
- `bin/rails s` — só server
- `bundle exec rspec` — specs
- `bundle exec standardrb --fix` — lint autofix
- `bin/rails db:migrate` — migrations
- `bin/rails db:seed` — seed (OurAirports + owner — Fase 2)
- `bin/kamal deploy` — deploy (Fase 8)

## Directory layout (autoridade: CLAUDE.base.md §Estrutura)
- `app/models/<entity>/` — toda lógica de domínio (adapters de API externa, scrapers, matching, notificações, query objects, orquestrações).
- `app/controllers/` — thin HTTP adapters. 5-7 linhas por action. Apenas 7 verbs REST.
- `app/components/` — ViewComponent. Cada componente com preview em `spec/components/previews/`.
- `app/jobs/` — casca fina ActiveJob delegando para orquestração em `app/models/`.
- `app/bots/telegram_bot.rb` — runner do bot (Fase 7).

**Proibido:** `app/services/`, `app/providers/`, `app/interactors/`, `app/operations/`.

## Conventions
- **Vocabulário unificado:** `grep Alert` retorna model + controller + view + job em uma busca. Namespace idêntico entre camadas.
- **Autoridade no model:** predicados, scopes, constantes, enums no model dono do dado. Controller chama `alert.notifiable?`, nunca `Alert.where(...).exists?`.
- **Enums sempre string-backed.** Nunca integer (hard to debug).
- **Time:** `Time.zone.now` sempre. App TZ = `America/Fortaleza`.
- **Money:** `price_cents` (integer). Formatação na view.
- **Specs para todo código.** Provider adapters NUNCA hit rede em testes — VCR cassette obrigatório.
- **Queue names por domínio:** `:flight_offers`, `:alerts`, `:notifications`, `:cleanup`.

## Testing expectations
- Model specs: validations, associations, scopes.
- Query object specs: lógica pura sobre fixtures/factories.
- Adapter specs (FlightOffer::Search::*): VCR cassette por teste.
- Component specs: `ViewComponent::TestHelpers`.
- Request specs: happy path por jornada (J1-J5 definidas em REQUIREMENTS.md).
- Job specs: enfileiramento + execução (mocked).

## Adicionando um novo search adapter (a partir da Fase 5)
1. Criar `app/models/flight_offer/search/<name>.rb` herdando de `FlightOffer::Search::Base`. Implementar `#call`.
2. Criar `app/jobs/flight_offer/search/<name>_job.rb` (casca; queue `:flight_offers`).
3. Registrar em `config/initializers/flight_offer_search.rb` (criado na Fase 4).
4. Cassette VCR em `spec/cassettes/flight_offer/search/<name>/`.
5. Specs de adapter + job.

## Adicionando uma nova entidade
1. Migration com índices corretos.
2. Model com validações, associations, enums string-backed.
3. Factory em `spec/factories/`.
4. Model spec.
5. Se user-facing: ViewComponent + Turbo Frame + request spec.

## Things Claude Code should NOT do without asking
- `db:reset` / `db:drop` em qualquer ambiente.
- Adicionar gem nova sem justificar (cada gem é supply-chain risk).
- Commit de credentials ou .env.
- `puts` de API keys em debug.
- Network calls em specs sem cassette — pare e pergunte.
- Push direto em `main` — sempre branch + PR.
- Alterar schemas Solid Queue/Cache/Cable manualmente.
- Hardcoded airline codes / cabin class — usar enums do model.
- Criar `app/services/` ou `app/providers/` — viola CLAUDE.base.md. Se uma fase do guide pede isso, reescrever usando `app/models/<entity>/`.
```

- [ ] **Step 9.2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(phase-0): adiciona CLAUDE.md do repo apontando autoridade para CLAUDE.base.md"
```

---

### Task 10: Configurar Standard linter

**Files:**
- Create: `.rubocop.yml`

- [ ] **Step 10.1: Criar .rubocop.yml**

Conteúdo exato de `/home/lucas/RubymineProjects/seats/.rubocop.yml`:

```yaml
inherit_gem:
  standard: config/base.yml
  standard-rails: config/base.yml

AllCops:
  NewCops: enable
  Exclude:
    - "db/schema.rb"
    - "db/migrate/*.rb"
    - "bin/**/*"
    - "vendor/**/*"
    - "tmp/**/*"
    - "node_modules/**/*"
```

- [ ] **Step 10.2: Adicionar standard-rails ao Gemfile**

No `Gemfile`, grupo `:development, :test`, adicionar (se ainda não estiver):

```ruby
gem "standard-rails"
```

Run:
```bash
bundle install
```

- [ ] **Step 10.3: Rodar lint**

Run:
```bash
bundle exec standardrb
```
Expected: zero offenses, ou pequenos offenses em arquivos gerados — rodar `bundle exec standardrb --fix` para autofix.

- [ ] **Step 10.4: Commit**

```bash
git add -A
git commit -m "chore(phase-0): configura Standard (+ standard-rails) como linter"
```

---

### Task 11: Smoke test final da Fase 0

- [ ] **Step 11.1: Rodar specs**

```bash
bundle exec rspec
```
Expected: `0 examples, 0 failures`.

- [ ] **Step 11.2: Rodar lint**

```bash
bundle exec standardrb
```
Expected: zero offenses.

- [ ] **Step 11.3: Rodar server por 5s para verificar boot**

```bash
timeout 5 bin/rails server 2>&1 | head -20 || true
```
Expected: ver `Listening on ... 3000` ou similar. Sem exceptions.

- [ ] **Step 11.4: Tag do fim da Fase 0 (opcional)**

```bash
git tag phase-0-complete
```

Fase 0 **completa** quando todos os 3 steps acima passam. Prosseguir para Fase 1.

---

## Fase 1 — Schema & Models

> 6 entidades (REQUIREMENTS.md §8). Para cada uma: migration → model → factory → spec. TDD dentro do spec: escrever teste → falhar → implementar → passar → commit.

> Ordem dos models escolhida por dependência: User → Airport → FlightOffer (depende de Airport) → Alert (depende de User) → AlertMatch (depende de Alert + FlightOffer) → ProviderCheck (standalone).

---

### Task 12: Model User (com encryption)

**Files:**
- Create: `db/migrate/<timestamp>_create_users.rb`
- Create: `app/models/user.rb`
- Create: `spec/factories/users.rb`
- Create: `spec/models/user_spec.rb`

- [ ] **Step 12.1: Gerar migration**

```bash
bin/rails g migration CreateUsers email:string password_digest:string telegram_chat_id:string program_credentials:text
```

- [ ] **Step 12.2: Editar migration para adicionar unique index + null constraints**

Abrir `db/migrate/<timestamp>_create_users.rb`. Conteúdo completo:

```ruby
class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :telegram_chat_id
      t.text :program_credentials
      t.timestamps
    end

    add_index :users, :email, unique: true
  end
end
```

- [ ] **Step 12.3: Rodar migration**

```bash
bin/rails db:migrate
```
Expected: `CreateUsers ==> Migrated`.

- [ ] **Step 12.4: Escrever spec do User com expectativas (inicialmente falham)**

Criar `spec/models/user_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    it "requires email" do
      user = User.new(password: "secret123")
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it "requires unique email" do
      create(:user, email: "a@b.com")
      dupe = build(:user, email: "a@b.com")
      expect(dupe).not_to be_valid
      expect(dupe.errors[:email]).to include("has already been taken")
    end

    it "requires password on create" do
      user = User.new(email: "a@b.com")
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("can't be blank")
    end
  end

  describe "has_secure_password" do
    it "sets password_digest" do
      user = create(:user, password: "my-secret-123")
      expect(user.password_digest).to be_present
      expect(user.authenticate("my-secret-123")).to eq(user)
      expect(user.authenticate("wrong")).to eq(false)
    end
  end

  describe "#program_credentials" do
    it "persists encrypted JSON" do
      user = create(:user, program_credentials: {smiles: {login: "x", password: "y"}})
      user.reload
      expect(user.program_credentials).to eq({"smiles" => {"login" => "x", "password" => "y"}})
    end

    it "encrypts at rest" do
      user = create(:user, program_credentials: {smiles: {login: "x"}})
      raw = User.connection.select_value("SELECT program_credentials FROM users WHERE id = #{user.id}")
      expect(raw).not_to include("smiles")
      expect(raw).not_to include("login")
    end
  end

  describe "associations" do
    it { is_expected.to have_many(:alerts).dependent(:destroy) }
  end
end
```

- [ ] **Step 12.5: Configurar shoulda-matchers (já instalado na Task 3)**

Em `spec/rails_helper.rb`, após `RSpec.configure do |config| ... end`, adicionar no final do arquivo:

```ruby
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
```

- [ ] **Step 12.6: Escrever factory**

Criar `spec/factories/users.rb`:

```ruby
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "owner#{n}@flighthunter.local" }
    password { "owner-password-123" }
    program_credentials { {} }
  end
end
```

- [ ] **Step 12.7: Rodar spec — deve falhar**

```bash
bundle exec rspec spec/models/user_spec.rb
```
Expected: vários failures (modelo vazio).

- [ ] **Step 12.8: Implementar model User**

Criar `app/models/user.rb`:

```ruby
class User < ApplicationRecord
  has_secure_password

  encrypts :program_credentials, deterministic: false

  serialize :program_credentials, coder: JSON

  has_many :alerts, dependent: :destroy

  validates :email, presence: true, uniqueness: {case_sensitive: false}

  def program_credentials
    super || {}
  end
end
```

- [ ] **Step 12.9: Rodar spec — deve passar**

```bash
bundle exec rspec spec/models/user_spec.rb
```
Expected: todos os examples verdes. Se `serialize + encrypts` der conflito, resolver usando apenas `encrypts :program_credentials` e colocar JSON coerce manualmente:

```ruby
class User < ApplicationRecord
  has_secure_password
  encrypts :program_credentials, deterministic: false

  has_many :alerts, dependent: :destroy

  validates :email, presence: true, uniqueness: {case_sensitive: false}

  def program_credentials
    raw = read_attribute(:program_credentials)
    raw.present? ? JSON.parse(raw) : {}
  end

  def program_credentials=(hash)
    write_attribute(:program_credentials, hash.to_json)
  end
end
```

Rerun rspec até verde.

- [ ] **Step 12.10: Commit**

```bash
git add -A
git commit -m "feat(phase-1): User model com has_secure_password + program_credentials encrypted"
```

---

### Task 13: Model Airport

**Files:**
- Create: migration, `app/models/airport.rb`, `spec/factories/airports.rb`, `spec/models/airport_spec.rb`

- [ ] **Step 13.1: Gerar migration**

```bash
bin/rails g migration CreateAirports iata_code:string icao_code:string name:string city:string country:string latitude:float longitude:float timezone:string airport_type:string
```

- [ ] **Step 13.2: Editar migration**

Conteúdo completo:

```ruby
class CreateAirports < ActiveRecord::Migration[8.0]
  def change
    create_table :airports do |t|
      t.string :iata_code, limit: 3
      t.string :icao_code, limit: 4
      t.string :name, null: false
      t.string :city
      t.string :country, limit: 2, null: false
      t.float :latitude
      t.float :longitude
      t.string :timezone
      t.string :airport_type
      t.timestamps
    end

    add_index :airports, :iata_code, unique: true, where: "iata_code IS NOT NULL"
    add_index :airports, :city
    add_index :airports, :country
  end
end
```

- [ ] **Step 13.3: Rodar migration**

```bash
bin/rails db:migrate
```

- [ ] **Step 13.4: Factory**

Criar `spec/factories/airports.rb`:

```ruby
FactoryBot.define do
  factory :airport do
    sequence(:iata_code) { |n| ("A".ord + (n % 26)).chr + ("A".ord + ((n / 26) % 26)).chr + ("A".ord + ((n / 676) % 26)).chr }
    sequence(:icao_code) { |n| "Z" + ("A".ord + (n % 26)).chr + ("A".ord + ((n / 26) % 26)).chr + ("A".ord + ((n / 676) % 26)).chr }
    name { "#{city} International Airport" }
    city { "Fortaleza" }
    country { "BR" }
    latitude { -3.7762 }
    longitude { -38.5326 }
    timezone { "America/Fortaleza" }
    airport_type { "large_airport" }

    trait :small do
      airport_type { "small_airport" }
    end

    trait :sao_paulo do
      city { "São Paulo" }
      country { "BR" }
      iata_code { "GRU" }
      icao_code { "SBGR" }
      name { "Guarulhos International" }
    end
  end
end
```

- [ ] **Step 13.5: Spec**

Criar `spec/models/airport_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Airport, type: :model do
  describe "validations" do
    it "requires name" do
      expect(build(:airport, name: nil)).not_to be_valid
    end

    it "requires country" do
      expect(build(:airport, country: nil)).not_to be_valid
    end

    it "allows nil iata_code" do
      expect(build(:airport, iata_code: nil)).to be_valid
    end

    it "enforces unique iata_code when present" do
      create(:airport, iata_code: "FOR")
      expect(build(:airport, iata_code: "FOR")).not_to be_valid
    end

    it "allows multiple airports with nil iata_code" do
      create(:airport, iata_code: nil, icao_code: "XXXX")
      expect(build(:airport, iata_code: nil, icao_code: "YYYY")).to be_valid
    end
  end

  describe ".by_city" do
    it "groups airports by city + country" do
      create(:airport, :sao_paulo, iata_code: "GRU")
      create(:airport, city: "São Paulo", country: "BR", iata_code: "CGH")
      create(:airport, :sao_paulo, iata_code: "VCP")
      results = Airport.where(city: "São Paulo", country: "BR")
      expect(results.count).to eq(3)
    end
  end
end
```

- [ ] **Step 13.6: Rodar spec — deve falhar**

```bash
bundle exec rspec spec/models/airport_spec.rb
```
Expected: falhas de validação (name, country).

- [ ] **Step 13.7: Implementar model**

Criar `app/models/airport.rb`:

```ruby
class Airport < ApplicationRecord
  validates :name, presence: true
  validates :country, presence: true, length: {is: 2}
  validates :iata_code, uniqueness: true, length: {is: 3}, allow_nil: true
  validates :icao_code, length: {is: 4}, allow_nil: true

  scope :with_iata, -> { where.not(iata_code: nil) }
  scope :in_city, ->(city, country:) { where(city: city, country: country) }
end
```

- [ ] **Step 13.8: Rodar spec — verde**

```bash
bundle exec rspec spec/models/airport_spec.rb
```

- [ ] **Step 13.9: Commit**

```bash
git add -A
git commit -m "feat(phase-1): Airport model com validação de IATA/ICAO e índices"
```

---

### Task 14: Model FlightOffer

**Files:**
- Create: migration, `app/models/flight_offer.rb`, `spec/factories/flight_offers.rb`, `spec/models/flight_offer_spec.rb`

- [ ] **Step 14.1: Gerar migration**

```bash
bin/rails g migration CreateFlightOffers provider:string offer_type:string origin_airport:references destination_airport:references departure_at:datetime arrival_at:datetime return_departure_at:datetime return_arrival_at:datetime airline_iata:string flight_numbers:text stops:integer cabin_class:string price_cents:bigint currency:string miles:integer taxes_cents:bigint program:string deep_link:text raw_payload:text found_at:datetime expires_at:datetime
```

- [ ] **Step 14.2: Editar migration — ajustar FKs, defaults, índices**

Conteúdo completo de `db/migrate/<timestamp>_create_flight_offers.rb`:

```ruby
class CreateFlightOffers < ActiveRecord::Migration[8.0]
  def change
    create_table :flight_offers do |t|
      t.string :provider, null: false
      t.string :offer_type, null: false
      t.references :origin_airport, null: false, foreign_key: {to_table: :airports}
      t.references :destination_airport, null: false, foreign_key: {to_table: :airports}
      t.datetime :departure_at, null: false
      t.datetime :arrival_at, null: false
      t.datetime :return_departure_at
      t.datetime :return_arrival_at
      t.string :airline_iata, limit: 3
      t.text :flight_numbers
      t.integer :stops, null: false, default: 0
      t.string :cabin_class
      t.bigint :price_cents
      t.string :currency, limit: 3
      t.integer :miles
      t.bigint :taxes_cents
      t.string :program
      t.text :deep_link, null: false
      t.text :raw_payload
      t.datetime :found_at, null: false
      t.datetime :expires_at
      t.timestamps
    end

    add_index :flight_offers, [:origin_airport_id, :destination_airport_id, :departure_at], name: "idx_flight_offers_route_departure"
    add_index :flight_offers, :provider
    add_index :flight_offers, :found_at
    add_index :flight_offers, :expires_at
  end
end
```

- [ ] **Step 14.3: Migrar**

```bash
bin/rails db:migrate
```

- [ ] **Step 14.4: Factory**

Criar `spec/factories/flight_offers.rb`:

```ruby
FactoryBot.define do
  factory :flight_offer do
    provider { "duffel" }
    offer_type { "cash" }
    association :origin_airport, factory: :airport
    association :destination_airport, factory: :airport
    departure_at { 30.days.from_now.change(hour: 10) }
    arrival_at { 30.days.from_now.change(hour: 13) }
    airline_iata { "AD" }
    flight_numbers { ["AD2716"].to_json }
    stops { 0 }
    cabin_class { "economy" }
    price_cents { 50_000 }
    currency { "BRL" }
    deep_link { "https://example.com/offer/abc" }
    raw_payload { {test: true}.to_json }
    found_at { Time.current }
    expires_at { 24.hours.from_now }

    trait :award do
      offer_type { "award" }
      price_cents { nil }
      currency { nil }
      miles { 35_000 }
      taxes_cents { 15_000 }
      program { "smiles" }
      provider { "smiles" }
    end

    trait :round_trip do
      return_departure_at { 37.days.from_now.change(hour: 18) }
      return_arrival_at { 37.days.from_now.change(hour: 21) }
    end
  end
end
```

- [ ] **Step 14.5: Spec**

Criar `spec/models/flight_offer_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe FlightOffer, type: :model do
  describe "validations" do
    it "requires provider" do
      expect(build(:flight_offer, provider: nil)).not_to be_valid
    end

    it "requires offer_type" do
      expect(build(:flight_offer, offer_type: nil)).not_to be_valid
    end

    it "requires origin + destination airports" do
      expect(build(:flight_offer, origin_airport: nil)).not_to be_valid
      expect(build(:flight_offer, destination_airport: nil)).not_to be_valid
    end

    it "requires deep_link" do
      expect(build(:flight_offer, deep_link: nil)).not_to be_valid
    end
  end

  describe "enums" do
    it "accepts valid providers" do
      %w[duffel amadeus seats_aero smiles latam_pass tudoazul].each do |p|
        expect(build(:flight_offer, provider: p)).to be_valid
      end
    end

    it "rejects invalid providers" do
      expect { build(:flight_offer, provider: "lol") }.to raise_error(ArgumentError)
    end

    it "accepts offer_type cash and award" do
      expect(build(:flight_offer, offer_type: "cash")).to be_valid
      expect(build(:flight_offer, :award)).to be_valid
    end
  end

  describe "scopes" do
    let(:fortaleza) { create(:airport, iata_code: "FOR", city: "Fortaleza") }
    let(:guarulhos) { create(:airport, :sao_paulo, iata_code: "GRU") }

    it ".for_route finds by origin + destination" do
      offer = create(:flight_offer, origin_airport: fortaleza, destination_airport: guarulhos)
      create(:flight_offer, origin_airport: guarulhos, destination_airport: fortaleza)
      expect(FlightOffer.for_route(fortaleza, guarulhos)).to contain_exactly(offer)
    end

    it ".expired returns offers past expires_at" do
      old = create(:flight_offer, expires_at: 2.hours.ago)
      create(:flight_offer, expires_at: 2.hours.from_now)
      expect(FlightOffer.expired).to contain_exactly(old)
    end

    it ".cash / .award filter by offer_type" do
      cash = create(:flight_offer)
      award = create(:flight_offer, :award)
      expect(FlightOffer.cash).to contain_exactly(cash)
      expect(FlightOffer.award).to contain_exactly(award)
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:origin_airport).class_name("Airport") }
    it { is_expected.to belong_to(:destination_airport).class_name("Airport") }
    it { is_expected.to have_many(:alert_matches).dependent(:destroy) }
  end
end
```

- [ ] **Step 14.6: Rodar spec — falhar**

```bash
bundle exec rspec spec/models/flight_offer_spec.rb
```

- [ ] **Step 14.7: Implementar model**

Criar `app/models/flight_offer.rb`:

```ruby
class FlightOffer < ApplicationRecord
  PROVIDERS = %w[duffel amadeus seats_aero smiles latam_pass tudoazul].freeze
  OFFER_TYPES = %w[cash award].freeze
  CABIN_CLASSES = %w[economy premium_economy business first].freeze

  enum :provider, PROVIDERS.index_with(&:itself)
  enum :offer_type, OFFER_TYPES.index_with(&:itself)
  enum :cabin_class, CABIN_CLASSES.index_with(&:itself), prefix: :cabin

  belongs_to :origin_airport, class_name: "Airport"
  belongs_to :destination_airport, class_name: "Airport"
  has_many :alert_matches, dependent: :destroy

  validates :deep_link, presence: true
  validates :departure_at, :arrival_at, :found_at, presence: true
  validates :stops, numericality: {greater_than_or_equal_to: 0}

  scope :for_route, ->(origin, destination) {
    where(origin_airport: origin, destination_airport: destination)
  }
  scope :expired, -> { where("expires_at < ?", Time.current) }

  def flight_numbers
    raw = read_attribute(:flight_numbers)
    raw.present? ? JSON.parse(raw) : []
  end

  def flight_numbers=(arr)
    write_attribute(:flight_numbers, arr.is_a?(String) ? arr : arr.to_json)
  end

  def raw_payload
    raw = read_attribute(:raw_payload)
    raw.present? ? JSON.parse(raw) : {}
  end
end
```

- [ ] **Step 14.8: Rodar spec — verde**

```bash
bundle exec rspec spec/models/flight_offer_spec.rb
```

Se falhar algum `enum` test por causa de `.cash`/`.award` scopes não existirem, garanta que os enums do Rails 8 geraram os scopes (por default eles geram). Se não, adicionar manualmente:

```ruby
scope :cash, -> { where(offer_type: "cash") }
scope :award, -> { where(offer_type: "award") }
```

- [ ] **Step 14.9: Commit**

```bash
git add -A
git commit -m "feat(phase-1): FlightOffer model com enums string-backed e associações a Airport"
```

---

### Task 15: Model Alert (o mais complexo — validações compostas)

**Files:**
- Create: migration, `app/models/alert.rb`, `spec/factories/alerts.rb`, `spec/models/alert_spec.rb`

- [ ] **Step 15.1: Gerar migration**

```bash
bin/rails g migration CreateAlerts user:references origin_type:string origin_code:string destination_type:string destination_code:string trip_type:string departure_date_from:date departure_date_to:date return_date_from:date return_date_to:date cabin_class:string passengers:integer max_price_cents:bigint max_miles:integer currency:string active:boolean last_checked_at:datetime
```

- [ ] **Step 15.2: Editar migration**

Conteúdo completo:

```ruby
class CreateAlerts < ActiveRecord::Migration[8.0]
  def change
    create_table :alerts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :origin_type, null: false
      t.string :origin_code, null: false
      t.string :destination_type, null: false
      t.string :destination_code, null: false
      t.string :trip_type, null: false
      t.date :departure_date_from, null: false
      t.date :departure_date_to, null: false
      t.date :return_date_from
      t.date :return_date_to
      t.string :cabin_class, null: false, default: "economy"
      t.integer :passengers, null: false, default: 1
      t.bigint :max_price_cents
      t.integer :max_miles
      t.string :currency, limit: 3, null: false, default: "BRL"
      t.boolean :active, null: false, default: true
      t.datetime :last_checked_at
      t.timestamps
    end

    add_index :alerts, [:active, :last_checked_at], name: "idx_alerts_active_checked"
  end
end
```

- [ ] **Step 15.3: Migrar**

```bash
bin/rails db:migrate
```

- [ ] **Step 15.4: Factory**

Criar `spec/factories/alerts.rb`:

```ruby
FactoryBot.define do
  factory :alert do
    user
    origin_type { "airport" }
    origin_code { "FOR" }
    destination_type { "airport" }
    destination_code { "GRU" }
    trip_type { "one_way" }
    departure_date_from { 30.days.from_now.to_date }
    departure_date_to { 45.days.from_now.to_date }
    cabin_class { "economy" }
    passengers { 1 }
    max_price_cents { 80_000 }
    currency { "BRL" }
    active { true }

    trait :round_trip do
      trip_type { "round_trip" }
      return_date_from { 50.days.from_now.to_date }
      return_date_to { 65.days.from_now.to_date }
    end

    trait :miles_only do
      max_price_cents { nil }
      max_miles { 40_000 }
    end

    trait :paused do
      active { false }
    end
  end
end
```

- [ ] **Step 15.5: Spec (cobre todas as validações compostas)**

Criar `spec/models/alert_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Alert, type: :model do
  describe "validations" do
    it "requires user" do
      expect(build(:alert, user: nil)).not_to be_valid
    end

    it "requires origin + destination" do
      expect(build(:alert, origin_code: nil)).not_to be_valid
      expect(build(:alert, destination_code: nil)).not_to be_valid
    end

    it "requires at least one of max_price_cents or max_miles" do
      invalid = build(:alert, max_price_cents: nil, max_miles: nil)
      expect(invalid).not_to be_valid
      expect(invalid.errors[:base]).to include(/preço ou milhas/i)
    end

    it "is valid with only max_price" do
      expect(build(:alert, max_price_cents: 80_000, max_miles: nil)).to be_valid
    end

    it "is valid with only max_miles" do
      expect(build(:alert, :miles_only)).to be_valid
    end

    it "round_trip requires return dates" do
      invalid = build(:alert, trip_type: "round_trip", return_date_from: nil, return_date_to: nil)
      expect(invalid).not_to be_valid
      expect(invalid.errors[:return_date_from]).to be_present
    end

    it "one_way does not require return dates" do
      expect(build(:alert, trip_type: "one_way")).to be_valid
    end

    it "departure_date_to must be >= departure_date_from" do
      invalid = build(:alert, departure_date_from: 30.days.from_now, departure_date_to: 10.days.from_now)
      expect(invalid).not_to be_valid
    end

    it "rejects departure in the past" do
      invalid = build(:alert, departure_date_from: 1.day.ago)
      expect(invalid).not_to be_valid
      expect(invalid.errors[:departure_date_from]).to be_present
    end

    it "limits to 10 active alerts per user" do
      user = create(:user)
      10.times { create(:alert, user: user, origin_code: "FOR", destination_code: "GRU") }
      eleventh = build(:alert, user: user)
      expect(eleventh).not_to be_valid
      expect(eleventh.errors[:base]).to include(/10 alerts/i)
    end

    it "allows more than 10 if some are paused" do
      user = create(:user)
      10.times { create(:alert, :paused, user: user) }
      active = build(:alert, user: user)
      expect(active).to be_valid
    end
  end

  describe "enums" do
    it "origin_type and destination_type accept airport|city" do
      %w[airport city].each do |t|
        expect(build(:alert, origin_type: t)).to be_valid
      end
    end

    it "trip_type accepts one_way|round_trip" do
      expect(build(:alert, trip_type: "one_way")).to be_valid
      expect(build(:alert, :round_trip)).to be_valid
    end
  end

  describe "scopes" do
    it ".active returns only active" do
      active = create(:alert)
      create(:alert, :paused)
      expect(Alert.active).to contain_exactly(active)
    end

    it ".due_for_check returns nil last_checked_at OR older than 2h" do
      never = create(:alert, last_checked_at: nil)
      stale = create(:alert, last_checked_at: 3.hours.ago)
      fresh = create(:alert, last_checked_at: 30.minutes.ago)
      expect(Alert.due_for_check).to contain_exactly(never, stale)
      expect(Alert.due_for_check).not_to include(fresh)
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:alert_matches).dependent(:destroy) }
    it { is_expected.to have_many(:flight_offers).through(:alert_matches) }
  end
end
```

- [ ] **Step 15.6: Rodar spec — falha**

```bash
bundle exec rspec spec/models/alert_spec.rb
```

- [ ] **Step 15.7: Implementar model**

Criar `app/models/alert.rb`:

```ruby
class Alert < ApplicationRecord
  ORIGIN_TYPES = %w[airport city].freeze
  TRIP_TYPES = %w[one_way round_trip].freeze
  CABIN_CLASSES = %w[economy premium_economy business first].freeze
  MAX_ACTIVE_PER_USER = 10

  enum :origin_type, ORIGIN_TYPES.index_with(&:itself), prefix: :origin
  enum :destination_type, ORIGIN_TYPES.index_with(&:itself), prefix: :destination
  enum :trip_type, TRIP_TYPES.index_with(&:itself)
  enum :cabin_class, CABIN_CLASSES.index_with(&:itself), prefix: :cabin

  belongs_to :user
  has_many :alert_matches, dependent: :destroy
  has_many :flight_offers, through: :alert_matches

  validates :origin_code, :destination_code, presence: true
  validates :departure_date_from, :departure_date_to, presence: true
  validates :passengers, numericality: {greater_than: 0}
  validates :currency, length: {is: 3}
  validate :at_least_one_ceiling
  validate :round_trip_has_return_dates
  validate :departure_range_well_formed
  validate :departure_not_in_past
  validate :respects_active_limit

  scope :active, -> { where(active: true) }
  scope :due_for_check, -> {
    where("last_checked_at IS NULL OR last_checked_at < ?", 2.hours.ago)
  }

  private

  def at_least_one_ceiling
    if max_price_cents.blank? && max_miles.blank?
      errors.add(:base, "defina teto de preço ou milhas")
    end
  end

  def round_trip_has_return_dates
    return unless trip_type == "round_trip"
    if return_date_from.blank? || return_date_to.blank?
      errors.add(:return_date_from, "é obrigatório em round_trip") if return_date_from.blank?
      errors.add(:return_date_to, "é obrigatório em round_trip") if return_date_to.blank?
    end
  end

  def departure_range_well_formed
    return if departure_date_from.blank? || departure_date_to.blank?
    if departure_date_to < departure_date_from
      errors.add(:departure_date_to, "deve ser >= departure_date_from")
    end
  end

  def departure_not_in_past
    return if departure_date_from.blank?
    if departure_date_from < Date.current
      errors.add(:departure_date_from, "não pode ser no passado")
    end
  end

  def respects_active_limit
    return unless active?
    return unless user
    current_active = user.alerts.where(active: true)
    current_active = current_active.where.not(id: id) if persisted?
    if current_active.count >= MAX_ACTIVE_PER_USER
      errors.add(:base, "limite de #{MAX_ACTIVE_PER_USER} alerts ativos atingido")
    end
  end
end
```

- [ ] **Step 15.8: Rodar spec — verde**

```bash
bundle exec rspec spec/models/alert_spec.rb
```

Se algum teste falhar por causa de encoding (ex: "preço" em regex), ajustar a regex no spec.

- [ ] **Step 15.9: Commit**

```bash
git add -A
git commit -m "feat(phase-1): Alert model com validações compostas, enums e limite de 10 ativos"
```

---

### Task 16: Model AlertMatch

**Files:**
- Create: migration, `app/models/alert_match.rb`, `spec/factories/alert_matches.rb`, `spec/models/alert_match_spec.rb`

- [ ] **Step 16.1: Gerar migration**

```bash
bin/rails g migration CreateAlertMatches alert:references flight_offer:references notified_at:datetime
```

- [ ] **Step 16.2: Editar migration (adicionar unique composto)**

Conteúdo completo:

```ruby
class CreateAlertMatches < ActiveRecord::Migration[8.0]
  def change
    create_table :alert_matches do |t|
      t.references :alert, null: false, foreign_key: true
      t.references :flight_offer, null: false, foreign_key: true
      t.datetime :notified_at
      t.timestamps
    end

    add_index :alert_matches, [:alert_id, :flight_offer_id], unique: true, name: "idx_alert_matches_unique"
  end
end
```

- [ ] **Step 16.3: Migrar**

```bash
bin/rails db:migrate
```

- [ ] **Step 16.4: Factory**

Criar `spec/factories/alert_matches.rb`:

```ruby
FactoryBot.define do
  factory :alert_match do
    alert
    flight_offer

    trait :notified do
      notified_at { Time.current }
    end
  end
end
```

- [ ] **Step 16.5: Spec**

Criar `spec/models/alert_match_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe AlertMatch, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:alert) }
    it { is_expected.to belong_to(:flight_offer) }
  end

  describe "validations" do
    it "prevents duplicate alert + flight_offer pair" do
      match = create(:alert_match)
      dupe = build(:alert_match, alert: match.alert, flight_offer: match.flight_offer)
      expect(dupe).not_to be_valid
    end
  end

  describe "scopes" do
    it ".pending returns matches without notified_at" do
      pending = create(:alert_match)
      create(:alert_match, :notified)
      expect(AlertMatch.pending).to contain_exactly(pending)
    end

    it ".notified returns matches with notified_at" do
      notified = create(:alert_match, :notified)
      create(:alert_match)
      expect(AlertMatch.notified).to contain_exactly(notified)
    end
  end
end
```

- [ ] **Step 16.6: Rodar spec — falha**

```bash
bundle exec rspec spec/models/alert_match_spec.rb
```

- [ ] **Step 16.7: Implementar model**

Criar `app/models/alert_match.rb`:

```ruby
class AlertMatch < ApplicationRecord
  belongs_to :alert
  belongs_to :flight_offer

  validates :alert_id, uniqueness: {scope: :flight_offer_id}

  scope :pending, -> { where(notified_at: nil) }
  scope :notified, -> { where.not(notified_at: nil) }

  def notified?
    notified_at.present?
  end
end
```

- [ ] **Step 16.8: Verde**

```bash
bundle exec rspec spec/models/alert_match_spec.rb
```

- [ ] **Step 16.9: Commit**

```bash
git add -A
git commit -m "feat(phase-1): AlertMatch model com unique composto e scopes pending/notified"
```

---

### Task 17: Model ProviderCheck

**Files:**
- Create: migration, `app/models/provider_check.rb`, `spec/factories/provider_checks.rb`, `spec/models/provider_check_spec.rb`

- [ ] **Step 17.1: Gerar migration**

```bash
bin/rails g migration CreateProviderChecks provider:string origin_code:string destination_code:string status:string error_message:text offers_count:integer duration_ms:integer ran_at:datetime
```

- [ ] **Step 17.2: Editar migration**

Conteúdo completo:

```ruby
class CreateProviderChecks < ActiveRecord::Migration[8.0]
  def change
    create_table :provider_checks do |t|
      t.string :provider, null: false
      t.string :origin_code
      t.string :destination_code
      t.string :status, null: false
      t.text :error_message
      t.integer :offers_count, null: false, default: 0
      t.integer :duration_ms
      t.datetime :ran_at, null: false
      t.timestamps
    end

    add_index :provider_checks, [:provider, :ran_at]
    add_index :provider_checks, :status
  end
end
```

- [ ] **Step 17.3: Migrar**

```bash
bin/rails db:migrate
```

- [ ] **Step 17.4: Factory**

Criar `spec/factories/provider_checks.rb`:

```ruby
FactoryBot.define do
  factory :provider_check do
    provider { "duffel" }
    origin_code { "FOR" }
    destination_code { "GRU" }
    status { "success" }
    offers_count { 5 }
    duration_ms { 1234 }
    ran_at { Time.current }

    trait :failed do
      status { "failure" }
      error_message { "Timeout" }
      offers_count { 0 }
    end

    trait :rate_limited do
      status { "rate_limited" }
      offers_count { 0 }
    end
  end
end
```

- [ ] **Step 17.5: Spec**

Criar `spec/models/provider_check_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe ProviderCheck, type: :model do
  describe "validations" do
    it "requires provider" do
      expect(build(:provider_check, provider: nil)).not_to be_valid
    end

    it "requires status" do
      expect(build(:provider_check, status: nil)).not_to be_valid
    end

    it "requires ran_at" do
      expect(build(:provider_check, ran_at: nil)).not_to be_valid
    end
  end

  describe "enums" do
    it "accepts success|failure|rate_limited" do
      expect(build(:provider_check, status: "success")).to be_valid
      expect(build(:provider_check, :failed)).to be_valid
      expect(build(:provider_check, :rate_limited)).to be_valid
    end

    it "rejects invalid status" do
      expect { build(:provider_check, status: "meh") }.to raise_error(ArgumentError)
    end
  end

  describe "scopes" do
    it ".recent orders by ran_at desc" do
      old = create(:provider_check, ran_at: 2.hours.ago)
      new = create(:provider_check, ran_at: 10.minutes.ago)
      expect(ProviderCheck.recent.first).to eq(new)
      expect(ProviderCheck.recent.last).to eq(old)
    end

    it ".for_provider filters by provider" do
      duffel = create(:provider_check, provider: "duffel")
      create(:provider_check, provider: "amadeus")
      expect(ProviderCheck.for_provider("duffel")).to contain_exactly(duffel)
    end

    it ".failed returns non-success" do
      create(:provider_check)
      failed = create(:provider_check, :failed)
      expect(ProviderCheck.failed).to contain_exactly(failed)
    end
  end
end
```

- [ ] **Step 17.6: Rodar spec — falha**

```bash
bundle exec rspec spec/models/provider_check_spec.rb
```

- [ ] **Step 17.7: Implementar model**

Criar `app/models/provider_check.rb`:

```ruby
class ProviderCheck < ApplicationRecord
  STATUSES = %w[success failure rate_limited].freeze

  enum :status, STATUSES.index_with(&:itself), prefix: :status

  validates :provider, presence: true
  validates :status, presence: true
  validates :ran_at, presence: true

  scope :recent, -> { order(ran_at: :desc) }
  scope :for_provider, ->(provider) { where(provider: provider) }
  scope :failed, -> { where.not(status: "success") }
end
```

- [ ] **Step 17.8: Verde**

```bash
bundle exec rspec spec/models/provider_check_spec.rb
```

- [ ] **Step 17.9: Commit**

```bash
git add -A
git commit -m "feat(phase-1): ProviderCheck model com enums de status e scopes recent/failed"
```

---

### Task 18: Smoke test da Fase 1

**Goal:** Garantir que schema, migrations e todos os specs de model passam limpos em banco zerado.

- [ ] **Step 18.1: Drop + recreate dev DB**

```bash
bin/rails db:drop db:create db:migrate
```
Expected: 6 migrations aplicadas sem erros.

> Nunca rodar `db:drop` em produção. Este step só roda em development.

- [ ] **Step 18.2: Rodar toda a suíte**

```bash
bundle exec rspec
```
Expected: todos os specs verdes (pelo menos User, Airport, FlightOffer, Alert, AlertMatch, ProviderCheck). Zero failures.

- [ ] **Step 18.3: Rodar lint**

```bash
bundle exec standardrb
```
Expected: zero offenses (ou rodar `--fix` e re-commitar).

- [ ] **Step 18.4: Verificar schema.rb**

```bash
head -30 db/schema.rb
cat db/schema.rb | grep -c "create_table"
```
Expected: 6 tabelas (users, airports, flight_offers, alerts, alert_matches, provider_checks) + as de Solid trio (solid_queue_*, solid_cache_entries, solid_cable_messages) se moram no mesmo DB. Como configuramos bancos separados, o schema principal deve ter exatamente as 6 tabelas de domínio.

- [ ] **Step 18.5: Tag phase-1-complete**

```bash
git tag phase-1-complete
```

- [ ] **Step 18.6: Rodar encrypted user smoke manual**

```bash
bin/rails runner '
  u = User.create!(email: "test@encrypted.local", password: "secret-123", program_credentials: {smiles: {login: "x"}})
  raw = User.connection.select_value("SELECT program_credentials FROM users WHERE id = #{u.id}")
  puts "PLAINTEXT: #{raw[0..40]}..."
  puts "DECRYPTED: #{u.reload.program_credentials.inspect}"
  u.destroy!
'
```
Expected: linha `PLAINTEXT:` mostra string encrypted (base64 tipo), `DECRYPTED:` mostra `{"smiles"=>{"login"=>"x"}}`.

Fase 1 **completa** quando os 6 steps acima passam.

---

## Resumo final

Ao final destas 18 tasks:

- Projeto Rails 8 bootstrapado, módulo `Flighthunter`, git inicializado.
- Gems de runtime e dev instaladas. RSpec + VCR + WebMock + Standard configurados.
- Solid Queue/Cache/Cable em bancos SQLite separados.
- ActiveRecord::Encryption pronto com chaves em credentials.
- CLAUDE.md do repo apontando pra `CLAUDE.base.md` como autoridade.
- 6 entidades do domínio com migrations, models, validações, enums string-backed, factories e specs verdes.
- `bundle exec rspec` totalmente verde.
- `bundle exec standardrb` sem offenses.

**Próximo passo (fora deste plano):** brainstorming da Fase 2 (Auth + seed + OurAirports importer). Não cobrir aqui.
