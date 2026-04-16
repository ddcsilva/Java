# Fase 01 — Fundação: Vite + React + TypeScript

> **Objetivo:** Criar o projeto frontend do zero com Vite, React 19, TypeScript e a estrutura de pastas Feature-Sliced. Ao final desta fase, você terá o ambiente configurado, ESLint, Prettier, Tailwind CSS instalados e a primeira tela renderizando.

---

## 1.1 Pré-requisitos

Verifique que tudo está instalado:

```bash
node --version   # v20.x ou superior
npm --version    # v10.x ou superior
git --version    # v2.x
```

> **O que é Node.js?** Node.js é o **runtime de JavaScript fora do browser**. Assim como você precisa do JDK para rodar Java, precisa do Node.js para rodar JavaScript no terminal (build, testes, dev server). O npm é o gerenciador de pacotes — equivalente ao Maven/Gradle.

---

## 1.2 Criar o Projeto com Vite

Vite (pronuncia-se "vit", do francês "rápido") é o **build tool** mais utilizado para React em 2025+. Ele substituiu o Create React App, que é considerado deprecated.

```bash
# Na pasta raiz do seu projeto (d:\Projetos\Java)
npm create vite@latest foodhub-frontend -- --template react-ts

# Entre na pasta criada
cd foodhub-frontend
```

> **O que aconteceu?** O comando `npm create vite@latest` usou o scaffolding do Vite para gerar um projeto React com TypeScript. O flag `--template react-ts` é o template com TypeScript pré-configurado.

### Estrutura gerada pelo Vite

```
foodhub-frontend/
├── public/                 # Arquivos estáticos servidos diretamente (favicon, etc.)
│   └── vite.svg
├── src/
│   ├── App.tsx             # Componente principal
│   ├── App.css             # Estilos do App (vamos remover)
│   ├── main.tsx            # Entry point — monta o React no DOM
│   ├── index.css           # CSS global (vamos substituir pelo Tailwind)
│   └── vite-env.d.ts       # Tipos do Vite para TypeScript
├── index.html              # HTML raiz — onde o React é montado
├── package.json            # Dependências e scripts
├── tsconfig.json           # Configuração TypeScript
├── tsconfig.app.json       # Config TypeScript para o app
├── tsconfig.node.json      # Config TypeScript para Vite/Node
├── vite.config.ts          # Configuração do Vite
└── .gitignore
```

### Instalar dependências e rodar

```bash
# Instalar as dependências
npm install

# Rodar o dev server
npm run dev
```

Abra `http://localhost:5173` no browser. Você deve ver a página padrão do Vite + React.

> **O que é `npm install`?** Lê o `package.json`, baixa todas as dependências listadas e cria a pasta `node_modules/`. É o equivalente ao `mvn dependency:resolve`.

> **O que é `npm run dev`?** Roda o script `dev` definido no `package.json` — que inicia o servidor de desenvolvimento do Vite com HMR (Hot Module Replacement). Qualquer alteração no código aparece instantaneamente no browser.

---

## 1.3 Instalar Dependências do Projeto

Vamos instalar todas as dependências que usaremos ao longo das fases:

### Dependências de produção

```bash
npm install react-router-dom @tanstack/react-query axios zustand react-hook-form @hookform/resolvers zod lucide-react clsx tailwind-merge
```

**O que cada uma faz:**

| Pacote | Para que serve |
|---|---|
| `react-router-dom` | Roteamento — navegação entre páginas |
| `@tanstack/react-query` | Cache e sincronização de dados do servidor |
| `axios` | HTTP client — faz chamadas para a API |
| `zustand` | Estado global leve (auth, UI) |
| `react-hook-form` | Gerenciamento de formulários (sem re-renders) |
| `@hookform/resolvers` | Conecta React Hook Form com Zod |
| `zod` | Validação de schemas type-safe |
| `lucide-react` | Ícones SVG |
| `clsx` | Concatenação condicional de classes CSS |
| `tailwind-merge` | Mescla classes Tailwind sem conflito |

### Dependências de desenvolvimento

```bash
npm install -D tailwindcss @tailwindcss/vite prettier eslint @eslint/js typescript-eslint eslint-plugin-react-hooks eslint-plugin-react-refresh eslint-config-prettier @tanstack/react-query-devtools husky lint-staged
```

| Pacote | Para que serve |
|---|---|
| `tailwindcss` + `@tailwindcss/vite` | Tailwind CSS 4 com plugin Vite |
| `prettier` + `eslint-config-prettier` | Formatação de código |
| `eslint` + plugins | Linter — encontra erros e enforça padrões |
| `@tanstack/react-query-devtools` | DevTools visual do TanStack Query |
| `husky` + `lint-staged` | Git hooks (lint antes do commit) |

---

## 1.4 Configurar Tailwind CSS 4

Tailwind CSS 4 usa uma nova abordagem — importação via CSS, sem `tailwind.config.js`:

### Atualizar `src/index.css` (renomear para `src/styles/globals.css`)

```css
@import "tailwindcss";

/* Custom CSS variables para o design system (compatível com shadcn/ui) */
@theme {
  --color-background: #ffffff;
  --color-foreground: #0a0a0a;
  --color-card: #ffffff;
  --color-card-foreground: #0a0a0a;
  --color-primary: #f97316;
  --color-primary-foreground: #ffffff;
  --color-secondary: #f5f5f4;
  --color-secondary-foreground: #0a0a0a;
  --color-muted: #f5f5f4;
  --color-muted-foreground: #737373;
  --color-accent: #f5f5f4;
  --color-accent-foreground: #0a0a0a;
  --color-destructive: #ef4444;
  --color-destructive-foreground: #ffffff;
  --color-border: #e5e5e5;
  --color-ring: #f97316;
  --radius-sm: 0.25rem;
  --radius-md: 0.375rem;
  --radius-lg: 0.5rem;
}

/* Dark mode */
@media (prefers-color-scheme: dark) {
  @theme {
    --color-background: #0a0a0a;
    --color-foreground: #fafafa;
    --color-card: #171717;
    --color-card-foreground: #fafafa;
    --color-primary: #f97316;
    --color-primary-foreground: #ffffff;
    --color-secondary: #262626;
    --color-secondary-foreground: #fafafa;
    --color-muted: #262626;
    --color-muted-foreground: #a3a3a3;
    --color-accent: #262626;
    --color-accent-foreground: #fafafa;
    --color-border: #262626;
    --color-ring: #f97316;
  }
}
```

> **O que são essas variáveis?** São CSS Custom Properties (variáveis CSS) que definem as cores do design system. O Tailwind CSS 4 lê essas variáveis e gera classes como `bg-primary`, `text-foreground`, etc. Isso é o padrão do shadcn/ui.

> **Por que laranja (`#f97316`)?** É a cor primária do FoodHub — remete a comida, delivery, energia. Você pode trocar para qualquer cor depois.

### Atualizar `vite.config.ts`

```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';
import path from 'path';

export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
  ],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true,
      },
    },
  },
});
```

**Explicação linha a linha:**

| Configuração | O que faz |
|---|---|
| `react()` | Plugin React — habilita JSX, Fast Refresh (HMR) |
| `tailwindcss()` | Plugin Tailwind — compila CSS on-the-fly |
| `alias '@'` | Permite importar `@/shared/api/client` em vez de `../../../shared/api/client` |
| `proxy '/api'` | Redireciona chamadas `/api/*` para o API Gateway (porta 8080) — resolve CORS em dev |

### Atualizar `tsconfig.app.json`

Adicione o `paths` para que o TypeScript entenda o alias `@/`:

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,

    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "isolatedModules": true,
    "moduleDetection": "force",
    "noEmit": true,
    "jsx": "react-jsx",

    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "noUncheckedSideEffectImports": true,

    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src"]
}
```

> **O que é `strict: true`?** Habilita todas as checagens rigorosas do TypeScript (null checks, implicit any, etc.). É como usar `-Xlint:all` no javac — pega mais erros em tempo de compilação.

---

## 1.5 Configurar ESLint 9 (Flat Config)

ESLint 9 usa o novo formato **flat config** — um array de objetos no `eslint.config.js`:

```javascript
// eslint.config.js
import js from '@eslint/js';
import tseslint from 'typescript-eslint';
import reactHooks from 'eslint-plugin-react-hooks';
import reactRefresh from 'eslint-plugin-react-refresh';
import prettier from 'eslint-config-prettier';

export default tseslint.config(
  { ignores: ['dist'] },
  {
    extends: [js.configs.recommended, ...tseslint.configs.recommended],
    files: ['**/*.{ts,tsx}'],
    plugins: {
      'react-hooks': reactHooks,
      'react-refresh': reactRefresh,
    },
    rules: {
      ...reactHooks.configs.recommended.rules,
      'react-refresh/only-export-components': [
        'warn',
        { allowConstantExport: true },
      ],
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_' },
      ],
    },
  },
  prettier,
);
```

**O que cada plugin faz:**

| Plugin | Regras |
|---|---|
| `react-hooks` | Garante que hooks são usados corretamente (order, dependencies) |
| `react-refresh` | Garante que Fast Refresh funciona (só exporte componentes) |
| `typescript-eslint` | Regras TypeScript (tipos, imports, etc.) |
| `prettier` | Desliga regras de formatação que conflitam com Prettier |

### Configurar Prettier

```json
// .prettierrc
{
  "semi": true,
  "singleQuote": true,
  "trailingComma": "all",
  "tabWidth": 2,
  "printWidth": 100,
  "bracketSpacing": true,
  "jsxSingleQuote": false,
  "arrowParens": "always"
}
```

---

## 1.6 Configurar Husky + lint-staged

Husky roda scripts antes de cada commit — garante que código com erros não entre no repositório:

```bash
# Inicializar Husky
npx husky init
```

Crie o hook de pre-commit:

```bash
# .husky/pre-commit
npx lint-staged
```

Adicione ao `package.json`:

```json
{
  "lint-staged": {
    "*.{ts,tsx}": ["eslint --fix", "prettier --write"],
    "*.{json,md,css}": ["prettier --write"]
  }
}
```

> **O que acontece agora?** Toda vez que você fizer `git commit`, o Husky roda o lint-staged, que aplica ESLint e Prettier **apenas nos arquivos modificados**. Se algum arquivo tiver erro de lint, o commit é bloqueado.

---

## 1.7 Montar a Estrutura de Pastas

Agora vamos criar a estrutura Feature-Sliced definida na Fase 00:

```bash
# Criar a estrutura de pastas (Windows PowerShell)
$dirs = @(
  "src/app/providers",
  "src/app/router",
  "src/app/layouts",
  "src/app/pages",
  "src/features/orders/api",
  "src/features/orders/components",
  "src/features/orders/hooks",
  "src/features/orders/pages",
  "src/features/orders/types",
  "src/features/orders/utils",
  "src/features/auth/api",
  "src/features/auth/components",
  "src/features/auth/hooks",
  "src/features/auth/pages",
  "src/features/auth/types",
  "src/features/restaurants/api",
  "src/features/restaurants/components",
  "src/features/restaurants/pages",
  "src/features/restaurants/types",
  "src/features/dashboard/api",
  "src/features/dashboard/components",
  "src/features/dashboard/pages",
  "src/shared/api",
  "src/shared/components/ui",
  "src/shared/hooks",
  "src/shared/lib",
  "src/shared/types",
  "src/assets/images",
  "src/styles"
)

foreach ($dir in $dirs) {
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
}
```

---

## 1.8 Criar Arquivos Base

### `src/shared/lib/utils.ts` — Utility function

```typescript
import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

/**
 * Combina classes CSS condicionalmente e resolve conflitos Tailwind.
 * Padrão do shadcn/ui — usado em todo o projeto.
 *
 * @example
 * cn('px-4 py-2', isActive && 'bg-primary', className)
 */
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
```

> **Por que `cn()`?** É a função mais usada no ecossistema shadcn/ui. Ela faz duas coisas: (1) `clsx` concatena classes condicionalmente (se `isActive` for false, não inclui `bg-primary`) e (2) `twMerge` resolve conflitos do Tailwind (se você passar `px-4` e `px-6`, mantém só `px-6`).

### `src/shared/types/index.ts` — Tipos globais

```typescript
/** Resposta paginada padrão do Spring Data JPA */
export interface PaginatedResponse<T> {
  content: T[];
  totalElements: number;
  totalPages: number;
  number: number;       // página atual (0-based)
  size: number;         // itens por página
  first: boolean;
  last: boolean;
}

/** Erro padrão da API (ProblemDetail RFC 7807) */
export interface ApiError {
  type: string;
  title: string;
  status: number;
  detail: string;
  instance: string;
  timestamp?: string;
}

/** Parâmetros de paginação */
export interface PaginationParams {
  page: number;
  size: number;
  sort?: string;
}
```

> **Por que tipar a resposta da API?** O backend retorna JSON "solto" — sem tipos. Com TypeScript, a gente define tipos que espelham os DTOs do Java. Isso dá autocomplete no editor e pega erros antes de rodar o código.

### `src/app/App.tsx` — Componente raiz (temporário)

```tsx
function App() {
  return (
    <div className="min-h-screen bg-background text-foreground">
      <header className="border-b border-border">
        <div className="max-w-7xl mx-auto px-4 py-4 flex items-center justify-between">
          <h1 className="text-2xl font-bold text-primary">🍔 FoodHub</h1>
          <span className="text-sm text-muted-foreground">v0.1.0 — Fase 01</span>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 py-8">
        <div className="rounded-lg border border-border bg-card p-8 text-center">
          <h2 className="text-3xl font-bold mb-4">Bem-vindo ao FoodHub! 🎉</h2>
          <p className="text-muted-foreground mb-6">
            Se você está vendo esta tela, o projeto está configurado corretamente.
          </p>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-left">
            <div className="rounded-md border border-border p-4">
              <h3 className="font-semibold mb-2">✅ React 19</h3>
              <p className="text-sm text-muted-foreground">Componentes, Hooks, JSX</p>
            </div>
            <div className="rounded-md border border-border p-4">
              <h3 className="font-semibold mb-2">✅ TypeScript 5</h3>
              <p className="text-sm text-muted-foreground">Tipagem estática</p>
            </div>
            <div className="rounded-md border border-border p-4">
              <h3 className="font-semibold mb-2">✅ Tailwind CSS 4</h3>
              <p className="text-sm text-muted-foreground">Utility-first styling</p>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}

export default App;
```

### `src/main.tsx` — Entry point

```tsx
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './app/App';
import './styles/globals.css';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
```

**Explicação:**

| Linha | O que faz |
|---|---|
| `StrictMode` | Modo de desenvolvimento que detecta problemas (double-render proposital para achar bugs) |
| `createRoot` | React 19 API para montar a árvore de componentes no DOM |
| `document.getElementById('root')!` | Pega o `<div id="root">` do `index.html`. O `!` é o TypeScript "non-null assertion" — garante que o elemento existe |
| `import './styles/globals.css'` | Carrega o Tailwind CSS e variáveis do design system |

> **Analogia com Java:** `main.tsx` é o `public static void main(String[] args)` do React. É aqui que tudo começa.

---

## 1.9 Atualizar Scripts do `package.json`

```json
{
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "preview": "vite preview",
    "lint": "eslint .",
    "lint:fix": "eslint . --fix",
    "format": "prettier --write \"src/**/*.{ts,tsx,css,json}\"",
    "type-check": "tsc --noEmit"
  }
}
```

| Script | O que faz | Equivalente Java |
|---|---|---|
| `npm run dev` | Dev server com HMR | `mvn spring-boot:run` |
| `npm run build` | Build de produção | `mvn package` |
| `npm run preview` | Serve o build localmente | `java -jar target/*.jar` |
| `npm run lint` | Checa erros de lint | `mvn checkstyle:check` |
| `npm run format` | Formata tudo | `mvn spotless:apply` |
| `npm run type-check` | Verifica tipos sem compilar | `mvn compile` (só checagem) |

---

## 1.10 Testar a Configuração

```bash
# 1. Rodar o dev server
npm run dev

# 2. Abrir http://localhost:5173 — deve mostrar "Bem-vindo ao FoodHub!"

# 3. Testar o build
npm run build

# 4. Testar lint
npm run lint

# 5. Testar type-check
npm run type-check
```

Se tudo funcionar sem erros, a fundação está pronta! 🎉

---

## 1.11 Entendendo o Ciclo de Desenvolvimento React

```
┌─────────────────────────────────────────────────────────────┐
│                      Editar .tsx no VS Code                  │
│                              │                               │
│                              ▼                               │
│                    Vite detecta a mudança                    │
│                              │                               │
│                              ▼                               │
│               HMR atualiza o browser instantaneamente        │
│              (sem reload — mantém state do componente)        │
│                              │                               │
│                              ▼                               │
│                   Você vê a mudança imediatamente             │
└─────────────────────────────────────────────────────────────┘
```

> **Comparação com o backend:** No Spring Boot, você muda um `.java`, o DevTools reinicia o servidor (2-5 segundos). No Vite + React, a mudança aparece em **milissegundos** sem perder o estado do componente. Isso muda completamente o workflow — você vai iterar muito mais rápido.

---

## 1.12 Git — Primeiro Commit

```bash
# Na pasta foodhub-frontend
git init
git add .
git commit -m "feat: setup Vite + React 19 + TypeScript + Tailwind CSS 4"
```

---

## 1.13 Resumo do que Instalamos

| Camada | Tecnologias | Status |
|---|---|---|
| **Build** | Vite 6 + React 19 + TypeScript 5 | ✅ Configurado |
| **Estilização** | Tailwind CSS 4 + CSS variables | ✅ Configurado |
| **Qualidade** | ESLint 9 + Prettier + Husky | ✅ Configurado |
| **Estrutura** | Feature-Sliced Design | ✅ Criada |
| **Tipos base** | PaginatedResponse, ApiError | ✅ Criados |
| **Roteamento** | React Router 7 | 📦 Instalado, config na Fase 03 |
| **Data fetching** | TanStack Query + Axios | 📦 Instalado, config na Fase 05 |
| **Estado** | Zustand | 📦 Instalado, config na Fase 04 |
| **Formulários** | React Hook Form + Zod | 📦 Instalado, config na Fase 07 |

---

## 1.14 Perguntas Frequentes em Entrevista

| # | Pergunta | Resposta |
|---|---|---|
| 1 | **Por que Vite e não Webpack?** | Vite usa ES Modules nativos no dev (sem bundling) — o dev server inicia em milissegundos. Webpack precisa empacotar tudo antes de servir. Para build de produção, Vite usa Rollup (ou esbuild), que é mais rápido. CRA é deprecated e usava Webpack. |
| 2 | **O que é TypeScript e por que usar com React?** | TypeScript adiciona tipos ao JavaScript — como compilar Java com `-Xlint:all`. Pega erros em tempo de compilação (props erradas, tipos incorretos, imports quebrados). Em entrevistas, é **obrigatório** saber TypeScript. |
| 3 | **O que é `"strict": true` no tsconfig?** | Habilita todas as verificações rigorosas: `strictNullChecks` (catch null), `noImplicitAny` (tudo precisa de tipo), `strictFunctionTypes`, etc. É o equivalente a `-Werror` do compilador — trata warnings como erros. |
| 4 | **O que é Hot Module Replacement (HMR)?** | HMR substitui apenas o módulo alterado no browser, sem recarregar a página inteira. O estado dos componentes React é preservado. É como o Live Reload do Spring DevTools, mas instantâneo e sem perder estado. |
| 5 | **Explique o que faz `eslint --fix`.** | Roda o linter e corrige automaticamente regras que podem ser auto-fixadas (imports ordenados, espaços, ponto-e-vírgula). Regras que exigem decisão humana (unused vars, any types) são apenas reportadas. |

---

> **Próximo passo:** [Fase 02 — Componentes e Estilização](fase-02-componentes.md)
