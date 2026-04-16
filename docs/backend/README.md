# FoodHub — Documentação do Projeto

> Guia completo, fase por fase, para construir um sistema de microserviços enterprise com Java Spring Boot.

## Estrutura da Documentação

| Arquivo | Conteúdo |
|---|---|
| [fase-00-visao-geral.md](fase-00-visao-geral.md) | Arquitetura, stack, estrutura de pacotes, decisões globais |
| [fase-01-fundacao.md](fase-01-fundacao.md) | Criação do order-service, pom.xml completo, entidades, DTOs, controller, service |
| [fase-02-persistencia.md](fase-02-persistencia.md) | Spring Data JPA, PostgreSQL, Flyway, boas práticas de performance |
| [fase-03-seguranca.md](fase-03-seguranca.md) | Spring Security 6, JWT, autenticação, autorização por roles |
| [fase-04-mensageria.md](fase-04-mensageria.md) | Apache Kafka, eventos de domínio, producer, consumer |
| [fase-05-testes.md](fase-05-testes.md) | JUnit 5, Mockito, Testcontainers, @WebMvcTest, @DataJpaTest |
| [fase-06-documentacao-api.md](fase-06-documentacao-api.md) | SpringDoc OpenAPI, Swagger UI, anotações |
| [fase-07-docker.md](fase-07-docker.md) | Dockerfile multi-stage, Docker Compose, init scripts |
| [fase-08-spring-cloud.md](fase-08-spring-cloud.md) | API Gateway, Eureka, Config Server, OpenFeign, Resilience4j |
| [fase-09-cicd.md](fase-09-cicd.md) | GitHub Actions, pipelines, build e deploy |
| [fase-10-observabilidade.md](fase-10-observabilidade.md) | Actuator, Micrometer, Prometheus, Grafana, deploy AWS |

## Ordem de Implementação Recomendada

```
 1. Fase 00 — Leia primeiro (visão geral, não escreve código)
 2. Fase 01 — Fundação do order-service (CRUD funcional)
 3. Fase 02 — Persistência avançada (N+1, projections, Flyway)
 4. Fase 03 — Segurança (JWT + Spring Security)
 5. Fase 04 — Mensageria (Kafka: producer + consumer)
 6. Fase 05 — Testes (unitários, integração, E2E)
 7. Fase 06 — Documentação da API (Swagger/OpenAPI)
 8. Fase 07 — Docker (containerização completa)
 9. Fase 08 — Spring Cloud (Gateway, Eureka, Feign)
10. Fase 09 — CI/CD (GitHub Actions pipeline)
11. Fase 10 — Observabilidade (métricas, logs, tracing)
```

> **Dica:** Cada fase depende das anteriores. Não pule fases — o conhecimento é cumulativo.

---

## Decisões Arquiteturais (ADRs)

### ADR-001: Comunicação entre serviços

| Item | Decisão |
|---|---|
| **Contexto** | Microserviços precisam se comunicar |
| **Decisão** | REST síncrono para queries, Kafka assíncrono para eventos |
| **Justificativa** | Queries precisam de resposta imediata; eventos permitem desacoplamento |
| **Consequência** | Consistência eventual para fluxos baseados em eventos |

### ADR-002: Estratégia de banco de dados

| Item | Decisão |
|---|---|
| **Contexto** | Múltiplos microserviços precisam de persistência |
| **Decisão** | Database-per-service com PostgreSQL |
| **Justificativa** | Autonomia, isolamento e desacoplamento |
| **Consequência** | Sem JOINs cross-service; dados duplicados via eventos |

### ADR-003: Versionamento de schema

| Item | Decisão |
|---|---|
| **Contexto** | Schema do banco precisa evoluir de forma controlada |
| **Decisão** | Flyway com migrations SQL versionadas |
| **Justificativa** | Rastreabilidade, reprodutibilidade, rollback possível |
| **Consequência** | Toda alteração de schema precisa de migration |

---

## Checklist de Competências

Use para acompanhar seu progresso. Cada item é praticado neste projeto:

| # | Competência | Onde no Projeto | Status |
|---|---|---|---|
| 1 | Java 21 (Records, Pattern Matching, Text Blocks) | DTOs, switch expressions, SQL queries | ⬜ |
| 2 | Spring Boot 3.5 | Todos os serviços | ⬜ |
| 3 | Spring Data JPA + Hibernate | Repositories, entidades, queries | ⬜ |
| 4 | PostgreSQL | Banco de cada serviço | ⬜ |
| 5 | APIs REST (CRUD + paginação) | Controllers | ⬜ |
| 6 | Arquitetura de Microserviços | 4 serviços + 3 infra | ⬜ |
| 7 | Spring Security + JWT | Autenticação e autorização | ⬜ |
| 8 | Maven | Build e dependências | ⬜ |
| 9 | Git + Git Flow | Branches feature/develop/main | ⬜ |
| 10 | JUnit 5 + Mockito | Testes unitários e com mock | ⬜ |
| 11 | Testcontainers | Testes de integração | ⬜ |
| 12 | Docker + Docker Compose | Containerização completa | ⬜ |
| 13 | Apache Kafka | Eventos entre serviços | ⬜ |
| 14 | Swagger/OpenAPI | Documentação automática | ⬜ |
| 15 | Spring Cloud Gateway | API Gateway | ⬜ |
| 16 | Spring Cloud Eureka | Service Discovery | ⬜ |
| 17 | Spring Cloud Config | Configuração centralizada | ⬜ |
| 18 | DDD (Entidades ricas, Aggregates, Events) | Camada domain/ | ⬜ |
| 19 | Arquitetura Hexagonal (Ports & Adapters, inversão de dep.) | Estrutura de pacotes | ⬜ |
| 20 | SOLID + Clean Code | Código inteiro | ⬜ |
| 21 | CI/CD | GitHub Actions | ⬜ |
| 22 | Observabilidade (Actuator, Prometheus, Grafana) | Métricas e health checks | ⬜ |
| 23 | Cloud (AWS) | Deploy com ECS | ⬜ |
| 24 | Flyway (Migrations) | Versionamento de schema | ⬜ |
