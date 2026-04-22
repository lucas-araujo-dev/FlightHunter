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
