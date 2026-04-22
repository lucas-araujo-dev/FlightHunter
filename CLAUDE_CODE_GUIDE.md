# Claude Code playbook — FlightHunter

Playbook específico para construir este projeto com Claude Code. Toda seção referencia o stack, entidades e serviços decididos em `REQUIREMENTS.md`.

## 0. Prerequisites

**Local machine:**
- Ruby 3.3+ (via `rbenv` ou `asdf`)
- SQLite 3 (já vem no macOS; `apt install sqlite3 libsqlite3-dev` no Linux)
- Chromium ou Google Chrome (para Ferrum nos scrapers)
- Docker (para build do container Kamal)
- Claude Code instalado: veja instruções atuais em https://docs.claude.com/en/docs/claude-code
- Git + acesso a um repo privado (GitHub)

**Contas e chaves (coletar antes de começar):**
- **Duffel:** conta de teste em https://duffel.com → API key (`duffel_test_...`)
- **Amadeus Self-Service:** https://developers.amadeus.com → Client ID + Client Secret
- **seats.aero Partner API:** assinatura Basic (US$10/mês) → Partner API key
- **Telegram Bot:** conversar com @BotFather no Telegram → `/newbot` → guardar token. Depois conversar com @userinfobot pra descobrir seu `chat_id` pessoal
- **Sentry:** projeto Ruby/Rails free → DSN
- **Hetzner Cloud:** conta + projeto criado + SSH key cadastrada
- **Domínio:** (opcional) subdomínio apontando para IP do VPS via A record

**Variáveis e credentials a preencher (após bootstrap):**
```
# config/credentials.yml.enc (Rails encrypted)
duffel_api_key:
amadeus_client_id:
amadeus_client_secret:
seats_aero_api_key:
telegram_bot_token:
telegram_owner_chat_id:
sentry_dsn:
active_record_encryption:
  primary_key:
  deterministic_key:
  key_derivation_salt:

# Kamal secrets (não encriptado, usa .env local + 1Password/similar)
RAILS_MASTER_KEY=
KAMAL_REGISTRY_PASSWORD=  # se usar GitHub Container Registry
OWNER_EMAIL=
OWNER_PASSWORD=           # usado só no primeiro seed
```

## 1. Repository setup

### One-shot bootstrap prompt

Em diretório vazio, rode `claude` e cole:

> "Inicialize um novo projeto Rails 8 chamado `flighthunter` usando `rails new . --database=sqlite3 --css=tailwind --skip-jbuilder --skip-docker`. Depois:
> 1. Adicione ao Gemfile: `view_component`, `rspec-rails`, `factory_bot_rails`, `faker`, `vcr`, `webmock`, `ferrum`, `nokogiri`, `httparty`, `telegram-bot-ruby`, `sentry-ruby`, `sentry-rails`, `kamal` (já vem em Rails 8), `solid_queue` e `solid_cache` e `solid_cable` (já vêm em Rails 8 — confirmar), `csv`, `standard` (linter). Rode `bundle install`.
> 2. Remova Minitest e rode `rails generate rspec:install`. Configure `spec/rails_helper.rb` para VCR com cassette path `spec/cassettes` e filtro de sensitive data (API keys viram `<FILTERED>`).
> 3. Configure ViewComponent com preview em `spec/components/previews`.
> 4. Instale Tailwind standalone via `rails tailwindcss:install` (deve já ter sido feito pelo `--css=tailwind`).
> 5. Configure Solid Queue, Solid Cache e Solid Cable como adapters (em `config/cable.yml`, `config/queue.yml`, `config/cache.yml`). Banco `queue` e `cache` em SQLite separados (`storage/queue.sqlite3`, `storage/cache.sqlite3`), não no mesmo arquivo do app.
> 6. Configure `ActiveRecord::Encryption` — gere chaves via `rails db:encryption:init` e salve em credentials.
> 7. Crie um `CLAUDE.md` na raiz com o conteúdo exato da seção 'Proposed CLAUDE.md' deste guia.
> 8. Crie `.rubocop.yml` estendendo `standard`. Commit inicial com mensagem 'chore: bootstrap Rails 8 + Hotwire + ViewComponent skeleton'."

Revise o diff antes de aceitar. Não rode migrations ainda — isso fica pra Fase 1.

### Proposed `CLAUDE.md` for the repo

Salve como `/CLAUDE.md`:

```markdown
# FlightHunter — conventions for Claude Code

Ferramenta pessoal (single-user) em Rails 8 + Hotwire que busca promoções de passagens (cash) e disponibilidade award de qualquer origem, com alertas automáticos via Telegram.

## Stack
- Ruby 3.3+, Rails 8+, SQLite (WAL), Hotwire (Turbo + Stimulus), ViewComponent, Tailwind standalone
- Solid Queue (jobs), Solid Cache (cache 30min), Solid Cable (Turbo Streams)
- Ferrum (Chrome headless) para scrapers, HTTParty para APIs REST
- RSpec + factory_bot + VCR; Standard para lint
- Deploy via Kamal 2 para Hetzner VPS

## Commands
- `bin/dev` — roda Rails server + worker Solid Queue + tailwindcss watch + Telegram bot worker (Procfile.dev)
- `bin/rails s` — só server
- `bin/rails test:prepare && bundle exec rspec` — specs
- `bundle exec standardrb --fix` — lint autofix
- `bin/rails db:migrate` — migrations
- `bin/rails db:seed` — seed (OurAirports + owner user)
- `bin/kamal deploy` — deploy a partir da local

## Directory layout
- `app/providers/` — Provider pattern. Cada adapter (DuffelProvider, SmilesProvider, etc.) implementa `#search(origin_code, destination_code, date_range, **opts)` retornando `[FlightOffer, ...]` não-persistidos.
- `app/providers/base.rb` — interface abstrata.
- `app/jobs/providers/` — um job por provider (`Providers::DuffelSearchJob`, etc.) que chama o provider, persiste `FlightOffer`s, cria `AlertMatch`es.
- `app/jobs/alerts/` — `Alerts::CheckJob` (orquestrador a cada 2h), `Alerts::NotifyJob` (envia ao Telegram).
- `app/components/` — ViewComponent (cards de oferta, forms, etc.). Cada componente tem preview em `spec/components/previews/`.
- `app/services/` — lógica de domínio sem estado HTTP (matching, parsing, cidade→aeroportos).
- `app/models/concerns/` — mixins reusáveis.
- `app/bots/telegram_bot.rb` — runner do bot (executado como processo separado).
- `config/initializers/providers.rb` — registro de providers ativos.

## Conventions
- **Always** add a spec for new code. No code without a corresponding RSpec file.
- **Provider adapters** must NEVER hit the network in tests. Use VCR with a fresh cassette per test.
- **Jobs** use `ActiveJob::Base` via Solid Queue. Queue name per domain: `:providers`, `:alerts`, `:notifications`, `:cleanup`.
- **No instance variables in components** — pass everything via `initialize`. Follow ViewComponent best practices.
- **Typed enums** via Rails `enum:` with string backing (never integer — hard to debug).
- **Time:** always `Time.zone.now`, never `Time.now` or `DateTime.now`. App TZ = `America/Fortaleza`.
- **Money:** `price_cents` (integer) sempre; formatar na view layer. Nunca float pra dinheiro.
- **Feature flags:** inexistentes no v1. Se precisar, usar `Rails.configuration` + credentials.

## Testing expectations
- Model specs: validations, associations, scopes.
- Service specs: lógica pura, sem DB quando possível.
- Provider specs: VCR cassette + WebMock pra stubs que precisam variar.
- Component specs: via `ViewComponent::TestHelpers`, renderizam e verificam HTML.
- Request specs: happy path por journey (J1, J2, J3, J4, J5).
- Job specs: testam que enfileiram corretamente e que execução chama o provider esperado (mocked).
- Cobertura alvo: 80%+ nas camadas `app/services`, `app/providers`, `app/jobs`.

## Adding a new provider
1. Create `app/providers/<name>_provider.rb` inheriting from `Providers::Base`. Implement `#search`.
2. Create `app/jobs/providers/<name>_search_job.rb` enfileirando na queue `:providers`.
3. Register in `config/initializers/providers.rb`.
4. Add VCR cassette in `spec/cassettes/providers/<name>/`.
5. Write provider spec + job spec.
6. Document credential requirements in this CLAUDE.md if new keys needed.

## Adding a new entity
1. Migration with proper indexes (see REQUIREMENTS.md §8).
2. Model with validations, associations, enums.
3. Factory in `spec/factories/`.
4. Model spec.
5. If user-facing: ViewComponent + Turbo Frame wrapper + request spec.

## Services this project talks to
- Duffel, Amadeus, seats.aero, Telegram Bot API, Sentry. Clients in `app/providers/` (external data) or `app/services/` (integrations like Telegram).

## Things Claude Code should NOT do without asking
- Never run `db:reset` or `db:drop` in any environment.
- Never add a new gem without flagging first and justifying (every gem is a supply-chain risk in scraping territory).
- Never commit credentials or `.env` files. Never `puts` API keys, even in debug.
- Never make network calls in specs — if VCR doesn't have a cassette, stop and ask.
- Never push directly to `main` — always branch + PR flow (or at minimum, branch locally).
- Never alter the Solid Queue schema files by hand (they come from Rails 8 installers).
- Never hardcode airline codes or cabin class strings — use the enums defined on the model.
```

## 2. Suggested MCP servers

Liste apenas os que agregam valor real neste projeto.

| Service in this project | MCP server | What it enables |
|-------------------------|------------|-----------------|
| SQLite local DB | `sqlite` MCP | Inspecionar schema, rodar queries ad-hoc durante dev, validar seeds |
| Sentry | `sentry` MCP oficial | Puxar exceptions recentes direto pro contexto do Claude na hora de debugar |
| GitHub | `github` MCP | Criar PRs, ler issues, ver CI status sem sair da sessão |
| Filesystem | (nativo) | Navegar repositório |

Amadeus, Duffel, seats.aero e Telegram **não têm MCP servers oficiais** — integração é via gems/HTTP direto. Não procure; é mais rápido implementar o adapter.

Install/config: verifique `https://docs.claude.com/en/docs/claude-code/mcp` — os comandos específicos mudam com frequência.

## 3. Build sequence — uma sessão Claude Code por fase

Oito fases. Mantenha cada uma focada; não misture.

### Phase 1: Schema & migrations

**Goal:** Traduzir `REQUIREMENTS.md §8` em migrations e models com associações/validações/enums.

**Kickoff prompt:**
> "Leia `REQUIREMENTS.md` §8. Gere migrations Rails para as 6 entidades: `User`, `Airport`, `Alert`, `FlightOffer`, `AlertMatch`, `ProviderCheck`. Respeite todos os índices, foreign keys, tipos (enums como string) e defaults. Crie os models correspondentes em `app/models/` com associações, validações (incluindo a regra 'pelo menos max_price_cents OU max_miles', validação round-trip exige datas de volta, e User tem ≤10 alerts ativos), enums e scopes úteis (`Alert.active`, `Alert.due_for_check`, `FlightOffer.expired`, `FlightOffer.by_route`). Configure `ActiveRecord::Encryption` em `User.program_credentials` (encrypts :program_credentials). Crie factories correspondentes em `spec/factories/`. Escreva model specs cobrindo validations, associations e scopes. Rode `bin/rails db:migrate` e `bundle exec rspec spec/models/` — tudo deve passar."

**Acceptance:**
- `db:migrate` aplica limpo em banco zerado.
- Todos os model specs passam.
- `User.new(program_credentials: {smiles: {login: 'x'}})` persiste encrypted (verificar no console).

### Phase 2: Auth, owner seed & OurAirports import

**Goal:** Single-user auth funcionando e dataset de aeroportos carregado.

**Kickoff prompt:**
> "Implemente auth single-user com `has_secure_password`. Controllers: `SessionsController` (new/create/destroy). Views simples com Tailwind. Layout com navbar mostrando email do owner + logout. Um `before_action :require_owner!` em `ApplicationController` que redireciona para login se não houver user na sessão. **Sem signup público** — o único user vem do seed.
>
> Crie `lib/our_airports/importer.rb` que baixa `https://davidmegginson.github.io/ourairports-data/airports.csv` (use `URI.open` + `CSV`), mapeia para o schema de `Airport` (ignora heliportos e closed airports filtrando pela coluna `type`), faz `upsert_all` em batches de 1000. Idempotente.
>
> Atualize `db/seeds.rb` para: (1) rodar `OurAirports::Importer.call` se `Airport.count.zero?`, (2) criar o owner User a partir de `ENV['OWNER_EMAIL']` e `ENV['OWNER_PASSWORD']` se `User.count.zero?`.
>
> Specs: request spec do login, spec do importer usando VCR pra stubar o CSV download com fixture reduzida (50 linhas)."

**Acceptance:**
- `OWNER_EMAIL=x@y.com OWNER_PASSWORD=test123 bin/rails db:seed` popula ~80k airports e 1 user.
- Login funciona; `/` redireciona para `/login` se deslogado.
- Specs passam.

### Phase 3: Autocomplete de origem/destino (J5) + Busca ad-hoc esqueleto (J1)

**Goal:** Formulário de busca funcional sem providers ainda — só UI + resolução de origem/destino.

**Kickoff prompt:**
> "Crie `SearchesController#new` (form) e `#create` (executa busca; por enquanto retorna lista vazia). Form usa Turbo Frame.
>
> Autocomplete: endpoint `GET /airports/search?q=...` retorna JSON com airports + cidades agregadas (top 10 resultados combinando match em `iata_code`, `name`, `city`). Use `Airports::Autocomplete` service em `app/services/`. Cidades agregadas = cidades onde `Airport.where(city: x).count >= 2` e appearem como um único resultado 'São Paulo (3 airports)'.
>
> Frontend: Stimulus controller `airport-combobox` que consulta o endpoint em cada keystroke (debounced 150ms), mostra dropdown, submete tanto `origin_type` (airport/city) quanto `origin_code` via hidden inputs.
>
> ViewComponent: `SearchFormComponent` renderiza o form completo (origin, destination, trip_type, dates, cabin, pax). Preview em `spec/components/previews/search_form_component_preview.rb` com variantes (one-way, round-trip, pré-preenchido).
>
> Specs: service spec pra autocomplete (inclui fuzzy 'são' → SP), component spec pra SearchForm, request spec pro endpoint de autocomplete."

**Acceptance:**
- Digitar 'for' na home mostra Fortaleza. Digitar 'são p' mostra 'São Paulo (3 airports)'.
- Submeter form cria request com params válidos.

### Phase 4: Provider pattern + primeiro provider (Duffel)

**Goal:** Fundação do sistema de providers, primeiro adapter (Duffel) end-to-end.

**Kickoff prompt:**
> "Crie `app/providers/base.rb` com `Providers::Base`: método abstrato `#search(origin:, destination:, departure_range:, return_range: nil, cabin: :economy, passengers: 1)` retornando `Array<FlightOffer>` (não persistidos). Incluir `City::Resolver` service que converte `origin_type=city, origin_code='São Paulo'` em `[iata_codes]` (chamando `Airport.where(city: ..., country: 'BR').pluck(:iata_code)`).
>
> Implemente `Providers::Duffel` usando HTTParty. Fluxo Duffel: POST `/air/offer_requests` com slices → retorna `id` → GET `/air/offers?offer_request_id=...`. Mapeia cada offer Duffel pra `FlightOffer` com `provider: :duffel`, `offer_type: :cash`, `price_cents`, `currency`, flight numbers e stops extraídos.
>
> Crie `Providers::DuffelSearchJob` (queue `:providers`) que chama o provider e `upsert_all` as offers (dedupe por `provider + deep_link + departure_at`).
>
> No `SearchesController#create`, enfileira `Providers::DuffelSearchJob.perform_later(search_params)` e responde com Turbo Stream renderizando um `SearchResultsComponent` em estado 'loading'. Quando o job termina, broadcast via Solid Cable/Turbo Streams pra atualizar os resultados.
>
> Gravar cassette VCR pra request de teste Duffel (FOR→GRU, próxima semana). Spec do provider replaya cassette e valida parsing."

**Acceptance:**
- Busca FOR→GRU retorna ao menos 1 oferta Duffel real em dev.
- Spec do provider passa usando só cassette.
- Turbo Stream atualiza progressivamente.

### Phase 5: Demais providers (Amadeus + seats.aero + scrapers BR)

**Goal:** Cobertura completa.

**Kickoff prompt:**
> "Seguindo o padrão de `Providers::Duffel` (Phase 4), implemente:
>
> 1. `Providers::Amadeus` — OAuth2 client credentials (cachear token 25min em Solid Cache), `GET /v2/shopping/flight-offers`. Fallback: só chamar se Duffel retornou 0 ofertas pra rota ou falhou.
>
> 2. `Providers::SeatsAero` — `GET /partnerapi/search` com `origin_airport`, `destination_airport`, `start_date`, `end_date`, `cabin`. Parsear cada programa (United, Aeroplan, etc) como `FlightOffer` `offer_type: :award`.
>
> 3. `Providers::Smiles` — Ferrum. Navegar https://www.smiles.com.br/emissao-passagem, preencher form, esperar resultados renderizarem, extrair DOM. Assumir busca anônima (sem login) inicialmente; se Smiles exigir login, usar `User.program_credentials['smiles']`. Timeout 60s, retry 2x, falhas gravadas em `ProviderCheck`.
>
> Cada provider tem seu próprio Job. `SearchesController#create` enfileira todos aplicáveis em paralelo.
>
> Deixe Latam Pass e TudoAzul stubbed (`raise NotImplementedError`) pra uma fase futura. Registre TODOs claros.
>
> VCR cassettes para Amadeus e seats.aero. Smiles: salve HTML de exemplo em `spec/fixtures/smiles/search_result.html` e stube Ferrum visitando um `data:` URL com esse HTML."

**Acceptance:**
- Busca real dispara todos os providers implementados em paralelo.
- Falha em um provider não quebra os outros.
- `ProviderCheck` registra cada execução.

### Phase 6: Alertas (CRUD + scheduler + matching + Telegram)

**Goal:** Jornadas J2, J3 completas + notificações.

**Kickoff prompt:**
> "Implemente CRUD de Alert em `AlertsController` (index, new, create, edit, update, destroy) com Turbo Frames pra edição inline e Turbo Streams pra toggle active/paused. Limite de 10 ativos validado no model + UI. `AlertFormComponent` reutiliza campos de `SearchFormComponent` e adiciona max_price / max_miles.
>
> Crie `Alerts::CheckJob` (queue `:alerts`) que roda a cada 2h via Solid Queue recurring jobs (configurar em `config/recurring.yml`): itera `Alert.active.due_for_check` (last_checked_at IS NULL OR < 2h atrás) e enfileira `Providers::*SearchJob` para cada alerta, depois chama `Alerts::MatcherJob` pra ver quais FlightOffers batem os critérios.
>
> `Alerts::Matcher` service: dado um Alert, busca FlightOffers criadas na última 1h que batem rota + datas + (price_cents ≤ max_price_cents OU miles ≤ max_miles), cria AlertMatch (insert_all com `on_duplicate: :skip` via unique index). Retorna AlertMatches novos.
>
> `Alerts::NotifyJob` (queue `:notifications`): para cada AlertMatch sem `notified_at`, envia mensagem Telegram formatada (Markdown: origem→destino, data, preço/milhas, companhia, link direto via `/offers/:id/redirect`). Atualiza `notified_at`.
>
> `TelegramNotifier` service encapsula `Telegram::Bot::Api.new(token).send_message(...)`. Chat_id vem de `credentials.telegram_owner_chat_id`.
>
> Specs: AlertsController requests, Matcher com vários cenários (match preço, match milhas, round-trip match, data fora da janela), Notifier com stubbed Telegram API."

**Acceptance:**
- Criar alerta → esperar 2min (ajustar schedule temporariamente pra dev) → ver execução nos logs.
- Telegram recebe mensagem quando há match.
- Reexecução não dispara notificação duplicada.

### Phase 7: Click-out (J4) + Bot Telegram interativo + Cleanup jobs

**Goal:** Fechar as jornadas restantes e adicionar limpeza de dados.

**Kickoff prompt:**
> "1. Rota `GET /offers/:id/redirect` em `OffersController#redirect`: registra um clique (opcional: nova tabela `OfferClick` ou só log), faz `redirect_to offer.deep_link, status: 302, allow_other_host: true`.
>
> 2. Bot Telegram runner em `app/bots/telegram_bot.rb` como processo separado (comando `bin/telegram_bot`). Usa `Telegram::Bot::Client.run` com long polling. Comandos: `/start` (registra o chat_id em `User.telegram_chat_id` se vazio), `/alerts` (lista alertas ativos), `/pause <id>`, `/resume <id>`. Valida que o `from.id` é o owner comparando com `credentials.telegram_owner_chat_id`.
>
> Adicionar ao Procfile.dev e Procfile (prod).
>
> 3. `Cleanup::ExpiredOffersJob` (recurring diário 3h AM): deleta `FlightOffer.where('expires_at < ?', 30.days.ago)`. `Cleanup::OldProviderChecksJob`: deleta `ProviderCheck.where('ran_at < ?', 90.days.ago)`.
>
> 4. Dashboard admin `/admin` (mesma auth do owner): tabela com providers, últimos 10 checks cada, status, counts agregados das últimas 24h. Usa `ProviderHealthComponent`."

**Acceptance:**
- Clicar numa oferta redireciona corretamente.
- Mandar `/alerts` no Telegram retorna a lista.
- Jobs de cleanup rodam e reduzem contagem esperada.

### Phase 8: Observability, CI e Deploy (Kamal → Hetzner)

**Goal:** Produção.

**Kickoff prompt:**
> "1. **Sentry:** instale e configure `sentry-ruby`/`sentry-rails` com DSN em credentials. `config.traces_sample_rate = 0.1`. Contexto extra em jobs (job class, args parciais — sem PII). Specs: não gerar eventos reais (usar `before_send` retornando nil em test).
>
> 2. **Structured logging:** `config.log_tags = [:request_id]`. Lograge opcional — se preferir, usar logs padrão Rails 8.
>
> 3. **Health check:** `GET /up` já vem em Rails 8, ok. Adicionar `GET /health/providers` que retorna JSON com status agregado dos últimos ProviderChecks.
>
> 4. **CI (GitHub Actions):** workflow `.github/workflows/ci.yml` rodando em push/PR: checkout, ruby setup 3.3, bundle cache, `bundle exec standardrb`, `bin/rails db:test:prepare`, `bundle exec rspec`. Chromium instalado via action pra tests que usam Ferrum.
>
> 5. **Kamal:** `config/deploy.yml` apontando pra Hetzner (1 servidor, 1 service). Dockerfile (Rails 8 já gera um ok — ajustar pra instalar Chromium). Volume persistente `/var/lib/flighthunter/db` pra SQLite. Configurar `kamal-proxy` pra HTTPS com Let's Encrypt. Secrets via `.kamal/secrets`.
>
> 6. **Primeiro deploy:** `kamal setup` (provisiona), `kamal deploy`. No primeiro boot, rodar `kamal app exec --interactive 'bin/rails db:prepare db:seed'` com OWNER_EMAIL/OWNER_PASSWORD nas envs.
>
> 7. Document rollback em README: `kamal rollback <version>`."

**Acceptance:**
- CI verde em PR.
- App acessível em HTTPS no domínio.
- Dados persistem entre deploys.
- Sentry recebe evento de teste (disparar `raise` numa rota temporária).

## 4. Session hygiene tips

- **Uma fase = uma sessão.** Se a conversa começa a vazar pra outra fase, encerre e abra nova.
- **Atualize CLAUDE.md** após cada fase com convenções que emergiram (ex: "a partir da fase 5, todo Provider tem um helper `City::Resolver.expand(origin)` chamado no início de `#search`").
- **Commits por fase** com prefixo tipo `feat(phase-4): duffel provider + search pipeline`. Isso mapeia histórico de commits ao playbook.
- **Destrutivo = plan-then-confirm.** `db:rollback`, `destroy`, qualquer `kamal` contra produção: peça a Claude Code pra mostrar o plano antes e só execute com seu "go".
- **VCR hygiene:** se um spec falhar por cassette desatualizado, entenda por quê antes de regravar. Regravação cega mascara mudanças de API.
- **Ferrum/Chrome:** em CI, use headless=new flag. Em dev, deixe visível ocasionalmente pra inspecionar scraping (`Ferrum::Browser.new(headless: false)`).

## 5. Out of this guide

Estes itens NÃO estão no escopo do v1 (ver `REQUIREMENTS.md §1 Out of scope`) e devem ser recusados se uma sessão começar a puxar pra eles:

- Checkout ou compra dentro do app
- Signup público, multi-usuário, roles
- Hotéis, carros, pacotes, seguro
- App mobile nativo
- Email transacional (Resend/Postmark/SMTP)
- Rotas com 3+ stops por perna
- Comparador cpm entre programas
- Integração com afiliados / rewriting de links
- Litestream / backup automatizado (deferred)

## 6. Next steps após v1 shipped

Ordem aproximada pós-v1, sem promessa:

1. **TudoAzul scraper** (P2 no v1) — Cloudflare, pode precisar de FlareSolverr ou similar.
2. **Latam Pass scraper** se ainda não entrou.
3. **Histórico e tendências**: gráfico Chart.js mostrando preço médio FOR→DESTINO nos últimos 90 dias, destacando ofertas atuais contra baseline.
4. **Múltiplos destinos por alerta** (hoje 1:1; aumentar pra "qualquer destino na Europa abaixo de 60k milhas").
5. **Litestream** pra backup automatizado S3/B2.
6. **Webhook Telegram** em vez de long polling (economia CPU, exige HTTPS — já teremos).
7. **Busca por flexibilidade de datas ±3 dias** em vez de janela fixa.
8. **iCal feed** de alertas disparados (calendário pessoal).
9. **PWA** com Web Push como canal adicional.
10. **Raspar tarifas de primeira classe / exec** com lógica específica de matching (alertas de mile runs).
