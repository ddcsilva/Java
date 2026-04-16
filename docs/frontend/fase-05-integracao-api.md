# Fase 05 — Integração com a API (Axios + TanStack Query)

> **Objetivo:** Configurar o Axios como HTTP client, implementar interceptors para JWT, usar TanStack Query para cache e sincronização de dados do servidor, e criar os hooks de data fetching para o FoodHub.

---

## 5.1 Separação de Responsabilidades

```
┌─────────────────────────────────────────────────────────────┐
│                 Camadas de Data Fetching                     │
│                                                             │
│   Componente                                                │
│       ↓ usa hook                                            │
│   TanStack Query Hook (useOrders, useOrderById)             │
│       ↓ chama função                                        │
│   API Function (ordersApi.getAll, ordersApi.getById)        │
│       ↓ usa                                                 │
│   Axios Instance (apiClient — com interceptors)             │
│       ↓ HTTP                                                │
│   Backend Java (API Gateway → Microserviço)                 │
└─────────────────────────────────────────────────────────────┘
```

> **Analogia com Java:** O componente é o Controller, o TanStack Query Hook é o Service, a API Function é o Repository (interface), e o Axios é o RestTemplate/WebClient. Cada camada tem uma responsabilidade única.

---

## 5.2 Configurar o Axios Client

### `src/shared/api/client.ts`

```typescript
import axios, { type InternalAxiosRequestConfig, type AxiosError } from 'axios';
import { useAuthStore } from '@/features/auth/hooks/useAuthStore';

export const apiClient = axios.create({
  baseURL: '/api',
  timeout: 15_000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Interceptor de REQUEST — adiciona o token JWT em toda request
apiClient.interceptors.request.use(
  (config: InternalAxiosRequestConfig) => {
    const token = useAuthStore.getState().token;
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
);

// Interceptor de RESPONSE — trata erros globais
apiClient.interceptors.response.use(
  (response) => response,
  (error: AxiosError) => {
    if (error.response?.status === 401) {
      // Token expirado ou inválido → logout
      useAuthStore.getState().logout();
      window.location.href = '/login';
    }
    return Promise.reject(error);
  },
);

// ⚠️ EVOLUÇÃO: Na Fase 06, este client será atualizado para:
//   - Usar `accessToken` em vez de `token` (a AuthStore ganha refresh token)
//   - Incluir lógica de refresh token com fila de requests pendentes
//   - Veja a versão completa em fase-06-autenticacao.md § 6.5
```

**Explicação:**

| Parte | O que faz |
|---|---|
| `baseURL: '/api'` | Todas as requests começam com `/api`. O Vite proxy redireciona para `localhost:8080` |
| `timeout: 15_000` | 15 segundos de timeout |
| Request interceptor | Lê o token do Zustand e adiciona `Authorization: Bearer <token>` em toda request |
| Response interceptor | Se receber 401, faz logout automático e redireciona para login |
| `useAuthStore.getState()` | Acessa o Zustand **fora** de um componente React (sem hook) |

> **Analogia com Java:** O request interceptor é como um `OncePerRequestFilter` do Spring Security que adiciona o token. O response interceptor é como um `@ControllerAdvice` global que trata 401.

---

## 5.3 Definir Tipos da API

### `src/features/orders/types/index.ts`

```typescript
export type OrderStatus =
  | 'PENDING'
  | 'CONFIRMED'
  | 'PREPARING'
  | 'READY'
  | 'OUT_FOR_DELIVERY'
  | 'DELIVERED'
  | 'CANCELLED';

export interface OrderItem {
  id: string;
  menuItemId: string;
  name: string;
  quantity: number;
  unitPrice: number;
  totalPrice: number;
}

export interface Order {
  id: string;
  customerId: string;
  customerName: string;
  restaurantId: string;
  restaurantName: string;
  items: OrderItem[];
  status: OrderStatus;
  totalAmount: number;
  deliveryAddress: string;
  createdAt: string;
  updatedAt: string;
}

export interface CreateOrderRequest {
  customerId: string;
  restaurantId: string;
  items: {
    menuItemId: string;
    quantity: number;
  }[];
  deliveryAddress: string;
}

export interface UpdateOrderStatusRequest {
  status: OrderStatus;
}
```

> **Esses tipos espelham os DTOs do Java.** No backend, você tem `OrderResponse`, `CreateOrderRequest`, etc. Aqui definimos as mesmas estruturas em TypeScript. Quando a API mudar, atualize esses tipos e o TypeScript apontará todos os lugares afetados.

---

## 5.4 Criar Funções de API

### `src/features/orders/api/ordersApi.ts`

```typescript
import { apiClient } from '@/shared/api/client';
import type { PaginatedResponse, PaginationParams } from '@/shared/types';
import type { Order, CreateOrderRequest, UpdateOrderStatusRequest } from '../types';

export const ordersApi = {
  getAll: async (params: PaginationParams & { status?: string }) => {
    const { data } = await apiClient.get<PaginatedResponse<Order>>('/orders', { params });
    return data;
  },

  getById: async (id: string) => {
    const { data } = await apiClient.get<Order>(`/orders/${id}`);
    return data;
  },

  create: async (request: CreateOrderRequest) => {
    const { data } = await apiClient.post<Order>('/orders', request);
    return data;
  },

  updateStatus: async (id: string, request: UpdateOrderStatusRequest) => {
    const { data } = await apiClient.patch<Order>(`/orders/${id}/status`, request);
    return data;
  },

  cancel: async (id: string) => {
    const { data } = await apiClient.patch<Order>(`/orders/${id}/cancel`);
    return data;
  },
};
```

> **Por que separar funções da API?** Isola a comunicação HTTP em um lugar só. Se a URL mudar de `/orders` para `/v2/orders`, altera em um lugar. Os hooks de TanStack Query chamam essas funções.

---

## 5.5 Configurar TanStack Query

### `src/app/providers/QueryProvider.tsx`

```tsx
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ReactQueryDevtools } from '@tanstack/react-query-devtools';
import type { ReactNode } from 'react';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000,       // 5 minutos — dados são "frescos" por 5 min
      gcTime: 10 * 60 * 1000,          // 10 minutos — cache é coletado após 10 min
      retry: 1,                         // 1 retry em caso de erro
      refetchOnWindowFocus: true,       // Refetch quando o usuário volta à aba
      refetchOnReconnect: true,         // Refetch quando reconecta à internet
    },
  },
});

export function QueryProvider({ children }: { children: ReactNode }) {
  return (
    <QueryClientProvider client={queryClient}>
      {children}
      <ReactQueryDevtools initialIsOpen={false} />
    </QueryClientProvider>
  );
}
```

**Explicação dos parâmetros:**

| Parâmetro | O que faz | Analogia Java |
|---|---|---|
| `staleTime` | Tempo que os dados são considerados válidos | `@Cacheable(ttl = 300)` |
| `gcTime` | Tempo até o cache ser removido da memória | Eviction policy do cache |
| `retry` | Quantas vezes tenta novamente em caso de erro | Retry policy do Resilience4j |
| `refetchOnWindowFocus` | Rebusca dados quando o usuário volta à aba | Sem equivalente direto — é UX |

### Montar no App

```tsx
// src/app/App.tsx
import { RouterProvider } from 'react-router-dom';
import { QueryProvider } from './providers/QueryProvider';
import { router } from './router/routes';

function App() {
  return (
    <QueryProvider>
      <RouterProvider router={router} />
    </QueryProvider>
  );
}

export default App;
```

---

## 5.6 Criar Hooks de Data Fetching

### `src/features/orders/hooks/useOrders.ts`

```typescript
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import type { PaginationParams } from '@/shared/types';
import { ordersApi } from '../api/ordersApi';
import type { CreateOrderRequest, UpdateOrderStatusRequest } from '../types';

// Query Keys — identificadores únicos para cada query no cache
export const orderKeys = {
  all: ['orders'] as const,
  lists: () => [...orderKeys.all, 'list'] as const,
  list: (params: PaginationParams & { status?: string }) =>
    [...orderKeys.lists(), params] as const,
  details: () => [...orderKeys.all, 'detail'] as const,
  detail: (id: string) => [...orderKeys.details(), id] as const,
};

/** Hook para listar pedidos com paginação */
export function useOrders(params: PaginationParams & { status?: string }) {
  return useQuery({
    queryKey: orderKeys.list(params),
    queryFn: () => ordersApi.getAll(params),
  });
}

/** Hook para buscar um pedido por ID */
export function useOrder(id: string) {
  return useQuery({
    queryKey: orderKeys.detail(id),
    queryFn: () => ordersApi.getById(id),
    enabled: !!id, // não executa se id for undefined/empty
  });
}

/** Hook para criar um pedido */
export function useCreateOrder() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (request: CreateOrderRequest) => ordersApi.create(request),
    onSuccess: () => {
      // Invalida o cache da lista — força refetch
      queryClient.invalidateQueries({ queryKey: orderKeys.lists() });
    },
  });
}

/** Hook para atualizar status de um pedido */
export function useUpdateOrderStatus() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, request }: { id: string; request: UpdateOrderStatusRequest }) =>
      ordersApi.updateStatus(id, request),
    onSuccess: (_data, variables) => {
      // Invalida tanto a lista quanto o detalhe do pedido
      queryClient.invalidateQueries({ queryKey: orderKeys.lists() });
      queryClient.invalidateQueries({ queryKey: orderKeys.detail(variables.id) });
    },
  });
}
```

**Conceitos do TanStack Query:**

| Conceito | O que faz |
|---|---|
| `queryKey` | Identificador único no cache. Se os params mudam, é uma query diferente |
| `queryFn` | Função que busca os dados (chama a API) |
| `enabled` | Booleano que controla se a query executa ou não |
| `useQuery` | Hook para **leitura** — GET requests |
| `useMutation` | Hook para **escrita** — POST/PUT/PATCH/DELETE |
| `invalidateQueries` | Marca queries como "stale" → dispara refetch automático |
| `queryClient` | Instância global que gerencia todo o cache |

> **Analogia Java:** `queryKey` é como a chave do cache (`@Cacheable(key = "#id")`). `invalidateQueries` é como `@CacheEvict`. O TanStack Query é, essencialmente, um cache layer inteligente para o frontend.

---

## 5.7 Usando os Hooks em Componentes

### Lista de pedidos

```tsx
// src/features/orders/pages/OrdersPage.tsx
import { useSearchParams } from 'react-router-dom';
import { useOrders } from '../hooks/useOrders';
import { Card, CardContent, CardHeader, CardTitle } from '@/shared/components/ui/card';
import { Badge } from '@/shared/components/ui/badge';
import { Button } from '@/shared/components/ui/button';

function OrdersPage() {
  const [searchParams, setSearchParams] = useSearchParams();
  const page = Number(searchParams.get('page') ?? '0');
  const status = searchParams.get('status') ?? undefined;

  // O hook retorna: data, isLoading, isError, error, refetch
  const { data, isLoading, isError, error } = useOrders({
    page,
    size: 10,
    status,
  });

  if (isLoading) {
    return (
      <div className="flex justify-center py-12">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary" />
      </div>
    );
  }

  if (isError) {
    return (
      <div className="text-center py-12">
        <p className="text-destructive">Erro ao carregar pedidos</p>
        <p className="text-sm text-muted-foreground mt-2">{error.message}</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Pedidos</h1>
        <p className="text-sm text-muted-foreground">
          {data?.totalElements} pedidos encontrados
        </p>
      </div>

      <div className="grid gap-4">
        {data?.content.map((order) => (
          <Card key={order.id}>
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-base">Pedido #{order.id}</CardTitle>
              <Badge>{order.status}</Badge>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground">
                {order.restaurantName} — R$ {order.totalAmount.toFixed(2)}
              </p>
            </CardContent>
          </Card>
        ))}
      </div>

      {/* Paginação */}
      <div className="flex justify-center gap-2">
        <Button
          variant="outline"
          size="sm"
          disabled={data?.first}
          onClick={() => setSearchParams({ page: String(page - 1) })}
        >
          Anterior
        </Button>
        <span className="flex items-center text-sm text-muted-foreground">
          Página {(data?.number ?? 0) + 1} de {data?.totalPages}
        </span>
        <Button
          variant="outline"
          size="sm"
          disabled={data?.last}
          onClick={() => setSearchParams({ page: String(page + 1) })}
        >
          Próxima
        </Button>
      </div>
    </div>
  );
}

export default OrdersPage;
```

### Detalhe do pedido

```tsx
// src/features/orders/pages/OrderDetailPage.tsx
import { useParams, useNavigate } from 'react-router-dom';
import { useOrder, useUpdateOrderStatus } from '../hooks/useOrders';
import { Button } from '@/shared/components/ui/button';

function OrderDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { data: order, isLoading } = useOrder(id!);
  const updateStatus = useUpdateOrderStatus();

  if (isLoading || !order) {
    return <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto" />;
  }

  function handleConfirm() {
    updateStatus.mutate(
      { id: order.id, request: { status: 'CONFIRMED' } },
      { onSuccess: () => navigate('/orders') },
    );
  }

  return (
    <div className="space-y-6 max-w-2xl">
      <Button variant="outline" size="sm" onClick={() => navigate('/orders')}>
        ← Voltar
      </Button>

      <h1 className="text-2xl font-bold">Pedido #{order.id}</h1>

      <div className="grid grid-cols-2 gap-4 text-sm">
        <div>
          <span className="text-muted-foreground">Cliente:</span>
          <p className="font-medium">{order.customerName}</p>
        </div>
        <div>
          <span className="text-muted-foreground">Restaurante:</span>
          <p className="font-medium">{order.restaurantName}</p>
        </div>
        <div>
          <span className="text-muted-foreground">Status:</span>
          <p className="font-medium">{order.status}</p>
        </div>
        <div>
          <span className="text-muted-foreground">Total:</span>
          <p className="font-medium">R$ {order.totalAmount.toFixed(2)}</p>
        </div>
      </div>

      <h2 className="text-lg font-semibold">Itens</h2>
      <div className="border border-border rounded-lg divide-y divide-border">
        {order.items.map((item) => (
          <div key={item.id} className="flex justify-between p-3 text-sm">
            <span>{item.quantity}x {item.name}</span>
            <span className="font-medium">R$ {item.totalPrice.toFixed(2)}</span>
          </div>
        ))}
      </div>

      {order.status === 'PENDING' && (
        <Button onClick={handleConfirm} disabled={updateStatus.isPending}>
          {updateStatus.isPending ? 'Confirmando...' : 'Confirmar Pedido'}
        </Button>
      )}
    </div>
  );
}

export default OrderDetailPage;
```

---

## 5.8 Ciclo de Vida do TanStack Query

```
┌──────────────────────────────────────────────────────────┐
│              Estado de uma Query                          │
│                                                          │
│   1. Componente monta → useQuery executa queryFn         │
│      Estado: isLoading = true                            │
│                  │                                       │
│                  ▼                                       │
│   2. API responde com sucesso                            │
│      Estado: data = {...}, isLoading = false              │
│      Cache: armazenado por 5 min (staleTime)             │
│                  │                                       │
│                  ▼                                       │
│   3. Após staleTime, dados ficam "stale"                 │
│      Próximo acesso: mostra cache + refetch em background │
│                  │                                       │
│                  ▼                                       │
│   4. Mutation (POST/PATCH) → invalidateQueries           │
│      Cache marcado como stale → refetch automático       │
│                  │                                       │
│                  ▼                                       │
│   5. Componente desmonta                                 │
│      Cache persiste por gcTime (10 min)                  │
│      Se remontar antes: dados disponíveis instantaneamente│
└──────────────────────────────────────────────────────────┘
```

> **Stale-While-Revalidate:** Mostra dados cacheados (resposta instantânea) enquanto busca dados novos em background. Se os dados novos forem diferentes, a UI atualiza automaticamente. O usuário quase nunca vê loading.

---

## 5.9 Tratamento de Erro Global

### `src/shared/api/handleApiError.ts`

```typescript
import type { AxiosError } from 'axios';
import type { ApiError } from '@/shared/types';

export function getErrorMessage(error: unknown): string {
  if (error instanceof Error) {
    const axiosError = error as AxiosError<ApiError>;
    if (axiosError.response?.data?.detail) {
      return axiosError.response.data.detail;
    }
    if (axiosError.response?.status === 404) {
      return 'Recurso não encontrado.';
    }
    if (axiosError.response?.status === 403) {
      return 'Você não tem permissão para esta ação.';
    }
    if (axiosError.code === 'ECONNABORTED') {
      return 'Tempo de conexão esgotado. Tente novamente.';
    }
    if (!axiosError.response) {
      return 'Sem conexão com o servidor. Verifique sua internet.';
    }
    return axiosError.message;
  }
  return 'Erro inesperado. Tente novamente.';
}
```

> **O backend retorna `ProblemDetail` (RFC 7807)** com campo `detail`. Esse helper extrai a mensagem mais útil para o usuário.

---

## 5.10 Resumo dos Conceitos

| Conceito | Descrição | Analogia Java |
|---|---|---|
| Axios instance | HTTP client configurado | `RestTemplate` / `WebClient` |
| Request interceptor | Adiciona headers em toda request | `OncePerRequestFilter` |
| Response interceptor | Trata erros globais | `@ControllerAdvice` |
| `useQuery` | Busca e cacheia dados (GET) | `@Cacheable` no Service |
| `useMutation` | Envia dados (POST/PUT/DELETE) | Service method que altera estado |
| `queryKey` | Identificador único no cache | Chave do cache |
| `invalidateQueries` | Limpa cache após mutation | `@CacheEvict` |
| `staleTime` | Tempo de validade dos dados | TTL do cache |
| Query DevTools | Visualiza estado do cache | Cache dashboard |

---

## 5.11 Perguntas Frequentes em Entrevista

| # | Pergunta | Resposta |
|---|---|---|
| 1 | **O que é TanStack Query e por que usar?** | É uma lib de data fetching que gerencia cache, loading states, error states, refetch automático, e sincronização com o servidor. Sem ela, você gerenciaria tudo manualmente com useState + useEffect — muito mais código e propenso a bugs (race conditions, stale data, etc.). |
| 2 | **Qual a diferença entre `staleTime` e `gcTime`?** | `staleTime` é quanto tempo os dados são considerados frescos (não refetch). `gcTime` é quanto tempo o cache fica na memória após o componente desmontar. staleTime controla UX, gcTime controla memória. |
| 3 | **O que é o padrão stale-while-revalidate?** | Mostra dados do cache imediatamente (sem loading) e faz um refetch em background. Se os dados novos forem diferentes, a UI atualiza sem que o usuário perceba. Resultado: UX extremamente rápida. |
| 4 | **Por que usar interceptors no Axios?** | Centraliza lógica que precisa rodar em toda request/response: adicionar token JWT (request), tratar 401 (response), logging, retry. Sem interceptors, você repetiria esse código em toda chamada. |
| 5 | **Como invalidar o cache após uma mutation?** | Use `queryClient.invalidateQueries({ queryKey: [...] })` no `onSuccess` da mutation. Isso marca as queries como stale e dispara refetch automático. O cache fica sempre sincronizado com o servidor. |

---

> **Próximo passo:** [Fase 06 — Autenticação](fase-06-autenticacao.md)
