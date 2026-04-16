# Fase 07 — Formulários e Validação (React Hook Form + Zod)

> **Objetivo:** Criar formulários performáticos com React Hook Form, validar dados com schemas Zod, exibir erros de forma acessível e integrar com a API.

---

## 7.1 Por que React Hook Form + Zod?

| Abordagem | Problema |
|---|---|
| `useState` para cada campo | Muitos re-renders, código verbose, validação manual |
| Formik | Popular mas pesado, re-renders em cada keystroke |
| **React Hook Form** | Zero re-renders desnecessários, API declarativa, performance excelente |
| **Zod** | Schemas de validação type-safe — TypeScript infere os tipos automaticamente |

```
┌─────────────────────────────────────────────┐
│            Formulário React Hook Form        │
│                                             │
│  Schema Zod (validação)                     │
│       ↓ gera tipos TypeScript               │
│  useForm<FormType> (gerencia o form)        │
│       ↓ registra campos                     │
│  <Input {...register('field')} />           │
│       ↓ submit                              │
│  handleSubmit → onSubmit (chama mutation)   │
└─────────────────────────────────────────────┘
```

> **Analogia com Java:** Zod é como Bean Validation (`@NotBlank`, `@Email`, `@Size`). React Hook Form é como o Spring que coleta os dados do formulário, aplica as validações e retorna os erros.

---

## 7.2 Criar um Schema Zod

### `src/features/restaurants/types/index.ts`

```typescript
import { z } from 'zod';

// Schema de validação
export const createRestaurantSchema = z.object({
  name: z
    .string()
    .min(3, 'Nome deve ter pelo menos 3 caracteres')
    .max(100, 'Nome deve ter no máximo 100 caracteres'),
  description: z
    .string()
    .min(10, 'Descrição deve ter pelo menos 10 caracteres')
    .max(500, 'Descrição deve ter no máximo 500 caracteres'),
  category: z.enum(['PIZZA', 'BURGER', 'SUSHI', 'BRAZILIAN', 'CHINESE', 'OTHER'], {
    errorMap: () => ({ message: 'Selecione uma categoria' }),
  }),
  phone: z
    .string()
    .regex(/^\(\d{2}\) \d{4,5}-\d{4}$/, 'Formato: (11) 99999-9999'),
  address: z.object({
    street: z.string().min(5, 'Rua é obrigatória'),
    number: z.string().min(1, 'Número é obrigatório'),
    complement: z.string().optional(),
    neighborhood: z.string().min(3, 'Bairro é obrigatório'),
    city: z.string().min(3, 'Cidade é obrigatória'),
    state: z.string().length(2, 'Use sigla do estado (ex: SP)'),
    zipCode: z.string().regex(/^\d{5}-\d{3}$/, 'Formato: 00000-000'),
  }),
  openingHours: z
    .string()
    .min(5, 'Horário de funcionamento é obrigatório'),
  minimumOrder: z
    .number({ invalid_type_error: 'Informe um valor numérico' })
    .min(0, 'Valor mínimo deve ser 0 ou mais')
    .max(200, 'Valor máximo é R$ 200'),
  deliveryFee: z
    .number({ invalid_type_error: 'Informe um valor numérico' })
    .min(0, 'Taxa de entrega deve ser 0 ou mais'),
});

// TypeScript infere o tipo automaticamente do schema!
export type CreateRestaurantForm = z.infer<typeof createRestaurantSchema>;

// Tipo para a API (pode ser diferente do form)
export interface Restaurant {
  id: string;
  name: string;
  description: string;
  category: string;
  phone: string;
  address: {
    street: string;
    number: string;
    complement?: string;
    neighborhood: string;
    city: string;
    state: string;
    zipCode: string;
  };
  openingHours: string;
  minimumOrder: number;
  deliveryFee: number;
  ownerId: string;
  active: boolean;
  rating: number;
  createdAt: string;
}
```

**Validações disponíveis no Zod:**

| Validação | Equivalente Java (Bean Validation) |
|---|---|
| `z.string().min(3)` | `@Size(min = 3)` |
| `z.string().email()` | `@Email` |
| `z.string().regex(...)` | `@Pattern` |
| `z.number().min(0)` | `@Min(0)` |
| `z.enum([...])` | `enum` type |
| `z.string().optional()` | campo nullable |
| `z.object({...})` | classe DTO aninhada |

> **Vantagem do Zod sobre Bean Validation:** O mesmo schema gera o tipo TypeScript E as validações. No Java, você escreve o Record E as annotations. Com Zod, `z.infer<typeof schema>` gera automaticamente `{ name: string; phone: string; ... }`.

---

## 7.3 Formulário Completo

### `src/features/restaurants/pages/CreateRestaurantPage.tsx`

```tsx
import { useNavigate } from 'react-router-dom';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { createRestaurantSchema, type CreateRestaurantForm } from '../types';
import { Button } from '@/shared/components/ui/button';
import { Input } from '@/shared/components/ui/input';
import { Label } from '@/shared/components/ui/label';
import { Textarea } from '@/shared/components/ui/textarea';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/shared/components/ui/select';
import { Card, CardContent, CardHeader, CardTitle } from '@/shared/components/ui/card';

const categories = [
  { value: 'PIZZA', label: 'Pizza' },
  { value: 'BURGER', label: 'Hambúrguer' },
  { value: 'SUSHI', label: 'Sushi' },
  { value: 'BRAZILIAN', label: 'Brasileira' },
  { value: 'CHINESE', label: 'Chinesa' },
  { value: 'OTHER', label: 'Outra' },
];

function CreateRestaurantPage() {
  const navigate = useNavigate();

  const {
    register,
    handleSubmit,
    setValue,
    formState: { errors, isSubmitting },
  } = useForm<CreateRestaurantForm>({
    resolver: zodResolver(createRestaurantSchema),
    defaultValues: {
      minimumOrder: 0,
      deliveryFee: 0,
    },
  });

  async function onSubmit(data: CreateRestaurantForm) {
    // data já está validado e tipado!
    console.log('Dados do formulário:', data);
    // Aqui chamaria a mutation: createRestaurant.mutate(data);
    navigate('/restaurants');
  }

  return (
    <div className="max-w-2xl mx-auto">
      <h1 className="text-2xl font-bold mb-6">Cadastrar Restaurante</h1>

      <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
        {/* Dados Básicos */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Dados Básicos</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="name">Nome do Restaurante</Label>
              <Input
                id="name"
                placeholder="Ex: Burger King"
                {...register('name')}
              />
              {errors.name && (
                <p className="text-sm text-destructive">{errors.name.message}</p>
              )}
            </div>

            <div className="space-y-2">
              <Label htmlFor="description">Descrição</Label>
              <Textarea
                id="description"
                placeholder="Descreva o restaurante..."
                {...register('description')}
              />
              {errors.description && (
                <p className="text-sm text-destructive">{errors.description.message}</p>
              )}
            </div>

            <div className="space-y-2">
              <Label>Categoria</Label>
              <Select onValueChange={(value) => setValue('category', value as never)}>
                <SelectTrigger>
                  <SelectValue placeholder="Selecione uma categoria" />
                </SelectTrigger>
                <SelectContent>
                  {categories.map((cat) => (
                    <SelectItem key={cat.value} value={cat.value}>
                      {cat.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              {errors.category && (
                <p className="text-sm text-destructive">{errors.category.message}</p>
              )}
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="phone">Telefone</Label>
                <Input
                  id="phone"
                  placeholder="(11) 99999-9999"
                  {...register('phone')}
                />
                {errors.phone && (
                  <p className="text-sm text-destructive">{errors.phone.message}</p>
                )}
              </div>

              <div className="space-y-2">
                <Label htmlFor="openingHours">Horário</Label>
                <Input
                  id="openingHours"
                  placeholder="Seg-Sex: 11h-23h"
                  {...register('openingHours')}
                />
                {errors.openingHours && (
                  <p className="text-sm text-destructive">{errors.openingHours.message}</p>
                )}
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Endereço */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Endereço</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-3 gap-4">
              <div className="col-span-2 space-y-2">
                <Label htmlFor="street">Rua</Label>
                <Input id="street" {...register('address.street')} />
                {errors.address?.street && (
                  <p className="text-sm text-destructive">{errors.address.street.message}</p>
                )}
              </div>
              <div className="space-y-2">
                <Label htmlFor="number">Número</Label>
                <Input id="number" {...register('address.number')} />
                {errors.address?.number && (
                  <p className="text-sm text-destructive">{errors.address.number.message}</p>
                )}
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="neighborhood">Bairro</Label>
                <Input id="neighborhood" {...register('address.neighborhood')} />
                {errors.address?.neighborhood && (
                  <p className="text-sm text-destructive">{errors.address.neighborhood.message}</p>
                )}
              </div>
              <div className="space-y-2">
                <Label htmlFor="complement">Complemento</Label>
                <Input id="complement" placeholder="Opcional" {...register('address.complement')} />
              </div>
            </div>

            <div className="grid grid-cols-3 gap-4">
              <div className="space-y-2">
                <Label htmlFor="city">Cidade</Label>
                <Input id="city" {...register('address.city')} />
                {errors.address?.city && (
                  <p className="text-sm text-destructive">{errors.address.city.message}</p>
                )}
              </div>
              <div className="space-y-2">
                <Label htmlFor="state">Estado</Label>
                <Input id="state" placeholder="SP" maxLength={2} {...register('address.state')} />
                {errors.address?.state && (
                  <p className="text-sm text-destructive">{errors.address.state.message}</p>
                )}
              </div>
              <div className="space-y-2">
                <Label htmlFor="zipCode">CEP</Label>
                <Input id="zipCode" placeholder="00000-000" {...register('address.zipCode')} />
                {errors.address?.zipCode && (
                  <p className="text-sm text-destructive">{errors.address.zipCode.message}</p>
                )}
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Valores */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Valores</CardTitle>
          </CardHeader>
          <CardContent className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label htmlFor="minimumOrder">Pedido Mínimo (R$)</Label>
              <Input
                id="minimumOrder"
                type="number"
                step="0.01"
                {...register('minimumOrder', { valueAsNumber: true })}
              />
              {errors.minimumOrder && (
                <p className="text-sm text-destructive">{errors.minimumOrder.message}</p>
              )}
            </div>
            <div className="space-y-2">
              <Label htmlFor="deliveryFee">Taxa de Entrega (R$)</Label>
              <Input
                id="deliveryFee"
                type="number"
                step="0.01"
                {...register('deliveryFee', { valueAsNumber: true })}
              />
              {errors.deliveryFee && (
                <p className="text-sm text-destructive">{errors.deliveryFee.message}</p>
              )}
            </div>
          </CardContent>
        </Card>

        {/* Botões */}
        <div className="flex justify-end gap-4">
          <Button type="button" variant="outline" onClick={() => navigate('/restaurants')}>
            Cancelar
          </Button>
          <Button type="submit" disabled={isSubmitting}>
            {isSubmitting ? 'Salvando...' : 'Cadastrar Restaurante'}
          </Button>
        </div>
      </form>
    </div>
  );
}

export default CreateRestaurantPage;
```

---

## 7.4 Como Funciona o `register`

```tsx
// Isto:
<Input {...register('name')} />

// É equivalente a:
<Input
  name="name"
  onChange={(e) => { /* react hook form controla */ }}
  onBlur={(e) => { /* react hook form valida */ }}
  ref={(el) => { /* react hook form registra */ }}
/>
```

> O `register` retorna `{ name, onChange, onBlur, ref }` — tudo que o `<input>` precisa para ser controlado pelo React Hook Form. O spread `{...register('name')}` aplica todos de uma vez.

---

## 7.5 Componente de Campo Reutilizável

Para não repetir o padrão `Label + Input + Error` em todo lugar:

### `src/shared/components/FormField.tsx`

```tsx
import type { ReactNode } from 'react';
import { Label } from '@/shared/components/ui/label';

interface FormFieldProps {
  label: string;
  htmlFor: string;
  error?: string;
  children: ReactNode;
}

export function FormField({ label, htmlFor, error, children }: FormFieldProps) {
  return (
    <div className="space-y-2">
      <Label htmlFor={htmlFor}>{label}</Label>
      {children}
      {error && (
        <p className="text-sm text-destructive" role="alert">
          {error}
        </p>
      )}
    </div>
  );
}
```

```tsx
// Uso simplificado:
<FormField label="Nome" htmlFor="name" error={errors.name?.message}>
  <Input id="name" {...register('name')} />
</FormField>
```

---

## 7.6 Validação Assíncrona (ex: email único)

```typescript
const emailSchema = z.string().email('Email inválido');

// No useForm:
const form = useForm({
  resolver: zodResolver(schema),
  mode: 'onBlur', // valida quando o campo perde foco
});
```

Para validação contra a API (ex: verificar se email já existe), use `validate` customizado:

```tsx
<Input
  {...register('email', {
    validate: async (value) => {
      const exists = await authApi.checkEmail(value);
      return exists ? 'Este email já está em uso' : true;
    },
  })}
/>
```

---

## 7.7 Resumo dos Conceitos

| Conceito | Descrição | Analogia Java |
|---|---|---|
| Zod schema | Define validações + gera tipos | Bean Validation + Record |
| `z.infer<typeof schema>` | Gera tipo TypeScript do schema | DTO inferido |
| `useForm()` | Gerencia o estado do formulário | FormBuilder |
| `register('field')` | Conecta input ao form manager | `@ModelAttribute` binding |
| `handleSubmit` | Valida e chama onSubmit se OK | `@Valid` no controller |
| `errors.field.message` | Mensagem de erro do campo | `BindingResult.getFieldError()` |
| `zodResolver` | Bridge entre Zod e React Hook Form | Validator adapter |
| `setValue` | Set valor programaticamente | `form.setField()` |
| `formState` | Estado: isSubmitting, isDirty, isValid | Form metadata |

---

## 7.8 Perguntas Frequentes em Entrevista

| # | Pergunta | Resposta |
|---|---|---|
| 1 | **Por que React Hook Form e não controlled inputs com useState?** | RHF usa refs internamente — o input não causa re-render em cada keystroke. Em forms grandes (20+ campos), a diferença de performance é enorme. Além disso, validação, dirty tracking e submit handling vêm prontos. |
| 2 | **O que é `resolver` no React Hook Form?** | O resolver conecta uma lib de validação (Zod, Yup, Joi) ao React Hook Form. O `zodResolver` traduz o schema Zod para o formato que o RHF entende. É um adapter pattern. |
| 3 | **Qual a diferença entre validação client-side e server-side?** | Client-side (Zod) dá feedback instantâneo ao usuário, sem request. Server-side (Bean Validation) é a validação autoritativa — o frontend pode ser manipulado. Sempre valide nos dois lados. |
| 4 | **O que é `mode: 'onBlur'` vs `'onChange'`?** | `onBlur` valida quando o campo perde foco (UX menos invasiva). `onChange` valida em cada keystroke (feedback mais rápido mas pode irritar). `onBlur` é recomendado na maioria dos casos. |
| 5 | **Como lidar com erros da API no formulário?** | Use `setError('root', { message: '...' })` para erros globais do servidor, ou `setError('email', { message: '...' })` para erros de campo específico retornados pela API. |

---

> **Próximo passo:** [Fase 08 — Testes](fase-08-testes.md)
