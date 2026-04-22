# CLAUDE.md — Rails Architecture Base

Base de regras arquiteturais para agentes de IA em projetos Rails. Destilado das 4 mudanças de maior alavancagem do gradiente Rails Whey (branches 3F, 5C, 5D, 6E, 6G).

> **Tese:** naming > estrutura física. O custo de mudança cai quando toda pergunta tem **um único endereço** e o primeiro chute do agente acerta o arquivo certo.

---

## Princípios fundamentais

1. **Stay on the Rails.** Use apenas primitivas Rails: controllers, models, concerns, callbacks, `Current`, scopes, `has_secure_password`, `generates_token_for`, `before_action`, `respond_to`. **Sem service objects, sem interactors, sem hexagonal, sem ports/adapters, sem `app/services/`, sem `app/interactors/`.** Toda lógica de domínio vive em `app/models/`.
2. **Progressive disclosure.** Cada arquivo deve caber na janela de contexto do agente sozinho. Um arquivo, um conceito. Se o agente precisa carregar 3 arquivos para entender 1, a extração está errada.
3. **1 grep = todas as camadas.** Se buscar `Task::List` não encontra model + controller + view + rota no mesmo resultado, a vocabulary não está unificada.
4. **O código É a documentação.** Nomes descritivos substituem comentários. Se precisar de comentário, o nome está errado.

---

## Regras de arquitetura (as 4 de maior alavancagem)

### 1. Unificar vocabulário entre camadas (padrão 5C)

Model, controller, view e rota compartilham **o mesmo namespace**. Path do arquivo é derivável do nome da classe.

```
Task::List                      # model
└── app/models/task/list.rb

Task::ListsController           # controller
└── app/controllers/task/lists_controller.rb

app/views/task/lists/           # views
config/routes.rb                # namespace :task { resources :lists }
```

**❌ Errado:** `TaskList` (flat) + `Task::ListsController` (namespaced) — força duas buscas separadas.
**✅ Certo:** `Task::List` em todos os lugares — uma única busca resolve.

### 2. Declarar autoridade no model dono dos dados (padrão 5D + 6E)

Toda pergunta sobre um dado tem **um único endereço**: o model que possui o dado.

- Predicados, scopes, constantes, enums: no model.
- Nunca faça `user.accounts.where(memberships: { role: ... })` do controller — chame `account.owner_or_admin?(user)`.
- Cada model declara suas próprias `ROLES`, `ACTIONS`, `STATUSES` como constantes nomeadas.

```ruby
# ✅ Autoridade declarada
class Account < ApplicationRecord
  ROLES = %w[owner admin collaborator].freeze

  def owner_or_admin?(user)
    memberships.where(user: user, role: %w[owner admin]).exists?
  end
end

# Controller chama: account.owner_or_admin?(current_user)
```

### 3. Nomear orquestrações explicitamente (padrão 6G)

Callbacks escondem comportamento. Extraia workflows multi-step para POROs nomeados dentro de `app/models/<entity>/`.

```
app/models/user/registration.rb           # User::Registration
app/models/account/invitation/lifecycle.rb  # Account::Invitation::Lifecycle
app/models/task/list/transfer/facilitation.rb
```

```ruby
# ❌ Escondido em callback
class User < ApplicationRecord
  after_create_commit :send_welcome_email, :provision_account
end

# ✅ Orquestração explícita
class User::Registration
  def create(params)
    ActiveRecord::Base.transaction do
      user = User.create!(params)
      Account.create!(owner: user)
      UserMailer.welcome(user).deliver_later
      user
    end
  end
end

# Controller: User::Registration.new.create(params)
```

**Regra:** se mais de 1 efeito colateral acontece num `save`, extraia uma orquestração.

### 4. Eliminar route overrides (padrão 3F)

Toda rota deve ser derivável do nome do recurso. Zero `controller:`, zero `param:`, zero `module:` customizados.

```ruby
# ❌ Override — quebra primeiro-chute do agente
resources :invitations, controller: 'account/invitations_controller', only: [:index]

# ✅ Split por audiência
namespace :account do
  resources :invitations, only: [:index, :create]   # autenticado
end
resources :acceptances, only: [:show, :update]      # público
```

**Regra:** se um controller serve dois públicos (autenticado + público), **divida em dois controllers** — não use `skip_before_action`.

---

## Estrutura de pastas (vocabulary unificada)

```
app/
├── controllers/
│   ├── application_controller.rb
│   ├── web/                          # se houver separação web/api (Family 4)
│   │   └── task/
│   │       ├── base_controller.rb
│   │       ├── lists_controller.rb
│   │       └── items_controller.rb
│   └── api/v1/
│       └── task/
│           └── lists_controller.rb
├── models/                           # TUDO de domínio vive aqui
│   ├── application_record.rb
│   ├── account.rb
│   ├── account/
│   │   ├── invitation.rb
│   │   ├── invitation/lifecycle.rb   # orquestração (PORO)
│   │   ├── member.rb                 # value object (PORO)
│   │   └── search.rb                 # query object (PORO)
│   ├── task/
│   │   ├── list.rb
│   │   ├── list/stats.rb             # query object
│   │   └── item.rb
│   └── user/
│       ├── registration.rb           # orquestração
│       └── token/secret.rb           # crypto PORO
└── views/
    └── task/lists/                   # mesmo namespace dos controllers
```

**Regra de ouro:** `app/services/` não existe. POROs de domínio moram em `app/models/<entity>/`.

---

## Controllers (thin HTTP adapters)

- **5–7 linhas por action.** Só traduz HTTP ↔ domínio.
- **Apenas as 7 verbs REST.** Nada de `complete`, `my_tasks`, `mark_all_read` — se não cabe nas 7, o recurso está errado (extraia um `CompleteTaskItemsController`).
- `before_action` só para auth/authz.
- Não consulte Active Record diretamente — chame o model.

```ruby
class Task::ListsController < ApplicationController
  def create
    @list = current_account.task_lists.create(list_params)
    respond_with @list
  end
end
```

---

## Models (rich domain entities)

- Nomes de método **expressam o domínio**: `order.ship`, não `order.update(status: 'shipped')`.
- Predicados terminam em `?`, operações perigosas em `!`.
- Validações expressam invariantes do domínio.
- Sem callbacks além de setagem de valores derivados (`before_validation :normalize_email`). Efeitos colaterais em orquestrações nomeadas.

---

## Query objects (quando extrair)

Quando uma computação sobre Active Record cresce mais que 10 linhas no model, extraia para `app/models/<entity>/<query>.rb` com `Data.define` para contrato de retorno.

```ruby
class Task::List::Stats
  Result = Data.define(:total, :completed, :progress)

  def initialize(list)
    @list = list
  end

  def call
    total = @list.items.count
    completed = @list.items.completed.count
    Result.new(total:, completed:, progress: completed.fdiv(total))
  end
end

# Model: def stats = Task::List::Stats.new(self).call
```

---

## Testes — teste comportamento, não estrutura

- **Apenas integration tests.** Sem controller tests. Model tests = stubs vazios.
- Tests exercitam HTTP: status codes, redirects, flash, JSON envelope.
- **Route abstraction layer:** tests nunca chamam `session_users_url` direto — usam aliases semânticos (`user__sessions_url`) via `WebAdapter` / `APIV1Adapter` em `test/test_helper.rb`.
- API envelope estrito: `{ status, type, data }`.

---

## Style Guide

## Code style

- Functions: 4-20 lines. Split if longer.
- Files: under 500 lines. Split by responsibility.
- One thing per function, one responsibility per module (SRP).
- Names: specific and unique. Avoid `data`, `handler`, `Manager`.
  Prefer names that return <5 grep hits in the codebase.
- Types: explicit. No `any`, no `Dict`, no untyped functions.
- No code duplication. Extract shared logic into a function/module.
- Early returns over nested ifs. Max 2 levels of indentation.
- Exception messages must include the offending value and expected shape.

## Comments

- Keep your own comments. Don't strip them on refactor — they carry
  intent and provenance.
- Write WHY, not WHAT. Skip `// increment counter` above `i++`.
- Docstrings on public functions: intent + one usage example.
- Reference issue numbers / commit SHAs when a line exists because
  of a specific bug or upstream constraint.

## Tests

- Tests run with a single command: `<project-specific>`.
- Every new function gets a test. Bug fixes get a regression test.
- Mock external I/O (API, DB, filesystem) with named fake classes,
  not inline stubs.
- Tests must be F.I.R.S.T: fast, independent, repeatable,
  self-validating, timely.

## Dependencies

- Inject dependencies through constructor/parameter, not global/import.
- Wrap third-party libs behind a thin interface owned by this project.

## Structure

- Follow the framework's convention (Rails, Django, Next.js, etc.).
- Prefer small focused modules over god files.
- Predictable paths: controller/model/view, src/lib/test, etc.

## Formatting

- Use the language default formatter (`cargo fmt`, `gofmt`, `prettier`,
  `black`, `rubocop -A`). Don't discuss style beyond that.

## Logging

- Structured JSON when logging for debugging / observability.
- Plain text only for user-facing CLI output.


## Naming conventions

| Tipo | Regra | Exemplo |
|------|-------|---------|
| Model | singular, PascalCase, namespaced | `Task::List` |
| Controller | plural + `Controller`, mesmo namespace do model | `Task::ListsController` |
| View path | espelha controller | `app/views/task/lists/` |
| Query object | substantivo específico | `Task::List::Stats` |
| Orquestração | substantivo de workflow | `User::Registration`, `Account::Invitation::Lifecycle` |
| Predicado | termina em `?` | `owner_or_admin?` |
| Operação perigosa | termina em `!` | `deactivate!` |

---

## Checklist do agente antes de abrir um PR

- [ ] O arquivo novo pode ser entendido sem abrir nenhum outro? (isolation 5/5)
- [ ] `grep <NomeDoConceito>` retorna **todas** as camadas em uma busca?
- [ ] A rota é derivável do recurso sem olhar `routes.rb`? (zero overrides)
- [ ] Todo side-effect está em orquestração nomeada — não em callback escondido?
- [ ] Toda query sobre um dado está no model dono do dado?
- [ ] O controller tem ≤ 7 linhas por action e só usa REST verbs?
- [ ] Nenhum arquivo em `app/services/`, `app/interactors/`, `app/operations/`?

---

## Quando quebrar essas regras

Se o codebase crescer a ponto de precisar de **deploys independentes** ou **isolamento de banco por contexto**, siga o Family 7 do gradiente (engines + domain databases) — mas documente explicitamente em uma seção "Bounded Contexts" deste arquivo o mapeamento route → model e as regras de placement. Para qualquer codebase abaixo desse porte, **Family 6 é o sweet spot**.
