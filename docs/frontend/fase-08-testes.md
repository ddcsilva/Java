# Fase 08 — Testes (Vitest + Testing Library + MSW + Playwright)

> **Objetivo:** Configurar a stack de testes, escrever testes unitários, de integração e E2E, mockar API com MSW e alcançar cobertura significativa nos fluxos críticos do FoodHub.

---

## 8.1 Pirâmide de Testes no Frontend

```
            ╱╲
           ╱  ╲          E2E (Playwright)
          ╱    ╲         Testa fluxos completos no browser real
         ╱──────╲        Lento, poucos testes (happy path)
        ╱        ╲
       ╱          ╲      Integração (Testing Library + MSW)
      ╱            ╲     Testa componentes com interação + API mockada
     ╱──────────────╲    Médio, testes dos fluxos principais
    ╱                ╲
   ╱                  ╲   Unitário (Vitest)
  ╱                    ╲  Testa funções puras, utils, hooks isolados
 ╱────────────────────── ╲ Rápido, muitos testes
```

| Camada | Ferramenta | O que testa | Analogia Java |
|---|---|---|---|
| **Unitário** | Vitest | Funções puras, utils, schemas Zod | JUnit 5 |
| **Integração** | Testing Library + MSW | Componentes renderizados + interação | @SpringBootTest + MockMvc |
| **E2E** | Playwright | Fluxos no browser real | Selenium / Testcontainers |

---

## 8.2 Configurar Vitest

### Instalar dependências

```bash
npm install -D vitest @testing-library/react @testing-library/jest-dom @testing-library/user-event jsdom msw
```

### `vitest.config.ts`

```typescript
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  test: {
    globals: true,                // describe, it, expect globais (sem import)
    environment: 'jsdom',         // simula DOM do browser
    setupFiles: ['./src/test/setup.ts'],
    include: ['src/**/*.{test,spec}.{ts,tsx}'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html', 'lcov'],
      include: ['src/**/*.{ts,tsx}'],
      exclude: ['src/test/**', 'src/**/*.d.ts', 'src/main.tsx'],
    },
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
});
```

### `src/test/setup.ts`

```typescript
import '@testing-library/jest-dom';
```

### Adicionar scripts ao `package.json`

```json
{
  "scripts": {
    "test": "vitest",
    "test:run": "vitest run",
    "test:coverage": "vitest run --coverage",
    "test:ui": "vitest --ui"
  }
}
```

| Script | O que faz | Analogia Java |
|---|---|---|
| `npm test` | Watch mode — re-executa ao mudar arquivos | `mvn test` com live reload |
| `npm run test:run` | Executa uma vez e sai | `mvn test` |
| `npm run test:coverage` | Gera relatório de cobertura | `mvn jacoco:report` |
| `npm run test:ui` | Interface visual dos testes | IntelliJ test runner |

---

## 8.3 Testes Unitários

### Testar a função `cn()`

```typescript
// src/shared/lib/utils.test.ts
import { cn } from './utils';

describe('cn', () => {
  it('combina classes simples', () => {
    expect(cn('px-4', 'py-2')).toBe('px-4 py-2');
  });

  it('remove classes condicionais falsas', () => {
    expect(cn('px-4', false && 'bg-red-500', 'py-2')).toBe('px-4 py-2');
  });

  it('resolve conflitos Tailwind', () => {
    expect(cn('px-4', 'px-6')).toBe('px-6');
  });

  it('aceita undefined e null', () => {
    expect(cn('px-4', undefined, null, 'py-2')).toBe('px-4 py-2');
  });
});
```

### Testar schema Zod

```typescript
// src/features/restaurants/types/restaurant.test.ts
import { createRestaurantSchema } from '.';

describe('createRestaurantSchema', () => {
  const validData = {
    name: 'Burger House',
    description: 'Hamburgueria artesanal no centro da cidade',
    category: 'BURGER' as const,
    phone: '(11) 99999-9999',
    address: {
      street: 'Rua das Flores',
      number: '123',
      neighborhood: 'Centro',
      city: 'São Paulo',
      state: 'SP',
      zipCode: '01234-567',
    },
    openingHours: 'Seg-Sex: 11h-23h',
    minimumOrder: 25,
    deliveryFee: 5.99,
  };

  it('valida dados corretos', () => {
    const result = createRestaurantSchema.safeParse(validData);
    expect(result.success).toBe(true);
  });

  it('rejeita nome curto', () => {
    const result = createRestaurantSchema.safeParse({ ...validData, name: 'AB' });
    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.error.errors[0].message).toContain('pelo menos 3');
    }
  });

  it('rejeita telefone inválido', () => {
    const result = createRestaurantSchema.safeParse({ ...validData, phone: '999' });
    expect(result.success).toBe(false);
  });

  it('rejeita categoria inválida', () => {
    const result = createRestaurantSchema.safeParse({ ...validData, category: 'INVALID' });
    expect(result.success).toBe(false);
  });

  it('aceita complemento opcional', () => {
    const data = { ...validData, address: { ...validData.address, complement: 'Apto 42' } };
    const result = createRestaurantSchema.safeParse(data);
    expect(result.success).toBe(true);
  });
});
```

> **`safeParse` vs `parse`:** `safeParse` retorna `{ success: true, data }` ou `{ success: false, error }` sem lançar exceção. `parse` lança `ZodError` se falhar. Em testes, `safeParse` é mais útil para verificar erros específicos.

---

## 8.4 Testes de Integração com Testing Library

Testing Library testa componentes **como o usuário interage** — não testa implementação interna:

```
❌ "O state mudou para X" (teste de implementação)
✅ "Após clicar no botão, aparece o texto Y" (teste de comportamento)
```

### Testar o componente `StatusBadge`

```tsx
// src/features/orders/components/StatusBadge.test.tsx
import { render, screen } from '@testing-library/react';
import StatusBadge from './StatusBadge';

describe('StatusBadge', () => {
  it('renderiza o status "Pendente" para pending', () => {
    render(<StatusBadge status="pending" />);
    expect(screen.getByText('Pendente')).toBeInTheDocument();
  });

  it('renderiza com cor verde para delivered', () => {
    render(<StatusBadge status="delivered" />);
    const badge = screen.getByText('Entregue');
    expect(badge).toHaveClass('bg-green-100');
  });

  it('aceita className customizada', () => {
    render(<StatusBadge status="pending" className="ml-4" />);
    const badge = screen.getByText('Pendente');
    expect(badge).toHaveClass('ml-4');
  });
});
```

### Queries do Testing Library

| Query | Quando usar | Analogia |
|---|---|---|
| `getByText('Texto')` | Elemento com texto visível | `driver.findElement(By.text)` |
| `getByRole('button')` | Por role de acessibilidade | `driver.findElement(By.role)` |
| `getByLabelText('Email')` | Input associado a um label | `driver.findElement(By.label)` |
| `getByPlaceholderText('...')` | Input com placeholder | |
| `getByTestId('id')` | Último recurso — `data-testid` | `driver.findElement(By.id)` |
| `queryByText('...')` | Retorna null se não encontrar | Para verificar ausência |
| `findByText('...')` | Async — espera aparecer | Para carregamento assíncrono |

> **Prioridade de queries:** `getByRole` > `getByLabelText` > `getByText` > `getByTestId`. Testing Library incentiva testes que refletem como o usuário interage — primeiro por acessibilidade.

---

## 8.5 Mock da API com MSW (Mock Service Worker)

MSW intercepta requests HTTP no nível de rede — não precisa mockar o Axios:

### `src/test/mocks/handlers.ts`

```typescript
import { http, HttpResponse } from 'msw';
import type { PaginatedResponse } from '@/shared/types';
import type { Order } from '@/features/orders/types';

const mockOrders: Order[] = [
  {
    id: '1',
    customerId: 'c1',
    customerName: 'João Silva',
    restaurantId: 'r1',
    restaurantName: 'Burger House',
    items: [{ id: 'i1', menuItemId: 'm1', name: 'X-Burger', quantity: 2, unitPrice: 25, totalPrice: 50 }],
    status: 'PENDING',
    totalAmount: 50,
    deliveryAddress: 'Rua das Flores, 123',
    createdAt: '2025-01-15T10:00:00Z',
    updatedAt: '2025-01-15T10:00:00Z',
  },
  {
    id: '2',
    customerId: 'c2',
    customerName: 'Maria Santos',
    restaurantId: 'r1',
    restaurantName: 'Burger House',
    items: [{ id: 'i2', menuItemId: 'm2', name: 'Batata Frita', quantity: 1, unitPrice: 15, totalPrice: 15 }],
    status: 'DELIVERED',
    totalAmount: 15,
    deliveryAddress: 'Av. Paulista, 456',
    createdAt: '2025-01-15T09:00:00Z',
    updatedAt: '2025-01-15T11:00:00Z',
  },
];

export const handlers = [
  http.get('/api/orders', ({ request }) => {
    const url = new URL(request.url);
    const page = Number(url.searchParams.get('page') ?? '0');
    const size = Number(url.searchParams.get('size') ?? '10');

    const response: PaginatedResponse<Order> = {
      content: mockOrders.slice(page * size, (page + 1) * size),
      totalElements: mockOrders.length,
      totalPages: Math.ceil(mockOrders.length / size),
      number: page,
      size,
      first: page === 0,
      last: (page + 1) * size >= mockOrders.length,
    };

    return HttpResponse.json(response);
  }),

  http.get('/api/orders/:id', ({ params }) => {
    const order = mockOrders.find((o) => o.id === params.id);
    if (!order) {
      return new HttpResponse(null, { status: 404 });
    }
    return HttpResponse.json(order);
  }),

  http.post('/api/auth/login', async ({ request }) => {
    const body = await request.json() as { email: string; password: string };
    if (body.email === 'admin@foodhub.com' && body.password === 'admin123') {
      return HttpResponse.json({
        accessToken: 'mock-access-token',
        refreshToken: 'mock-refresh-token',
        expiresIn: 900,
        user: { id: '1', name: 'Admin', email: 'admin@foodhub.com', role: 'ADMIN' },
      });
    }
    return HttpResponse.json(
      { type: 'about:blank', title: 'Unauthorized', status: 401, detail: 'Credenciais inválidas' },
      { status: 401 },
    );
  }),
];
```

### `src/test/mocks/server.ts`

```typescript
import { setupServer } from 'msw/node';
import { handlers } from './handlers';

export const server = setupServer(...handlers);
```

### Atualizar `src/test/setup.ts`

```typescript
import '@testing-library/jest-dom';
import { server } from './mocks/server';

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

---

## 8.6 Teste de Integração — Página de Pedidos

```tsx
// src/features/orders/pages/OrdersPage.test.tsx
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import OrdersPage from './OrdersPage';

function renderWithProviders(ui: React.ReactElement) {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false }, // não fazer retry em testes
    },
  });

  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter>
        {ui}
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

describe('OrdersPage', () => {
  it('mostra loading inicialmente', () => {
    renderWithProviders(<OrdersPage />);
    // O spinner ou skeleton deve aparecer enquanto carrega
  });

  it('renderiza pedidos após carregamento', async () => {
    renderWithProviders(<OrdersPage />);

    // findByText é async — espera o elemento aparecer
    expect(await screen.findByText('João Silva')).toBeInTheDocument();
    expect(await screen.findByText('Maria Santos')).toBeInTheDocument();
  });

  it('mostra o total correto', async () => {
    renderWithProviders(<OrdersPage />);
    expect(await screen.findByText(/R\$ 50,00/)).toBeInTheDocument();
  });

  it('mostra total de pedidos', async () => {
    renderWithProviders(<OrdersPage />);
    expect(await screen.findByText('2 pedidos encontrados')).toBeInTheDocument();
  });
});
```

**Por que `renderWithProviders`?** Componentes que usam React Router, TanStack Query ou Context precisam de seus providers. No teste, envolvemos com `MemoryRouter` (router em memória) e `QueryClientProvider` (client fresh para cada teste).

---

## 8.7 Teste de Interação — Login

```tsx
// src/features/auth/pages/LoginPage.test.tsx
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import LoginPage from './LoginPage';

const mockNavigate = vi.fn();
vi.mock('react-router-dom', async () => {
  const actual = await vi.importActual('react-router-dom');
  return { ...actual, useNavigate: () => mockNavigate };
});

describe('LoginPage', () => {
  it('faz login com sucesso', async () => {
    const user = userEvent.setup();
    render(
      <MemoryRouter>
        <LoginPage />
      </MemoryRouter>,
    );

    await user.type(screen.getByLabelText('Email'), 'admin@foodhub.com');
    await user.type(screen.getByLabelText('Senha'), 'admin123');
    await user.click(screen.getByRole('button', { name: 'Entrar' }));

    // Espera o redirect após login
    await vi.waitFor(() => {
      expect(mockNavigate).toHaveBeenCalledWith('/', { replace: true });
    });
  });

  it('mostra erro com credenciais inválidas', async () => {
    const user = userEvent.setup();
    render(
      <MemoryRouter>
        <LoginPage />
      </MemoryRouter>,
    );

    await user.type(screen.getByLabelText('Email'), 'wrong@email.com');
    await user.type(screen.getByLabelText('Senha'), 'wrong');
    await user.click(screen.getByRole('button', { name: 'Entrar' }));

    expect(await screen.findByText('Credenciais inválidas')).toBeInTheDocument();
  });
});
```

> **`userEvent`** simula interações reais do usuário (digitar, clicar, tab). É mais realista que `fireEvent` (que dispara eventos diretamente no DOM).

---

## 8.8 Testes E2E com Playwright

### Instalar

```bash
npm install -D @playwright/test
npx playwright install
```

### `playwright.config.ts`

```typescript
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  webServer: {
    command: 'npm run dev',
    port: 5173,
    reuseExistingServer: !process.env.CI,
  },
  use: {
    baseURL: 'http://localhost:5173',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
});
```

### `e2e/login.spec.ts`

```typescript
import { test, expect } from '@playwright/test';

test.describe('Login', () => {
  test('fluxo completo de login', async ({ page }) => {
    await page.goto('/login');

    await page.getByLabel('Email').fill('admin@foodhub.com');
    await page.getByLabel('Senha').fill('admin123');
    await page.getByRole('button', { name: 'Entrar' }).click();

    // Após login, deve ir para o dashboard
    await expect(page).toHaveURL('/');
    await expect(page.getByText('Dashboard')).toBeVisible();
  });
});
```

---

## 8.9 Resumo dos Conceitos

| Conceito | Descrição | Analogia Java |
|---|---|---|
| Vitest | Test runner rápido (compatível com Jest API) | JUnit 5 |
| Testing Library | Testa comportamento, não implementação | AssertJ + Spring MockMvc |
| MSW | Intercepta HTTP e retorna mocks | WireMock / MockServer |
| Playwright | Testa no browser real | Selenium WebDriver |
| `render()` | Renderiza componente no jsdom | `MockMvc.perform()` |
| `screen.getBy*` | Encontra elementos na tela | `mockMvc.andExpect()` |
| `userEvent` | Simula interações do usuário | `perform(post(...))` |
| `findBy*` | Busca async (espera aparecer) | `await().until()` do Awaitility |
| Coverage | Relatório de linhas testadas | JaCoCo |

---

## 8.10 Perguntas Frequentes em Entrevista

| # | Pergunta | Resposta |
|---|---|---|
| 1 | **Qual a diferença entre Testing Library e Enzyme?** | Enzyme testa implementação interna (state, lifecycle). Testing Library testa comportamento do usuário (o que aparece na tela, interações). O ecossistema migrou para Testing Library — Enzyme era para class components. |
| 2 | **O que é MSW e por que não mockar o Axios?** | MSW intercepta no nível de rede — o código real (Axios, interceptors, etc.) executa normalmente. Mockar o Axios pula lógica real e pode mascarar bugs. MSW testa o fluxo completo: componente → hook → API function → Axios → MSW. |
| 3 | **Quando usar teste E2E vs integração?** | E2E testa fluxos críticos no browser real (login → dashboard → criar pedido). Integração testa componentes isolados com mocks. E2E é lento e frágil — use poucos. Integração é rápido — use bastante. |
| 4 | **O que é coverage e qual meta realista?** | Coverage mede % de linhas/branches executadas pelos testes. Meta realista: 70-80% geral, 90%+ para utils/hooks. 100% não significa código livre de bugs — foque em testar comportamentos importantes. |
| 5 | **Por que `retry: false` em testes?** | Em produção, TanStack Query faz retry automático em caso de erro. Em testes, retry causaria timeout e falsos positivos. Desabilitar retry faz o teste falhar imediatamente se a API mocada não responder. |
| 6 | **Como testar hooks customizados?** | Use `renderHook()` do Testing Library. Permite renderizar o hook isoladamente, chamar suas funções via `result.current`, e fazer `waitFor` em updates assíncronos. Para hooks que dependem de providers (QueryClient, Router), envolva com wrapper. |
| 7 | **O que é a abordagem "teste como o usuário"?** | Testing Library incentiva testar por behavior, não por implementação. Use `getByRole('button')` em vez de `getByTestId('submit-btn')`. Use `userEvent.click()` em vez de `fireEvent.click()`. Se o texto ou role muda, o teste quebra por motivo válido — significa que a UX mudou. |

---

> **Próximo passo:** [Fase 09 — Performance](fase-09-performance.md)
