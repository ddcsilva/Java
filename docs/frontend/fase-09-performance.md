# Fase 09 — Performance e Otimização

> **Objetivo:** Aplicar técnicas de otimização de performance no React — lazy loading, memoização, virtualização de listas, análise de bundle e métricas Web Vitals.

---

## 9.1 Onde a Performance Importa

```
┌─────────────────────────────────────────────────────────┐
│              Gargalos de Performance no Frontend          │
│                                                         │
│  1. Bundle grande → First Load lento                    │
│     Solução: code splitting, tree-shaking, lazy loading │
│                                                         │
│  2. Re-renders desnecessários → UI travada              │
│     Solução: React.memo, useMemo, useCallback           │
│                                                         │
│  3. Listas enormes → scroll lag                         │
│     Solução: virtualização (TanStack Virtual)           │
│                                                         │
│  4. Imagens pesadas → carregamento lento                │
│     Solução: lazy loading, WebP, responsive images      │
│                                                         │
│  5. API lenta → tela em branco                          │
│     Solução: Suspense, skeleton, stale-while-revalidate │
└─────────────────────────────────────────────────────────┘
```

---

## 9.2 Code Splitting com React.lazy

Code splitting já foi configurado na Fase 03 (lazy por rota). Mas também pode ser feito por componente:

```tsx
import { lazy, Suspense } from 'react';

// Componente pesado (gráfico) carregado sob demanda
const RevenueChart = lazy(() => import('./RevenueChart'));

function DashboardPage() {
  return (
    <div>
      <h1>Dashboard</h1>

      {/* Stats cards (rápidos — renderizam imediato) */}
      <StatsGrid />

      {/* Gráfico (pesado — carregado lazy) */}
      <Suspense fallback={<ChartSkeleton />}>
        <RevenueChart />
      </Suspense>
    </div>
  );
}
```

> **Quando usar lazy por componente?** Para componentes pesados que não aparecem imediatamente (modais, gráficos abaixo da dobra, tabs secundárias). O chunk é baixado só quando o componente precisa renderizar.

---

## 9.3 React.memo — Evitar Re-renders

`React.memo` "memoriza" um componente — ele só re-renderiza se suas props mudarem:

```tsx
import { memo } from 'react';

interface OrderCardProps {
  id: string;
  title: string;
  total: number;
  status: string;
  onSelect: (id: string) => void;
}

const OrderCard = memo(function OrderCard({ id, title, total, status, onSelect }: OrderCardProps) {
  console.log(`OrderCard ${id} renderizou`); // para debug

  return (
    <div
      className="rounded-lg border border-border p-4 cursor-pointer hover:bg-accent"
      onClick={() => onSelect(id)}
    >
      <h3 className="font-medium">{title}</h3>
      <p className="text-sm text-muted-foreground">R$ {total.toFixed(2)}</p>
      <span className="text-xs">{status}</span>
    </div>
  );
});

export default OrderCard;
```

### Problema: `onSelect` recria a cada render

```tsx
function OrderList({ orders }: { orders: Order[] }) {
  // ❌ PROBLEMA: nova função a cada render → OrderCard re-renderiza sempre
  // function handleSelect(id: string) { ... }

  // ✅ SOLUÇÃO: useCallback mantém referência estável
  const handleSelect = useCallback((id: string) => {
    navigate(`/orders/${id}`);
  }, [navigate]);

  return orders.map((o) => (
    <OrderCard key={o.id} {...o} onSelect={handleSelect} />
  ));
}
```

> **Quando usar memo?** Componentes que (1) renderizam frequentemente, (2) recebem as mesmas props na maioria dos renders, (3) são custosos de renderizar. Não use em componentes simples — o overhead do memo pode ser maior que o re-render.

---

## 9.4 Virtualização de Listas

Para listas com 1000+ itens, renderizar tudo no DOM causa lag. Virtualização renderiza apenas os itens **visíveis na tela**:

```bash
npm install @tanstack/react-virtual
```

```tsx
import { useVirtualizer } from '@tanstack/react-virtual';
import { useRef } from 'react';

interface VirtualOrderListProps {
  orders: Order[];
}

function VirtualOrderList({ orders }: VirtualOrderListProps) {
  const parentRef = useRef<HTMLDivElement>(null);

  const virtualizer = useVirtualizer({
    count: orders.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 80, // altura estimada de cada item em px
  });

  return (
    <div ref={parentRef} className="h-[600px] overflow-auto">
      <div
        style={{
          height: `${virtualizer.getTotalSize()}px`,
          position: 'relative',
        }}
      >
        {virtualizer.getVirtualItems().map((virtualRow) => (
          <div
            key={virtualRow.key}
            style={{
              position: 'absolute',
              top: 0,
              left: 0,
              width: '100%',
              height: `${virtualRow.size}px`,
              transform: `translateY(${virtualRow.start}px)`,
            }}
          >
            <OrderCard {...orders[virtualRow.index]} />
          </div>
        ))}
      </div>
    </div>
  );
}
```

> **Analogia com Java:** Virtualização é como **paginação no backend** — em vez de trazer 10.000 registros, traz só os 20 visíveis. A diferença é que a virtualização é client-side (todos os dados estão na memória, mas só os visíveis estão no DOM).

---

## 9.5 Skeleton Loading

Em vez de spinner genérico, use skeletons que simulam o layout final:

```tsx
function OrderCardSkeleton() {
  return (
    <div className="rounded-lg border border-border p-4 animate-pulse">
      <div className="h-4 bg-muted rounded w-3/4 mb-3" />
      <div className="h-3 bg-muted rounded w-1/2 mb-2" />
      <div className="h-3 bg-muted rounded w-1/4" />
    </div>
  );
}

function OrdersPageSkeleton() {
  return (
    <div className="space-y-4">
      <div className="h-8 bg-muted rounded w-48 animate-pulse" />
      {Array.from({ length: 5 }).map((_, i) => (
        <OrderCardSkeleton key={i} />
      ))}
    </div>
  );
}
```

```tsx
// Uso
const { data, isLoading } = useOrders(params);

if (isLoading) return <OrdersPageSkeleton />;
```

> **Por que skeleton?** Pesquisas de UX mostram que skeletons fazem o carregamento parecer mais rápido que spinners. O usuário vê a "forma" do conteúdo e sabe o que esperar. Google, Facebook e LinkedIn usam skeletons extensivamente.

---

## 9.6 Debounce em Inputs de Busca

Quando um campo de busca faz request a cada keystroke, é ineficiente. Debounce espera o usuário parar de digitar:

```typescript
// src/shared/hooks/useDebounce.ts
import { useState, useEffect } from 'react';

export function useDebounce<T>(value: T, delay: number): T {
  const [debouncedValue, setDebouncedValue] = useState(value);

  useEffect(() => {
    const timer = setTimeout(() => setDebouncedValue(value), delay);
    return () => clearTimeout(timer);
  }, [value, delay]);

  return debouncedValue;
}
```

```tsx
function OrderSearchBar() {
  const [search, setSearch] = useState('');
  const debouncedSearch = useDebounce(search, 300); // 300ms

  // TanStack Query só refetch quando debouncedSearch mudar
  const { data } = useOrders({ search: debouncedSearch, page: 0, size: 10 });

  return (
    <Input
      placeholder="Buscar pedidos..."
      value={search}
      onChange={(e) => setSearch(e.target.value)}
    />
  );
}
```

---

## 9.7 Análise de Bundle

```bash
# Instalar visualizer
npm install -D rollup-plugin-visualizer

# Adicionar ao vite.config.ts
import { visualizer } from 'rollup-plugin-visualizer';

export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
    visualizer({ open: true, gzipSize: true }),
  ],
  // ...
});

# Gerar build e abrir análise
npm run build
```

O visualizer gera um treemap interativo mostrando o tamanho de cada pacote. Use para identificar dependências pesadas que podem ser substituídas ou code-split.

---

## 9.8 Web Vitals — Métricas de Performance

| Métrica | O que mede | Meta |
|---|---|---|
| **LCP** (Largest Contentful Paint) | Tempo até o maior elemento visível renderizar | < 2.5s |
| **FID** (First Input Delay) | Tempo de resposta à primeira interação | < 100ms |
| **CLS** (Cumulative Layout Shift) | Quanto o layout "pula" durante carregamento | < 0.1 |
| **TTFB** (Time to First Byte) | Tempo até o primeiro byte do servidor | < 800ms |
| **INP** (Interaction to Next Paint) | Latência geral de interações | < 200ms |

```typescript
// src/shared/lib/reportWebVitals.ts
import { onCLS, onFID, onLCP } from 'web-vitals';

export function reportWebVitals() {
  onCLS(console.log);
  onFID(console.log);
  onLCP(console.log);
}
```

---

## 9.9 Resumo dos Conceitos

| Conceito | Descrição | Quando usar |
|---|---|---|
| `React.lazy` | Carrega componente sob demanda | Rotas, modais, tabs pesadas |
| `React.memo` | Evita re-render se props iguais | Listas, componentes puros |
| `useMemo` | Cache de valor computado | Filtros, cálculos pesados |
| `useCallback` | Cache de referência de função | Callbacks passados como props |
| Virtualização | Renderiza só itens visíveis | Listas com 100+ itens |
| Skeleton | Placeholder de carregamento | Substituir spinners genéricos |
| Debounce | Atrasa execução até parar de mudar | Inputs de busca, filtros |
| Code splitting | Divide o bundle em chunks | Por rota (lazy) / por componente |
| Bundle analysis | Visualiza tamanho de dependências | Antes de releases |
| Web Vitals | Métricas de performance do Google | Monitoramento contínuo |

---

## 9.10 Perguntas Frequentes em Entrevista

| # | Pergunta | Resposta |
|---|---|---|
| 1 | **O que causa re-renders desnecessários no React?** | Mudança de state no pai (re-renderiza todos os filhos), nova referência de objeto/função em props, Context mudou. Soluções: memo, useMemo, useCallback, split Context. |
| 2 | **O que é virtualização de lista?** | Renderizar apenas os elementos visíveis no viewport enquanto mantém todos os dados em memória. O DOM fica leve (20 elementos em vez de 10.000), preservando scroll e performance. |
| 3 | **Quando NÃO otimizar?** | Quando não há problema mensurável. Otimização prematura é a raiz de todo mal. Use o React DevTools Profiler para identificar gargalos reais antes de aplicar memo/useMemo em tudo. |
| 4 | **O que são Web Vitals?** | Métricas do Google para performance web. LCP (carregamento visual), FID/INP (responsividade), CLS (estabilidade visual). Afetam SEO e UX. |
| 5 | **Como reduzir o bundle size?** | Code splitting (lazy routes), tree-shaking (importar só o necessário), substituir libs pesadas por leves, análise com visualizer, evitar polyfills desnecessários. |

---

> **Próximo passo:** [Fase 10 — Build, Docker e CI/CD](fase-10-build-deploy.md)
