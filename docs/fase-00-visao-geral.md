# Fase 00 — Visão Geral, Arquitetura e Decisões Globais

> **Objetivo desta fase:** Entender o projeto como um todo antes de escrever qualquer linha de código. Pensar como arquiteto: quais problemas estamos resolvendo, quais tecnologias vamos usar e por quê.

---

## 1. O Sistema: FoodHub

**FoodHub** é uma plataforma simplificada de pedidos de comida. O domínio foi escolhido porque:

- Todo mundo entende — já pediu comida alguma vez.
- Tem múltiplas entidades com relacionamentos reais (Restaurante → Cardápio → Item → Pedido → Pagamento).
- Exige comunicação entre serviços (síncrona e assíncrona).
- Permite praticar segurança (autenticação, autorização por role).
- Gera eventos de negócio reais (pedido criado, pagamento confirmado, notificação enviada).

---

## 2. Microserviços de Negócio

| Microserviço | Porta | Responsabilidade | Banco |
|---|---|---|---|
| **order-service** | 8081 | Criação, consulta e gerenciamento de pedidos | `foodhub_orders` |
| **restaurant-service** | 8082 | Cadastro de restaurantes, cardápios e itens | `foodhub_restaurants` |
| **payment-service** | 8083 | Processamento (simulado) de pagamentos | `foodhub_payments` |
| **notification-service** | 8084 | Envio de notificações (via evento Kafka) | — (sem banco) |

> **📝 Nota:** O `notification-service` e o `payment-service` não são implementados passo a passo nos documentos. O foco das fases é o `order-service`. Após completar todas as fases, implemente os outros serviços como exercício — a arquitetura e padrões são os mesmos.

### Por que 4 serviços?

Cada serviço representa um **bounded context** diferente no DDD:

- **Order** — contexto de pedidos. Sabe sobre pedidos e seus itens.
- **Restaurant** — contexto de restaurantes. Sabe sobre restaurantes, cardápios e preços.
- **Payment** — contexto financeiro. Sabe sobre pagamentos e transações.
- **Notification** — contexto de comunicação. Sabe sobre como notificar o usuário.

> **Regra DDD:** Cada bounded context tem sua própria linguagem ubíqua e seu próprio modelo. Um "Item" no contexto de Restaurante (menu item com descrição e preço) é diferente de um "Item" no contexto de Pedido (item pedido com quantidade e subtotal).

---

## 3. Serviços de Infraestrutura

| Serviço | Porta | Responsabilidade |
|---|---|---|
| **api-gateway** | 8080 | Spring Cloud Gateway — ponto único de entrada para todos os clientes |
| **config-server** | 8888 | Spring Cloud Config — configuração centralizada (puxada de um repo Git) |
| **discovery-server** | 8761 | Spring Cloud Netflix Eureka — registro e descoberta de serviços |

---

## 4. Diagrama da Arquitetura

```
                            ┌─────────────────┐
                            │   Cliente/App    │
                            └────────┬────────┘
                                     │ HTTP (porta 8080)
                            ┌────────▼────────┐
                            │   API Gateway    │
                            │ (Spring Cloud    │
                            │  Gateway)        │
                            └────────┬────────┘
                                     │
                 ┌───────────────────┼───────────────────┐
                 │                   │                     │
        ┌────────▼──────┐  ┌────────▼──────┐   ┌─────────▼─────┐
        │ order-service  │  │ restaurant-   │   │ payment-      │
        │   :8081        │  │ service       │   │ service       │
        │                │◄─┤   :8082       │   │   :8083       │
        └───────┬────────┘  └───────────────┘   └───────┬───────┘
                │    OpenFeign (REST síncrono) ▲         │
                │                                        │
                │        ┌──────────────┐               │
                └───────►│    Kafka      │◄──────────────┘
                         │   Broker      │
                         └──────┬───────┘
                                │
                       ┌────────▼────────┐
                       │ notification-   │
                       │ service         │
                       │   :8084         │
                       └─────────────────┘

        ┌─────────────────┐    ┌─────────────────┐
        │ Config Server   │    │ Eureka Server   │
        │   :8888         │    │   :8761         │
        └─────────────────┘    └─────────────────┘
```

---

## 5. Fluxo Principal: Criar um Pedido (passo a passo)

```
Cliente                Gateway         order-service    restaurant-service    Kafka           payment-service    notification-service
  │                      │                  │                  │                │                  │                    │
  │ POST /api/orders     │                  │                  │                │                  │                    │
  │─────────────────────►│                  │                  │                │                  │                    │
  │                      │  roteia p/ order │                  │                │                  │                    │
  │                      │─────────────────►│                  │                │                  │                    │
  │                      │                  │ GET /api/internal│                │                  │                    │
  │                      │                  │  /restaurants/   │                │                  │                    │
  │                      │                  │  {id}/menu-items │                │                  │                    │
  │                      │                  │─────────────────►│                │                  │                    │
  │                      │                  │  200 OK (itens)  │                │                  │                    │
  │                      │                  │◄─────────────────│                │                  │                    │
  │                      │                  │                  │                │                  │                    │
  │                      │                  │ Salva pedido     │                │                  │                    │
  │                      │                  │ (PostgreSQL)     │                │                  │                    │
  │                      │                  │                  │                │                  │                    │
  │                      │                  │ Publica OrderCreatedEvent        │                  │                    │
  │                      │                  │─────────────────────────────────►│                  │                    │
  │                      │  201 Created     │                  │                │                  │                    │
  │                      │◄─────────────────│                  │                │                  │                    │
  │  201 Created         │                  │                  │                │                  │                    │
  │◄─────────────────────│                  │                  │                │                  │                    │
  │                      │                  │                  │                │ Consome evento   │                    │
  │                      │                  │                  │                │─────────────────►│                    │
  │                      │                  │                  │                │                  │ Processa pgto       │
  │                      │                  │                  │                │                  │ (simulado)          │
  │                      │                  │                  │                │ PaymentConfirmed │                    │
  │                      │                  │                  │                │◄─────────────────│                    │
  │                      │                  │ Consome evento   │                │                  │                    │
  │                      │                  │◄─────────────────────────────────│                  │                    │
  │                      │                  │ Atualiza status  │                │                  │                    │
  │                      │                  │ → CONFIRMED      │                │                  │                    │
  │                      │                  │                  │                │                  │                    │
  │                      │                  │                  │                │ Consome ambos    │                    │
  │                      │                  │                  │                │──────────────────────────────────────►│
  │                      │                  │                  │                │                  │   Notifica cliente  │
```

### Comunicação Síncrona vs Assíncrona

| Tipo | Quando usar | Exemplo no FoodHub | Tecnologia |
|---|---|---|---|
| **Síncrona (REST)** | O chamador **precisa da resposta** para continuar | order-service verifica se os itens do menu existem no restaurant-service | OpenFeign |
| **Assíncrona (Evento)** | É uma **consequência/reação** que não bloqueia o chamador | Após criar o pedido, o payment-service processa o pagamento | Apache Kafka |

> **Regra prática:** Se o fluxo para sem a resposta → síncrono. Se é uma ação decorrente que pode acontecer depois → assíncrono.

---

## 6. Stack Tecnológica Completa

| Categoria | Tecnologia | Versão | Justificativa |
|---|---|---|---|
| **Linguagem** | Java | 21 (LTS) | LTS mais recente; records, sealed classes, pattern matching, virtual threads |
| **Framework** | Spring Boot | 3.5.x | Última versão estável; suporta Java 21 nativamente |
| **Build** | Maven | 3.9+ | Mais usado em projetos enterprise no Brasil |
| **Banco** | PostgreSQL | 16+ | O banco relacional mais pedido nas vagas |
| **ORM** | Spring Data JPA + Hibernate 6 | (gerenciado pelo Spring Boot) | Padrão da indústria |
| **Migrations** | Flyway | (gerenciado pelo Spring Boot) | Versionamento de schema do banco |
| **Segurança** | Spring Security 6 + jjwt | 6.x / 0.12.x | JWT stateless para microserviços |
| **Mensageria** | Apache Kafka | 3.x via Spring Kafka | Broker de eventos mais pedido |
| **Gateway** | Spring Cloud Gateway | 2025.0.x (Northfields) | API Gateway reativo |
| **Discovery** | Eureka Server | 2025.0.x (Northfields) | Service discovery mais comum |
| **Config** | Spring Cloud Config | 2025.0.x (Northfields) | Configuração centralizada via Git |
| **Feign** | Spring Cloud OpenFeign | 2025.0.x (Northfields) | Cliente HTTP declarativo entre serviços |
| **Resiliência** | Resilience4j | 2.x | Circuit breaker, retry, rate limiter |
| **Docs** | SpringDoc OpenAPI | 2.8.x | Swagger UI automático para Spring Boot 3 |
| **Testes** | JUnit 5 + Mockito + Testcontainers | (gerenciado pelo Spring Boot) | Stack padrão enterprise |
| **Container** | Docker + Docker Compose | — | Containerização padrão |
| **CI/CD** | GitHub Actions | — | Integração nativa com GitHub |

### Por que Maven e não Gradle?

Maven é mais verboso (XML), mas é o que a **maioria dos projetos enterprise no Brasil** usa. Para fins de empregabilidade, dominar Maven primeiro é mais estratégico. Gradle é mais moderno, mas a migração de conhecimento Maven → Gradle é simples.

### Por que Java 21 e não 17?

Java 17 é o LTS mais consolidado. Java 21 é o LTS mais recente e já está sendo adotado pelas empresas mais modernas. Usar 21 permite praticar features que impressionam entrevistadores: **records** (DTOs), **pattern matching** (switch), **sealed classes** (hierarquias controladas), **text blocks** (SQL/JSON legíveis) e **virtual threads** (concorrência leve). Se a empresa usar Java 17 ou 11, a migração descendente é trivial.

---

## 7. Estrutura de Pacotes — Arquitetura Hexagonal (Ports & Adapters)

Cada microserviço segue **DDD + Arquitetura Hexagonal (Ports & Adapters)**:

> **Por que Hexagonal?** — É a arquitetura mais adotada por **bancos, fintechs e grandes empresas** no Brasil. O conceito central é simples: o domínio (hexágono interno) não conhece o mundo externo. Toda comunicação passa por **portas** (interfaces) e **adaptadores** (implementações concretas). Isso permite trocar banco de dados, broker de mensageria ou framework web sem alterar uma linha de lógica de negócio.

```
order-service/
├── src/main/java/com/foodhub/order/
│   ├── OrderServiceApplication.java           # @SpringBootApplication (Composition Root)
│   │
│   ├── domain/                                 # HEXÁGONO INTERNO — Regras de negócio (Java puro)
│   │   ├── model/                              # Entidades JPA e Value Objects
│   │   │   ├── Order.java                      # Aggregate Root
│   │   │   ├── OrderItem.java                  # Entidade filha
│   │   │   ├── OrderStatus.java                # Enum
│   │   │   └── Money.java                      # Value Object (opcional)
│   │   ├── service/                            # Regras de negócio puras (opcional)
│   │   │   └── OrderDomainService.java
│   │   ├── event/                              # Eventos de domínio (records)
│   │   │   └── OrderCreatedEvent.java
│   │   └── exception/                          # Exceções de domínio
│   │       └── OrderNotFoundException.java
│   │
│   ├── application/                            # CAMADA DE APLICAÇÃO (Use Cases + Portas)
│   │   ├── port/                               # PORTAS — Contratos do hexágono
│   │   │   ├── in/                             # Portas de ENTRADA (o que o app sabe fazer)
│   │   │   │   └── CreateOrderUseCase.java     # Interface do use case (opcional)
│   │   │   └── out/                            # Portas de SAÍDA (o que o app precisa)
│   │   │       ├── OrderRepository.java        # Porta para persistência (Spring Data)
│   │   │       └── OrderEventPublisher.java    # Porta para publicar eventos
│   │   ├── usecase/                            # Implementações dos use cases
│   │   │   └── OrderApplicationService.java    # Orquestra domínio + portas
│   │   ├── dto/                                # Data Transfer Objects (records)
│   │   │   ├── CreateOrderRequest.java
│   │   │   ├── OrderResponse.java
│   │   │   ├── OrderItemRequest.java
│   │   │   ├── OrderItemResponse.java
│   │   │   └── UpdateOrderStatusRequest.java
│   │   └── mapper/                             # Conversão Entity <-> DTO
│   │       └── OrderMapper.java
│   │
│   └── adapter/                                # ADAPTADORES — Implementações concretas
│       ├── in/                                 # Adaptadores de ENTRADA (quem chama o app)
│       │   └── web/                            # HTTP/REST
│       │       ├── controller/                 # REST Controllers
│       │       │   └── OrderController.java    # Chama use case via porta
│       │       ├── exception/                  # Exception handlers globais
│       │       │   └── GlobalExceptionHandler.java
│       │       └── security/                   # Segurança HTTP (JWT, filtros)
│       │           ├── JwtService.java
│       │           ├── JwtAuthenticationFilter.java
│       │           └── SecurityConfig.java
│       └── out/                                # Adaptadores de SAÍDA (o app chama)
│           ├── persistence/                    # JPA configs
│           │   └── JpaConfig.java
│           ├── messaging/                      # Kafka (implementa OrderEventPublisher)
│           │   ├── KafkaOrderEventPublisher.java
│           │   ├── PaymentEventListener.java
│           │   └── KafkaConfig.java
│           ├── client/                         # OpenFeign (comunicação inter-serviço)
│           │   ├── RestaurantClient.java        # @FeignClient para restaurant-service
│           │   └── RestaurantClientFallback.java
│           └── config/                         # Configs de infraestrutura
│               └── OpenApiConfig.java
│
├── src/main/resources/
│   ├── application.yml                         # Configuração principal
│   ├── application-dev.yml                     # Profile de desenvolvimento
│   ├── application-prod.yml                    # Profile de produção
│   └── db/migration/                           # Flyway migrations
│       ├── V1__create_orders_table.sql
│       └── V2__create_order_items_table.sql
│
├── src/test/java/com/foodhub/order/
│   ├── domain/model/OrderTest.java             # Testes unitários de domínio
│   ├── application/usecase/OrderApplicationServiceTest.java  # Testes com Mockito
│   ├── adapter/in/web/controller/OrderControllerTest.java # @WebMvcTest
│   └── integration/OrderIntegrationTest.java   # @SpringBootTest + Testcontainers
│
├── Dockerfile
└── pom.xml
```

> **💡 Convenção de nomes:** Portas em `application/port/out/` são **interfaces Java** — o pacote já indica que são portas, dispensando sufixo "Port". Spring Data repositories (como `OrderRepository extends JpaRepository`) naturalmente servem como portas de saída por serem interfaces. O `@FeignClient` (`RestaurantClient`) é usado diretamente como adaptador para simplicidade; em produção, extraia uma porta `RestaurantPort` em `application/port/out/` e faça o Feign implementá-la.

### Regra de Dependência (Arquitetura Hexagonal)

```
    adapter.in  →  application  →  domain
       (web)                        ↑
                    adapter.out  ───┘
               (persistence, messaging, client)
```

- **domain/** é o hexágono interno. Não depende de nada externo. É Java puro (com anotações JPA como exceção pragmática).
- **application/** contém os use cases e as **portas** (interfaces). Depende do domínio. Não conhece detalhes de infraestrutura.
- **adapter/out/** implementa as **portas de saída** (inversão de dependência). Banco, Kafka, Feign — tudo é adaptador.
- **adapter/in/** são os **adaptadores de entrada** — controllers, filtros, listeners. Chamam os use cases via portas de entrada.

> **Conceito-chave:** As portas são **interfaces** que vivem em `application/port/`. Os adaptadores são **implementações concretas** que vivem em `adapter/`. A dependência sempre aponta para **dentro** do hexágono, nunca para fora. Isso é a **inversão de dependência** em ação.

> **Por que a entidade JPA está no domain/?** — Em arquitetura hexagonal pura, a entidade JPA ficaria em `adapter/out/persistence/` e haveria uma entidade de domínio separada. Isso é over-engineering para a maioria dos projetos. A abordagem pragmática (e a mais usada no mercado, inclusive em bancos e fintechs) é manter a entidade JPA no domain/ com anotações JPA. O importante é que a **lógica de negócio** fique na entidade (Rich Domain Model), não espalhada em services.

---

## 8. Modelagem de Dados

### order-service

```
┌──────────────────────────────┐
│           orders             │
├──────────────────────────────┤
│ id              BIGSERIAL PK │
│ customer_id     BIGINT       │
│ restaurant_id   BIGINT       │
│ status          VARCHAR(20)  │
│ total_amount    DECIMAL(10,2)│
│ created_at      TIMESTAMP    │
│ updated_at      TIMESTAMP    │
│ version         INTEGER      │  ← Optimistic locking
└──────────────────────────────┘
         │ 1:N
┌──────────────────────────────┐
│        order_items           │
├──────────────────────────────┤
│ id              BIGSERIAL PK │
│ order_id        BIGINT FK    │
│ menu_item_id    BIGINT       │
│ menu_item_name  VARCHAR(255) │  ← Desnormalizado (snapshot do nome)
│ quantity        INTEGER      │
│ unit_price      DECIMAL(10,2)│
│ subtotal        DECIMAL(10,2)│
└──────────────────────────────┘
```

### restaurant-service

```
┌──────────────────────────────┐
│        restaurants           │
├──────────────────────────────┤
│ id              BIGSERIAL PK │
│ name            VARCHAR(255) │
│ description     TEXT         │
│ address         VARCHAR(500) │
│ phone           VARCHAR(20)  │
│ active          BOOLEAN      │
│ created_at      TIMESTAMP    │
│ updated_at      TIMESTAMP    │
└──────────────────────────────┘
         │ 1:N
┌──────────────────────────────┐
│        menu_items            │
├──────────────────────────────┤
│ id              BIGSERIAL PK │
│ restaurant_id   BIGINT FK    │
│ name            VARCHAR(255) │
│ description     TEXT         │
│ price           DECIMAL(10,2)│
│ available       BOOLEAN      │
│ created_at      TIMESTAMP    │
│ updated_at      TIMESTAMP    │
└──────────────────────────────┘
```

### payment-service

```
┌──────────────────────────────┐
│          payments            │
├──────────────────────────────┤
│ id              BIGSERIAL PK │
│ order_id        BIGINT       │  ← Referência lógica (não FK real)
│ amount          DECIMAL(10,2)│
│ status          VARCHAR(20)  │
│ payment_method  VARCHAR(50)  │
│ transaction_id  VARCHAR(100) │  ← Simulado (UUID)
│ created_at      TIMESTAMP    │
│ updated_at      TIMESTAMP    │
└──────────────────────────────┘
```

> **Por que `order_id` no payment-service não é um FK real?** — Porque cada microserviço tem seu próprio banco. Não existem FKs cross-database. O `order_id` é uma **referência lógica** — sabemos que se refere a um pedido, mas a integridade é garantida pelo fluxo de eventos, não por constraints do banco.

> **Por que `menu_item_name` está desnormalizado em order_items?** — Porque o order-service não pode fazer JOIN com o banco do restaurant-service. Quando o pedido é criado, salvamos um **snapshot** do nome do item naquele momento. Se o restaurante mudar o nome do prato depois, o pedido mantém o nome original. Isso é um padrão comum em microserviços.

---

## 9. Decisões Arquiteturais Globais (ADRs)

### ADR-001: Comunicação entre serviços

| Campo | Valor |
|---|---|
| **Contexto** | Microserviços precisam se comunicar para completar fluxos de negócio |
| **Decisão** | REST síncrono (OpenFeign) para queries; Kafka assíncrono para eventos de domínio |
| **Justificativa** | Queries/validações precisam de resposta imediata; consequências/reações podem ser eventuais |
| **Consequência** | Consistência eventual para fluxos baseados em eventos; necessário tratar falhas e retries |
| **Alternativas descartadas** | gRPC (curva de aprendizado maior, menos pedido nas vagas), RabbitMQ (Kafka é mais pedido) |

### ADR-002: Estratégia de banco de dados

| Campo | Valor |
|---|---|
| **Contexto** | Múltiplos microserviços precisam de persistência de dados |
| **Decisão** | Database-per-service com PostgreSQL |
| **Justificativa** | Autonomia de cada equipe/serviço, isolamento de falhas, evolução independente do schema |
| **Consequência** | Sem JOINs cross-service; dados podem ser duplicados via eventos (desnormalização) |
| **Alternativas descartadas** | Banco compartilhado (acoplamento forte), MongoDB (banco relacional é mais pedido nas vagas) |

### ADR-003: Versionamento de schema

| Campo | Valor |
|---|---|
| **Contexto** | Schema do banco precisa evoluir de forma controlada e auditável |
| **Decisão** | Flyway com migrations SQL versionadas (`V1__`, `V2__`, ...) |
| **Justificativa** | Rastreabilidade, reprodutibilidade, rollback possível, SQL explícito |
| **Consequência** | Toda alteração no banco exige uma migration; `ddl-auto` configurado como `validate` |
| **Alternativas descartadas** | Liquibase (igualmente bom, mas Flyway é mais simples), `ddl-auto: update` (perigoso em produção) |

### ADR-004: Autenticação e autorização

| Campo | Valor |
|---|---|
| **Contexto** | APIs precisam ser protegidas; múltiplas instâncias de cada serviço |
| **Decisão** | JWT stateless com Spring Security 6 |
| **Justificativa** | Token self-contained; qualquer instância valida sem consultar banco central; padrão de mercado |
| **Consequência** | Não é possível revogar tokens individuais sem blacklist; tokens têm TTL fixo |
| **Alternativas descartadas** | Sessions (requer sticky sessions ou Redis), OAuth2/Keycloak (complexidade adicional para fins didáticos) |

### ADR-005: Estrutura de pacotes

| Campo | Valor |
|---|---|
| **Contexto** | Precisamos de uma estrutura clara que reflita a arquitetura |
| **Decisão** | DDD + Arquitetura Hexagonal (Ports & Adapters) — domain → application (ports + use cases) → adapters (in/out) |
| **Justificativa** | Separa negócio de infraestrutura; facilita testes; é a arquitetura mais adotada em bancos e fintechs no Brasil; permite trocar qualquer adaptador sem alterar o domínio |
| **Consequência** | Mais pacotes que o padrão simplificado; entidades JPA ficam no domain/ por pragmatismo |
| **Alternativas descartadas** | Clean Architecture pura (nomenclatura menos intuitiva que Ports & Adapters), package-by-feature (não evidencia as fronteiras do hexágono) |

---

## 10. Princípios SOLID Aplicados no Projeto

| Princípio | Onde no FoodHub |
|---|---|
| **S** — Single Responsibility | Cada classe tem 1 razão para mudar: Controller (adaptador de entrada), Use Case (orquestração), Entity (regras de domínio), Repository (porta de saída) |
| **O** — Open/Closed | `OrderEventPublisher` (porta de saída) pode ter novas implementações (Kafka, RabbitMQ, SNS) sem alterar o código que a usa |
| **L** — Liskov Substitution | `OrderEventPublisher` (porta) pode ser implementada por `KafkaOrderEventPublisher` ou por `LoggingOrderEventPublisher` (no-op para testes) |
| **I** — Interface Segregation | `OrderEventPublisher` publica eventos; `OrderRepository` persiste pedidos. Cada porta tem uma responsabilidade |
| **D** — Dependency Inversion | `OrderApplicationService` depende de `OrderEventPublisher` (porta/abstração), não de `KafkaOrderEventPublisher` (adaptador/implementação concreta) |

---

## 11. Checklist de Competências das Vagas

| # | Competência | Onde no Projeto | Fase |
|---|---|---|---|
| 1 | Java 21 (Records, Pattern Matching, Text Blocks) | DTOs, switch expressions, SQL em text blocks | 01 |
| 2 | Spring Boot 3.5 | Todos os serviços | 01 |
| 3 | Spring Data JPA + Hibernate 6 | Repositories, entidades, queries customizadas | 02 |
| 4 | PostgreSQL | Banco dedicado por serviço | 02 |
| 5 | Flyway (Migrations) | Versionamento de schema | 02 |
| 6 | APIs REST (CRUD + paginação) | Controllers com ResponseEntity, Page, ProblemDetail | 01 |
| 7 | Spring Security + JWT | Autenticação, autorização por role | 03 |
| 8 | Apache Kafka (Mensageria) | Eventos entre serviços: producer e consumer | 04 |
| 9 | JUnit 5 + Mockito | Testes unitários e com mock | 05 |
| 10 | Testcontainers | Testes de integração com PostgreSQL e Kafka reais | 05 |
| 11 | SpringDoc OpenAPI / Swagger | Documentação automática da API | 06 |
| 12 | Docker + Docker Compose | Containerização de todos os serviços | 07 |
| 13 | Spring Cloud Gateway | API Gateway com roteamento e load balancing | 08 |
| 14 | Spring Cloud Eureka | Service Discovery | 08 |
| 15 | Spring Cloud Config | Configuração centralizada via Git | 08 |
| 16 | Spring Cloud OpenFeign | Comunicação REST entre serviços | 08 |
| 17 | Resilience4j (Circuit Breaker) | Resiliência na comunicação entre serviços | 08 |
| 18 | DDD (Entidades ricas, Aggregates, Events) | Camada domain/ com Rich Domain Model | 01 |
| 19 | Arquitetura Hexagonal (Ports & Adapters, inversão de dependência) | Estrutura de pacotes com portas e adaptadores | 01 |
| 20 | SOLID + Clean Code | Aplicado no código inteiro | Todas |
| 21 | Maven | Build, dependências, multi-module | 01 |
| 22 | Git + Git Flow | Branches feature/develop/main | Todas |
| 23 | CI/CD | GitHub Actions com build, test, Docker | 09 |
| 24 | Observabilidade (Actuator, Prometheus) | Métricas, health checks, dashboards | 10 |
| 25 | Cloud (AWS) | Deploy com ECS Fargate | 10 |

---

> **Próximo passo:** Vá para a [Fase 01 — Fundação](fase-01-fundacao.md) e comece a criar o order-service.
