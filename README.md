<p align="center">
  <img src="https://img.shields.io/badge/Java-21-ED8B00?style=for-the-badge&logo=openjdk&logoColor=white" alt="Java 21"/>
  <img src="https://img.shields.io/badge/Spring_Boot-3.5-6DB33F?style=for-the-badge&logo=springboot&logoColor=white" alt="Spring Boot 3.5"/>
  <img src="https://img.shields.io/badge/Spring_Cloud-2025.0-6DB33F?style=for-the-badge&logo=spring&logoColor=white" alt="Spring Cloud"/>
  <img src="https://img.shields.io/badge/Apache_Kafka-3.x-231F20?style=for-the-badge&logo=apachekafka&logoColor=white" alt="Kafka"/>
  <img src="https://img.shields.io/badge/PostgreSQL-16-4169E1?style=for-the-badge&logo=postgresql&logoColor=white" alt="PostgreSQL"/>
  <img src="https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker"/>
</p>

<h1 align="center">🍔 FoodHub</h1>

<p align="center">
  <strong>Plataforma de pedidos de comida baseada em microserviços</strong><br/>
  Projeto enterprise completo com Java 21, Spring Boot 3.5 e Spring Cloud — do zero ao deploy.
</p>

<p align="center">
  <a href="#arquitetura">Arquitetura</a> •
  <a href="#serviços">Serviços</a> •
  <a href="#tech-stack">Tech Stack</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#documentação">Documentação</a> •
  <a href="#roadmap">Roadmap</a>
</p>

---

## Sobre

**FoodHub** é uma plataforma de pedidos de comida construída como microserviços enterprise. O projeto cobre o ciclo completo de desenvolvimento: API REST, persistência, segurança, mensageria assíncrona, containerização, service mesh, CI/CD e observabilidade.

Projetado para demonstrar as competências exigidas em vagas enterprise de Java no Brasil — cada módulo mapeia diretamente para um requisito real de mercado.

---

## Arquitetura

```
                            ┌─────────────────┐
                            │   Cliente/App   │
                            └────────┬────────┘
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

**Padrões:** REST síncrono para queries (OpenFeign) · Eventos assíncronos para reações (Kafka) · Database-per-service · DDD + Arquitetura Hexagonal (Ports & Adapters)

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

## Tech Stack

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

---

## Quick Start

### Pré-requisitos

- **Java 21** — [SDKMAN](https://sdkman.io/) ou [Eclipse Temurin](https://adoptium.net/)
- **Maven 3.9+** — ou use o wrapper `./mvnw`
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

### Endpoints úteis

| URL | Descrição |
|---|---|
| `http://localhost:8080` | API Gateway |
| `http://localhost:8081/swagger-ui.html` | Swagger UI (order-service) |
| `http://localhost:8761` | Eureka Dashboard |
| `http://localhost:9090` | Prometheus |
| `http://localhost:3000` | Grafana |
| `http://localhost:9411` | Zipkin (tracing) |

---

## Documentação

Toda a documentação técnica está em [`docs/`](docs/README.md), organizada em fases progressivas:

| Fase | Tema | Descrição |
|---|---|---|
| [00](docs/fase-00-visao-geral.md) | **Visão Geral** | Arquitetura, stack, decisões globais |
| [01](docs/fase-01-fundacao.md) | **Fundação** | Order-service do zero, CRUD, Rich Domain Model |
| [02](docs/fase-02-persistencia.md) | **Persistência** | JPA avançado, N+1, Specifications, Flyway |
| [03](docs/fase-03-seguranca.md) | **Segurança** | Spring Security 6, JWT, roles, autorização |
| [04](docs/fase-04-mensageria.md) | **Mensageria** | Kafka, eventos de domínio, DLT, retry |
| [05](docs/fase-05-testes.md) | **Testes** | JUnit 5, Mockito, Testcontainers, @WebMvcTest |
| [06](docs/fase-06-documentacao-api.md) | **API Docs** | SpringDoc OpenAPI, Swagger UI |
| [07](docs/fase-07-docker.md) | **Docker** | Multi-stage build, Compose, init scripts |
| [08](docs/fase-08-spring-cloud.md) | **Spring Cloud** | Gateway, Eureka, Config, Feign, Resilience4j |
| [09](docs/fase-09-cicd.md) | **CI/CD** | GitHub Actions, pipelines, quality gates |
| [10](docs/fase-10-observabilidade.md) | **Observabilidade** | Actuator, Micrometer, Prometheus, Grafana, Zipkin |

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
├── docs/                       # Documentação completa (11 fases)
├── docker-compose.yml          # Orquestração do ecossistema
└── .github/workflows/          # CI/CD pipelines
```

Cada microserviço segue Arquitetura Hexagonal (Ports & Adapters):

```
service/
├── domain/           # Hexágono interno — Entidades, Value Objects, eventos (Java puro)
├── application/      # Use Cases, DTOs, portas de entrada/saída (interfaces)
└── adapter/          # Adaptadores concretos
    ├── in/web/       # Controllers, exception handlers, segurança (entrada HTTP)
    └── out/          # JPA, Kafka, Feign, configs (saída para infra)
```

> **Regra de dependência:** `adapter.in → application → domain ← adapter.out`

---

## Decisões Arquiteturais

| ADR | Decisão | Justificativa |
|---|---|---|
| **ADR-001** | REST síncrono + Kafka assíncrono | Queries precisam de resposta imediata; eventos permitem desacoplamento |
| **ADR-002** | Database-per-service (PostgreSQL) | Autonomia, isolamento e desacoplamento entre serviços |
| **ADR-003** | Flyway para migrations | Rastreabilidade, reprodutibilidade e rollback de schema |

---

## Testes

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

---

## Roadmap

- [x] Arquitetura e documentação completa
- [ ] Implementação do order-service (fases 01–06)
- [ ] Docker Compose do ecossistema (fase 07)
- [ ] Spring Cloud: Gateway, Eureka, Config (fase 08)
- [ ] CI/CD com GitHub Actions (fase 09)
- [ ] Observabilidade: Prometheus, Grafana, Zipkin (fase 10)
- [ ] Restaurant-service e Payment-service
- [ ] Deploy AWS (ECS)

---

## Competências Praticadas

Este projeto cobre **24 competências** exigidas em vagas enterprise Java:

<details>
<summary>Ver checklist completo</summary>

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

</details>

---

## Licença

Este projeto é para fins educacionais e de portfólio.

---

<p align="center">
  <sub>Feito com ☕ Java e dedicação</sub>
</p>
