# Fase 00 — Visão Geral, Arquitetura e Stack do Frontend

> **Objetivo desta fase:** Entender a solução frontend como um todo antes de escrever qualquer linha de código. Aqui você vai conhecer o ecossistema React, as tecnologias escolhidas e por quê, a estrutura de pastas e como o frontend se conecta ao backend FoodHub.

---

## 1. O FoodHub — Perspectiva do Frontend

O frontend do FoodHub é uma **SPA (Single Page Application)** que consome a API REST do backend Java Spring Boot. O usuário interage com o sistema através dessa interface:

| Funcionalidade | Backend (já definido) | Frontend (o que vamos construir) |
|---|---|---|
| **Fazer pedido** | `POST /api/orders` | Formulário com seleção de restaurante, itens, quantidades |
| **Listar pedidos** | `GET /api/orders?page=0&size=10` | Tabela paginada com filtros e status |
| **Ver detalhes** | `GET /api/orders/{id}` | Página de detalhes com timeline de status |
| **Atualizar status** | `PATCH /api/orders/{id}/status` | Botões de ação com confirmação |
| **Login/Autenticação** | `POST /api/auth/token` | Tela de login com JWT |
| **Dashboard** | Múltiplos endpoints | Gráficos de pedidos por status, faturamento |

> **Conceito-chave para iniciante:** O frontend é o **"rosto" do sistema** — tudo que o usuário vê e clica. O backend é o **"cérebro"** — processa regras de negócio e persiste dados. Eles se comunicam via HTTP (requests e responses em JSON).

---

## 2. Por que React?

React é a **biblioteca JavaScript mais utilizada no mercado** para construção de interfaces. Veja o contexto:

| Critério | React | Angular | Vue |
|---|---|---|---|
| **Mercado de trabalho (BR)** | 🥇 Mais vagas (bancos, fintechs, big techs) | 🥈 Forte em consultorias | 🥉 Crescendo, menos vagas |
| **Curva de aprendizado** | Moderada — JavaScript puro + JSX | Alta — TypeScript obrigatório + conceitos próprios | Baixa — mais "mágico" |
| **Ecossistema** | Gigante — npm tem tudo | Embutido (tudo no framework) | Médio — crescendo |
| **Flexibilidade** | Alta — você escolhe as libs | Baixa — opinado (usa o que o Angular define) | Média |
| **Grandes empresas** | Meta, Netflix, Airbnb, Nubank, iFood, Itaú | Google, bancos tradicionais | Alibaba, GitLab |

### React 19 — O que há de novo?

Estamos usando **React 19** (versão estável mais recente):

| Feature | O que faz | Onde usamos |
|---|---|---|
| **React Compiler** | Otimiza re-renders automaticamente (sem `useMemo`/`useCallback` manual) — **opt-in**, requer configuração do plugin no build | Disponível, mas não habilitado por padrão |
| **Actions** | Funções async para formulários com estados pendentes | Formulários de pedido |
| **`useActionState`** | Gerencia estado de ações de formulário (loading, error, data) | Forms com submit |
| **`useOptimistic`** | Atualização otimista da UI antes da resposta do servidor | Atualização de status |
| **`use()`** | Lê Promises e Contextos dentro de render | Carregamento de dados |
| **Server Components** | Componentes que rodam no servidor (Next.js) | Não usamos (SPA pura) |

> **📝 Nota:** Não usamos Server Components porque nosso frontend é uma **SPA** servida estaticamente. Server Components fazem sentido com Next.js/Remix — são ótimos, mas adicionam complexidade que não precisamos agora.

---

## 3. Stack Tecnológica Completa

### Core

| Tecnologia | Versão | Para que serve |
|---|---|---|
| **React** | 19.x | Biblioteca de UI — componentes reativos |
| **TypeScript** | 5.x | Tipagem estática para JavaScript — evita bugs, melhora DX |
| **Vite** | 6.x | Build tool — dev server instantâneo, HMR (Hot Module Replacement) super rápido |

### Roteamento

| Tecnologia | Versão | Para que serve |
|---|---|---|
| **React Router** | 7.x | Roteamento client-side — navegação entre páginas sem reload |

### Estilização

| Tecnologia | Versão | Para que serve |
|---|---|---|
| **Tailwind CSS** | 4.x | Utility-first CSS — estiliza direto no HTML com classes |
| **shadcn/ui** | latest | Componentes acessíveis e estilizados — copiados para o projeto (não é npm) |
| **Lucide React** | latest | Ícones SVG consistentes |

### Estado e Data Fetching

| Tecnologia | Versão | Para que serve |
|---|---|---|
| **TanStack Query** | 5.x | Data fetching, cache, sync — gerencia estado do servidor |
| **Zustand** | 5.x | Estado global client-side — leve, simples, sem boilerplate |
| **Axios** | 1.x | HTTP client — interceptors, transformers, mais ergonômico que fetch |

### Formulários e Validação

| Tecnologia | Versão | Para que serve |
|---|---|---|
| **React Hook Form** | 7.x | Formulários performáticos — sem re-renders desnecessários |
| **Zod** | 3.x | Validação de schema — type-safe, integra com React Hook Form |

### Testes

| Tecnologia | Versão | Para que serve |
|---|---|---|
| **Vitest** | 3.x | Test runner — compatível com Vite, API igual ao Jest |
| **Testing Library** | 16.x | Testes de componentes — testa como o usuário interage |
| **MSW** | 2.x | Mock Service Worker — intercepta HTTP para testes |
| **Playwright** | latest | Testes E2E — automação de browser real |

### DevEx (Developer Experience)

| Tecnologia | Versão | Para que serve |
|---|---|---|
| **ESLint** | 9.x | Linter — encontra erros e enforça padrões (flat config) |
| **Prettier** | 3.x | Formatter — formata código automaticamente |
| **Husky** | 9.x | Git hooks — roda lint/testes antes de commits |

---

## 4. Arquitetura do Frontend

### Feature-Sliced Design (Adaptado)

Usamos uma arquitetura baseada em **Feature-Sliced Design** — organização por funcionalidade (feature), não por tipo de arquivo:

```
src/
├── app/                        # Bootstrap e configuração global
│   ├── App.tsx                 # Componente raiz (providers, router)
│   ├── main.tsx                # Entry point (ReactDOM.createRoot)
│   ├── providers/              # Providers globais (Query, Auth, Theme)
│   │   ├── QueryProvider.tsx
│   │   ├── AuthProvider.tsx
│   │   └── ThemeProvider.tsx
│   └── router/                 # Configuração de rotas
│       ├── index.tsx           # createBrowserRouter
│       ├── routes.tsx          # Definição de rotas
│       └── ProtectedRoute.tsx  # Guarda de rota autenticada
│
├── features/                   # Features de negócio (coração do app)
│   ├── orders/                 # Tudo sobre pedidos
│   │   ├── api/                # Hooks de API (useOrders, useCreateOrder)
│   │   ├── components/         # Componentes específicos (OrderCard, OrderTable)
│   │   ├── hooks/              # Hooks de lógica (useOrderFilters, useOrderForm)
│   │   ├── pages/              # Páginas completas (OrdersPage, OrderDetailPage)
│   │   ├── types/              # Tipos TypeScript (Order, OrderStatus, etc.)
│   │   └── utils/              # Helpers (formatters, validators)
│   │
│   ├── auth/                   # Autenticação
│   │   ├── api/
│   │   ├── components/
│   │   ├── hooks/
│   │   ├── pages/
│   │   └── types/
│   │
│   ├── restaurants/            # Restaurantes
│   │   ├── api/
│   │   ├── components/
│   │   ├── pages/
│   │   └── types/
│   │
│   └── dashboard/              # Dashboard com métricas
│       ├── api/
│       ├── components/
│       └── pages/
│
├── shared/                     # Código reutilizável entre features
│   ├── api/                    # Axios instance, interceptors, tipos base
│   │   ├── client.ts           # Axios configurado (baseURL, JWT interceptor)
│   │   └── types.ts            # PaginatedResponse<T>, ApiError, etc.
│   ├── components/             # Componentes genéricos (Button, Modal, Table, etc.)
│   │   └── ui/                 # shadcn/ui components
│   ├── hooks/                  # Hooks utilitários (useDebounce, useLocalStorage)
│   ├── lib/                    # Funções utilitárias (cn(), formatCurrency, formatDate)
│   └── types/                  # Tipos globais
│
├── assets/                     # Imagens, fontes, SVGs
│   └── images/
│
└── styles/                     # CSS global
    └── globals.css             # Tailwind directives + CSS variables
```

### Por que Feature-Sliced?

| Abordagem Comum (por tipo) | Feature-Sliced (por feature) |
|---|---|
| `components/OrderCard.tsx` | `features/orders/components/OrderCard.tsx` |
| `hooks/useOrders.ts` | `features/orders/hooks/useOrders.ts` |
| `services/orderService.ts` | `features/orders/api/useOrders.ts` |
| Quando cresce, vira um caos | Cada feature é autocontida |

> **Analogia com o backend:** Feature-Sliced é como o **bounded context** do DDD. Cada feature tem seu próprio "mundo" — api, components, hooks, types. Isso é o equivalente no frontend ao `package-by-feature` do backend.

### Regra de Dependência

```
    pages  →  features  →  shared
      ↓           ↓
   components    api/hooks
```

- **`shared/`** não importa de `features/`
- **`features/`** não importam entre si (se precisar, extraia para `shared/`)
- **`pages/`** compõem components de features
- **`app/`** é o raiz — importa tudo para montar o app

---

## 5. Como o Frontend Conversa com o Backend

### Fluxo de uma requisição

```
┌─────────────┐       HTTP/JSON        ┌──────────────────┐
│  React App  │ ◄────────────────────► │    API Gateway    │
│  (browser)  │  Authorization: Bearer  │   (porta 8080)   │
└─────────────┘                        └────────┬─────────┘
                                                │
                                                ▼
                                       Service Discovery
                                          (Eureka)
                                                │
                                    ┌───────────┼───────────┐
                                    ▼           ▼           ▼
                               order-svc   restaurant-svc  payment-svc
                               (8081)       (8082)         (8083)
```

### Contrato da API

O frontend faz chamadas HTTP para o **API Gateway** (porta 8080). O Gateway roteia para o microserviço correto.

```typescript
// Exemplo de chamada — buscar pedidos paginados
const response = await axios.get('/api/orders', {
  params: { page: 0, size: 10, status: 'PENDING' },
  headers: { Authorization: `Bearer ${token}` }
});

// Resposta JSON esperada (do backend Spring Boot):
{
  "content": [
    {
      "id": 1,
      "customerId": 42,
      "restaurantId": 7,
      "status": "PENDING",
      "totalAmount": 89.90,
      "items": [
        { "id": "i1", "menuItemId": "m1", "name": "Pizza Margherita", "quantity": 2, "unitPrice": 39.90, "totalPrice": 79.80 },
        { "id": "i2", "menuItemId": "m2", "name": "Refrigerante", "quantity": 1, "unitPrice": 10.10, "totalPrice": 10.10 }
      ],
      "createdAt": "2026-04-15T14:30:00"
    }
  ],
  "totalElements": 47,
  "totalPages": 5,
  "number": 0,
  "size": 10,
  "first": true,
  "last": false
}
```

> **CORS:** O API Gateway já está configurado para aceitar requisições do `http://localhost:5173` (porta do Vite). Se não estiver, basta adicionar a config no backend — veremos isso na Fase 05.

---

## 6. Conceitos Fundamentais para Quem Nunca Mexeu com React

### O que é um Componente?

Um componente é uma **função JavaScript que retorna HTML** (JSX). É a unidade básica do React:

```tsx
// Isso é um componente React
function OrderCard({ order }) {
  return (
    <div className="border rounded-lg p-4">
      <h3>Pedido #{order.id}</h3>
      <p>Status: {order.status}</p>
      <p>Total: R$ {order.totalAmount.toFixed(2)}</p>
    </div>
  );
}
```

### O que é JSX?

JSX é HTML dentro do JavaScript. O compilador transforma `<div>` em chamadas `React.createElement()`. Parece mágico, mas é só açúcar sintático.

```tsx
// Você escreve:
<h1 className="text-2xl">Olá</h1>

// O compilador gera:
React.createElement('h1', { className: 'text-2xl' }, 'Olá')
```

> **Diferenças do HTML:** `class` vira `className`, `for` vira `htmlFor`, e toda tag deve ser fechada (`<img />`, não `<img>`).

### O que é um Hook?

Hook é uma **função especial** que começa com `use` e permite que componentes tenham "memória" e "efeitos colaterais":

| Hook | Para que serve | Analogia com Java |
|---|---|---|
| `useState` | Variável reativa (muda → re-renderiza) | Campo de uma entidade |
| `useEffect` | Executar algo quando dados mudam | `@PostConstruct` / `@EventListener` |
| `useContext` | Acessar dados globais sem prop drilling | Injeção de dependência |
| `useRef` | Referência mutável sem re-render | Campo `transient` |
| `useMemo` | Cachear valor calculado | `@Cacheable` |
| `useCallback` | Cachear uma função | Cache de lambda |

### O que é TypeScript?

TypeScript é **JavaScript com tipos** — como Java, você declara tipos de variáveis, parâmetros e retornos:

```typescript
// JavaScript: pode ser qualquer coisa — descobre só em runtime
const order = await fetchOrder(1);
order.statusss; // erro de digitação — só dá erro no browser, tarde demais

// TypeScript: compilador avisa ANTES de rodar
interface Order {
  id: number;
  status: 'PENDING' | 'CONFIRMED' | 'DELIVERED' | 'CANCELLED';
  totalAmount: number;
}

const order: Order = await fetchOrder(1);
order.statusss; // ❌ Erro no editor: Property 'statusss' does not exist on type 'Order'
```

> **Analogia com Java:** TypeScript é para JavaScript assim como o compilador javac é para Java — pega erros em tempo de compilação, não em runtime.

---

## 7. Decisões Arquiteturais (ADRs)

### ADR-F001: SPA com Vite (sem SSR)

| Campo | Valor |
|---|---|
| **Contexto** | Precisamos de uma aplicação frontend para consumir a API REST |
| **Decisão** | SPA pura com React + Vite, servida via CDN/Nginx em produção |
| **Justificativa** | O backend já é API-first; SEO não é prioridade (app interno/logado); Vite é o build tool mais rápido e moderno; evita complexidade de SSR |
| **Consequência** | Sem SSR/ISR — conteúdo não indexável por buscadores (OK para painel admin) |
| **Alternativas descartadas** | Next.js (SSR desnecessário para painel admin), Create React App (lento, deprecated) |

### ADR-F002: Tailwind CSS + shadcn/ui

| Campo | Valor |
|---|---|
| **Contexto** | Precisamos de um sistema de design para UI |
| **Decisão** | Tailwind CSS para utility classes + shadcn/ui para componentes base |
| **Justificativa** | Tailwind é o padrão de mercado para React; shadcn/ui é acessível (ARIA), customizável (os componentes são **seus**, não de uma lib), e usa Radix UI por baixo |
| **Consequência** | Componentes copiados para o projeto (vendoring), não instalados via npm |
| **Alternativas descartadas** | Material UI (pesado, difícil de customizar), Chakra UI (bom, mas menor adoção em 2025+), CSS Modules (verboso) |

### ADR-F003: TanStack Query para data fetching

| Campo | Valor |
|---|---|
| **Contexto** | Precisamos gerenciar estado do servidor (dados da API) |
| **Decisão** | TanStack Query (React Query v5) para cache, refetch, loading states |
| **Justificativa** | Separa estado do servidor (cache) de estado do client (UI); stale-while-revalidate; retry automático; devtools excelente |
| **Consequência** | Estado do servidor vive no cache do TanStack Query, não no Zustand |
| **Alternativas descartadas** | SWR (menos features), Redux Toolkit Query (mais verboso), useEffect + useState (código espaguete, não cacheia) |

### ADR-F004: Zustand para estado global do client

| Campo | Valor |
|---|---|
| **Contexto** | Precisamos gerenciar estado que não é do servidor (tema, sidebar, auth token) |
| **Decisão** | Zustand para estado global leve |
| **Justificativa** | API mínima (3 linhas criam um store), sem boilerplate, sem providers, selectors nativos |
| **Consequência** | Zustand só gerencia estado do **client** (UI). Estado do **servidor** (dados) fica no TanStack Query |
| **Alternativas descartadas** | Redux (muito boilerplate), Context API pura (re-renders desnecessários), Jotai (ótimo, mas Zustand é mais intuitivo para stores centralizados) |

### ADR-F005: Estrutura Feature-Sliced

| Campo | Valor |
|---|---|
| **Contexto** | Precisamos organizar o código do frontend de forma escalável |
| **Decisão** | Feature-Sliced Design: `features/` por bounded context, `shared/` para reutilizáveis |
| **Justificativa** | Coloca tudo de uma feature junto (colocation); análogo ao package-by-feature do backend; fácil de navegar; scale naturalmente |
| **Consequência** | Mais pastas do que flat structure; precisa de disciplina para não importar entre features |
| **Alternativas descartadas** | Flat (components/, hooks/, services/) — vira caos com 50+ componentes; Atomic Design (teórico demais para este projeto) |

---

## 8. Princípios do React Aplicados no Projeto

| Princípio | Onde no FoodHub Frontend |
|---|---|
| **Composição** | `OrdersPage` compõe `OrderTable` + `OrderFilters` + `Pagination` |
| **Unidirecionalidade** | Dados fluem de cima para baixo (props); ações fluem de baixo para cima (callbacks) |
| **Imutabilidade** | Estado nunca é mutado diretamente — sempre `setState(newValue)` |
| **Colocation** | Código que muda junto vive junto: `features/orders/` tem api, components, hooks, types |
| **Separation of Concerns** | View (components) separada de lógica (hooks) e data (api) |
| **DRY** | Componentes e hooks compartilhados em `shared/` |
| **Single Responsibility** | Cada componente faz UMA coisa: `OrderCard` exibe, `useOrders` busca, `OrderForm` captura input |

---

## 9. Checklist de Competências Frontend

Use para acompanhar seu progresso. Cada item é praticado neste projeto:

| # | Competência | Onde no Projeto | Fase |
|---|---|---|---|
| 1 | React 19 (Hooks, JSX, Components) | Todo o frontend | 01 |
| 2 | TypeScript 5.x (Tipos, Interfaces, Generics) | Todo o frontend | 01 |
| 3 | Vite (Dev server, Build, Config) | Setup do projeto | 01 |
| 4 | Componentização (Props, Children, Composição) | shared/ e features/ | 02 |
| 5 | Hooks (useState, useEffect, useRef, custom) | Todos os componentes | 04 |
| 6 | React Router 7 (Rotas, Nested, Guards, Loaders) | app/router/ | 03 |
| 7 | Tailwind CSS 4 + shadcn/ui | Toda a estilização | 02-03 |
| 8 | Zustand (Estado global, Slices, Persist) | Auth store, UI store | 04 |
| 9 | TanStack Query (useQuery, useMutation, cache) | features/\*/api/ | 05 |
| 10 | Axios (Interceptors, Error handling) | shared/api/client.ts | 05 |
| 11 | Autenticação JWT (Login, Refresh, Protected Routes) | features/auth/ | 06 |
| 12 | React Hook Form + Zod (Validação type-safe) | features/orders/hooks/ | 07 |
| 13 | Vitest + Testing Library (Unit/Integration) | Testes \*.test.tsx | 08 |
| 14 | MSW (Mock Service Worker) | Mocks de API para testes | 08 |
| 15 | Playwright (Testes E2E) | Fluxos end-to-end | 08 |
| 16 | React.lazy + Suspense (Code splitting) | Router lazy loading | 09 |
| 17 | Performance (memo, virtualização, bundle size) | Otimizações | 09 |
| 18 | ESLint 9 + Prettier (Lint, Format, Hooks rules) | Configs do projeto | 01 |
| 19 | Husky + lint-staged (Pre-commit hooks) | Git workflow | 01 |
| 20 | Docker (Nginx + multi-stage build) | Deploy do frontend | 10 |
| 21 | CI/CD (GitHub Actions para frontend) | Pipeline de build/test/deploy | 10 |
| 22 | Responsividade (Mobile-first, Breakpoints) | Todas as telas | 02-09 |
| 23 | Acessibilidade (ARIA, keyboard nav, screen readers) | shadcn/ui + custom a11y | 02-09 |
| 24 | Feature-Sliced Design (Organização por feature) | Estrutura de pastas | 01 |

---

## 10. Pré-requisitos

Antes de começar a Fase 01, você precisa ter instalado:

| Ferramenta | Versão Mínima | Como verificar | Como instalar |
|---|---|---|---|
| **Node.js** | 20.x LTS | `node --version` | [nodejs.org](https://nodejs.org) ou `nvm install 20` |
| **npm** | 10.x | `npm --version` | Vem com Node.js |
| **Git** | 2.x | `git --version` | [git-scm.com](https://git-scm.com) |
| **VS Code** | latest | — | [code.visualstudio.com](https://code.visualstudio.com) |

### Extensões VS Code Recomendadas

| Extensão | Para que serve |
|---|---|
| **ES7+ React/Redux/React-Native snippets** | Atalhos para criar componentes (`rafce` → cria component) |
| **Tailwind CSS IntelliSense** | Autocomplete de classes Tailwind |
| **Prettier - Code formatter** | Formata código ao salvar |
| **ESLint** | Mostra erros de lint no editor |
| **TypeScript Importer** | Auto-importa ao digitar |
| **Error Lens** | Mostra erros inline no editor |

---

## 11. Ordem de Implementação

```
 1. Fase 00 — Visão geral (esta fase — leitura obrigatória)
 2. Fase 01 — Fundação (Vite + React + TypeScript + estrutura)
 3. Fase 02 — Componentes e Estilização (Tailwind + shadcn/ui)
 4. Fase 03 — Roteamento (React Router 7, layouts, guards)
 5. Fase 04 — Estado Global (Zustand + gerenciamento de UI)
 6. Fase 05 — Integração com API (Axios + TanStack Query)
 7. Fase 06 — Autenticação (JWT, login, proteção de rotas)
 8. Fase 07 — Formulários e Validação (React Hook Form + Zod)
 9. Fase 08 — Testes (Vitest, Testing Library, MSW, Playwright)
10. Fase 09 — Performance e Otimização (lazy loading, virtualização)
11. Fase 10 — Build, Docker e CI/CD
```

> **Dica:** Assim como no backend, cada fase depende das anteriores. O conhecimento é cumulativo.

---

## 12. Glossário para Iniciantes

| Termo | O que é | Analogia com Java |
|---|---|---|
| **SPA** | Single Page Application — uma só página HTML, JavaScript troca o conteúdo | Como um desktop app (Angular = Swing, React = JavaFX) |
| **JSX** | HTML dentro de JavaScript | Como Thymeleaf, mas no client |
| **Component** | Função que retorna UI | Uma classe `@Controller` que retorna HTML |
| **Props** | Parâmetros de um componente | Parâmetros de método |
| **State** | Dados reativos do componente | Campos de um `@Stateful` bean |
| **Hook** | Função especial (`use*`) que dá poderes ao componente | `@Autowired` inject |
| **Effect** | Código que roda quando dados mudam | `@EventListener` / `@Scheduled` |
| **Render** | Processo de gerar HTML a partir do JSX | `Template.render()` |
| **Re-render** | Recalcular o HTML quando state/props mudaram | `Observer.update()` |
| **Virtual DOM** | Cópia em memória do DOM real — React calcula diffs para atualizar eficientemente | `EntityManager.merge()` (diff e update) |
| **Build** | Compilar TypeScript/JSX para JS otimizado | `mvn package` |
| **HMR** | Hot Module Replacement — alterações no código refletem no browser sem reload | `spring.devtools.restart` |
| **Bundle** | Arquivo JS final gerado pelo build | `.jar` / `.war` |

---

## 13. Perguntas Frequentes em Entrevista (React)

| # | Pergunta | Resposta Resumida |
|---|---|---|
| 1 | **O que é o Virtual DOM?** | Uma representação em memória do DOM real. React compara o virtual DOM anterior com o novo (reconciliation/diffing) e atualiza apenas o que mudou no DOM real — isso é muito mais rápido que manipular o DOM diretamente. |
| 2 | **Qual a diferença entre `state` e `props`?** | `props` são dados passados do pai para o filho (read-only). `state` são dados internos do componente (mutáveis via `setState`). Props vêm de fora, state vive dentro. |
| 3 | **Por que usar `key` em listas?** | React usa `key` para identificar qual item mudou, foi adicionado ou removido. Sem `key`, React re-renderiza toda a lista. Com `key` única e estável, atualiza apenas o item alterado. |
| 4 | **O que é o hook `useEffect` e quando usar?** | `useEffect` executa efeitos colaterais (fetch de dados, subscriptions, timers) após o render. Roda quando as dependências no array mudam. Array vazio (`[]`) = roda só uma vez (mount). |
| 5 | **Diferencie componentes controlados e não-controlados.** | Controlado: o React controla o valor do input via state (`value={state}`). Não-controlado: o DOM controla — React acessa via `ref`. Controlados são preferidos para validação e form state consistente. |
| 6 | **O que é prop drilling e como evitar?** | Passar props por muitos níveis de componentes intermediários. Evita-se com Context API, Zustand ou TanStack Query (para dados do servidor). |
| 7 | **O que são custom hooks?** | Funções `use*` que encapsulam lógica reutilizável com hooks. Ex: `useDebounce`, `useLocalStorage`. Seguem as mesmas regras dos hooks nativos. |
| 8 | **O que mudou no React 19?** | Actions (funções assíncronas em transições), `useActionState` para forms com server actions, `useOptimistic` para UI otimista, `use()` para ler Promises/Context em render. O React Compiler (opt-in) pode memoizar automaticamente eliminando `useMemo`/`useCallback` manuais. Para SPAs como FoodHub, o principal ganho é melhoria de performance e o runtime do Compiler. |
| 9 | **Qual a diferença entre SSR, CSR e SSG?** | **CSR** (Client-Side Rendering): o browser baixa um HTML vazio e o JS renderiza tudo — é o que o FoodHub usa (SPA com Vite). **SSR** (Server-Side Rendering): o servidor gera HTML completo em cada request (Next.js). **SSG** (Static Site Generation): HTML gerado no build time. CSR é ideal para dashboards/apps autenticados. SSR/SSG para conteúdo público com SEO. |

---

> **Próximo passo:** [Fase 01 — Fundação: Vite + React + TypeScript](fase-01-fundacao.md)
