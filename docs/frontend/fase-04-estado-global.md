# Fase 04 — Estado Global com Zustand

> **Objetivo:** Entender gerenciamento de estado no React, separar estado do servidor (TanStack Query) do estado do cliente (Zustand), e implementar stores para autenticação e UI.

---

## 4.1 O que é Estado (State)?

**Estado** é qualquer dado que muda ao longo do tempo e afeta o que é renderizado na tela.

```
┌─────────────────────────────────────────────────────┐
│                   Tipos de Estado                    │
│                                                     │
│  ┌──────────────┐          ┌──────────────────┐     │
│  │ Estado Local  │          │ Estado Global    │     │
│  │ (useState)   │          │ (Zustand)        │     │
│  │              │          │                  │     │
│  │ • input text │          │ • auth token     │     │
│  │ • modal open │          │ • user info      │     │
│  │ • tab ativo  │          │ • theme          │     │
│  └──────────────┘          │ • sidebar open   │     │
│                            └──────────────────┘     │
│                                                     │
│  ┌──────────────────────────────────────────────┐   │
│  │ Estado do Servidor (TanStack Query — Fase 05) │   │
│  │                                              │   │
│  │ • lista de pedidos                           │   │
│  │ • dados do restaurante                       │   │
│  │ • estatísticas do dashboard                  │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

> **Analogia com Java:** Estado local é como uma variável de instância privada. Estado global é como um Singleton acessível por toda a aplicação. Estado do servidor é o que vem do banco de dados e precisa de cache/sincronização.

---

## 4.2 useState — Estado Local

`useState` é o Hook mais fundamental do React. Vamos entendê-lo antes de ir para Zustand:

```tsx
import { useState } from 'react';

function Counter() {
  // Declara uma variável de estado chamada "count", inicializada com 0
  // setCount é a função para atualizar o valor
  const [count, setCount] = useState(0);

  return (
    <div>
      <p>Contagem: {count}</p>
      <button onClick={() => setCount(count + 1)}>+1</button>
      <button onClick={() => setCount(0)}>Reset</button>
    </div>
  );
}
```

**Como funciona:**

| Passo | O que acontece |
|---|---|
| 1 | `useState(0)` cria a variável `count` com valor inicial `0` |
| 2 | O componente renderiza mostrando `Contagem: 0` |
| 3 | Usuário clica em `+1` → `setCount(1)` é chamado |
| 4 | React agenda uma re-renderização |
| 5 | O componente re-executa, agora `count` é `1` |
| 6 | O DOM é atualizado para mostrar `Contagem: 1` |

> **Regra:** Nunca mude o estado diretamente (`count = 5` ❌). Sempre use a função setter (`setCount(5)` ✅). Isso é porque o React precisa saber que o valor mudou para re-renderizar.

> **Analogia com Java:** `useState` é como um `AtomicInteger` — você não muda o valor diretamente, usa `.set()` que dispara a notificação para observers.

---

## 4.3 Por que Zustand?

Quando estado precisa ser acessado por **componentes distantes na árvore** (ex: o Header precisa saber se o usuário está logado, e a Sidebar também), usar `useState` não funciona bem — teria que passar props por muitos níveis (**prop drilling**).

Soluções de estado global:

| Solução | Complexidade | Boilerplate | Quando usar |
|---|---|---|---|
| **Context API** | Baixa | Médio | 1-2 valores simples (theme, locale) |
| **Zustand** | Baixa | Mínimo | Estado global real (auth, UI) |
| **Redux Toolkit** | Alta | Alto | Apps enormes (Facebook, Airbnb scale) |
| **Jotai** | Baixa | Mínimo | Estado atômico (muitos estados pequenos) |

> **Por que Zustand e não Redux?** Redux exige actions, reducers, dispatch, middleware — muita cerimônia para apps de porte médio. Zustand faz o mesmo com ~10 linhas. A maioria das vagas modernas aceita Zustand ou Redux Toolkit.

---

## 4.4 Criar a Auth Store

### `src/features/auth/hooks/useAuthStore.ts`

```typescript
import { create } from 'zustand';
import { persist } from 'zustand/middleware';

interface User {
  id: string;
  name: string;
  email: string;
  role: 'ADMIN' | 'RESTAURANT_OWNER' | 'CUSTOMER';
}

interface AuthState {
  token: string | null;
  user: User | null;
  isAuthenticated: boolean;
}

interface AuthActions {
  login: (token: string, user: User) => void;
  logout: () => void;
  updateUser: (user: Partial<User>) => void;
}

type AuthStore = AuthState & AuthActions;

export const useAuthStore = create<AuthStore>()(
  persist(
    (set) => ({
      // Estado inicial
      token: null,
      user: null,
      isAuthenticated: false,

      // Ações
      login: (token, user) =>
        set({
          token,
          user,
          isAuthenticated: true,
        }),

      logout: () =>
        set({
          token: null,
          user: null,
          isAuthenticated: false,
        }),

      updateUser: (updates) =>
        set((state) => ({
          user: state.user ? { ...state.user, ...updates } : null,
        })),
    }),
    {
      name: 'foodhub-auth', // chave no localStorage
      partialize: (state) => ({
        token: state.token,
        user: state.user,
        isAuthenticated: state.isAuthenticated,
      }),
    },
  ),
);
```

**Explicação detalhada:**

| Parte | O que faz |
|---|---|
| `create<AuthStore>()` | Cria uma store Zustand tipada |
| `persist(...)` | Middleware que salva/restaura do `localStorage` automaticamente |
| `set({...})` | Atualiza o estado (equivalente ao `setState` do React) |
| `set((state) => ({...}))` | Versão funcional — acessa o estado anterior para merge |
| `partialize` | Define quais campos são salvos no localStorage (evita salvar funções) |
| `name: 'foodhub-auth'` | Chave no localStorage — se o usuário fechar e reabrir o browser, o login persiste |

> **Analogia com Java:** A store Zustand é como um **@Service singleton** com estado. `login()` e `logout()` são métodos do service. O `persist` é como usar um cache Redis — dados sobrevivem ao restart.

### Usando a store em componentes

```tsx
function Header() {
  // Pega só o que precisa — Zustand re-renderiza apenas se esses valores mudarem
  const user = useAuthStore((state) => state.user);
  const logout = useAuthStore((state) => state.logout);

  return (
    <header className="flex items-center justify-between p-4 border-b border-border">
      <h1 className="text-lg font-bold text-primary">FoodHub</h1>
      {user && (
        <div className="flex items-center gap-4">
          <span className="text-sm text-muted-foreground">{user.name}</span>
          <button
            onClick={logout}
            className="text-sm text-muted-foreground hover:text-foreground"
          >
            Sair
          </button>
        </div>
      )}
    </header>
  );
}
```

> **Seletor `(state) => state.user`:** Isso é um **selector** — pega só uma parte do estado. Se `token` mudar mas `user` não, este componente NÃO re-renderiza. É como fazer um `SELECT user FROM auth_store` — não traz tudo.

---

## 4.5 Criar a UI Store

### `src/shared/hooks/useUIStore.ts`

```typescript
import { create } from 'zustand';

interface UIState {
  sidebarOpen: boolean;
  theme: 'light' | 'dark' | 'system';
}

interface UIActions {
  toggleSidebar: () => void;
  setSidebarOpen: (open: boolean) => void;
  setTheme: (theme: UIState['theme']) => void;
}

type UIStore = UIState & UIActions;

export const useUIStore = create<UIStore>()((set) => ({
  sidebarOpen: true,
  theme: 'system',

  toggleSidebar: () => set((state) => ({ sidebarOpen: !state.sidebarOpen })),
  setSidebarOpen: (open) => set({ sidebarOpen: open }),
  setTheme: (theme) => set({ theme }),
}));
```

> **Sem `persist` aqui:** Sidebar open/close não precisa sobreviver ao reload — é estado efêmero da UI.

### Usando no layout

```tsx
function RootLayout() {
  const sidebarOpen = useUIStore((state) => state.sidebarOpen);
  const toggleSidebar = useUIStore((state) => state.toggleSidebar);

  return (
    <div className="flex min-h-screen">
      {/* Sidebar — largura condicional */}
      <aside
        className={cn(
          'border-r border-border bg-card transition-all duration-200',
          sidebarOpen ? 'w-64' : 'w-0 overflow-hidden md:w-16',
        )}
      >
        {/* Menu items */}
      </aside>

      <div className="flex-1">
        <header className="border-b border-border p-4">
          <button onClick={toggleSidebar} className="p-2 hover:bg-accent rounded-md">
            ☰
          </button>
        </header>
        <main className="p-6">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
```

---

## 4.6 Regras de Ouro do Estado

### Onde colocar cada tipo de estado

```
┌────────────────────────────────────────────────────────┐
│              DECISÃO: Onde colocar o estado?            │
│                                                        │
│  O dado vem da API?                                    │
│    SIM → TanStack Query (Fase 05)                      │
│    NÃO ↓                                               │
│                                                        │
│  Mais de um componente distante precisa acessar?       │
│    SIM → Zustand store                                 │
│    NÃO ↓                                               │
│                                                        │
│  Apenas este componente usa?                           │
│    SIM → useState                                      │
│                                                        │
│  É um valor derivado (calculado de outros)?            │
│    SIM → useMemo ou computed no selector               │
└────────────────────────────────────────────────────────┘
```

| Tipo | Exemplo | Solução |
|---|---|---|
| Lista de pedidos | Dados do backend | TanStack Query |
| Token JWT | Compartilhado por toda app | Zustand (persist) |
| Sidebar aberta/fechada | Compartilhado por layout | Zustand |
| Texto do input | Só o form usa | useState |
| Modal aberto/fechado | Só o componente pai usa | useState |
| Total do pedido (soma dos itens) | Derivado | useMemo / selector |

> **O erro mais comum de iniciantes:** Colocar dados da API em Zustand. Dados do servidor pertencem ao TanStack Query — ele cuida de cache, revalidação, loading states, error states. Zustand é só para estado **client-side** puro.

---

## 4.7 useEffect — Efeitos Colaterais

`useEffect` é o Hook para **efeitos colaterais** — coisas que acontecem fora da renderização:

```tsx
import { useEffect, useState } from 'react';

function OnlineStatus() {
  const [isOnline, setIsOnline] = useState(true);

  useEffect(() => {
    function handleOnline() { setIsOnline(true); }
    function handleOffline() { setIsOnline(false); }

    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    // Cleanup — executado quando o componente é desmontado
    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, []); // [] = executa apenas na montagem

  return (
    <span className={isOnline ? 'text-green-600' : 'text-red-600'}>
      {isOnline ? '● Online' : '○ Offline'}
    </span>
  );
}
```

**Array de dependências:**

| Dependências | Comportamento |
|---|---|
| `[]` | Executa **uma vez** na montagem (como `@PostConstruct`) |
| `[count]` | Executa quando `count` mudar |
| sem array | Executa em **toda** re-renderização (geralmente errado) |

> **Quando usar useEffect:** Event listeners, timers, integração com APIs do browser. **Não use** para buscar dados da API — use TanStack Query (Fase 05). Não use para derivar estado — use cálculo direto ou `useMemo`.

---

## 4.8 useMemo e useCallback — Performance

```tsx
import { useMemo, useCallback } from 'react';

function OrdersPage({ orders }: { orders: Order[] }) {
  const [filter, setFilter] = useState('all');

  // useMemo: recalcula apenas quando orders ou filter mudam
  const filteredOrders = useMemo(() => {
    if (filter === 'all') return orders;
    return orders.filter((o) => o.status === filter);
  }, [orders, filter]);

  // useCallback: mantém a mesma referência de função entre renders
  const handleDelete = useCallback((id: string) => {
    console.log('delete', id);
  }, []);

  return (
    <div>
      <p>{filteredOrders.length} pedidos</p>
      {filteredOrders.map((o) => (
        <OrderCard key={o.id} order={o} onDelete={handleDelete} />
      ))}
    </div>
  );
}
```

| Hook | Para que serve | Quando usar |
|---|---|---|
| `useMemo` | Cacheia um **valor** computado | Cálculos pesados (filtro de lista grande, etc.) |
| `useCallback` | Cacheia uma **função** | Funções passadas como props para componentes memo |

> **Regra:** Não use `useMemo`/`useCallback` prematuramente. Só otimize quando houver problema de performance mensurável.

---

## 4.9 Custom Hooks — Reutilizar Lógica

Custom Hooks encapsulam lógica reutilizável. Convenção: nome começa com `use`.

```typescript
// src/shared/hooks/useMediaQuery.ts
import { useState, useEffect } from 'react';

export function useMediaQuery(query: string): boolean {
  const [matches, setMatches] = useState(false);

  useEffect(() => {
    const media = window.matchMedia(query);
    setMatches(media.matches);

    function listener(event: MediaQueryListEvent) {
      setMatches(event.matches);
    }

    media.addEventListener('change', listener);
    return () => media.removeEventListener('change', listener);
  }, [query]);

  return matches;
}

// Uso
function Sidebar() {
  const isMobile = useMediaQuery('(max-width: 768px)');

  if (isMobile) return null; // esconde sidebar no mobile

  return <aside>...</aside>;
}
```

> **Analogia com Java:** Custom Hooks são como **utility classes** com estado. `useMediaQuery` encapsula a lógica de detectar o tamanho da tela — qualquer componente pode usar sem reimplementar.

---

## 4.10 Resumo dos Conceitos

| Conceito | Descrição | Analogia Java |
|---|---|---|
| `useState` | Estado local de um componente | Variável de instância |
| `useEffect` | Efeitos colaterais (mount, update, unmount) | `@PostConstruct` / `@PreDestroy` |
| `useMemo` | Cache de valor computado | Lazy-init + cache |
| `useCallback` | Cache de referência de função | Method reference cacheado |
| Zustand `create` | Cria store global | `@Service` singleton com estado |
| `persist` | Persiste estado no localStorage | Redis cache |
| Selector | Pega parte do estado | `SELECT coluna FROM tabela` |
| Custom Hook | Lógica reutilizável com estado | Utility class com estado |

---

## 4.11 Perguntas Frequentes em Entrevista

| # | Pergunta | Resposta |
|---|---|---|
| 1 | **Qual a diferença entre estado local e global?** | Local (`useState`) pertence a um componente específico. Global (Zustand/Redux/Context) é acessível por qualquer componente da árvore. Use global apenas quando múltiplos componentes distantes precisam do mesmo dado. |
| 2 | **Por que não usar Redux?** | Redux é excelente para apps enormes, mas adiciona boilerplate significativo (actions, reducers, selectors, slices). Para apps médias, Zustand oferece a mesma funcionalidade com ~80% menos código. Ambos são aceitos no mercado. |
| 3 | **O que é o array de dependências do useEffect?** | Lista de valores que o efeito "observa". Quando um valor muda, o efeito re-executa. Array vazio = executa uma vez. Sem array = executa em todo render (geralmente bug). |
| 4 | **Quando usar useMemo vs useCallback?** | `useMemo` cacheia um **valor** (resultado de cálculo). `useCallback` cacheia uma **função** (referência estável). Ambos recomputam quando suas dependências mudam. Use quando há impacto de performance mensurável. |
| 5 | **O que são custom hooks?** | Funções que usam hooks internamente e encapsulam lógica reutilizável. Começam com `use`. Permitem extrair lógica stateful sem alterar a hierarquia de componentes. É como criar um trait/mixin reutilizável. |

---

> **Próximo passo:** [Fase 05 — Integração com a API](fase-05-integracao-api.md)
