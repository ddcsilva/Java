# Fase 02 — Componentes e Estilização

> **Objetivo:** Entender o modelo de componentes do React, criar componentes reutilizáveis com Tailwind CSS, instalar shadcn/ui, e aprender props, children, composição e tipagem.

---

## 2.1 O que é um Componente React?

Um componente é uma **função que retorna JSX** (HTML-like syntax). É a unidade fundamental do React — toda a UI é composta por componentes.

```tsx
// Componente mais simples possível
function Greeting() {
  return <h1>Olá, FoodHub!</h1>;
}
```

> **Analogia com Java:** Um componente React é como um **método que retorna HTML**. A diferença é que ele é declarativo (você descreve o que quer ver) em vez de imperativo (manipular o DOM diretamente).

### Anatomia de um componente

```tsx
// 1. Imports
import { ShoppingBag } from 'lucide-react';

// 2. Interface de Props (contrato de entrada — como parâmetros de método)
interface OrderCardProps {
  title: string;
  total: number;
  status: 'pending' | 'confirmed' | 'delivered';
}

// 3. Componente (função)
function OrderCard({ title, total, status }: OrderCardProps) {
  return (
    <div className="rounded-lg border border-border bg-card p-4">
      <div className="flex items-center gap-2">
        <ShoppingBag className="h-5 w-5 text-primary" />
        <h3 className="font-semibold">{title}</h3>
      </div>
      <p className="text-sm text-muted-foreground mt-2">
        Total: R$ {total.toFixed(2)}
      </p>
      <span className="text-xs mt-1 inline-block rounded-full px-2 py-0.5 bg-secondary">
        {status}
      </span>
    </div>
  );
}

// 4. Export
export default OrderCard;
```

**Mapeamento para Java:**

| React | Java |
|---|---|
| `interface OrderCardProps` | Parâmetros do construtor de um Record/DTO |
| `{ title, total, status }` | Destructuring — como se fosse `var title = props.title()` |
| `className="..."` | Atributo `class` do HTML (renomeado porque `class` é palavra reservada no JS) |
| `{title}` | Expressão dentro do JSX — renderiza o valor da variável |
| `{total.toFixed(2)}` | Qualquer expressão JavaScript válida entre `{}` |

---

## 2.2 Props — O Contrato do Componente

Props (properties) são os **parâmetros** de um componente. São **read-only** — o componente nunca modifica suas props.

```tsx
// Definição: interface com todas as props
interface ButtonProps {
  label: string;
  variant?: 'primary' | 'secondary' | 'destructive';  // ? = opcional
  size?: 'sm' | 'md' | 'lg';
  disabled?: boolean;
  onClick?: () => void;  // função callback
}

// Uso com valores padrão via destructuring
function Button({
  label,
  variant = 'primary',
  size = 'md',
  disabled = false,
  onClick,
}: ButtonProps) {
  const sizeClasses = {
    sm: 'px-3 py-1.5 text-sm',
    md: 'px-4 py-2 text-base',
    lg: 'px-6 py-3 text-lg',
  };

  const variantClasses = {
    primary: 'bg-primary text-primary-foreground hover:bg-primary/90',
    secondary: 'bg-secondary text-secondary-foreground hover:bg-secondary/80',
    destructive: 'bg-destructive text-destructive-foreground hover:bg-destructive/90',
  };

  return (
    <button
      className={`rounded-md font-medium transition-colors ${sizeClasses[size]} ${variantClasses[variant]} disabled:opacity-50 disabled:cursor-not-allowed`}
      disabled={disabled}
      onClick={onClick}
    >
      {label}
    </button>
  );
}
```

### Usando o componente

```tsx
// Em outro componente
function OrderActions() {
  return (
    <div className="flex gap-2">
      <Button label="Confirmar" variant="primary" onClick={() => console.log('confirmou!')} />
      <Button label="Cancelar" variant="destructive" />
      <Button label="Salvar" disabled />
    </div>
  );
}
```

> **Regra de ouro das Props:** Dados fluem de cima para baixo (pai → filho). Se o componente filho precisa "avisar" o pai de algo, ele chama uma função callback recebida via props (como `onClick`).

---

## 2.3 Children — Composição de Componentes

`children` é uma prop especial que contém tudo que está **entre as tags** do componente:

```tsx
import { type ReactNode } from 'react';

interface CardProps {
  title: string;
  children: ReactNode;
}

function Card({ title, children }: CardProps) {
  return (
    <div className="rounded-lg border border-border bg-card">
      <div className="border-b border-border px-4 py-3">
        <h3 className="font-semibold">{title}</h3>
      </div>
      <div className="p-4">{children}</div>
    </div>
  );
}

// Uso
function Dashboard() {
  return (
    <Card title="Pedidos Recentes">
      <p>Aqui vai qualquer conteúdo</p>
      <OrderCard title="Pedido #1" total={45.90} status="pending" />
      <OrderCard title="Pedido #2" total={32.00} status="confirmed" />
    </Card>
  );
}
```

> **Analogia com Java:** `children` é como o **corpo de um método template** — o Card define a estrutura externa (borda, título), e quem usa define o conteúdo interno.

> **`ReactNode`** é o tipo que aceita qualquer coisa renderizável: string, número, JSX, array, null. É o tipo mais flexível para children.

---

## 2.4 Tailwind CSS — Estilização Utility-First

Em vez de escrever CSS em arquivos separados, Tailwind usa **classes utilitárias** diretamente no JSX:

### Referência rápida

| Categoria | Classes | Equivalente CSS |
|---|---|---|
| **Espaçamento** | `p-4`, `px-2`, `my-6`, `gap-4` | `padding: 1rem`, `padding-inline: 0.5rem` |
| **Flexbox** | `flex`, `items-center`, `justify-between` | `display: flex`, `align-items: center` |
| **Grid** | `grid`, `grid-cols-3`, `col-span-2` | `display: grid`, `grid-template-columns` |
| **Tipografia** | `text-lg`, `font-bold`, `text-muted-foreground` | `font-size: 1.125rem`, `font-weight: 700` |
| **Bordas** | `border`, `rounded-lg`, `border-border` | `border: 1px solid`, `border-radius: 0.5rem` |
| **Cores** | `bg-primary`, `text-foreground`, `bg-card` | `background-color: var(--color-primary)` |
| **Hover** | `hover:bg-primary/90` | `.class:hover { opacity: 0.9 }` |
| **Responsivo** | `md:grid-cols-3`, `lg:px-8` | `@media (min-width: 768px)` |
| **Transição** | `transition-colors`, `duration-200` | `transition: color 200ms` |

### Mobile-first approach

Tailwind é **mobile-first** — as classes sem prefixo valem para telas pequenas. Prefixos adicionam media queries:

```tsx
<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
  {/* 1 coluna no mobile, 2 no tablet, 3 no desktop */}
</div>
```

| Prefixo | Breakpoint | Dispositivo |
|---|---|---|
| (nenhum) | `< 768px` | Celular |
| `md:` | `≥ 768px` | Tablet |
| `lg:` | `≥ 1024px` | Desktop |
| `xl:` | `≥ 1280px` | Desktop grande |

---

## 2.5 Instalar e Configurar shadcn/ui

shadcn/ui não é uma biblioteca — são **componentes vendored** (copiados para o projeto). Você tem controle total sobre o código.

### Inicializar

```bash
npx shadcn@latest init
```

Responda as perguntas:

```
✔ Which style would you like to use? → New York
✔ Which color would you like to use as base color? → Orange
✔ Would you like to use CSS variables for colors? → yes
```

### Instalar componentes que usaremos

```bash
npx shadcn@latest add button badge card input label select separator table textarea toast dialog dropdown-menu avatar sheet tabs
```

Os componentes são copiados para `src/shared/components/ui/`. Cada arquivo é um componente completo que você pode modificar livremente.

> **Diferença do Material UI / Ant Design:** Essas libs são pacotes npm — você estiliza via props/themes. O shadcn/ui copia o código fonte para o seu projeto. Vantagem: controle total, sem lock-in, sem overhead de runtime.

### Usando componentes shadcn/ui

```tsx
import { Button } from '@/shared/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/shared/components/ui/card';
import { Badge } from '@/shared/components/ui/badge';

function OrderSummary() {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center justify-between">
          Pedido #1042
          <Badge variant="secondary">Em preparo</Badge>
        </CardTitle>
      </CardHeader>
      <CardContent>
        <p className="text-sm text-muted-foreground mb-4">
          2x Hambúrguer Artesanal, 1x Batata Frita
        </p>
        <div className="flex justify-between items-center">
          <span className="text-lg font-bold">R$ 67,90</span>
          <Button size="sm">Ver detalhes</Button>
        </div>
      </CardContent>
    </Card>
  );
}
```

---

## 2.6 Função `cn()` — Merge de Classes

A função `cn()` criada na Fase 01 é essencial para composição de estilos:

```tsx
import { cn } from '@/shared/lib/utils';

interface StatusBadgeProps {
  status: 'pending' | 'confirmed' | 'preparing' | 'delivered' | 'cancelled';
  className?: string;
}

function StatusBadge({ status, className }: StatusBadgeProps) {
  const statusStyles = {
    pending: 'bg-yellow-100 text-yellow-800',
    confirmed: 'bg-blue-100 text-blue-800',
    preparing: 'bg-orange-100 text-orange-800',
    delivered: 'bg-green-100 text-green-800',
    cancelled: 'bg-red-100 text-red-800',
  };

  const statusLabels = {
    pending: 'Pendente',
    confirmed: 'Confirmado',
    preparing: 'Em preparo',
    delivered: 'Entregue',
    cancelled: 'Cancelado',
  };

  return (
    <span
      className={cn(
        'inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium',
        statusStyles[status],
        className,  // permite override externo
      )}
    >
      {statusLabels[status]}
    </span>
  );
}
```

> **Por que aceitar `className`?** É o padrão da comunidade React — todo componente reutilizável deve aceitar `className` para que o consumidor possa ajustar estilos sem modificar o componente original.

---

## 2.7 Padrão de Export — Barrel Exports

Para organizar imports, use barrel exports (arquivos `index.ts` que re-exportam):

```typescript
// src/shared/components/ui/index.ts
export { Button, buttonVariants } from './button';
export { Badge, badgeVariants } from './badge';
export { Card, CardContent, CardHeader, CardTitle, CardDescription, CardFooter } from './card';
export { Input } from './input';
export { Label } from './label';
```

```typescript
// Agora em vez de importar cada um separadamente:
// import { Button } from '@/shared/components/ui/button';
// import { Badge } from '@/shared/components/ui/badge';

// Você faz:
import { Button, Badge, Card, CardContent } from '@/shared/components/ui';
```

---

## 2.8 Composição vs Herança

React favorece **composição** sobre herança. Nunca use `extends` em componentes:

```tsx
// ❌ ERRADO — não existe "herança de componentes"
// class OrderPage extends BasePage { ... }

// ✅ CERTO — composição via children e props
function PageLayout({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="max-w-7xl mx-auto px-4 py-8">
      <h1 className="text-2xl font-bold mb-6">{title}</h1>
      {children}
    </div>
  );
}

function OrdersPage() {
  return (
    <PageLayout title="Pedidos">
      <OrderSummary />
      <OrderSummary />
    </PageLayout>
  );
}

function RestaurantsPage() {
  return (
    <PageLayout title="Restaurantes">
      <p>Lista de restaurantes aqui</p>
    </PageLayout>
  );
}
```

> **Analogia com Java:** Em Java, `OrderService implements UseCase<Order>` usa interfaces. Em React, composição via props/children é o equivalente — você "injeta" conteúdo em vez de herdar comportamento.

---

## 2.9 Renderização Condicional e Listas

### Condicional

```tsx
function OrderStatus({ status }: { status: string }) {
  return (
    <div>
      {/* if-else com ternário */}
      {status === 'delivered' ? (
        <p className="text-green-600">Entregue ✓</p>
      ) : (
        <p className="text-yellow-600">Em andamento...</p>
      )}

      {/* Mostra só se true (short-circuit) */}
      {status === 'cancelled' && (
        <p className="text-red-600">Pedido cancelado</p>
      )}
    </div>
  );
}
```

### Listas com `map()`

```tsx
interface Order {
  id: string;
  restaurant: string;
  total: number;
  status: 'pending' | 'confirmed' | 'delivered';
}

function OrderList({ orders }: { orders: Order[] }) {
  if (orders.length === 0) {
    return (
      <p className="text-center text-muted-foreground py-8">
        Nenhum pedido encontrado.
      </p>
    );
  }

  return (
    <div className="space-y-4">
      {orders.map((order) => (
        <OrderCard
          key={order.id}
          title={`Pedido #${order.id} — ${order.restaurant}`}
          total={order.total}
          status={order.status}
        />
      ))}
    </div>
  );
}
```

> **Por que `key`?** O React usa `key` para identificar qual item da lista mudou, foi adicionado ou removido. **Sempre use um ID único** — nunca use o índice do array como key (causa bugs em reordenação).

> **`orders.map()` é como Java Streams:** `orders.stream().map(o -> renderCard(o)).collect(toList())`. O `map()` transforma cada objeto em JSX.

---

## 2.10 Exercício Prático — Tela de Dashboard

Crie o componente `src/features/dashboard/pages/DashboardPage.tsx`:

```tsx
import { Card, CardContent, CardHeader, CardTitle } from '@/shared/components/ui/card';
import { ShoppingBag, Store, DollarSign, TrendingUp } from 'lucide-react';

const stats = [
  { title: 'Pedidos Hoje', value: '142', icon: ShoppingBag, change: '+12%' },
  { title: 'Restaurantes Ativos', value: '38', icon: Store, change: '+2' },
  { title: 'Receita Hoje', value: 'R$ 8.420,00', icon: DollarSign, change: '+18%' },
  { title: 'Ticket Médio', value: 'R$ 59,30', icon: TrendingUp, change: '+5%' },
];

function DashboardPage() {
  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">Dashboard</h1>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {stats.map((stat) => (
          <Card key={stat.title}>
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">
                {stat.title}
              </CardTitle>
              <stat.icon className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{stat.value}</div>
              <p className="text-xs text-muted-foreground mt-1">
                <span className="text-green-600">{stat.change}</span> vs ontem
              </p>
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  );
}

export default DashboardPage;
```

---

## 2.11 Resumo dos Conceitos

| Conceito | Descrição | Analogia Java |
|---|---|---|
| **Componente** | Função que retorna JSX | Método que retorna HTML |
| **Props** | Parâmetros do componente (read-only) | Parâmetros de construtor de um Record |
| **Children** | Conteúdo entre as tags | Corpo de um Template Method |
| **JSX** | Syntax extension — HTML dentro do JS | Template engine (Thymeleaf) |
| **Renderização condicional** | `{cond && <X/>}` ou ternário | `if/else` no template |
| **Listas** | `.map()` + `key` | Stream `.map()` → List |
| **Tailwind CSS** | Classes utilitárias inline | CSS inline, mas organizado |
| **shadcn/ui** | Componentes vendored | Copiar um componente reutilizável e customizar |
| **`cn()`** | Merge de classes | String builder condicional de classes CSS |
| **Barrel export** | `index.ts` que re-exporta | Package-level export (`public` API) |

---

## 2.12 Perguntas Frequentes em Entrevista

| # | Pergunta | Resposta |
|---|---|---|
| 1 | **Qual a diferença entre props e state?** | Props vêm do pai e são read-only. State é local ao componente e pode mudar. Props descrevem "o que renderizar", state descreve "o que mudou". |
| 2 | **Por que a `key` é importante em listas?** | O React usa key para reconciliação (diffing do Virtual DOM). Sem key ou com key duplicada, o React pode reutilizar o DOM errado e causar bugs visuais. Sempre use IDs únicos. |
| 3 | **Composição vs herança em React?** | React não usa herança de componentes. Em vez disso, usa composição via children e props. Até a documentação oficial lista "Composition vs Inheritance" e conclui que nunca encontraram caso de uso para herança. |
| 4 | **O que é Tailwind CSS e por que é popular?** | Tailwind é um framework CSS utility-first — em vez de escrever classes semânticas (`.btn-primary`), usa classes atômicas (`bg-primary text-white px-4 py-2`). Vantagens: zero CSS escrito manualmente, design system built-in, tree-shaking remove classes não usadas, sem conflito de estilos. |
| 5 | **O que é shadcn/ui e como difere de Material UI?** | shadcn/ui são componentes copiados para o projeto (vendored), não um pacote npm. Você tem controle total do código-fonte. Material UI é um pacote externo com opinião de design forte (Material Design). shadcn/ui usa Radix UI (acessível) + Tailwind (customizável). |
| 6 | **O que é Compound Component Pattern?** | Padrão onde múltiplos componentes trabalham juntos compartilhando estado implícito. Exemplo clássico: `<Select>`, `<SelectTrigger>`, `<SelectItem>` do Radix/shadcn. O pai gerencia o estado, os filhos lêem via Context. Vantagem: API flexível e declaratíva. |
| 7 | **Quando usar `children` vs props específicas?** | `children` é ideal para **slots genéricos** (ex: `<Card>{conteudo}</Card>`). Props específicas (`title`, `icon`) são melhores quando o componente precisa **controlar o layout** do conteúdo. Combinar ambos é comum: `<Card title="..."> {children} </Card>`. |

---

> **Próximo passo:** [Fase 03 — Roteamento](fase-03-roteamento.md)
