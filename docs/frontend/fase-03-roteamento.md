# Fase 03 — Roteamento com React Router 7

> **Objetivo:** Configurar o sistema de rotas do FoodHub com React Router 7, implementar layouts aninhados, navegação, lazy loading e proteção de rotas.

---

## 3.1 O que é Roteamento no Frontend?

Em uma **SPA** (Single Page Application), o browser carrega **uma única página HTML**. O JavaScript troca o conteúdo dinamicamente. O roteamento faz a URL mudar e renderizar componentes diferentes — sem recarregar a página.

```
URL                          Componente renderizado
─────────────────────────    ────────────────────────
/                            DashboardPage
/orders                      OrdersPage
/orders/123                  OrderDetailPage
/restaurants                 RestaurantsPage
/login                       LoginPage
```

> **Analogia com Java:** No Spring MVC, `@GetMapping("/orders")` mapeia URL → Controller → View. No React Router, `path: "/orders"` mapeia URL → Componente. A diferença é que tudo roda no browser, sem request ao servidor.

---

## 3.2 Conceitos Fundamentais do React Router 7

| Conceito | Descrição | Analogia Java |
|---|---|---|
| **Route** | Mapeia URL para componente | `@RequestMapping` |
| **Router** | Gerencia o histórico de navegação | `DispatcherServlet` |
| **Outlet** | Ponto de inserção para rotas filhas | `<div th:insert>` do Thymeleaf |
| **Link** | Navegação sem reload | `<a href>` mas via JS |
| **Loader** | Carrega dados antes de renderizar | `@ModelAttribute` |
| **Layout** | Componente wrapper com Outlet | Template/Layout global |

---

## 3.3 Criar o Router

### `src/app/router/routes.tsx`

```tsx
import { createBrowserRouter } from 'react-router-dom';
import { lazy } from 'react';

// Layouts (carregamento síncrono — sempre presentes)
import RootLayout from '@/app/layouts/RootLayout';
import AuthLayout from '@/app/layouts/AuthLayout';

// Pages (lazy loading — carregadas sob demanda)
const DashboardPage = lazy(() => import('@/features/dashboard/pages/DashboardPage'));
const OrdersPage = lazy(() => import('@/features/orders/pages/OrdersPage'));
const OrderDetailPage = lazy(() => import('@/features/orders/pages/OrderDetailPage'));
const RestaurantsPage = lazy(() => import('@/features/restaurants/pages/RestaurantsPage'));
const LoginPage = lazy(() => import('@/features/auth/pages/LoginPage'));

export const router = createBrowserRouter([
  {
    path: '/login',
    element: <AuthLayout />,
    children: [
      { index: true, element: <LoginPage /> },
    ],
  },
  {
    path: '/',
    element: <RootLayout />,
    children: [
      { index: true, element: <DashboardPage /> },
      {
        path: 'orders',
        children: [
          { index: true, element: <OrdersPage /> },
          { path: ':id', element: <OrderDetailPage /> },
        ],
      },
      { path: 'restaurants', element: <RestaurantsPage /> },
    ],
  },
]);
```

**Explicação detalhada:**

| Linha | O que faz |
|---|---|
| `createBrowserRouter` | Cria um router que usa a History API do browser (URLs limpas, sem `#`) |
| `lazy(() => import(...))` | **Code splitting** — o componente só é baixado quando a rota é acessada |
| `path: '/'` | Rota raiz — tudo que não é `/login` fica aqui |
| `element: <RootLayout />` | Layout com sidebar + header (wrapper) |
| `index: true` | Rota padrão quando nenhum path filho casa (equivale a `path: ''`) |
| `path: ':id'` | **Parâmetro dinâmico** — `:id` captura o valor da URL (ex: `/orders/123` → `id = "123"`) |
| `children: [...]` | **Rotas aninhadas** — renderizadas dentro do `<Outlet />` do pai |

---

## 3.4 Layouts

### `src/app/layouts/RootLayout.tsx` — Layout principal (autenticado)

```tsx
import { Outlet, Link, useLocation } from 'react-router-dom';
import { Suspense } from 'react';
import {
  LayoutDashboard,
  ShoppingBag,
  Store,
  LogOut,
} from 'lucide-react';
import { cn } from '@/shared/lib/utils';

const navItems = [
  { to: '/', label: 'Dashboard', icon: LayoutDashboard },
  { to: '/orders', label: 'Pedidos', icon: ShoppingBag },
  { to: '/restaurants', label: 'Restaurantes', icon: Store },
];

function RootLayout() {
  const { pathname } = useLocation();

  return (
    <div className="min-h-screen bg-background flex">
      {/* Sidebar */}
      <aside className="w-64 border-r border-border bg-card hidden md:block">
        <div className="p-6">
          <h1 className="text-xl font-bold text-primary">🍔 FoodHub</h1>
        </div>
        <nav className="px-3 space-y-1">
          {navItems.map((item) => (
            <Link
              key={item.to}
              to={item.to}
              className={cn(
                'flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors',
                pathname === item.to
                  ? 'bg-primary/10 text-primary'
                  : 'text-muted-foreground hover:bg-accent hover:text-foreground',
              )}
            >
              <item.icon className="h-4 w-4" />
              {item.label}
            </Link>
          ))}
        </nav>
        <div className="absolute bottom-4 left-3 right-3">
          <button className="flex items-center gap-3 rounded-md px-3 py-2 text-sm text-muted-foreground hover:text-foreground w-full">
            <LogOut className="h-4 w-4" />
            Sair
          </button>
        </div>
      </aside>

      {/* Conteúdo principal */}
      <main className="flex-1 p-6">
        <Suspense
          fallback={
            <div className="flex items-center justify-center h-full">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary" />
            </div>
          }
        >
          <Outlet />
        </Suspense>
      </main>
    </div>
  );
}

export default RootLayout;
```

**Conceitos importantes:**

| Conceito | Explicação |
|---|---|
| `<Outlet />` | Ponto de renderização das rotas filhas — é onde `DashboardPage`, `OrdersPage`, etc. aparecem |
| `<Suspense>` | Mostra o `fallback` (spinner) enquanto o componente lazy está carregando |
| `useLocation()` | Hook que retorna a URL atual — usado para highlight do item ativo no menu |
| `<Link to="/orders">` | Navegação sem reload. Não use `<a href>` — causaria reload da página inteira |
| `cn()` | Aplica classes condicionalmente — item ativo fica com cor primária |

> **Analogia com Java:** O `RootLayout` é como um **template Thymeleaf** com `<div th:insert="~{fragments/sidebar}">` e `<div th:replace="~{content}">`. O `<Outlet />` é o slot onde o conteúdo da rota é injetado.

### `src/app/layouts/AuthLayout.tsx` — Layout para login (sem sidebar)

```tsx
import { Outlet } from 'react-router-dom';
import { Suspense } from 'react';

function AuthLayout() {
  return (
    <div className="min-h-screen bg-background flex items-center justify-center">
      <div className="w-full max-w-md px-4">
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold text-primary">🍔 FoodHub</h1>
          <p className="text-muted-foreground mt-2">Painel Administrativo</p>
        </div>
        <Suspense
          fallback={
            <div className="flex justify-center">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary" />
            </div>
          }
        >
          <Outlet />
        </Suspense>
      </div>
    </div>
  );
}

export default AuthLayout;
```

---

## 3.5 Montar no App

### Atualizar `src/app/App.tsx`

```tsx
import { RouterProvider } from 'react-router-dom';
import { router } from './router/routes';

function App() {
  return <RouterProvider router={router} />;
}

export default App;
```

O `App.tsx` agora é apenas a ponte entre o React e o Router. Todo conteúdo é renderizado pelas rotas.

---

## 3.6 Navegação Programática

Além do `<Link>`, você pode navegar via código com `useNavigate()`:

```tsx
import { useNavigate } from 'react-router-dom';

function OrderCard({ orderId }: { orderId: string }) {
  const navigate = useNavigate();

  function handleClick() {
    navigate(`/orders/${orderId}`);
  }

  return (
    <div onClick={handleClick} className="cursor-pointer hover:bg-accent rounded-lg p-4">
      <p>Pedido #{orderId}</p>
    </div>
  );
}
```

### Ler parâmetros da URL

```tsx
import { useParams } from 'react-router-dom';

function OrderDetailPage() {
  const { id } = useParams<{ id: string }>();

  return (
    <div>
      <h1 className="text-2xl font-bold">Detalhes do Pedido #{id}</h1>
      {/* Buscar dados do pedido com TanStack Query (Fase 05) */}
    </div>
  );
}

export default OrderDetailPage;
```

> **`useParams`** extrai parâmetros dinâmicos da URL. `:id` na definição da rota vira `{ id: "123" }` em runtime.

### Query parameters (filtros)

```tsx
import { useSearchParams } from 'react-router-dom';

function OrdersPage() {
  const [searchParams, setSearchParams] = useSearchParams();
  const status = searchParams.get('status') ?? 'all';
  const page = Number(searchParams.get('page') ?? '0');

  function handleFilterChange(newStatus: string) {
    setSearchParams({ status: newStatus, page: '0' });
  }

  return (
    <div>
      <h1>Pedidos (filtro: {status}, página: {page})</h1>
      {/* URL fica: /orders?status=pending&page=0 */}
    </div>
  );
}

export default OrdersPage;
```

> **Para que serve?** Manter filtros e paginação na URL permite que o usuário compartilhe o link com o estado atual. `useSearchParams` é o equivalente a `@RequestParam` do Spring MVC.

---

## 3.7 Proteção de Rotas — ProtectedRoute

Antes de ter o sistema de autenticação completo (Fase 06), vamos preparar a estrutura:

### `src/shared/components/ProtectedRoute.tsx`

```tsx
import { Navigate, Outlet } from 'react-router-dom';

interface ProtectedRouteProps {
  isAuthenticated: boolean;
  redirectTo?: string;
}

function ProtectedRoute({ isAuthenticated, redirectTo = '/login' }: ProtectedRouteProps) {
  if (!isAuthenticated) {
    return <Navigate to={redirectTo} replace />;
  }

  return <Outlet />;
}

export default ProtectedRoute;
```

> **⚠️ Evolução:** Esta é a versão simplificada. Na **Fase 06**, o `ProtectedRoute` será reescrito para ler o estado de autenticação diretamente do Zustand (sem receber `isAuthenticated` via props) e suportar `allowedRoles` para autorização baseada em perfis.

### Usar no router (ficará completo na Fase 06)

```tsx
// Exemplo de como será integrado nas rotas:
{
  path: '/',
  element: <ProtectedRoute isAuthenticated={isAuth} />,
  children: [
    {
      element: <RootLayout />,
      children: [
        { index: true, element: <DashboardPage /> },
        // ... demais rotas
      ],
    },
  ],
}
```

> **Como funciona?** Se `isAuthenticated` é false, redireciona para `/login`. Se true, renderiza `<Outlet />` que mostra as rotas filhas (ou seja, o `RootLayout` e seu conteúdo).

---

## 3.8 Lazy Loading e Code Splitting

O `lazy()` que usamos cria **code splitting automático**. Vite gera bundles separados para cada rota:

```
Build output:
  dist/assets/index-[hash].js         → código principal (React, Router, Layout)
  dist/assets/DashboardPage-[hash].js → chunk do dashboard
  dist/assets/OrdersPage-[hash].js    → chunk de pedidos
  dist/assets/LoginPage-[hash].js     → chunk do login
```

> **Qual a vantagem?** O usuário baixa apenas o código da página que está acessando. Se ele abre o Dashboard, não baixa o código da página de Restaurantes até navegar para lá. Isso melhora significativamente o tempo de carregamento inicial.

---

## 3.9 Página 404

### `src/app/pages/NotFoundPage.tsx`

```tsx
import { Link } from 'react-router-dom';
import { Button } from '@/shared/components/ui/button';

function NotFoundPage() {
  return (
    <div className="min-h-screen flex items-center justify-center bg-background">
      <div className="text-center">
        <h1 className="text-6xl font-bold text-muted-foreground">404</h1>
        <p className="text-xl text-muted-foreground mt-4">Página não encontrada</p>
        <Button asChild className="mt-6">
          <Link to="/">Voltar ao Dashboard</Link>
        </Button>
      </div>
    </div>
  );
}

export default NotFoundPage;
```

Adicione ao router:

```tsx
// No final do array de rotas
{ path: '*', element: <NotFoundPage /> },
```

> **`path: '*'`** é o catch-all — qualquer URL que não casa com nenhuma rota definida renderiza o 404.

---

## 3.10 Fluxo Completo de Navegação

```
┌──────────────────────────────────────────────────────────────┐
│  Usuário clica em <Link to="/orders">                        │
│                        │                                     │
│                        ▼                                     │
│  React Router atualiza a URL (History API)                   │
│  Browser mostra /orders na barra de endereço                 │
│                        │                                     │
│                        ▼                                     │
│  Router encontra a rota { path: 'orders' }                   │
│                        │                                     │
│                        ▼                                     │
│  OrdersPage está lazy → Suspense mostra spinner              │
│  Vite baixa o chunk OrdersPage-[hash].js                     │
│                        │                                     │
│                        ▼                                     │
│  OrdersPage renderiza dentro do <Outlet /> do RootLayout     │
│  (Sidebar + Header permanecem — só o conteúdo muda)          │
└──────────────────────────────────────────────────────────────┘
```

---

## 3.11 Resumo dos Conceitos

| Conceito | Usado para | Analogia Java |
|---|---|---|
| `createBrowserRouter` | Definir todas as rotas | Bean de configuração de rotas |
| `RouterProvider` | Montar o router no React | `DispatcherServlet` |
| `<Link to="...">` | Navegação declarativa | `<a href>` sem reload |
| `useNavigate()` | Navegação programática | `response.sendRedirect()` |
| `useParams()` | Ler parâmetros da URL (`:id`) | `@PathVariable` |
| `useSearchParams()` | Ler query strings (`?status=pending`) | `@RequestParam` |
| `useLocation()` | URL atual | `HttpServletRequest.getRequestURI()` |
| `<Outlet />` | Renderizar rota filha no layout | `<div th:replace="~{content}">` |
| `<Suspense>` | Fallback enquanto lazy carrega | Loading screen |
| `lazy()` | Code splitting automático | Módulos carregados sob demanda |
| `<Navigate to>` | Redirect declarativo | `RedirectView` |
| `path: '*'` | Rota catch-all (404) | `@ExceptionHandler` |

---

## 3.12 Perguntas Frequentes em Entrevista

| # | Pergunta | Resposta |
|---|---|---|
| 1 | **Qual a diferença entre `<Link>` e `<a href>`?** | `<Link>` faz navegação client-side via JavaScript (History API), sem recarregar a página. `<a href>` causa full page reload. Em SPA, sempre use `<Link>`. |
| 2 | **O que é code splitting e por que importa?** | Code splitting divide o bundle em chunks menores carregados sob demanda. Reduz o tempo de carregamento inicial. No React, use `lazy()` + `Suspense` para split por rota. |
| 3 | **Como proteger rotas no frontend?** | Use um componente wrapper (ProtectedRoute) que verifica autenticação e redireciona se necessário. Lembre: a proteção real é no backend via JWT — a proteção no frontend é UX, não segurança. |
| 4 | **O que são rotas aninhadas?** | Rotas definidas como `children` de outra rota. A rota pai renderiza um layout, e as rotas filhas renderizam dentro do `<Outlet />` do pai. Permite compartilhar sidebar/header entre páginas. |
| 5 | **Qual a diferença entre `useNavigate` e `<Navigate>`?** | `useNavigate()` retorna uma função para navegar programaticamente (em event handlers, callbacks). `<Navigate>` é um componente declarativo que redireciona quando renderizado (usado em condicionais de JSX). |

---

> **Próximo passo:** [Fase 04 — Estado Global](fase-04-estado-global.md)
