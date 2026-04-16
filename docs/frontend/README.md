# 📦 FoodHub — Frontend (React)

> Documentação completa do frontend React do FoodHub — do zero ao deploy em produção.

---

## Stack Tecnológica

| Camada | Tecnologia | Versão |
|---|---|---|
| UI | React + TypeScript | 19.x + 5.x |
| Build | Vite | 6.x |
| Roteamento | React Router | 7.x |
| Estilização | Tailwind CSS + shadcn/ui | 4.x |
| Estado (servidor) | TanStack Query | 5.x |
| Estado (cliente) | Zustand | 5.x |
| HTTP | Axios | 1.x |
| Formulários | React Hook Form + Zod | 7.x + 3.x |
| Testes Unit/Int | Vitest + Testing Library + MSW | 3.x + 16.x + 2.x |
| Testes E2E | Playwright | latest |
| Qualidade | ESLint 9 + Prettier + Husky | 9.x + 3.x + 9.x |
| Arquitetura | Feature-Sliced Design | — |

---

## Fases de Implementação

| # | Fase | Documento | Foco |
|---|---|---|---|
| 00 | Visão Geral | [fase-00-visao-geral.md](fase-00-visao-geral.md) | Arquitetura, stack, ADRs, glossário |
| 01 | Fundação | [fase-01-fundacao.md](fase-01-fundacao.md) | Vite + React 19 + TS + Tailwind + ESLint |
| 02 | Componentes | [fase-02-componentes.md](fase-02-componentes.md) | Props, children, shadcn/ui, composição |
| 03 | Roteamento | [fase-03-roteamento.md](fase-03-roteamento.md) | React Router 7, layouts, lazy loading |
| 04 | Estado Global | [fase-04-estado-global.md](fase-04-estado-global.md) | Zustand, useState, hooks, custom hooks |
| 05 | Integração API | [fase-05-integracao-api.md](fase-05-integracao-api.md) | Axios, TanStack Query, cache |
| 06 | Autenticação | [fase-06-autenticacao.md](fase-06-autenticacao.md) | JWT, login, proteção de rotas, refresh |
| 07 | Formulários | [fase-07-formularios.md](fase-07-formularios.md) | React Hook Form, Zod, validação |
| 08 | Testes | [fase-08-testes.md](fase-08-testes.md) | Vitest, Testing Library, MSW, Playwright |
| 09 | Performance | [fase-09-performance.md](fase-09-performance.md) | Memo, virtual, skeleton, bundle |
| 10 | Build & Deploy | [fase-10-build-deploy.md](fase-10-build-deploy.md) | Docker, Nginx, GitHub Actions |

---

## ADRs (Architecture Decision Records)

| ADR | Decisão |
|---|---|
| F-001 | SPA com Vite (sem SSR/Next.js) |
| F-002 | Tailwind CSS 4 + shadcn/ui |
| F-003 | TanStack Query para estado do servidor |
| F-004 | Zustand para estado do cliente |
| F-005 | Feature-Sliced Design como arquitetura |

---

## Pré-requisitos

- **Node.js** 20.x LTS
- **npm** 10.x
- **VS Code** com extensões: ES7+ React/Redux/React-Native, Tailwind CSS IntelliSense, Prettier, ESLint

---

## Começar

```bash
# 1. Criar o projeto
npm create vite@latest foodhub-frontend -- --template react-ts
cd foodhub-frontend

# 2. Instalar dependências
npm install

# 3. Rodar
npm run dev
# → http://localhost:5173
```

Siga as fases em ordem: 00 → 01 → ... → 10.
