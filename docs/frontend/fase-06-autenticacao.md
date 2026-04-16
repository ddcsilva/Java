# Fase 06 — Autenticação (JWT + AuthProvider + Login)

> **Objetivo:** Implementar o fluxo de autenticação completo — login page, interceptação de JWT, proteção de rotas, persistência de sessão e refresh token.

---

## 6.1 Fluxo de Autenticação

```
┌────────────────────────────────────────────────────────────────┐
│                 Fluxo de Login — JWT                           │
│                                                                │
│  1. Usuário preenche email + senha no LoginPage                │
│  2. Frontend envia POST /api/auth/login { email, password }    │
│  3. Backend valida → retorna { accessToken, refreshToken, user }│
│  4. Frontend salva no Zustand (persist → localStorage)         │
│  5. Axios interceptor adiciona "Bearer <token>" em toda request│
│  6. Rotas protegidas verificam isAuthenticated antes de render │
│                                                                │
│  Token expirou?                                                │
│  7. Backend retorna 401                                        │
│  8. Interceptor tenta refresh com refreshToken                 │
│  9. Se refresh OK → novo token, retry request original         │
│  10. Se refresh falhou → logout, redirect /login               │
└────────────────────────────────────────────────────────────────┘
```

> **Analogia com Java:** O frontend faz a mesma coisa que um cliente REST faria com Spring Security + JWT: envia credenciais, recebe token, envia token em todo request subsequente. A proteção de rotas no frontend é UX (esconder páginas); a segurança real é no backend.

---

## 6.2 Tipos de Autenticação

### `src/features/auth/types/index.ts`

```typescript
export interface LoginRequest {
  email: string;
  password: string;
}

export interface AuthResponse {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  user: AuthUser;
}

export interface AuthUser {
  id: string;
  name: string;
  email: string;
  role: 'ADMIN' | 'RESTAURANT_OWNER' | 'CUSTOMER';
}

export interface RefreshTokenRequest {
  refreshToken: string;
}
```

---

## 6.3 API de Autenticação

### `src/features/auth/api/authApi.ts`

```typescript
import { apiClient } from '@/shared/api/client';
import type { LoginRequest, AuthResponse, RefreshTokenRequest } from '../types';

export const authApi = {
  login: async (request: LoginRequest) => {
    const { data } = await apiClient.post<AuthResponse>('/auth/login', request);
    return data;
  },

  refresh: async (request: RefreshTokenRequest) => {
    const { data } = await apiClient.post<AuthResponse>('/auth/refresh', request);
    return data;
  },

  logout: async () => {
    await apiClient.post('/auth/logout');
  },

  me: async () => {
    const { data } = await apiClient.get<AuthUser>('/auth/me');
    return data;
  },
};
```

---

## 6.4 Atualizar a Auth Store

### `src/features/auth/hooks/useAuthStore.ts` (versão completa)

```typescript
import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { AuthUser } from '../types';

interface AuthState {
  accessToken: string | null;
  refreshToken: string | null;
  user: AuthUser | null;
  isAuthenticated: boolean;
}

interface AuthActions {
  setAuth: (accessToken: string, refreshToken: string, user: AuthUser) => void;
  setTokens: (accessToken: string, refreshToken: string) => void;
  logout: () => void;
}

type AuthStore = AuthState & AuthActions;

export const useAuthStore = create<AuthStore>()(
  persist(
    (set) => ({
      accessToken: null,
      refreshToken: null,
      user: null,
      isAuthenticated: false,

      setAuth: (accessToken, refreshToken, user) =>
        set({
          accessToken,
          refreshToken,
          user,
          isAuthenticated: true,
        }),

      setTokens: (accessToken, refreshToken) =>
        set({ accessToken, refreshToken }),

      logout: () =>
        set({
          accessToken: null,
          refreshToken: null,
          user: null,
          isAuthenticated: false,
        }),
    }),
    {
      name: 'foodhub-auth',
      partialize: (state) => ({
        accessToken: state.accessToken,
        refreshToken: state.refreshToken,
        user: state.user,
        isAuthenticated: state.isAuthenticated,
      }),
    },
  ),
);
```

---

## 6.5 Interceptor com Refresh Token

### Atualizar `src/shared/api/client.ts`

```typescript
import axios, { type InternalAxiosRequestConfig, type AxiosError } from 'axios';
import { useAuthStore } from '@/features/auth/hooks/useAuthStore';

export const apiClient = axios.create({
  baseURL: '/api',
  timeout: 15_000,
  headers: { 'Content-Type': 'application/json' },
});

// Request interceptor: adiciona Bearer token
apiClient.interceptors.request.use((config: InternalAxiosRequestConfig) => {
  const token = useAuthStore.getState().accessToken;
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Response interceptor: refresh token em caso de 401
let isRefreshing = false;
let failedQueue: Array<{
  resolve: (token: string) => void;
  reject: (error: unknown) => void;
}> = [];

function processQueue(error: unknown, token: string | null) {
  failedQueue.forEach((promise) => {
    if (token) {
      promise.resolve(token);
    } else {
      promise.reject(error);
    }
  });
  failedQueue = [];
}

apiClient.interceptors.response.use(
  (response) => response,
  async (error: AxiosError) => {
    const originalRequest = error.config;
    if (!originalRequest) return Promise.reject(error);

    // Se não é 401 ou é a rota de refresh, não tenta refresh
    if (error.response?.status !== 401 || originalRequest.url === '/auth/refresh') {
      return Promise.reject(error);
    }

    // Se já está fazendo refresh, enfileira o request
    if (isRefreshing) {
      return new Promise((resolve, reject) => {
        failedQueue.push({
          resolve: (token: string) => {
            originalRequest.headers.Authorization = `Bearer ${token}`;
            resolve(apiClient(originalRequest));
          },
          reject,
        });
      });
    }

    isRefreshing = true;
    const refreshToken = useAuthStore.getState().refreshToken;

    if (!refreshToken) {
      useAuthStore.getState().logout();
      window.location.href = '/login';
      return Promise.reject(error);
    }

    try {
      const { data } = await axios.post('/api/auth/refresh', { refreshToken });
      useAuthStore.getState().setTokens(data.accessToken, data.refreshToken);
      processQueue(null, data.accessToken);

      originalRequest.headers.Authorization = `Bearer ${data.accessToken}`;
      return apiClient(originalRequest);
    } catch (refreshError) {
      processQueue(refreshError, null);
      useAuthStore.getState().logout();
      window.location.href = '/login';
      return Promise.reject(refreshError);
    } finally {
      isRefreshing = false;
    }
  },
);
```

**Explicação do refresh flow:**

| Situação | O que acontece |
|---|---|
| Request retorna 401 | Interceptor tenta refresh |
| Refresh deu certo | Atualiza tokens, re-executa o request original |
| Refresh falhou | Logout + redirect para login |
| Múltiplos 401 simultâneos | Enfileira requests, faz refresh uma vez só, re-executa todos |

> **A fila (`failedQueue`) é essencial.** Se 3 requests falham com 401 ao mesmo tempo, sem a fila seriam 3 tentativas de refresh simultâneas. Com a fila, a primeira faz refresh, e as outras esperam.

---

## 6.6 Login Page

### `src/features/auth/pages/LoginPage.tsx`

```tsx
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '../hooks/useAuthStore';
import { authApi } from '../api/authApi';
import { getErrorMessage } from '@/shared/api/handleApiError';
import { Button } from '@/shared/components/ui/button';
import { Input } from '@/shared/components/ui/input';
import { Label } from '@/shared/components/ui/label';
import { Card, CardContent, CardHeader, CardTitle } from '@/shared/components/ui/card';

function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const navigate = useNavigate();
  const setAuth = useAuthStore((state) => state.setAuth);

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    setError('');
    setIsLoading(true);

    try {
      const response = await authApi.login({ email, password });
      setAuth(response.accessToken, response.refreshToken, response.user);
      navigate('/', { replace: true });
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Entrar</CardTitle>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} className="space-y-4">
          {error && (
            <div className="rounded-md bg-destructive/10 p-3 text-sm text-destructive">
              {error}
            </div>
          )}

          <div className="space-y-2">
            <Label htmlFor="email">Email</Label>
            <Input
              id="email"
              type="email"
              placeholder="admin@foodhub.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              autoComplete="email"
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="password">Senha</Label>
            <Input
              id="password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              autoComplete="current-password"
            />
          </div>

          <Button type="submit" className="w-full" disabled={isLoading}>
            {isLoading ? 'Entrando...' : 'Entrar'}
          </Button>
        </form>
      </CardContent>
    </Card>
  );
}

export default LoginPage;
```

> **`event.preventDefault()`** impede que o `<form>` faça o submit padrão do HTML (que recarregaria a página inteira). Em SPAs, sempre tratamos o submit via JavaScript.

---

## 6.7 Proteção de Rotas

### `src/shared/components/ProtectedRoute.tsx` (versão completa)

```tsx
import { Navigate, Outlet, useLocation } from 'react-router-dom';
import { useAuthStore } from '@/features/auth/hooks/useAuthStore';

interface ProtectedRouteProps {
  allowedRoles?: string[];
}

function ProtectedRoute({ allowedRoles }: ProtectedRouteProps) {
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  const user = useAuthStore((state) => state.user);
  const location = useLocation();

  if (!isAuthenticated) {
    // Salva a URL de destino para redirecionar após login
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  if (allowedRoles && user && !allowedRoles.includes(user.role)) {
    return <Navigate to="/" replace />;
  }

  return <Outlet />;
}

export default ProtectedRoute;
```

### Atualizar o router

```tsx
// src/app/router/routes.tsx
import ProtectedRoute from '@/shared/components/ProtectedRoute';

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
    element: <ProtectedRoute />,
    children: [
      {
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
    ],
  },
  { path: '*', element: <NotFoundPage /> },
]);
```

> **Fluxo:** Ao acessar `/orders`, o `ProtectedRoute` verifica `isAuthenticated`. Se `false`, redireciona para `/login` com `state: { from: location }`. Após login, pode redirecionar de volta para `/orders`.

---

## 6.8 Resumo dos Conceitos

| Conceito | Descrição | Analogia Java |
|---|---|---|
| JWT → localStorage | Token persistido via Zustand persist | Token em cookie/session |
| Request interceptor | Adiciona `Bearer <token>` | `OncePerRequestFilter` |
| Refresh token flow | Renova accessToken sem re-login | Refresh token do OAuth2 |
| `failedQueue` | Enfileira requests durante refresh | Queue/Buffer pattern |
| ProtectedRoute | Wrapper que verifica auth | `@PreAuthorize` / Security filter |
| `allowedRoles` | Autorização por perfil | `hasRole('ADMIN')` |
| `Navigate` state | Redireciona preservando destino | `SavedRequest` do Spring Security |

---

## 6.9 Perguntas Frequentes em Entrevista

| # | Pergunta | Resposta |
|---|---|---|
| 1 | **Onde guardar o JWT — localStorage ou cookie?** | localStorage é simples mas vulnerável a XSS. HttpOnly cookie é mais seguro (inacessível por JS) mas requer configuração no backend. Para SPAs simples, localStorage + proteção contra XSS é aceitável. Para apps críticos (banking), prefira HttpOnly cookies. |
| 2 | **A proteção de rotas no frontend é segurança?** | Não. É UX — esconde componentes que o usuário não deveria ver. A segurança real está no backend (validação do JWT em todo endpoint). Um atacante pode modificar o JavaScript local, mas sem token válido não acessa a API. |
| 3 | **O que é um refresh token?** | Um token de vida longa (dias/semanas) usado para obter um novo access token (vida curta, ~15min). Permite "sessão contínua" sem re-login, enquanto mantém os access tokens com vida curta (menor janela de ataque se comprometido). |
| 4 | **Por que enfileirar requests durante o refresh?** | Se 5 requests falham com 401 simultaneamente и cada um tentasse refresh, seriam 5 chamadas de refresh (race condition). A fila garante que apenas 1 refresh acontece — os outros esperam e recebem o novo token. |
| 5 | **Como prevenir XSS em React?** | React escapa automaticamente todo conteúdo renderizado em JSX (previne injection). Evite `dangerouslySetInnerHTML`. Sanitize inputs. Use CSP headers. Não armazene dados sensíveis em state acessível por extensões do browser. |

---

> **Próximo passo:** [Fase 07 — Formulários e Validação](fase-07-formularios.md)
