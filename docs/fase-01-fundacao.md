# Fase 01 — Fundação: Order Service

> **Objetivo:** Criar o order-service do zero com Spring Boot 3.5, Java 21 e Maven. Ao final desta fase, você terá um serviço REST funcional com entidades de domínio ricas, DTOs com Records, controller, service, exception handler e todas as classes auxiliares.

### 🎯 O que você vai aprender nesta fase

- Inicializar um projeto Spring Boot com Maven
- Configurar `application.yml` corretamente (sem propriedades deprecated)
- Criar entidades JPA com **Rich Domain Model** (DDD)
- Implementar **máquina de estados** com enum
- Usar **Java Records** como DTOs
- Criar REST API com validação (`@Valid`) e paginação
- Tratar erros com **ProblemDetail (RFC 7807)**
- Aplicar **Flyway** para migrations de banco
- Entender **inversão de dependência** com portas e adaptadores (Arquitetura Hexagonal)

---

## Pré-requisitos

- **JDK 21** instalado (recomendo [Eclipse Temurin](https://adoptium.net/))
- **Maven 3.9+** instalado (ou use o wrapper `mvnw` do projeto)
- **IDE** — IntelliJ IDEA (Community ou Ultimate) ou VS Code com Extension Pack for Java
- **PostgreSQL 16+** rodando (pode ser via Docker: `docker run -d --name pg -p 5432:5432 -e POSTGRES_USER=foodhub -e POSTGRES_PASSWORD=foodhub123 postgres:16-alpine`)
- **Git** configurado

---

## 1.1 Inicializar o Projeto

### Opção A: Via start.spring.io

Acesse [start.spring.io](https://start.spring.io) e configure:

| Campo | Valor |
|---|---|
| Project | Maven |
| Language | Java |
| Spring Boot | 3.5.x (a mais recente da série 3.5) |
| Group | `com.foodhub` |
| Artifact | `order-service` |
| Name | `order-service` |
| Description | FoodHub Order Management Service |
| Package name | `com.foodhub.order` |
| Packaging | Jar |
| Java | 21 |

**Dependências para selecionar:**
- Spring Web
- Spring Data JPA
- PostgreSQL Driver
- Validation
- Flyway Migration
- Spring Boot DevTools
- Lombok

Clique em **Generate**, extraia o zip e abra na IDE.

### Opção B: Via terminal com curl

```bash
curl https://start.spring.io/starter.zip \
  -d type=maven-project \
  -d language=java \
  -d bootVersion=3.5.x \
  -d baseDir=order-service \
  -d groupId=com.foodhub \
  -d artifactId=order-service \
  -d name=order-service \
  -d packageName=com.foodhub.order \
  -d javaVersion=21 \
  -d dependencies=web,data-jpa,postgresql,validation,flyway,devtools,lombok \
  -o order-service.zip

unzip order-service.zip
cd order-service
```

---

## 1.2 O pom.xml Completo

Após gerar o projeto, o `pom.xml` terá a estrutura abaixo. Vou explicar cada seção:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <!-- Parent: herda configurações padrão do Spring Boot -->
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.5.x</version> <!-- Use a versão mais recente da série 3.5 -->
        <relativePath/> <!-- lookup parent from repository -->
    </parent>

    <groupId>com.foodhub</groupId>
    <artifactId>order-service</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <name>order-service</name>
    <description>FoodHub Order Management Service</description>

    <properties>
        <java.version>21</java.version>
    </properties>

    <dependencies>
        <!-- ===== WEB ===== -->
        <!-- Inclui: Spring MVC, Jackson (JSON), Tomcat embutido -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>

        <!-- ===== PERSISTÊNCIA ===== -->
        <!-- Inclui: Spring Data JPA, Hibernate 6, HikariCP (connection pool) -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>

        <!-- Driver JDBC do PostgreSQL -->
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
            <scope>runtime</scope>
        </dependency>

        <!-- Flyway: versionamento de schema do banco -->
        <dependency>
            <groupId>org.flywaydb</groupId>
            <artifactId>flyway-core</artifactId>
        </dependency>
        <dependency>
            <groupId>org.flywaydb</groupId>
            <artifactId>flyway-database-postgresql</artifactId>
        </dependency>

        <!-- ===== VALIDAÇÃO ===== -->
        <!-- Bean Validation (JSR 380): @NotNull, @NotEmpty, @Positive, etc. -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-validation</artifactId>
        </dependency>

        <!-- ===== UTILITÁRIOS ===== -->
        <!-- Lombok: reduz boilerplate (getters, constructors, builders) -->
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <optional>true</optional>
        </dependency>

        <!-- DevTools: hot reload durante desenvolvimento -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-devtools</artifactId>
            <scope>runtime</scope>
            <optional>true</optional>
        </dependency>

        <!-- ===== TESTES ===== -->
        <!-- Inclui: JUnit 5, Mockito, AssertJ, Spring Test, MockMvc -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
                <configuration>
                    <excludes>
                        <exclude>
                            <groupId>org.projectlombok</groupId>
                            <artifactId>lombok</artifactId>
                        </exclude>
                    </excludes>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
```

### Entendendo as versões

Note que **não declaramos versões** nas dependências. Por quê? Porque o `spring-boot-starter-parent` herda um BOM (Bill of Materials) que gerencia todas as versões compatíveis. Quando você usa `spring-boot-starter-parent 3.5.x`, o Spring Boot já sabe que o Flyway compatível é o X.Y.Z, o Hibernate é o A.B.C, etc. **Nunca declare versões manualmente** para dependências gerenciadas pelo Spring Boot — isso pode causar conflitos.

### Debate: Lombok — Usar ou não?

> **Prós:** Reduz boilerplate massivamente. `@RequiredArgsConstructor` gera o construtor de injeção, `@Getter` evita dezenas de getters.
>
> **Contras:** É uma "magia" que não é Java padrão. Esconde código que deveria ser explícito. Algumas equipes proíbem Lombok.
>
> **Recomendação para este projeto:** Use Lombok nas classes que precisam (entidades JPA, config classes). Para DTOs, use **Records** (Java 21 nativo). Assim você pratica ambos os estilos.

---

## 1.3 Configuração — application.yml

Crie/edite `src/main/resources/application.yml`:

```yaml
server:
  port: 8081

spring:
  application:
    name: order-service

  datasource:
    url: jdbc:postgresql://localhost:5432/foodhub_orders
    username: foodhub
    password: foodhub123
    driver-class-name: org.postgresql.Driver

  jpa:
    hibernate:
      ddl-auto: validate
    show-sql: false
    open-in-view: false
    properties:
      hibernate:
        format_sql: true

  flyway:
    enabled: true
    locations: classpath:db/migration
```

### O que cada propriedade faz

| Propriedade | Valor | Explicação |
|---|---|---|
| `server.port` | `8081` | Porta HTTP do order-service |
| `spring.application.name` | `order-service` | Nome usado pelo Eureka e nos logs |
| `spring.datasource.*` | conexão PG | URL JDBC, user e senha do PostgreSQL |
| `spring.jpa.hibernate.ddl-auto` | `validate` | Hibernate **não altera** o banco; apenas valida que entidades estão alinhadas |
| `spring.jpa.show-sql` | `false` | Não mostra SQL no console (use `true` apenas para debug pontual) |
| `spring.jpa.open-in-view` | `false` | Desabilita OSIV — mantém a sessão JPA fechada após o Service retornar. Em microserviços, carregar dados LAZY no controller causa queries inesperadas e N+1. |
| `spring.jpa.properties.hibernate.format_sql` | `true` | Formata SQL quando exibido (útil para debug) |
| `spring.flyway.*` | ativado | Flyway roda migrations SQL de `db/migration/` na inicialização |

### Por que não tem `hibernate.dialect`?

No Hibernate 6.x (usado pelo Spring Boot 3.x), o **dialect é auto-detectado** a partir da URL JDBC. Especificar manualmente (`org.hibernate.dialect.PostgreSQLDialect`) é **deprecated** e desnecessário. O Hibernate detecta que é PostgreSQL pela URL `jdbc:postgresql://...`.

### Profile de desenvolvimento (opcional)

Crie `src/main/resources/application-dev.yml`:

```yaml
spring:
  jpa:
    show-sql: true
  
  flyway:
    clean-disabled: false  # Permite rodar flyway:clean em dev (NUNCA em prod)

logging:
  level:
    com.foodhub: DEBUG
    org.springframework.web: DEBUG
```

Para ativar: `mvn spring-boot:run -Dspring-boot.run.profiles=dev`

---

## 1.4 Criar o Banco de Dados

Antes de rodar o serviço, crie o banco no PostgreSQL:

```sql
-- Conecte no PostgreSQL como superuser
CREATE DATABASE foodhub_orders;
CREATE USER foodhub WITH PASSWORD 'foodhub123';
GRANT ALL PRIVILEGES ON DATABASE foodhub_orders TO foodhub;

-- Conecte no banco foodhub_orders e garanta permissões no schema public
\c foodhub_orders
GRANT ALL ON SCHEMA public TO foodhub;
```

Ou via Docker (se ainda não estiver rodando):

```bash
docker run -d \
  --name foodhub-postgres \
  -p 5432:5432 \
  -e POSTGRES_USER=foodhub \
  -e POSTGRES_PASSWORD=foodhub123 \
  -e POSTGRES_DB=foodhub_orders \
  postgres:16-alpine
```

---

## 1.5 Flyway Migrations

Crie os diretórios e arquivos de migration:

### `src/main/resources/db/migration/V1__create_orders_table.sql`

```sql
CREATE TABLE orders (
    id              BIGSERIAL       PRIMARY KEY,
    customer_id     BIGINT          NOT NULL,
    restaurant_id   BIGINT          NOT NULL,
    status          VARCHAR(20)     NOT NULL DEFAULT 'PENDING',
    total_amount    DECIMAL(10,2)   NOT NULL,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version         INTEGER         NOT NULL DEFAULT 0
);

-- Índices para queries frequentes
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_restaurant_id ON orders(restaurant_id);
```

### `src/main/resources/db/migration/V2__create_order_items_table.sql`

```sql
CREATE TABLE order_items (
    id              BIGSERIAL       PRIMARY KEY,
    order_id        BIGINT          NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    menu_item_id    BIGINT          NOT NULL,
    menu_item_name  VARCHAR(255)    NOT NULL,
    quantity        INTEGER         NOT NULL CHECK (quantity > 0),
    unit_price      DECIMAL(10,2)   NOT NULL CHECK (unit_price > 0),
    subtotal        DECIMAL(10,2)   NOT NULL
);

CREATE INDEX idx_order_items_order_id ON order_items(order_id);
```

### Como funciona o Flyway

1. Na **primeira execução**, o Flyway cria uma tabela `flyway_schema_history` para rastrear quais migrations já rodaram.
2. Ele escaneia `classpath:db/migration/` por arquivos com o padrão `V{versão}__{descrição}.sql`.
3. Executa as migrations **na ordem da versão**, uma vez cada.
4. Se tentar alterar uma migration já executada, o Flyway **falha** (checksum mismatch) — protege contra alterações acidentais.

> **Regra de ouro:** Nunca altere uma migration já commitada. Para mudanças novas, crie `V3__...`, `V4__...`, etc.

---

## 1.6 Camada de Domínio

### OrderStatus (Enum)

```java
package com.foodhub.order.domain.model;

public enum OrderStatus {
    PENDING,
    CONFIRMED,
    PREPARING,
    READY,
    DELIVERED,
    CANCELLED;

    /**
     * Verifica se a transição de status é permitida.
     * Máquina de estados simplificada:
     * 
     * PENDING → CONFIRMED → PREPARING → READY → DELIVERED
     *    ↓         ↓           ↓
     * CANCELLED CANCELLED  CANCELLED
     */
    public boolean canTransitionTo(OrderStatus target) {
        return switch (this) {
            case PENDING    -> target == CONFIRMED || target == CANCELLED;
            case CONFIRMED  -> target == PREPARING || target == CANCELLED;
            case PREPARING  -> target == READY || target == CANCELLED;
            case READY      -> target == DELIVERED;
            case DELIVERED  -> false; // Estado final
            case CANCELLED  -> false; // Estado final
        };
    }
}
```

> **Por que a máquina de estados no enum?** — Centraliza as regras de transição em um único lugar. Em vez de espalhar `if/else` por todo o código, qualquer lugar que precise verificar se uma transição é válida chama `status.canTransitionTo(novoStatus)`. É **Clean Code** puro: a regra está perto dos dados que ela governa.

### Order (Aggregate Root — Entidade JPA)

```java
package com.foodhub.order.domain.model;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

@Entity
@Table(name = "orders")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED) // Construtor protegido para JPA
public class Order {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "customer_id", nullable = false)
    private Long customerId;

    @Column(name = "restaurant_id", nullable = false)
    private Long restaurantId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private OrderStatus status;

    @Column(name = "total_amount", nullable = false, precision = 10, scale = 2)
    private BigDecimal totalAmount;

    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<OrderItem> items = new ArrayList<>();

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @Version // Optimistic locking: evita conflitos de atualização concorrente
    private Integer version;

    // ==================== FACTORY METHOD ====================

    /**
     * Cria um novo pedido com status PENDING.
     * Este é o ÚNICO ponto de criação de pedidos — garante invariantes.
     */
    public static Order create(Long customerId, Long restaurantId, List<OrderItem> items) {
        if (items == null || items.isEmpty()) {
            throw new IllegalArgumentException("Pedido deve ter ao menos um item");
        }

        Order order = new Order();
        order.customerId = customerId;
        order.restaurantId = restaurantId;
        order.status = OrderStatus.PENDING;
        order.createdAt = LocalDateTime.now();
        order.updatedAt = LocalDateTime.now();

        // Associa os itens ao pedido (bidirecional)
        items.forEach(order::addItem);

        // Calcula o total a partir dos itens
        order.recalculateTotal();

        return order;
    }

    // ==================== MÉTODOS DE DOMÍNIO ====================

    /**
     * Adiciona um item ao pedido. Mantém a consistência bidirecional.
     */
    public void addItem(OrderItem item) {
        items.add(item);
        item.setOrder(this);
        recalculateTotal();
    }

    /**
     * Confirma o pedido. Só é possível se estiver PENDING.
     */
    public void confirm() {
        transitionTo(OrderStatus.CONFIRMED);
    }

    /**
     * Marca o pedido como em preparo.
     */
    public void startPreparing() {
        transitionTo(OrderStatus.PREPARING);
    }

    /**
     * Marca o pedido como pronto para entrega.
     */
    public void markReady() {
        transitionTo(OrderStatus.READY);
    }

    /**
     * Marca o pedido como entregue. Estado final.
     */
    public void deliver() {
        transitionTo(OrderStatus.DELIVERED);
    }

    /**
     * Cancela o pedido. Só é possível se não estiver DELIVERED ou já CANCELLED.
     */
    public void cancel() {
        transitionTo(OrderStatus.CANCELLED);
    }

    /**
     * Retorna os itens como lista imutável (protege o encapsulamento).
     * Nota: o @Getter do Lombok na classe gera getters para TODOS os campos,
     * mas este método manual tem precedência sobre o gerado pelo Lombok.
     * O Lombok não gera getter quando já existe um método com a mesma assinatura.
     */
    public List<OrderItem> getItems() {
        return Collections.unmodifiableList(items);
    }

    // ==================== MÉTODOS PRIVADOS ====================

    private void transitionTo(OrderStatus target) {
        if (!this.status.canTransitionTo(target)) {
            throw new IllegalStateException(
                String.format("Não é possível transicionar de %s para %s", this.status, target)
            );
        }
        this.status = target;
        this.updatedAt = LocalDateTime.now();
    }

    private void recalculateTotal() {
        this.totalAmount = items.stream()
                .map(OrderItem::getSubtotal)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }
}
```

### Por que Rich Domain Model?

Repare que a entidade `Order` **não tem setters públicos** (exceto o que JPA precisa internamente). Toda alteração de estado passa por métodos de negócio (`confirm()`, `cancel()`, `deliver()`) que **validam as regras antes de aplicar**. Isso é o oposto do "Anemic Domain Model" (anti-pattern muito comum) onde a entidade tem só getters/setters e a lógica fica toda em services.

**Benefícios:**
- É **impossível** colocar um pedido DELIVERED em status PENDING — a máquina de estados do enum impede.
- O total é **sempre recalculado** quando itens mudam — nunca fica inconsistente.
- A lista de items é retornada como **imutável** — ninguém faz `order.getItems().clear()` de fora.

### OrderItem (Entidade filha)

```java
package com.foodhub.order.domain.model;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Entity
@Table(name = "order_items")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class OrderItem {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "order_id", nullable = false)
    private Order order;

    @Column(name = "menu_item_id", nullable = false)
    private Long menuItemId;

    @Column(name = "menu_item_name", nullable = false)
    private String menuItemName;

    @Column(nullable = false)
    private Integer quantity;

    @Column(name = "unit_price", nullable = false, precision = 10, scale = 2)
    private BigDecimal unitPrice;

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal subtotal;

    /**
     * Construtor para criação de novos itens (antes de persistir).
     */
    public OrderItem(Long menuItemId, String menuItemName, Integer quantity, BigDecimal unitPrice) {
        if (quantity == null || quantity <= 0) {
            throw new IllegalArgumentException("Quantidade deve ser positiva");
        }
        if (unitPrice == null || unitPrice.compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("Preço unitário deve ser positivo");
        }
        this.menuItemId = menuItemId;
        this.menuItemName = menuItemName;
        this.quantity = quantity;
        this.unitPrice = unitPrice;
        this.subtotal = unitPrice.multiply(BigDecimal.valueOf(quantity));
    }

    /**
     * Package-private: só Order pode setar a referência bidirecional.
     */
    void setOrder(Order order) {
        this.order = order;
    }
}
```

> **Detalhe importante:** `setOrder()` é **package-private** (`void` sem modificador de acesso). Isso significa que só classes no mesmo pacote (`domain.model`) podem chamar — neste caso, o `Order.addItem()`. Nenhum código externo consegue alterar a associação bidirecional diretamente. Isso é **encapsulamento DDD**.

> **Por que `FetchType.LAZY` no `@ManyToOne`?** — `@ManyToOne` tem `EAGER` como padrão no JPA. Isso significa que toda vez que você carregar um `OrderItem`, ele carrega o `Order` inteiro junto (e seus outros items, e os items deles...). Com `LAZY`, o `Order` só é carregado quando você realmente acessa `item.getOrder()`. Sempre use LAZY em todos os relacionamentos.

---

## 1.7 Exceção de Domínio

```java
package com.foodhub.order.domain.exception;

public class OrderNotFoundException extends RuntimeException {

    public OrderNotFoundException(Long id) {
        super("Pedido não encontrado com id: " + id);
    }
}
```

> Por que `RuntimeException` (unchecked) e não `Exception` (checked)? — Exceções de negócio em APIs REST são **condições esperadas**, não erros de programação. Usar checked exceptions obriga o caller a fazer try/catch explícito, poluindo o código. Unchecked exceptions são tratadas globalmente pelo `@RestControllerAdvice`.

---

## 1.8 Evento de Domínio

```java
package com.foodhub.order.domain.event;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * Evento publicado quando um novo pedido é criado.
 * Record = imutável, sem boilerplate. Perfeito para eventos.
 */
public record OrderCreatedEvent(
    Long orderId,
    Long customerId,
    Long restaurantId,
    BigDecimal totalAmount,
    LocalDateTime occurredAt
) {
    /**
     * Construtor conveniente que auto-preenche o timestamp.
     */
    public OrderCreatedEvent(Long orderId, Long customerId,
                              Long restaurantId, BigDecimal totalAmount) {
        this(orderId, customerId, restaurantId, totalAmount, LocalDateTime.now());
    }
}
```

---

## 1.9 Repository (Porta de Saída — Outbound Port)

```java
package com.foodhub.order.application.port.out;

import com.foodhub.order.domain.model.Order;
import com.foodhub.order.domain.model.OrderStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface OrderRepository extends JpaRepository<Order, Long> {

    Page<Order> findByCustomerId(Long customerId, Pageable pageable);

    List<Order> findByStatus(OrderStatus status);

    /**
     * JOIN FETCH resolve o problema N+1: carrega o pedido E seus itens em uma query.
     */
    @Query("SELECT o FROM Order o JOIN FETCH o.items WHERE o.id = :id")
    Optional<Order> findByIdWithItems(@Param("id") Long id);

    /**
     * Text block (Java 15+): SQL multi-linha legível.
     * Disponível no Java 21, mas introduzido como feature estável no Java 15.
     */
    @Query("""
        SELECT o FROM Order o
        WHERE o.customerId = :customerId
        AND o.createdAt BETWEEN :start AND :end
        ORDER BY o.createdAt DESC
        """)
    List<Order> findByCustomerAndDateRange(
        @Param("customerId") Long customerId,
        @Param("start") LocalDateTime start,
        @Param("end") LocalDateTime end
    );
}
```

> **Por que o repository fica em application/port/out/ e não em domain/?** — Em Arquitetura Hexagonal, a interface do repositório é uma **porta de saída** — ela define o que a aplicação precisa, sem saber como é implementado. A interface `extends JpaRepository` já acopla ao Spring Data, mas isso é uma troca pragmática aceita pela maioria dos projetos (inclusive em bancos e fintechs). O importante é que o use case (`OrderApplicationService`) dependa da **porta** (interface), não de uma implementação concreta.

---

## 1.10 Portas de Saída (Outbound Ports)

### OrderEventPublisher

```java
package com.foodhub.order.application.port.out;

import com.foodhub.order.domain.event.OrderCreatedEvent;

/**
 * Porta de saída para publicação de eventos.
 * A implementação concreta (Kafka) fica em adapter/out/messaging/.
 * Na Fase 01, usamos uma implementação "no-op" (não faz nada).
 */
public interface OrderEventPublisher {
    void publish(OrderCreatedEvent event);
}
```

### Implementação temporária (No-Op — Adaptador de saída sem Kafka)

```java
package com.foodhub.order.adapter.out.messaging;

import com.foodhub.order.application.port.out.OrderEventPublisher;
import com.foodhub.order.domain.event.OrderCreatedEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * Implementação temporária que apenas loga o evento.
 * Será substituída pelo KafkaOrderEventPublisher na Fase 04.
 * Este é um ADAPTADOR DE SAÍDA — implementa a porta OrderEventPublisher.
 */
@Component
public class LoggingOrderEventPublisher implements OrderEventPublisher {

    private static final Logger log = LoggerFactory.getLogger(LoggingOrderEventPublisher.class);

    @Override
    public void publish(OrderCreatedEvent event) {
        log.info("Evento publicado (log-only): OrderCreated orderId={} customerId={} total={}",
                event.orderId(), event.customerId(), event.totalAmount());
    }
}
```

> **Por que uma implementação temporária?** — Na Fase 01, ainda não temos Kafka. Mas o `OrderApplicationService` (use case) precisa de um `OrderEventPublisher` (porta de saída) para funcionar. Em vez de comentar o código ou usar flags, criamos um **adaptador** que simplesmente loga. Na Fase 04, criamos `KafkaOrderEventPublisher` e usamos `@Primary` ou `@Profile` para selecionar o adaptador correto. Isso é Arquitetura Hexagonal em ação: o use case depende da porta (interface), e os adaptadores são intercambiáveis.

---

## 1.11 DTOs (Records — Java 21)

### CreateOrderRequest

```java
package com.foodhub.order.application.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.util.List;

public record CreateOrderRequest(
    @NotNull(message = "customerId é obrigatório")
    Long customerId,

    @NotNull(message = "restaurantId é obrigatório")
    Long restaurantId,

    @NotEmpty(message = "O pedido deve ter ao menos um item")
    @Valid  // <-- IMPORTANTE: sem @Valid aqui, os itens internos não são validados!
    List<OrderItemRequest> items
) {}
```

> **Atenção ao `@Valid` na lista!** — Sem `@Valid` em `List<OrderItemRequest>`, o Bean Validation verifica que a lista não está vazia (`@NotEmpty`), mas **não valida os objetos dentro da lista**. Ou seja, um item com `quantity: -5` passaria. `@Valid` propaga a validação para cada elemento da lista.

### OrderItemRequest

```java
package com.foodhub.order.application.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import java.math.BigDecimal;

public record OrderItemRequest(
    @NotNull(message = "menuItemId é obrigatório")
    Long menuItemId,

    @NotBlank(message = "Nome do item é obrigatório")
    String menuItemName,

    @NotNull(message = "quantity é obrigatório")
    @Positive(message = "quantity deve ser positivo")
    Integer quantity,

    @NotNull(message = "unitPrice é obrigatório")
    @Positive(message = "unitPrice deve ser positivo")
    BigDecimal unitPrice
) {}
```

### OrderResponse

```java
package com.foodhub.order.application.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

public record OrderResponse(
    Long id,
    Long customerId,
    Long restaurantId,
    String status,
    BigDecimal totalAmount,
    List<OrderItemResponse> items,
    LocalDateTime createdAt,
    LocalDateTime updatedAt
) {}
```

### OrderItemResponse

```java
package com.foodhub.order.application.dto;

import java.math.BigDecimal;

public record OrderItemResponse(
    Long id,
    Long menuItemId,
    String menuItemName,
    Integer quantity,
    BigDecimal unitPrice,
    BigDecimal subtotal
) {}
```

### UpdateOrderStatusRequest

```java
package com.foodhub.order.application.dto;

import jakarta.validation.constraints.NotBlank;

public record UpdateOrderStatusRequest(
    @NotBlank(message = "status é obrigatório")
    String status
) {}
```

---

## 1.12 Mapper (Entity ↔ DTO)

```java
package com.foodhub.order.application.mapper;

import com.foodhub.order.application.dto.*;
import com.foodhub.order.domain.model.Order;
import com.foodhub.order.domain.model.OrderItem;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
public class OrderMapper {

    public OrderResponse toResponse(Order order) {
        List<OrderItemResponse> itemResponses = order.getItems().stream()
                .map(this::toItemResponse)
                .toList();

        return new OrderResponse(
                order.getId(),
                order.getCustomerId(),
                order.getRestaurantId(),
                order.getStatus().name(),
                order.getTotalAmount(),
                itemResponses,
                order.getCreatedAt(),
                order.getUpdatedAt()
        );
    }

    public OrderItemResponse toItemResponse(OrderItem item) {
        return new OrderItemResponse(
                item.getId(),
                item.getMenuItemId(),
                item.getMenuItemName(),
                item.getQuantity(),
                item.getUnitPrice(),
                item.getSubtotal()
        );
    }

    public List<OrderItem> toOrderItems(List<OrderItemRequest> requests) {
        return requests.stream()
                .map(req -> new OrderItem(
                        req.menuItemId(),
                        req.menuItemName(),
                        req.quantity(),
                        req.unitPrice()
                ))
                .toList();
    }
}
```

> **Por que um Mapper manual e não MapStruct?** — MapStruct é uma excelente opção enterprise (gera código em compile-time, zero overhead). Mas para fins didáticos, o mapper manual torna o fluxo explícito. Depois, migrar para MapStruct é simples — basta criar uma interface com `@Mapper` e os métodos `toResponse`, `toEntity`.

---

## 1.13 Application Service (Use Case)

```java
package com.foodhub.order.application.usecase;

import com.foodhub.order.application.dto.*;
import com.foodhub.order.application.mapper.OrderMapper;
import com.foodhub.order.application.port.out.OrderEventPublisher;
import com.foodhub.order.domain.event.OrderCreatedEvent;
import com.foodhub.order.domain.exception.OrderNotFoundException;
import com.foodhub.order.domain.model.Order;
import com.foodhub.order.domain.model.OrderItem;
import com.foodhub.order.domain.model.OrderStatus;
import com.foodhub.order.application.port.out.OrderRepository;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true) // Classe inteira é read-only por padrão
public class OrderApplicationService {

    private static final Logger log = LoggerFactory.getLogger(OrderApplicationService.class);

    private final OrderRepository orderRepository;
    private final OrderMapper orderMapper;
    private final OrderEventPublisher eventPublisher;

    /**
     * Cria um novo pedido.
     * @Transactional sobrescreve o readOnly da classe para este método.
     */
    @Transactional
    public OrderResponse createOrder(CreateOrderRequest request) {
        log.info("Criando pedido para customer={} restaurant={}",
                request.customerId(), request.restaurantId());

        // 1. Converte DTOs para entidades de domínio
        List<OrderItem> items = orderMapper.toOrderItems(request.items());

        // 2. Cria o pedido via factory method (garante invariantes)
        Order order = Order.create(
                request.customerId(),
                request.restaurantId(),
                items
        );

        // 3. Persiste no banco
        Order saved = orderRepository.save(order);
        log.info("Pedido criado com id={}", saved.getId());

        // 4. Publica evento de domínio
        eventPublisher.publish(new OrderCreatedEvent(
                saved.getId(),
                saved.getCustomerId(),
                saved.getRestaurantId(),
                saved.getTotalAmount()
        ));

        // 5. Retorna DTO de resposta
        return orderMapper.toResponse(saved);
    }

    /**
     * Busca pedido por ID com itens (JOIN FETCH).
     */
    public OrderResponse getOrderById(Long id) {
        Order order = orderRepository.findByIdWithItems(id)
                .orElseThrow(() -> new OrderNotFoundException(id));
        return orderMapper.toResponse(order);
    }

    /**
     * Lista pedidos paginados.
     */
    public Page<OrderResponse> listOrders(Pageable pageable) {
        return orderRepository.findAll(pageable)
                .map(orderMapper::toResponse);
    }

    /**
     * Lista pedidos de um cliente específico, paginados.
     */
    public Page<OrderResponse> listOrdersByCustomer(Long customerId, Pageable pageable) {
        return orderRepository.findByCustomerId(customerId, pageable)
                .map(orderMapper::toResponse);
    }

    /**
     * Atualiza o status de um pedido.
     * A validação de transição de status é feita pela ENTIDADE (Rich Domain Model).
     */
    @Transactional
    public OrderResponse updateOrderStatus(Long id, UpdateOrderStatusRequest request) {
        Order order = orderRepository.findById(id)
                .orElseThrow(() -> new OrderNotFoundException(id));

        // Pattern matching com switch (Java 21)
        OrderStatus targetStatus = OrderStatus.valueOf(request.status().toUpperCase());

        // A entidade valida se a transição é permitida
        switch (targetStatus) {
            case CONFIRMED -> order.confirm();
            case PREPARING -> order.startPreparing();
            case READY -> order.markReady();
            case DELIVERED -> order.deliver();
            case CANCELLED -> order.cancel();
            default -> throw new IllegalArgumentException("Status inválido: " + request.status());
        }

        log.info("Pedido {} atualizado para status {}", id, targetStatus);
        return orderMapper.toResponse(orderRepository.save(order));
    }
}
```

### Por que `@Transactional(readOnly = true)` na classe?

Marcar a classe inteira como `readOnly = true` e sobrescrever com `@Transactional` apenas nos métodos de **escrita** é uma boa prática enterprise:

1. **Performance:** Métodos read-only desabilitam o dirty checking do Hibernate (ele não precisa comparar o estado da entidade com o snapshot), economizando CPU.
2. **Segurança:** Previne escritas acidentais em métodos que deveriam ser apenas leitura.
3. **Escalabilidade:** O banco pode direcionar queries read-only para réplicas de leitura.

---

## 1.14 REST Controller (Adaptador de Entrada)

```java
package com.foodhub.order.adapter.in.web.controller;

import com.foodhub.order.application.dto.*;
import com.foodhub.order.application.usecase.OrderApplicationService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/orders")
@RequiredArgsConstructor
public class OrderController {

    private final OrderApplicationService orderService;

    @PostMapping
    public ResponseEntity<OrderResponse> createOrder(
            @Valid @RequestBody CreateOrderRequest request) {
        OrderResponse response = orderService.createOrder(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @GetMapping("/{id}")
    public ResponseEntity<OrderResponse> getOrder(@PathVariable Long id) {
        return ResponseEntity.ok(orderService.getOrderById(id));
    }

    private static final String DEFAULT_PAGE_SIZE = "20";

    @GetMapping
    public ResponseEntity<Page<OrderResponse>> listOrders(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = DEFAULT_PAGE_SIZE) int size) {
        PageRequest pageRequest = PageRequest.of(page, size, Sort.by("createdAt").descending());
        return ResponseEntity.ok(orderService.listOrders(pageRequest));
    }

    @GetMapping("/customer/{customerId}")
    public ResponseEntity<Page<OrderResponse>> listOrdersByCustomer(
            @PathVariable Long customerId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = DEFAULT_PAGE_SIZE) int size) {
        PageRequest pageRequest = PageRequest.of(page, size, Sort.by("createdAt").descending());
        return ResponseEntity.ok(orderService.listOrdersByCustomer(customerId, pageRequest));
    }

    @PatchMapping("/{id}/status")
    public ResponseEntity<OrderResponse> updateStatus(
            @PathVariable Long id,
            @Valid @RequestBody UpdateOrderStatusRequest request) {
        return ResponseEntity.ok(orderService.updateOrderStatus(id, request));
    }
}
```

### Por que PATCH e não PUT para atualizar status?

- **PUT** substitui o recurso inteiro (all fields).
- **PATCH** aplica uma alteração parcial (só o status).

Como estamos alterando apenas o status do pedido (não o pedido todo), **PATCH** é o verbo HTTP semanticamente correto.

---

## 1.15 Exception Handler Global (Adaptador de Entrada)

```java
package com.foodhub.order.adapter.in.web.exception;

import com.foodhub.order.domain.exception.OrderNotFoundException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.validation.FieldError;

import java.net.URI;
import java.time.Instant;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Trata exceções globalmente e retorna respostas no formato RFC 7807 (Problem Detail).
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(OrderNotFoundException.class)
    public ProblemDetail handleNotFound(OrderNotFoundException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
                HttpStatus.NOT_FOUND, ex.getMessage()
        );
        problem.setTitle("Recurso não encontrado");
        problem.setType(URI.create("https://foodhub.com/errors/not-found"));
        problem.setProperty("timestamp", Instant.now());
        return problem;
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ProblemDetail handleValidation(MethodArgumentNotValidException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
                HttpStatus.BAD_REQUEST, "Um ou mais campos são inválidos"
        );
        problem.setTitle("Erro de validação");
        problem.setType(URI.create("https://foodhub.com/errors/validation"));

        Map<String, String> errors = ex.getBindingResult().getFieldErrors().stream()
                .collect(Collectors.toMap(
                        FieldError::getField,
                        fe -> fe.getDefaultMessage() != null ? fe.getDefaultMessage() : "Valor inválido",
                        (existing, replacement) -> existing // Em caso de campos duplicados, mantém o primeiro
                ));
        problem.setProperty("errors", errors);
        problem.setProperty("timestamp", Instant.now());
        return problem;
    }

    @ExceptionHandler(IllegalStateException.class)
    public ProblemDetail handleIllegalState(IllegalStateException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
                HttpStatus.CONFLICT, ex.getMessage()
        );
        problem.setTitle("Operação não permitida");
        problem.setType(URI.create("https://foodhub.com/errors/conflict"));
        problem.setProperty("timestamp", Instant.now());
        return problem;
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ProblemDetail handleBadRequest(IllegalArgumentException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
                HttpStatus.BAD_REQUEST, ex.getMessage()
        );
        problem.setTitle("Requisição inválida");
        problem.setType(URI.create("https://foodhub.com/errors/bad-request"));
        problem.setProperty("timestamp", Instant.now());
        return problem;
    }
}
```

### ProblemDetail (RFC 7807) — O padrão para erros em APIs REST

Spring Boot 3 suporta nativamente o **RFC 7807**. Em vez de inventar seu próprio formato de erro (cada empresa fazia diferente), o padrão define:

```json
{
  "type": "https://foodhub.com/errors/not-found",
  "title": "Recurso não encontrado",
  "status": 404,
  "detail": "Pedido não encontrado com id: 999",
  "timestamp": "2026-04-15T10:30:00Z"
}
```

É o que APIs profissionais usam e entrevistadores reconhecem.

---

## 1.16 Classe Principal

```java
package com.foodhub.order;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class OrderServiceApplication {

    public static void main(String[] args) {
        SpringApplication.run(OrderServiceApplication.class, args);
    }
}
```

---

## 1.17 Testando a Fase 01

### Rodar o serviço

```bash
# Na raiz do order-service
mvn spring-boot:run
```

O Flyway vai criar as tabelas automaticamente na primeira execução.

### Testar com curl

> **⚠️ Nota:** Esses comandos funcionam sem autenticação porque ainda não adicionamos Spring Security. A partir da **Fase 03**, todos os endpoints exigirão um token JWT no header `Authorization: Bearer <token>`.

```bash
# Criar um pedido
curl -X POST http://localhost:8081/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customerId": 1,
    "restaurantId": 1,
    "items": [
      {"menuItemId": 101, "menuItemName": "Pizza Margherita", "quantity": 2, "unitPrice": 35.90},
      {"menuItemId": 102, "menuItemName": "Coca-Cola 600ml", "quantity": 1, "unitPrice": 8.50}
    ]
  }'

# Resposta esperada: 201 Created
# {
#   "id": 1,
#   "customerId": 1,
#   "restaurantId": 1,
#   "status": "PENDING",
#   "totalAmount": 80.30,
#   "items": [...],
#   "createdAt": "2026-04-15T10:00:00",
#   "updatedAt": "2026-04-15T10:00:00"
# }

# Consultar o pedido
curl http://localhost:8081/api/orders/1

# Confirmar o pedido
curl -X PATCH http://localhost:8081/api/orders/1/status \
  -H "Content-Type: application/json" \
  -d '{"status": "CONFIRMED"}'

# Tentar confirmar de novo (deve retornar 409 Conflict)
curl -X PATCH http://localhost:8081/api/orders/1/status \
  -H "Content-Type: application/json" \
  -d '{"status": "CONFIRMED"}'

# Listar pedidos paginados
curl "http://localhost:8081/api/orders?page=0&size=10"
```

---

## 1.18 Git — Primeiro Commit

```bash
cd order-service
git init
git add .
git commit -m "feat: criar order-service com Spring Boot 3.5

- Entidade Order com Rich Domain Model (DDD)
- Máquina de estados para OrderStatus
- REST API com CRUD e paginação
- DTOs com Java Records
- Flyway migrations para PostgreSQL
- GlobalExceptionHandler com RFC 7807 ProblemDetail
- Logging estruturado com SLF4J"
```

---

## Resumo da Fase 01

| O que foi criado | Arquivo |
|---|---|
| Projeto Maven com Spring Boot 3.5 | `pom.xml` |
| Configuração | `application.yml`, `application-dev.yml` |
| Enum com máquina de estados | `OrderStatus.java` |
| Entidade rica (Aggregate Root) | `Order.java` |
| Entidade filha | `OrderItem.java` |
| Exceção de domínio | `OrderNotFoundException.java` |
| Evento de domínio (record) | `OrderCreatedEvent.java` |
| Repository (porta de saída) | `OrderRepository.java` |
| Interface para eventos (porta de saída) | `OrderEventPublisher.java` |
| Adaptador temporário (log) | `LoggingOrderEventPublisher.java` |
| DTOs (5 records) | `CreateOrderRequest`, `OrderItemRequest`, `OrderResponse`, `OrderItemResponse`, `UpdateOrderStatusRequest` |
| Mapper | `OrderMapper.java` |
| Application Service | `OrderApplicationService.java` |
| Controller REST (adaptador de entrada) | `OrderController.java` |
| Exception Handler (adaptador de entrada) | `GlobalExceptionHandler.java` |
| Flyway Migrations | `V1__create_orders_table.sql`, `V2__create_order_items_table.sql` |

---

## 💼 Perguntas frequentes em entrevistas

1. **"O que é Rich Domain Model vs Anemic Domain Model?"** — Rich: a entidade contém regras de negócio (ex: `Order.confirm()` valida a transição de estado). Anemic: entidade só tem getters/setters, e a lógica fica toda no Service. Rich Domain Model é o padrão DDD recomendado.

2. **"Para que servem Java Records como DTOs?"** — Records são classes imutáveis com `equals()`, `hashCode()`, `toString()` gerados automaticamente. Perfeitos para DTOs pois: (1) são imutáveis, (2) sem boilerplate, (3) deixam claro que são apenas transportadores de dados.

3. **"O que é RFC 7807 (ProblemDetail)?"** — Padrão HTTP para respostas de erro estruturadas. Spring Boot 3.x suporta nativamente via `ProblemDetail`. Contém: `type`, `title`, `status`, `detail`, `instance` — substituindo objetos de erro ad-hoc.

4. **"Por que `ddl-auto: validate` com Flyway em vez de `update`?"** — `update` pode causar perda de dados em produção (ex: renomear coluna = dropar + criar). `validate` garante que as entidades JPA estão alinhadas com o banco. Flyway gerencia as migrations de forma versionada e rastreável.

5. **"O que é o padrão Factory Method em entidades?"** — `Order.create(...)` é um factory method estático que encapsula a lógica de criação, garante invariantes (status PENDING, cálculo de total) e impede criação de objetos em estado inválido. Compila melhor que um construtor com muitos parâmetros.

6. **"Explique Arquitetura Hexagonal (Ports & Adapters)."** — O domínio (hexágono interno) não conhece o mundo externo. Toda comunicação passa por **portas** (interfaces em `application/port/`) e **adaptadores** (implementações em `adapter/`). Adaptadores de entrada (controllers, listeners) chamam o app; adaptadores de saída (JPA, Kafka, Feign) são chamados pelo app. A dependência sempre aponta para dentro: `adapter → application → domain`. Isso permite trocar qualquer tecnologia sem alterar o domínio.

7. **"Qual a diferença entre porta de entrada e porta de saída?"** — **Porta de entrada** (inbound port) define o que o app sabe fazer (ex: `CreateOrderUseCase`). **Porta de saída** (outbound port) define o que o app precisa do mundo externo (ex: `OrderRepository`, `OrderEventPublisher`). Adaptadores de entrada chamam portas de entrada; adaptadores de saída implementam portas de saída.

> **Próximo passo:** [Fase 02 — Persistência](fase-02-persistencia.md) — aprofundaremos JPA, performance, queries customizadas e Flyway.
