# Fase 10 — Build, Docker e CI/CD

> **Objetivo:** Gerar o build de produção, criar um container Docker com Nginx, configurar pipeline GitHub Actions para CI/CD e preparar o frontend para deploy.

---

## 10.1 Build de Produção

```bash
# Build para produção
npm run build
```

**O que acontece:**

```
1. TypeScript compila → verifica erros de tipo
2. Vite/Rollup empacota todo o código
3. Tree-shaking remove código não utilizado
4. Minificação reduz tamanho dos arquivos
5. Code splitting gera chunks por rota
6. CSS é extraído e minificado
7. Output vai para dist/
```

### Estrutura do build

```
dist/
├── index.html                        # HTML com references aos assets
├── assets/
│   ├── index-[hash].js               # Bundle principal (~150KB gzip)
│   ├── index-[hash].css              # CSS compilado (~20KB gzip)
│   ├── DashboardPage-[hash].js       # Chunk lazy do dashboard
│   ├── OrdersPage-[hash].js          # Chunk lazy de pedidos
│   └── vendor-[hash].js              # Libs externas (React, React Router)
└── vite.svg
```

> **Por que `[hash]` nos nomes?** É cache busting — o hash muda quando o conteúdo muda. O browser pode cachear por tempo indeterminado. Quando você faz deploy de uma nova versão, os nomes mudam e o browser baixa os novos arquivos.

### Preview local

```bash
# Serve o build localmente para testar
npm run preview
# Abra http://localhost:4173
```

---

## 10.2 Variáveis de Ambiente

Vite expõe variáveis de ambiente via `import.meta.env`:

### `.env` (desenvolvimento)

```
VITE_API_BASE_URL=http://localhost:8080/api
VITE_APP_NAME=FoodHub
VITE_APP_VERSION=0.1.0
```

### `.env.production` (produção)

```
VITE_API_BASE_URL=/api
VITE_APP_NAME=FoodHub
VITE_APP_VERSION=0.1.0
```

### Uso no código

```typescript
// Apenas variáveis com prefixo VITE_ são expostas ao client
const apiUrl = import.meta.env.VITE_API_BASE_URL;
const appName = import.meta.env.VITE_APP_NAME;
```

### Tipagem das variáveis

```typescript
// src/vite-env.d.ts
/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_BASE_URL: string;
  readonly VITE_APP_NAME: string;
  readonly VITE_APP_VERSION: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
```

> **Segurança:** Variáveis `VITE_*` são **incluídas no bundle final** — qualquer um pode vê-las no DevTools. **Nunca** coloque secrets, API keys privadas ou credenciais aqui. O prefixo `VITE_` é proposital para evitar vazamentos acidentais.

---

## 10.3 Docker — Nginx Multi-Stage

### `Dockerfile`

```dockerfile
# ─── Stage 1: Build ───────────────────────────────
FROM node:20-alpine AS build

WORKDIR /app

# Copiar apenas package files (cache de dependências)
COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts

# Copiar código e buildar
COPY . .
RUN npm run build

# ─── Stage 2: Serve ───────────────────────────────
FROM nginx:1.27-alpine

# Copiar build para o Nginx
COPY --from=build /app/dist /usr/share/nginx/html

# Configuração customizada do Nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

**Explicação do multi-stage:**

| Stage | O que faz | Resultado |
|---|---|---|
| Build | Instala Node, dependências, compila | ~1.2 GB com node_modules |
| Serve | Apenas Nginx + arquivos estáticos | ~25 MB final |

> **Analogia Java:** É como o multi-stage do backend: primeiro `maven:3-eclipse-temurin` para buildar, depois `eclipse-temurin:21-jre-alpine` para rodar. No frontend, o "runtime" é o Nginx servindo arquivos estáticos.

### `nginx.conf`

```nginx
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml;
    gzip_min_length 256;

    # Cache de assets com hash (indefinido)
    location /assets/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # SPA fallback — ESSENCIAL
    # Toda rota que não casa com arquivo real redireciona para index.html
    # Sem isso, acessar /orders diretamente retorna 404
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Proxy para a API (produção)
    location /api/ {
        proxy_pass http://api-gateway:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
}
```

> **Por que `try_files $uri /index.html`?** Em uma SPA, todas as rotas (`/orders`, `/restaurants`, etc.) são gerenciadas pelo JavaScript. Quando o usuario acessa `/orders` diretamente (ou faz refresh), o Nginx não tem um arquivo `/orders` — sem o fallback, retornaria 404. Com `try_files`, ele serve o `index.html` e o React Router assume o roteamento.

### `.dockerignore`

```
node_modules
dist
.git
.env.local
*.md
```

### Rodar

```bash
# Build da imagem
docker build -t foodhub-frontend .

# Rodar
docker run -p 3000:80 foodhub-frontend

# Abrir http://localhost:3000
```

---

## 10.4 Docker Compose — Stack Completa

```yaml
# docker-compose.yml (na raiz do projeto Java)
services:
  # ... outros serviços backend ...

  frontend:
    build:
      context: ./foodhub-frontend
      dockerfile: Dockerfile
    ports:
      - "3000:80"
    depends_on:
      - api-gateway
    networks:
      - foodhub-network

networks:
  foodhub-network:
    driver: bridge
```

---

## 10.5 GitHub Actions — CI/CD

### `.github/workflows/frontend-ci.yml`

```yaml
name: Frontend CI

on:
  push:
    branches: [main, develop]
    paths: ['foodhub-frontend/**']
  pull_request:
    branches: [main]
    paths: ['foodhub-frontend/**']

defaults:
  run:
    working-directory: foodhub-frontend

jobs:
  quality:
    name: Quality Checks
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
          cache-dependency-path: foodhub-frontend/package-lock.json

      - run: npm ci

      - name: Type Check
        run: npm run type-check

      - name: Lint
        run: npm run lint

      - name: Format Check
        run: npx prettier --check "src/**/*.{ts,tsx,css,json}"

  test:
    name: Tests
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
          cache-dependency-path: foodhub-frontend/package-lock.json

      - run: npm ci

      - name: Unit & Integration Tests
        run: npm run test:coverage

      - name: Upload Coverage
        uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: foodhub-frontend/coverage/

  build:
    name: Build
    runs-on: ubuntu-latest
    needs: [quality, test]

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
          cache-dependency-path: foodhub-frontend/package-lock.json

      - run: npm ci
      - run: npm run build

      - name: Upload Build
        uses: actions/upload-artifact@v4
        with:
          name: dist
          path: foodhub-frontend/dist/

  docker:
    name: Docker Build
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/main'

    steps:
      - uses: actions/checkout@v4

      - name: Build Docker Image
        run: |
          docker build -t foodhub-frontend:${{ github.sha }} .
          docker tag foodhub-frontend:${{ github.sha }} foodhub-frontend:latest
```

**Pipeline flow:**

```
┌──────────┐   ┌──────────┐
│ Quality  │   │  Tests   │
│ (lint,   │   │ (vitest  │
│  types)  │   │ coverage)│
└────┬─────┘   └────┬─────┘
     │              │
     └──────┬───────┘
            ▼
      ┌──────────┐
      │  Build   │
      │ (vite    │
      │  build)  │
      └────┬─────┘
           ▼
    ┌────────────┐
    │   Docker   │  (apenas na main)
    │   Build    │
    └────────────┘
```

---

## 10.6 Checklist de Deploy

| Item | Verificação |
|---|---|
| ✅ Build sem erros | `npm run build` passa |
| ✅ Lint limpo | `npm run lint` sem warnings |
| ✅ Tipos corretos | `npm run type-check` passa |
| ✅ Testes passando | `npm run test:run` 100% green |
| ✅ Variáveis de ambiente | `.env.production` configurado |
| ✅ Docker funciona | `docker build` + `docker run` OK |
| ✅ SPA fallback | Nginx `try_files` configurado |
| ✅ CORS/Proxy | API acessível do container |
| ✅ Security headers | X-Frame-Options, CSP, etc. |
| ✅ Gzip habilitado | Assets comprimidos |
| ✅ Cache | Assets com hash têm cache immutable |

---

## 10.7 Resumo dos Conceitos

| Conceito | Descrição | Analogia Java |
|---|---|---|
| `npm run build` | Gera bundle de produção | `mvn package` |
| Tree-shaking | Remove código morto | ProGuard / dead code elimination |
| Cache busting | Hash no nome dos assets | Versioned JARs |
| Multi-stage Docker | Build + serve separados | JDK para build, JRE para run |
| Nginx SPA fallback | `try_files → index.html` | Servlet mapping `/*` |
| Nginx proxy | Redireciona `/api` para o backend | API Gateway reverse proxy |
| GitHub Actions | CI/CD automatizado | Jenkins / GitLab CI |
| Env variables | `VITE_*` no build | `application.properties` |

---

## 10.8 Perguntas Frequentes em Entrevista

| # | Pergunta | Resposta |
|---|---|---|
| 1 | **Por que multi-stage Docker no frontend?** | O Node.js é necessário apenas para buildar — o resultado são arquivos estáticos. Servir com Nginx reduz a imagem de ~1.2GB para ~25MB e é significativamente mais performático. |
| 2 | **O que é `try_files` e por que é essencial para SPAs?** | Em SPAs, as rotas são gerenciadas pelo JavaScript. Quando o usuário acessa `/orders` diretamente, o Nginx procura o arquivo `/orders` (não existe). `try_files $uri /index.html` faz o fallback para o `index.html`, onde o React Router assume. |
| 3 | **Como funciona o cache de assets?** | Assets com hash no nome (`index-a1b2c3.js`) são cacheados por 1 ano (`immutable`). Quando o código muda, o hash muda, e o browser baixa automaticamente o novo arquivo. O `index.html` nunca é cacheado (sempre fresco). |
| 4 | **O que é tree-shaking?** | Processo de eliminação de código morto durante o build. Se você importa só `Button` de uma lib que tem 100 componentes, os outros 99 são removidos do bundle. Funciona com ES Modules (import/export estáticos). |
| 5 | **Qual a diferença entre `npm install` e `npm ci`?** | `npm ci` instala **exatamente** o que está no `package-lock.json` (reprodutível). `npm install` pode atualizar versões dentro do range do `package.json`. Em CI/CD, sempre use `npm ci`. |

---

> **Parabéns!** 🎉 Você completou todas as 10 fases do frontend do FoodHub.
>
> **Recapitulando a jornada:**
> - **Fase 00:** Visão geral, stack e arquitetura
> - **Fase 01:** Fundação (Vite + React + TypeScript)
> - **Fase 02:** Componentes e estilização
> - **Fase 03:** Roteamento
> - **Fase 04:** Estado global (Zustand)
> - **Fase 05:** Integração com API (Axios + TanStack Query)
> - **Fase 06:** Autenticação (JWT)
> - **Fase 07:** Formulários (React Hook Form + Zod)
> - **Fase 08:** Testes (Vitest + Testing Library + MSW)
> - **Fase 09:** Performance
> - **Fase 10:** Build, Docker e CI/CD
