<p align="center">
  <img src="https://img.shields.io/badge/Java-21-ED8B00?style=for-the-badge&logo=openjdk&logoColor=white" alt="Java 21"/>
  <img src="https://img.shields.io/badge/Spring_Boot-3.5-6DB33F?style=for-the-badge&logo=springboot&logoColor=white" alt="Spring Boot 3.5"/>
  <img src="https://img.shields.io/badge/Spring_Cloud-2025.0-6DB33F?style=for-the-badge&logo=spring&logoColor=white" alt="Spring Cloud"/>
  <img src="https://img.shields.io/badge/React-19-61DAFB?style=for-the-badge&logo=react&logoColor=black" alt="React 19"/>
  <img src="https://img.shields.io/badge/TypeScript-5-3178C6?style=for-the-badge&logo=typescript&logoColor=white" alt="TypeScript 5"/>
  <img src="https://img.shields.io/badge/Vite-6-646CFF?style=for-the-badge&logo=vite&logoColor=white" alt="Vite 6"/>
  <img src="https://img.shields.io/badge/Tailwind_CSS-4-06B6D4?style=for-the-badge&logo=tailwindcss&logoColor=white" alt="Tailwind CSS 4"/>
  <img src="https://img.shields.io/badge/Apache_Kafka-3.x-231F20?style=for-the-badge&logo=apachekafka&logoColor=white" alt="Kafka"/>
  <img src="https://img.shields.io/badge/PostgreSQL-16-4169E1?style=for-the-badge&logo=postgresql&logoColor=white" alt="PostgreSQL"/>
  <img src="https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker"/>
</p>

<h1 align="center">🍔 FoodHub</h1>

<p align="center">
  <strong>Plataforma fullstack de pedidos de comida</strong><br/>
  Backend em microserviços (Java 21 + Spring Boot 3.5 + Spring Cloud) e frontend SPA (React 19 + TypeScript + Vite) — do zero ao deploy.
</p>

<p align="center">
  <a href="#arquitetura">Arquitetura</a> •
  <a href="#serviços">Serviços</a> •
  <a href="#frontend">Frontend</a> •
  <a href="#tech-stack">Tech Stack</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#documentação">Documentação</a> •
  <a href="#roadmap">Roadmap</a>
</p>

---

## Sobre

**FoodHub** é uma plataforma fullstack de pedidos de comida. O **backend** é composto por microserviços enterprise (Java 21, Spring Boot, Spring Cloud, Kafka, PostgreSQL) e o **frontend** é uma SPA moderna (React 19, TypeScript, Vite, Tailwind CSS, TanStack Query). O projeto cobre o ciclo completo de desenvolvimento: API REST, persistência, segurança, mensageria assíncrona, UI componentizada, gerenciamento de estado, testes automatizados, containerização, CI/CD e observabilidade.

Projetado para demonstrar as competências exigidas em vagas enterprise fullstack no Brasil — cada módulo mapeia diretamente para um requisito real de mercado.

---

## Arquitetura

```
                    ┌───────────────────────────────────────┐
                    │  FoodHub Frontend (React SPA)   │
                    │  :5173 (dev) │ :80 (prod/nginx) │
                    └───────────────────┬───────────────────┘
                                    │ :8080
                            ┌────────▼────────┐
                            │   API Gateway   │
                            │ (Spring Cloud)  │
                            └────────┬────────┘
                                     │
                 ┌───────────────────┼───────────────────┐
                 │                   │                   │
        ┌────────▼───────┐  ┌────────▼──────┐   ┌────────▼───────┐
        │ order-service  │  │  restaurant-  │   │    payment-    │
        │     :8081      │  │   service     │   │    service     │
        │                │◄─┤    :8082      │   │     :8083      │
        └────────┬───────┘  └───────────────┘   └──────────┬─────┘
                 │   OpenFeign (REST síncrono)             │
                 │                                         │
                 │         ┌──────────────┐                │
                 └────────►│ Apache Kafka │◄───────────────┘
                           │    (KRaft)   │
                           └──────┬───────┘
                                  │
                         ┌────────▼────────┐
                         │  notification-  │
                         │    service      │
                         │     :8084       │
                         └─────────────────┘
```

**Padrões:** REST síncrono para queries (OpenFeign) · Eventos assíncronos para reações (Kafka) · Database-per-service · DDD + Arquitetura Hexagonal (Ports & Adapters) · Feature-Sliced Design (frontend)

---

## Serviços

### Negócio

| Serviço | Porta | Descrição | Banco |
|---|---|---|---|
| **order-service** | 8081 | Criação, consulta e gerenciamento de pedidos | `foodhub_orders` |
| **restaurant-service** | 8082 | Cadastro de restaurantes, cardápios e itens | `foodhub_restaurants` |
| **payment-service** | 8083 | Processamento de pagamentos (simulado) | `foodhub_payments` |
| **notification-service** | 8084 | Notificações via eventos Kafka | — |

### Infraestrutura

| Serviço | Porta | Descrição |
|---|---|---|
| **api-gateway** | 8080 | Spring Cloud Gateway — ponto único de entrada |
| **config-server** | 8888 | Spring Cloud Config — configuração centralizada via Git |
| **discovery-server** | 8761 | Eureka Server — service discovery |

---

## Frontend

SPA moderna construída com **React 19** e **TypeScript**, seguindo **Feature-Sliced Design**.

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
| Testes | Vitest + Testing Library + MSW + Playwright | 3.x + 16.x + 2.x |
| Qualidade | ESLint 9 + Prettier + Husky | 9.x + 3.x + 9.x |

```
foodhub-frontend/
└── src/
    ├── app/            # Providers, router, layouts, páginas
    ├── features/       # Feature modules (orders, restaurants, auth)
    └── shared/         # Componentes, hooks, utils, tipos reutilizáveis
```

---

## Tech Stack

### Backend

| Categoria | Tecnologia | Versão |
|---|---|---|
| **Linguagem** | Java (LTS) | 21 |
| **Framework** | Spring Boot | 3.5.x |
| **Cloud** | Spring Cloud (Northfields) | 2025.0.x |
| **Build** | Maven | 3.9+ |
| **Banco** | PostgreSQL | 16+ |
| **ORM** | Spring Data JPA + Hibernate 6 | gerenciado |
| **Migrations** | Flyway | gerenciado |
| **Segurança** | Spring Security 6 + JWT (jjwt) | 6.x / 0.12.x |
| **Mensageria** | Apache Kafka (KRaft) | 3.x |
| **Resiliência** | Resilience4j | 2.x |
| **Docs API** | SpringDoc OpenAPI | 2.8.x |
| **Testes** | JUnit 5 + Mockito + Testcontainers | gerenciado |
| **Container** | Docker + Docker Compose | — |
| **CI/CD** | GitHub Actions | — |
| **Observabilidade** | Micrometer + Prometheus + Grafana + Zipkin | — |

### Frontend

| Categoria | Tecnologia | Versão |
|---|---|---|
| **UI** | React + TypeScript | 19.x + 5.x |
| **Build** | Vite | 6.x |
| **Roteamento** | React Router | 7.x |
| **Estilização** | Tailwind CSS + shadcn/ui | 4.x |
| **Estado** | TanStack Query (servidor) + Zustand (cliente) | 5.x + 5.x |
| **HTTP** | Axios | 1.x |
| **Formulários** | React Hook Form + Zod | 7.x + 3.x |
| **Testes** | Vitest + Testing Library + MSW + Playwright | 3.x + 16.x + 2.x |
| **Qualidade** | ESLint 9 (flat config) + Prettier + Husky | 9.x + 3.x + 9.x |
| **Arquitetura** | Feature-Sliced Design | — |
| **Runtime** | Node.js (LTS) | 20.x |

---

## Quick Start

### Pré-requisitos

- **Java 21** — [SDKMAN](https://sdkman.io/) ou [Eclipse Temurin](https://adoptium.net/)
- **Maven 3.9+** — ou use o wrapper `./mvnw`
- **Node.js 20 LTS** — [nvm](https://github.com/nvm-sh/nvm) ou [volta](https://volta.sh/)
- **npm 10+** — incluso no Node.js
- **Docker + Docker Compose** — [Docker Desktop](https://www.docker.com/products/docker-desktop/)

### Subir o ecossistema completo

```bash
# Clone o repositório
git clone https://github.com/seu-usuario/foodhub.git
cd foodhub

# Subir infraestrutura + serviços
docker compose up -d

# Verificar status
docker compose ps
```

### Desenvolvimento local (order-service isolado)

```bash
# Subir apenas infra (PostgreSQL + Kafka)
docker compose up -d postgres kafka

# Rodar o serviço
cd order-service
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev
```

### Desenvolvimento local (frontend)

```bash
# Criar e entrar no projeto
npm create vite@latest foodhub-frontend -- --template react-ts
cd foodhub-frontend

# Instalar dependências
npm install

# Rodar em desenvolvimento (proxy para :8080)
npm run dev
# → http://localhost:5173
```

### Endpoints úteis

| URL | Descrição |
|---|---|
| `http://localhost:8080` | API Gateway |
| `http://localhost:8081/swagger-ui.html` | Swagger UI (order-service) |
| `http://localhost:8761` | Eureka Dashboard |
| `http://localhost:9090` | Prometheus |
| `http://localhost:3000` | Grafana |
| `http://localhost:9411` | Zipkin (tracing) |
| `http://localhost:5173` | Frontend (Vite dev server) |

---

## Documentação

Toda a documentação técnica está em [`docs/`](docs/README.md), organizada em fases progressivas para backend e frontend:

### Backend (Java Spring Boot)

| Fase | Tema | Descrição |
|---|---|---|
| [00](docs/backend/fase-00-visao-geral.md) | **Visão Geral** | Arquitetura, stack, decisões globais |
| [01](docs/backend/fase-01-fundacao.md) | **Fundação** | Order-service do zero, CRUD, Rich Domain Model |
| [02](docs/backend/fase-02-persistencia.md) | **Persistência** | JPA avançado, N+1, Specifications, Flyway |
| [03](docs/backend/fase-03-seguranca.md) | **Segurança** | Spring Security 6, JWT, roles, autorização |
| [04](docs/backend/fase-04-mensageria.md) | **Mensageria** | Kafka, eventos de domínio, DLT, retry |
| [05](docs/backend/fase-05-testes.md) | **Testes** | JUnit 5, Mockito, Testcontainers, @WebMvcTest |
| [06](docs/backend/fase-06-documentacao-api.md) | **API Docs** | SpringDoc OpenAPI, Swagger UI |
| [07](docs/backend/fase-07-docker.md) | **Docker** | Multi-stage build, Compose, init scripts |
| [08](docs/backend/fase-08-spring-cloud.md) | **Spring Cloud** | Gateway, Eureka, Config, Feign, Resilience4j |
| [09](docs/backend/fase-09-cicd.md) | **CI/CD** | GitHub Actions, pipelines, quality gates |
| [10](docs/backend/fase-10-observabilidade.md) | **Observabilidade** | Actuator, Micrometer, Prometheus, Grafana, Zipkin |

### Frontend (React)

| Fase | Tema | Descrição |
|---|---|---|
| [00](docs/frontend/fase-00-visao-geral.md) | **Visão Geral** | Arquitetura FSD, stack, ADRs, glossário |
| [01](docs/frontend/fase-01-fundacao.md) | **Fundação** | Vite + React 19 + TS + Tailwind + ESLint |
| [02](docs/frontend/fase-02-componentes.md) | **Componentes** | Props, children, shadcn/ui, composição |
| [03](docs/frontend/fase-03-roteamento.md) | **Roteamento** | React Router 7, layouts, lazy loading |
| [04](docs/frontend/fase-04-estado-global.md) | **Estado Global** | Zustand, useState, hooks, custom hooks |
| [05](docs/frontend/fase-05-integracao-api.md) | **Integração API** | Axios, TanStack Query, cache |
| [06](docs/frontend/fase-06-autenticacao.md) | **Autenticação** | JWT, login, proteção de rotas, refresh token |
| [07](docs/frontend/fase-07-formularios.md) | **Formulários** | React Hook Form, Zod, validação |
| [08](docs/frontend/fase-08-testes.md) | **Testes** | Vitest, Testing Library, MSW, Playwright |
| [09](docs/frontend/fase-09-performance.md) | **Performance** | Memo, virtual, skeleton, bundle |
| [10](docs/frontend/fase-10-build-deploy.md) | **Build & Deploy** | Docker, Nginx, GitHub Actions |

---

## Estrutura do Projeto

```
foodhub/
├── order-service/              # Serviço principal de pedidos
├── restaurant-service/         # Cadastro de restaurantes e cardápios
├── payment-service/            # Processamento de pagamentos
├── notification-service/       # Notificações via Kafka
├── api-gateway/                # Spring Cloud Gateway
├── config-server/              # Spring Cloud Config
├── discovery-server/           # Eureka Server
├── foodhub-frontend/           # SPA React + TypeScript
├── docs/                       # Documentação completa (backend + frontend)
│   ├── backend/                # 11 fases do backend
│   └── frontend/               # 11 fases do frontend
├── docker-compose.yml          # Orquestração do ecossistema
└── .github/workflows/          # CI/CD pipelines
```

Cada microserviço segue **Arquitetura Hexagonal** (Ports & Adapters):

```
service/
├── domain/           # Hexágono interno — Entidades, Value Objects, eventos (Java puro)
├── application/      # Use Cases, DTOs, portas de entrada/saída (interfaces)
└── adapter/          # Adaptadores concretos
    ├── in/web/       # Controllers, exception handlers, segurança (entrada HTTP)
    └── out/          # JPA, Kafka, Feign, configs (saída para infra)
```

> **Regra de dependência:** `adapter.in → application → domain ← adapter.out`

O frontend segue **Feature-Sliced Design**:

```
foodhub-frontend/src/
├── app/              # Providers, router, layouts globais, páginas
├── features/         # Módulos por domínio (orders/, restaurants/, auth/)
│   └── <feature>/
│       ├── api/      # Hooks TanStack Query + funções Axios
│       ├── components/
│       ├── hooks/
│       └── types/
└── shared/           # Componentes, hooks, utils e tipos reutilizáveis
    ├── components/ui/  # shadcn/ui components
    ├── hooks/
    ├── lib/          # Axios client, cn(), helpers
    └── types/        # ApiError, PaginatedResponse, etc.
```

---

## Decisões Arquiteturais

### Backend

| ADR | Decisão | Justificativa |
|---|---|---|
| **ADR-001** | REST síncrono + Kafka assíncrono | Queries precisam de resposta imediata; eventos permitem desacoplamento |
| **ADR-002** | Database-per-service (PostgreSQL) | Autonomia, isolamento e desacoplamento entre serviços |
| **ADR-003** | Flyway para migrations | Rastreabilidade, reprodutibilidade e rollback de schema |

### Frontend

| ADR | Decisão | Justificativa |
|---|---|---|
| **F-001** | SPA com Vite (sem SSR/Next.js) | Painel admin—SPA pura, sem necessidade de SEO |
| **F-002** | Tailwind CSS 4 + shadcn/ui | Utility-first, componentes versionados no projeto |
| **F-003** | TanStack Query para estado do servidor | Cache, revalidação automática, stale-while-revalidate |
| **F-004** | Zustand para estado do cliente | Leve, sem boilerplate, persist middleware |
| **F-005** | Feature-Sliced Design | Arquitetura escalável com módulos isolados por domínio |

---

## Testes

### Backend

```bash
# Testes unitários
./mvnw test

# Testes de integração (requer Docker)
./mvnw verify -Pfailsafe

# Cobertura
./mvnw jacoco:report
```

| Camada | Tipo | Ferramentas |
|---|---|---|
| Domain | Unitário | JUnit 5, AssertJ |
| Application | Unitário + Mock | JUnit 5, Mockito |
| API | Slice test | @WebMvcTest, MockMvc |
| Integração | E2E | @SpringBootTest, Testcontainers |

### Frontend

```bash
# Testes unitários e de integração
npm run test

# Com cobertura
npm run test -- --coverage

# Testes E2E
npx playwright test
```

| Camada | Tipo | Ferramentas |
|---|---|---|
| Utils/Hooks | Unitário | Vitest, Testing Library |
| Componentes | Integração | Vitest, Testing Library, MSW |
| Páginas | Integração | Vitest, Testing Library, MSW |
| Fluxos | E2E | Playwright |

---

## Roadmap

### Backend

- [x] Arquitetura e documentação completa
- [ ] Implementação do order-service (fases 01–06)
- [ ] Docker Compose do ecossistema (fase 07)
- [ ] Spring Cloud: Gateway, Eureka, Config (fase 08)
- [ ] CI/CD com GitHub Actions (fase 09)
- [ ] Observabilidade: Prometheus, Grafana, Zipkin (fase 10)
- [ ] Restaurant-service e Payment-service
- [ ] Deploy AWS (ECS)

### Frontend

- [x] Documentação completa (11 fases)
- [ ] Fundação: Vite + React 19 + Tailwind CSS 4 (fase 01)
- [ ] Componentes e estilização com shadcn/ui (fase 02)
- [ ] Roteamento e layouts (fase 03)
- [ ] Estado global com Zustand (fase 04)
- [ ] Integração API com TanStack Query (fase 05)
- [ ] Autenticação JWT completa (fase 06)
- [ ] Formulários com React Hook Form + Zod (fase 07)
- [ ] Testes: Vitest + Playwright (fase 08)
- [ ] Performance e otimização (fase 09)
- [ ] Build, Docker e CI/CD (fase 10)

---

## Competências Praticadas

Este projeto cobre **36 competências** exigidas em vagas enterprise fullstack:

<details>
<summary>Ver checklist completo</summary>

### Backend (24)

| # | Competência | Módulo |
|---|---|---|
| 1 | Java 21 (Records, Pattern Matching) | DTOs, switch, text blocks |
| 2 | Spring Boot 3.5 | Todos os serviços |
| 3 | Spring Data JPA + Hibernate | Repositories, queries |
| 4 | PostgreSQL | Database-per-service |
| 5 | APIs REST + Paginação | Controllers |
| 6 | Microserviços | 4 negócio + 3 infra |
| 7 | Spring Security + JWT | Auth, roles |
| 8 | Maven | Build, BOM |
| 9 | Git + Git Flow | Branches |
| 10 | JUnit 5 + Mockito | Unit + mock tests |
| 11 | Testcontainers | Integration tests |
| 12 | Docker + Compose | Containerização |
| 13 | Apache Kafka | Eventos |
| 14 | OpenAPI/Swagger | API docs |
| 15 | Spring Cloud Gateway | API Gateway |
| 16 | Eureka | Service Discovery |
| 17 | Spring Cloud Config | Configuração |
| 18 | DDD | Rich Domain Model |
| 19 | Arquitetura Hexagonal (Ports & Adapters) | Portas e Adaptadores |
| 20 | SOLID + Clean Code | Código |
| 21 | CI/CD | GitHub Actions |
| 22 | Observabilidade | Metrics, tracing |
| 23 | Cloud (AWS) | Deploy ECS |
| 24 | Flyway | Migrations |

### Frontend (12)

| # | Competência | Módulo |
|---|---|---|
| 25 | React 19 + TypeScript 5 | Componentes, hooks, tipagem |
| 26 | Vite 6 | Build, HMR, dev server |
| 27 | Tailwind CSS 4 + shadcn/ui | Estilização, design system |
| 28 | React Router 7 | Roteamento, lazy loading, layouts |
| 29 | Zustand 5 | Estado global do cliente |
| 30 | TanStack Query 5 | Cache, stale-while-revalidate |
| 31 | Axios + JWT interceptors | HTTP client, refresh token |
| 32 | React Hook Form + Zod | Formulários, validação |
| 33 | Vitest + Testing Library | Testes unitários/integração |
| 34 | MSW (Mock Service Worker) | Mocks de API para testes |
| 35 | Playwright | Testes E2E |
| 36 | Feature-Sliced Design | Arquitetura de frontend escalável |

</details>

---

## Licença

Este projeto é para fins educacionais e de portfólio.

---

<p align="center">
  <sub>Feito com ☕ Java, ⚛️ React e dedicação</sub>
</p>
