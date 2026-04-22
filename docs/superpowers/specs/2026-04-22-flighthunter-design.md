# FlightHunter — Master Design

> Spec master sintetizando `REQUIREMENTS.md` (o quê), `CLAUDE.base.md` (como — arquitetura), `CLAUDE_CODE_GUIDE.md` (roteiro). Data: 2026-04-22.

## 1. Objetivo

Ferramenta pessoal web (single-user) que monitora promoções de passagens — cash via Duffel/Amadeus, award via seats.aero e scrapers BR (Smiles, Latam Pass, TudoAzul) — e dispara alertas por Telegram quando uma oferta bate os critérios salvos.

Sucesso = ≥1 notificação acionável por semana.

## 2. Princípios arquiteturais (autoridade: CLAUDE.base.md)

Family 6 do gradiente "Rails Whey" — naming over structure. Quatro regras não-negociáveis:

1. **Vocabulário unificado entre camadas.** Model, controller, view e rota compartilham namespace. `grep Alert` retorna tudo em uma busca.
2. **Autoridade no model dono do dado.** Predicados, scopes, constantes no model. Controller chama `alert.notifiable?`, nunca `Alert.where(...).exists?`.
3. **Orquestrações nomeadas.** Side-effects multi-step viram POROs em `app/models/<entity>/` (ex: `User::Registration`, `Alert::CheckCycle`). Sem `after_commit` escondido.
4. **Zero route overrides.** Toda rota derivável do recurso. Sem `controller:`, `param:`, `module:` customizados.

**Consequência:** `app/services/`, `app/providers/`, `app/interactors/` **não existem** neste projeto. Toda lógica de domínio — incluindo adapters de API externa, scrapers, matching, notificação — mora em `app/models/<entity>/`.

## 3. Tradução do guia para vocabulário base-conforme

O `CLAUDE_CODE_GUIDE.md` usa `app/services/` e `app/providers/`. Rescrita para alinhar com `CLAUDE.base.md`:

| Guia original | Base-conforme | Justificativa |
|---|---|---|
| `Providers::Duffel` em `app/providers/` | `FlightOffer::Search::Duffel` em `app/models/flight_offer/search/` | Provider é quem busca *FlightOffer*. FlightOffer é o model dono. |
| `Providers::Amadeus` | `FlightOffer::Search::Amadeus` | idem |
| `Providers::SeatsAero` | `FlightOffer::Search::SeatsAero` | idem |
| `Providers::Smiles` | `FlightOffer::Search::Smiles` | idem (Ferrum scraper) |
| `Providers::Base` (interface) | `FlightOffer::Search::Base` | idem |
| `Airports::Autocomplete` service | `Airport::Autocomplete` query object | Query sobre Airports, model dono é Airport. |
| `City::Resolver` service | `City::Resolver` PORO em `app/models/city/` | City é conceito derivado; `City` como PORO namespace. |
| `Alerts::Matcher` service | `Alert::Matcher` em `app/models/alert/` | Regra de matching é invariante do Alert. |
| `Alerts::CheckJob` | `Alert::CheckCycle` (orquestração PORO) + `Alert::CheckCycleJob` (casca ActiveJob) | Orquestração nomeada. Job só enfileira. |
| `Alerts::NotifyJob` | `Alert::Notification` (orquestração) + job casca | idem |
| `TelegramNotifier` service | `Notification::Telegram` em `app/models/notification/` | Notification é o conceito; Telegram é canal. |
| `OurAirports::Importer` | `Airport::Import::OurAirports` | Import é função do Airport. |

Todos os jobs ficam em `app/jobs/` (convenção Rails), mas cada job é **casca fina** que delega a uma orquestração em `app/models/`. Queue names por domínio: `:flight_offers`, `:alerts`, `:notifications`, `:cleanup`.

## 4. Estrutura de pastas final

```
app/
├── controllers/
│   ├── application_controller.rb
│   ├── sessions_controller.rb             # auth single-user
│   ├── searches_controller.rb             # busca ad-hoc (J1)
│   ├── alerts_controller.rb               # CRUD de alertas (J2, J3)
│   ├── offers_controller.rb               # redirect click-out (J4)
│   ├── airports_controller.rb             # autocomplete JSON (J5)
│   └── admin/
│       └── providers_controller.rb        # dashboard F-040
├── models/
│   ├── application_record.rb
│   ├── user.rb
│   ├── user/
│   │   └── registration.rb                # seed do owner
│   ├── airport.rb
│   ├── airport/
│   │   ├── autocomplete.rb                # query object
│   │   └── import/
│   │       └── our_airports.rb            # importer
│   ├── city/
│   │   └── resolver.rb                    # city → [iata]
│   ├── alert.rb
│   ├── alert/
│   │   ├── matcher.rb                     # regras de matching
│   │   ├── check_cycle.rb                 # orquestração 2h
│   │   └── notification.rb                # orquestração envio
│   ├── alert_match.rb
│   ├── flight_offer.rb
│   ├── flight_offer/
│   │   └── search/
│   │       ├── base.rb                    # interface abstrata
│   │       ├── duffel.rb
│   │       ├── amadeus.rb
│   │       ├── seats_aero.rb
│   │       ├── smiles.rb                  # Ferrum
│   │       ├── latam_pass.rb              # P1
│   │       └── tudo_azul.rb               # P2
│   ├── notification/
│   │   └── telegram.rb                    # canal Telegram
│   └── provider_check.rb
├── jobs/
│   ├── application_job.rb
│   ├── flight_offer/
│   │   └── search/                        # um job casca por search
│   │       ├── duffel_job.rb
│   │       ├── amadeus_job.rb
│   │       ├── seats_aero_job.rb
│   │       └── smiles_job.rb
│   ├── alert/
│   │   ├── check_cycle_job.rb             # recurring 2h
│   │   └── notification_job.rb
│   └── cleanup/
│       ├── expired_offers_job.rb
│       └── old_provider_checks_job.rb
├── components/                            # ViewComponent
│   ├── search_form_component.rb
│   ├── search_results_component.rb
│   ├── flight_offer_card_component.rb
│   ├── alert_form_component.rb
│   └── provider_health_component.rb
├── bots/
│   └── telegram_bot.rb                    # long polling runner
└── views/
    ├── sessions/
    ├── searches/
    ├── alerts/
    ├── airports/
    └── admin/providers/
```

## 5. Jornadas mapeadas para artefatos

| Jornada | Controller#action | Model principal | Orquestração |
|---|---|---|---|
| J1 Busca ad-hoc | `SearchesController#create` | `FlightOffer` | `FlightOffer::Search::{Duffel,Amadeus,SeatsAero,Smiles}` (paralelo via jobs) |
| J2 Criar alerta | `AlertsController#create` | `Alert` | — (create simples; validações no model) |
| J3 Gerenciar alertas | `AlertsController#{index,update,destroy}` | `Alert` | — |
| J4 Click-out | `OffersController#redirect` | `FlightOffer` | — |
| J5 Autocomplete origem/destino | `AirportsController#index` | `Airport` | `Airport::Autocomplete` |

## 6. Data model

Entidades, colunas, índices e validações conforme **REQUIREMENTS.md §8**, sem alteração. Recapitulando:

- `User` (1 registro, `email`, `password_digest`, `telegram_chat_id`, `program_credentials` encrypted JSON)
- `Airport` (~80k do OurAirports)
- `Alert` (FK user, janela de datas, teto preço/milhas, `active`)
- `FlightOffer` (provider enum, offer_type enum, FK origin/destination airports, `price_cents` ou `miles`, `deep_link`, `raw_payload`)
- `AlertMatch` (FK alert + flight_offer, unique composto, `notified_at`)
- `ProviderCheck` (log operacional, `status` enum, `duration_ms`, `ran_at`)

Enums sempre com backing **string**, nunca integer. Encryption via `ActiveRecord::Encryption` em `User#program_credentials` (deterministic=false).

## 7. Stack e decisões operacionais (de REQUIREMENTS.md §5–6)

Sem mudanças: Ruby 3.3+, Rails 8+, SQLite WAL, Hotwire + ViewComponent + Tailwind standalone, Solid Queue/Cache/Cable, Ferrum, RSpec + VCR + FactoryBot, Standard (linter), Kamal 2 para Hetzner CX22.

Tudo o que está em REQUIREMENTS.md §5–9 é decidido — não reabrir.

## 8. Decomposição em fases (de CLAUDE_CODE_GUIDE.md §3)

8 fases independentes. Cada fase ganha **spec própria quando chegar a vez dela**. Ordem:

| Fase | Nome | Escopo resumido | Depende de |
|---|---|---|---|
| **0** | **Bootstrap** | `rails new`, gems, ViewComponent, Solid trio, ActiveRecord::Encryption, RSpec, VCR, Standard, CLAUDE.md do repo | — |
| **1** | **Schema & models** | 6 entidades com migrations, models, validações, factories, specs | 0 |
| **2** | **Auth + seed** | Login single-user, OurAirports importer, seed do owner | 1 |
| **3** | **Autocomplete + esqueleto busca (J5, J1-ui)** | `AirportsController`, `Airport::Autocomplete`, Stimulus combobox, `SearchFormComponent`, `SearchesController#{new,create}` retornando vazio | 2 |
| **4** | **Primeiro search adapter — Duffel (J1 completa)** | `FlightOffer::Search::Base`, `FlightOffer::Search::Duffel`, job casca `FlightOffer::Search::DuffelJob` em `app/jobs/flight_offer/search/duffel_job.rb`, Turbo Stream progressive update | 3 |
| **5** | **Demais search adapters** | Amadeus, seats.aero, Smiles (Ferrum). Latam Pass + TudoAzul stubs. | 4 |
| **6** | **Alertas + matching + Telegram (J2, J3)** | CRUD de Alert, `Alert::Matcher`, `Alert::CheckCycle` (recurring 2h), `Notification::Telegram`, `Alert::NotificationJob` | 5 |
| **7** | **Click-out (J4) + bot interativo + cleanup** | `OffersController#redirect`, `app/bots/telegram_bot.rb` com `/start /alerts /pause /resume`, cleanup jobs, dashboard admin | 6 |
| **8** | **Observability, CI, deploy** | Sentry, structured logs, `/health/providers`, GitHub Actions CI, Kamal + Dockerfile com Chromium, HTTPS Let's Encrypt | 7 |

**Critério de pronto de cada fase:** specs passam + acceptance do guia §3 + manual smoke test da jornada tocada.

## 9. Out of scope v1 (REQUIREMENTS.md §1)

Rejeitar sem negociar: checkout no app, signup público, multi-user, hotéis/carros/pacotes, mobile nativo, 3+ stops, cpm comparator, email transacional, afiliados.

## 10. Próximos passos imediatos

1. **Escrever spec da Fase 0 + Fase 1** (sub-specs em `docs/superpowers/specs/2026-04-22-flighthunter-phase-0-bootstrap.md` e `-phase-1-schema.md`).
2. **Executar Fase 0** (bootstrap do Rails 8 project).
3. **Executar Fase 1** (schema + models).
4. **Commit por fase** com prefixo `feat(phase-N): ...`.
5. **Só abrir a spec da Fase 2** quando Fase 1 estiver aceita.

## 11. Risco principal

Conflito `CLAUDE.base.md` vs `CLAUDE_CODE_GUIDE.md` resolvido a favor de base.md (§3 deste doc). Se durante a execução surgir caso onde base.md for excessivamente dogmático (raro, mas possível em scrapers Ferrum que têm pouco a ver com domain modeling), abrir discussão antes de violar — nunca introduzir `app/services/` sem decisão explícita.
