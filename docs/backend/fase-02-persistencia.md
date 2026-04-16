# Fase 02 — Persistência Avançada com JPA, Hibernate 6 e Flyway

> **Objetivo:** Dominar Spring Data JPA em cenário enterprise: performance (N+1, EntityGraph, projections), transações, versionamento de schema com Flyway, auditoria automática e paginação customizada.

### 🎯 O que você vai aprender nesta fase

- Identificar e resolver o **problema N+1** (3 soluções diferentes)
- Entender **propagação de transações** e a armadilha do self-invocation
- Usar **Projections** para queries otimizadas
- Implementar **auditoria automática** com `@CreatedDate` / `@LastModifiedDate`
- Aplicar **Optimistic Locking** com `@Version`
- Construir filtros dinâmicos com **Specification Pattern**
- Configurar **Flyway** para migrations avançadas
- Dimensionar o **HikariCP** connection pool

---

## 2.1 O Problema N+1 — O Maior Vilão de Performance JPA

### O que é o N+1?

Considere que temos 100 pedidos no banco, cada um com itens. Se você fizer:

```java
List<Order> orders = orderRepository.findAll(); // 1 query para pedidos
for (Order order : orders) {
    System.out.println(order.getItems().size()); // +100 queries (uma por pedido!)
}
```

**Resultado:** 1 query para buscar pedidos + 100 queries para buscar os itens de cada pedido = **101 queries**. Isso é o N+1.

### Por que acontece?

Porque os itens são `@OneToMany` com `FetchType.LAZY` (que é o correto!). Quando você acessa `order.getItems()`, o Hibernate dispara uma query separada para buscar os itens daquele pedido.

> **Nota:** Usar `FetchType.EAGER` **não** resolve. Apenas transforma o N+1 de lazy em N+1 de eager — o Hibernate vai buscar todos os itens para TODOS os pedidos, mesmo quando você não precisa deles.

### Solução 1: JOIN FETCH (JPQL)

Já vimos isso na Fase 01:

```java
@Query("SELECT o FROM Order o JOIN FETCH o.items WHERE o.id = :id")
Optional<Order> findByIdWithItems(@Param("id") Long id);
```

O `JOIN FETCH` diz ao Hibernate: "traga os itens na mesma query, com um SQL JOIN". Resultado: **1 query** em vez de 2.

### Cuidado com JOIN FETCH + Paginação

```java
// ⚠️ PERIGOSO: JOIN FETCH + paginação
@Query("SELECT o FROM Order o JOIN FETCH o.items")
Page<Order> findAllWithItems(Pageable pageable);
```

O Hibernate **não consegue** fazer paginação no SQL quando há JOIN FETCH em coleções. Ele carrega TUDO em memória e pagina na aplicação. Você vai ver este warning:

```
HHH90003004: firstResult/maxResults specified with collection fetch; applying in memory!
```

Em uma tabela com 1 milhão de pedidos, isso vai **crashar** sua aplicação.

### Solução 2: @EntityGraph

`@EntityGraph` é a alternativa do Spring Data JPA ao JOIN FETCH. É mais limpo e funciona com derived queries:

```java
@EntityGraph(attributePaths = {"items"})
Optional<Order> findWithItemsById(Long id);

// Funciona com queries derivadas do Spring Data
@EntityGraph(attributePaths = {"items"})
List<Order> findByStatus(OrderStatus status);
```

### Solução 3: @BatchSize (Para Coleções — Resolve N+1 em Lote)

Quando **não é viável** usar JOIN FETCH (ex: paginação), use `@BatchSize`:

```java
@Entity
@Table(name = "orders")
public class Order {

    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL, orphanRemoval = true)
    @BatchSize(size = 50) // Carrega items em lotes de 50 pedidos
    private List<OrderItem> items = new ArrayList<>();
}
```

**Como funciona:** Em vez de 100 queries individuais (`WHERE order_id = 1`, `WHERE order_id = 2`, ...), o Hibernate faz 2 queries (`WHERE order_id IN (1, 2, ..., 50)` e `WHERE order_id IN (51, ..., 100)`).

### Quando usar qual?

| Cenário | Solução |
|---|---|
| Query única por ID com join | `JOIN FETCH` ou `@EntityGraph` |
| Listagem paginada com coleções | `@BatchSize` |
| Query derivada simples | `@EntityGraph` |
| Relatório com muitos campos | Projection (seção 2.3) |

---

## 2.2 Transações em Profundidade

### Propagação de transações

O Spring gerencia transações como um "envelope" em torno dos seus métodos. Quando o método acaba, o Spring decide: commit ou rollback.

```java
@Service
@Transactional(readOnly = true)
public class OrderApplicationService {

    // Herda readOnly = true da classe
    public OrderResponse getOrderById(Long id) { ... }

    // Sobrescreve: abre transação de escrita
    @Transactional
    public OrderResponse createOrder(CreateOrderRequest request) { ... }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void logAuditEvent(Long orderId, String action) {
        // Abre uma transação SEPARADA. Se a transação do caller falhar
        // com rollback, este log ainda é salvo.
    }
}
```

### Tipos de propagação

| Tipo | Quando usar |
|---|---|
| `REQUIRED` (padrão) | Usa a transação existente ou cria uma nova |
| `REQUIRES_NEW` | Sempre cria uma nova transação (independente do caller) |
| `SUPPORTS` | Usa transação se existir, senão roda sem transação |
| `MANDATORY` | Deve haver transação; se não houver, lança exceção |
| `NOT_SUPPORTED` | Suspende a transação atual (roda sem transação) |
| `NEVER` | Se houver transação, lança exceção |
| `NESTED` | Cria savepoint dentro da transação existente |

### Armadilha: Self-Invocation

```java
@Service
public class OrderApplicationService {

    @Transactional
    public void processOrder(Long id) {
        // ⚠️ ESTA CHAMADA NÃO ABRE TRANSAÇÃO!
        // O proxy do Spring não intercepta chamadas internas.
        this.auditLog(id, "PROCESSED");
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void auditLog(Long id, String action) {
        // Não vai abrir nova transação quando chamado internamente
    }
}
```

**Por quê?** — O `@Transactional` funciona via proxy AOP. Quando `processOrder` chama `auditLog` diretamente (`this.auditLog()`), a chamada não passa pelo proxy, então o `@Transactional` é ignorado. 

**Solução:** Extrair para outro `@Component`:

```java
@Component
@RequiredArgsConstructor
public class AuditService {

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void logAuditEvent(Long orderId, String action) {
        // Agora sim — chamado via proxy do Spring
    }
}
```

---

## 2.3 Projections (Query Otimizada)

### Problema

Quando você chama `orderRepository.findAll()`, o Hibernate traz **todas as colunas** de todas as entidades. Para uma tela de listagem que só mostra ID, status e total, isso é desperdício.

### Interface Projection

```java
package com.foodhub.order.application.port.out;

/**
 * Projection que retorna apenas campos necessários para listagem.
 * O Spring Data JPA gera a query SELECT otimizada automaticamente.
 */
public interface OrderSummary {
    Long getId();
    String getStatus();
    java.math.BigDecimal getTotalAmount();
    java.time.LocalDateTime getCreatedAt();
}
```

No repository:

```java
public interface OrderRepository extends JpaRepository<Order, Long> {

    // Spring Data gera: SELECT id, status, total_amount, created_at FROM orders WHERE status = ?
    List<OrderSummary> findSummaryByStatus(OrderStatus status);

    Page<OrderSummary> findSummaryByCustomerId(Long customerId, Pageable pageable);
}
```

### Record Projection (DTO Projection)

Para mais controle, use JPQL com construtor:

```java
@Query("""
    SELECT new com.foodhub.order.application.dto.OrderSummaryDto(
        o.id, o.status, o.totalAmount, o.createdAt
    )
    FROM Order o
    WHERE o.customerId = :customerId
    ORDER BY o.createdAt DESC
    """)
Page<OrderSummaryDto> findSummaryByCustomer(
    @Param("customerId") Long customerId, Pageable pageable);
```

Com o DTO:

```java
public record OrderSummaryDto(
    Long id,
    OrderStatus status,
    BigDecimal totalAmount,
    LocalDateTime createdAt
) {}
```

> **Performance:** Projections podem ser **3-5x mais rápidas** que entidades completas para queries de listagem. O Hibernate pula o dirty checking e o snapshot, e o banco transfere menos dados.

---

## 2.4 Auditoria Automática com JPA

Automatize os campos `createdAt` e `updatedAt` para todas as entidades:

### Base Entity

```java
package com.foodhub.order.domain.model;

import jakarta.persistence.Column;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.MappedSuperclass;
import lombok.Getter;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDateTime;

@MappedSuperclass
@EntityListeners(AuditingEntityListener.class)
@Getter
public abstract class BaseEntity {

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @LastModifiedDate
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;
}
```

### Habilitar JPA Auditing

```java
package com.foodhub.order.adapter.out.persistence;

import org.springframework.context.annotation.Configuration;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

@Configuration
@EnableJpaAuditing
public class JpaConfig {
}
```

### Refatorar Order para usar BaseEntity

```java
@Entity
@Table(name = "orders")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Order extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // ... (remover createdAt e updatedAt — agora vêm da BaseEntity)

    @Version
    private Integer version;

    // ... resto da entidade
}
```

> **Benefício:** Toda nova entidade que estender `BaseEntity` ganha `createdAt` e `updatedAt` automaticamente. Não precisa setar manualmente no `Order.create()`.

> **Importante:** Após essa refatoração, **remova** as linhas `order.createdAt = LocalDateTime.now()` e `order.updatedAt = LocalDateTime.now()` do método `Order.create()` da Fase 01. O JPA Auditing via `@CreatedDate` e `@LastModifiedDate` agora cuida disso automaticamente no momento do `save()`. Sem remover essas linhas, os valores serão setados duas vezes (uma manual, uma pelo auditing) — funciona, mas é redundante e confuso.

---

## 2.5 Optimistic Locking com @Version

### O que é o problema?

Dois usuários abrem o mesmo pedido. Ambos veem status PENDING. Usuário A muda para CONFIRMED. Usuário B tenta mudar para CANCELLED. Sem controle, B sobrescreve A.

### Como @Version resolve

```java
@Entity
@Table(name = "orders")
public class Order {
    @Version
    private Integer version;
}
```

Quando o Hibernate faz UPDATE, inclui a versão:

```sql
UPDATE orders SET status = 'CONFIRMED', version = 1, updated_at = now()
WHERE id = 1 AND version = 0;
```

Se o `WHERE version = 0` não encontrar nenhuma linha (porque B já alterou para version = 1), o Hibernate lança `OptimisticLockException`. Trate no exception handler:

```java
@ExceptionHandler(OptimisticLockException.class)
public ProblemDetail handleOptimisticLock(OptimisticLockException ex) {
    ProblemDetail problem = ProblemDetail.forStatusAndDetail(
        HttpStatus.CONFLICT,
        "Este recurso foi modificado por outro usuário. Recarregue e tente novamente."
    );
    problem.setTitle("Conflito de concorrência");
    problem.setType(URI.create("https://foodhub.com/errors/optimistic-lock"));
    problem.setProperty("timestamp", Instant.now());
    return problem;
}
```

---

## 2.6 Specification Pattern (Queries Dinâmicas)

Para filtros complexos (ex: buscar pedidos por status E data E restaurante), use `Specification`:

### Adicionar dependência

Já incluída no `spring-boot-starter-data-jpa`, mas precisamos que o repository estenda `JpaSpecificationExecutor`:

```java
public interface OrderRepository extends JpaRepository<Order, Long>,
                                          JpaSpecificationExecutor<Order> {
    // queries existentes...
}
```

### Criar specifications

```java
package com.foodhub.order.application.port.out;

import com.foodhub.order.domain.model.Order;
import com.foodhub.order.domain.model.OrderStatus;
import org.springframework.data.jpa.domain.Specification;

import java.time.LocalDateTime;

public final class OrderSpecifications {

    private OrderSpecifications() {} // Utility class

    public static Specification<Order> hasStatus(OrderStatus status) {
        return (root, query, cb) -> 
            status == null ? null : cb.equal(root.get("status"), status);
    }

    public static Specification<Order> hasCustomerId(Long customerId) {
        return (root, query, cb) -> 
            customerId == null ? null : cb.equal(root.get("customerId"), customerId);
    }

    public static Specification<Order> hasRestaurantId(Long restaurantId) {
        return (root, query, cb) -> 
            restaurantId == null ? null : cb.equal(root.get("restaurantId"), restaurantId);
    }

    public static Specification<Order> createdAfter(LocalDateTime date) {
        return (root, query, cb) -> 
            date == null ? null : cb.greaterThanOrEqualTo(root.get("createdAt"), date);
    }

    public static Specification<Order> createdBefore(LocalDateTime date) {
        return (root, query, cb) -> 
            date == null ? null : cb.lessThanOrEqualTo(root.get("createdAt"), date);
    }
}
```

### Usar no Service

```java
public Page<OrderResponse> searchOrders(OrderSearchCriteria criteria, Pageable pageable) {
    Specification<Order> spec = Specification
            .where(OrderSpecifications.hasStatus(criteria.status()))
            .and(OrderSpecifications.hasCustomerId(criteria.customerId()))
            .and(OrderSpecifications.hasRestaurantId(criteria.restaurantId()))
            .and(OrderSpecifications.createdAfter(criteria.fromDate()))
            .and(OrderSpecifications.createdBefore(criteria.toDate()));

    return orderRepository.findAll(spec, pageable)
            .map(orderMapper::toResponse);
}
```

Com o DTO de busca:

```java
public record OrderSearchCriteria(
    OrderStatus status,
    Long customerId,
    Long restaurantId,
    LocalDateTime fromDate,
    LocalDateTime toDate
) {}
```

E o endpoint no controller:

```java
@GetMapping("/search")
public ResponseEntity<Page<OrderResponse>> searchOrders(
        @RequestParam(required = false) OrderStatus status,
        @RequestParam(required = false) Long customerId,
        @RequestParam(required = false) Long restaurantId,
        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime fromDate,
        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime toDate,
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = DEFAULT_PAGE_SIZE) int size) {

    OrderSearchCriteria criteria = new OrderSearchCriteria(
            status, customerId, restaurantId, fromDate, toDate);
    PageRequest pageRequest = PageRequest.of(page, size, Sort.by("createdAt").descending());
    return ResponseEntity.ok(orderService.searchOrders(criteria, pageRequest));
}
```

> **Specification vs JPQL:** — Use Specification quando os filtros são **dinâmicos** (o usuário pode filtrar por qualquer combinação). Use JPQL quando a query é **fixa** (sempre os mesmos parâmetros).

---

## 2.7 Flyway Avançado

### Migrations de Dados (DML)

```sql
-- V3__insert_seed_data.sql
-- Dados iniciais para desenvolvimento/testes
-- Em produção, este tipo de migration pode ser condicional

INSERT INTO orders (customer_id, restaurant_id, status, total_amount, created_at, updated_at, version)
VALUES
    (1, 1, 'DELIVERED', 80.30, NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days', 0),
    (1, 2, 'CONFIRMED', 45.00, NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day', 0),
    (2, 1, 'PENDING', 120.50, NOW(), NOW(), 0);
```

### Migrations de Alteração (Schema Evolution)

```sql
-- V4__add_delivery_address_to_orders.sql
ALTER TABLE orders ADD COLUMN delivery_address VARCHAR(500);

-- Preencher campo existente com valor padrão (não-null migration em 2 passos)
-- Passo 1: Adiciona como nullable (V4)
-- Passo 2: Preenche valores (V5)
-- Passo 3: Altera para not null (V6)
-- NUNCA faça tudo em uma migration — pode travar tabelas grandes por minutos
```

### Repeatable Migrations

Migrations que podem ser re-executadas (ex: views, functions):

```sql
-- R__create_order_stats_view.sql  (o prefixo "R__" indica repeatable)
CREATE OR REPLACE VIEW order_stats AS
SELECT
    restaurant_id,
    status,
    COUNT(*) as order_count,
    SUM(total_amount) as revenue,
    AVG(total_amount) as avg_ticket
FROM orders
GROUP BY restaurant_id, status;
```

### Boas práticas com Flyway

| Regra | Explicação |
|---|---|
| Nunca altere uma migration que já rodou | O checksum mudaria, causando falha na próxima inicialização |
| Uma migration, uma responsabilidade | `V5__add_index.sql` vs `V5__add_index_and_change_column_and_insert_data.sql` |
| Teste migrations em dev antes de prod | Use `spring.flyway.clean-disabled: false` **apenas em dev** |
| Numere sequencialmente | V1, V2, V3... (não pule números) |
| Use SQL, não Java migrations | SQL é revisável, portável e simples |

---

## 2.8 Connection Pool (HikariCP)

O Spring Boot usa **HikariCP** como connection pool padrão. Configure adequadamente:

```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 20          # Máximo de conexões simultâneas
      minimum-idle: 5                 # Mínimo de conexões ociosas
      connection-timeout: 30000       # Timeout para obter conexão (ms)
      idle-timeout: 600000            # Tempo antes de fechar conexão ociosa (ms)
      max-lifetime: 1800000           # Tempo máximo de vida de uma conexão (ms)
      leak-detection-threshold: 60000 # Detecta vazamento se conexão não retornada em 60s
```

### Fórmula para pool size

Um bom ponto de partida:

$$\text{pool\_size} = (\text{core\_count} \times 2) + \text{effective\_spindle\_count}$$

Para um servidor com 4 cores e SSD (1 disco efetivo): $4 \times 2 + 1 = 9$ conexões.

Na prática, **10-20 conexões** atendem a maioria dos microserviços.

> **Armadilha:** Definir pool size = 100 parece "melhor", mas cada conexão PostgreSQL consome ~10MB de memória. 100 conexões = 1GB só de pool. E PostgreSQL tem seu próprio limite (default 100).

---

## 2.9 Indices e Performance no PostgreSQL

Crie uma migration com índices para queries frequentes:

```sql
-- V5__add_performance_indexes.sql

-- Índice composto para busca de pedidos por cliente + data
CREATE INDEX idx_orders_customer_created ON orders(customer_id, created_at DESC);

-- Índice parcial: só pedidos pendentes (otimiza queries de processamento)
CREATE INDEX idx_orders_pending ON orders(status) WHERE status = 'PENDING';

-- Índice para busca por restaurante + status
CREATE INDEX idx_orders_restaurant_status ON orders(restaurant_id, status);
```

### Analisar queries com EXPLAIN

```sql
EXPLAIN ANALYZE
SELECT * FROM orders WHERE customer_id = 1 AND created_at > '2026-01-01'
ORDER BY created_at DESC;
```

Habilitar logging de queries lentas no PostgreSQL:

```sql
ALTER SYSTEM SET log_min_duration_statement = 100; -- ms
SELECT pg_reload_conf();
```

---

## 2.10 Resumo: Patterns de Persistência

| Pattern | Quando usar | Exemplo no projeto |
|---|---|---|
| JOIN FETCH | Query única com associação | `findByIdWithItems` |
| @EntityGraph | Derived query com associação | `findWithItemsById` |
| @BatchSize | Listagem paginada com coleções | `Order.items` com batch = 50 |
| Projection | Telas de listagem (poucos campos) | `OrderSummary` |
| Specification | Filtros dinâmicos | `searchOrders` |
| @Version | Controle de concorrência otimista | `Order.version` |
| BaseEntity | Auditoria automática | `createdAt`, `updatedAt` |
| Flyway | Versionamento de schema | `V1__create_orders_table.sql` |
| HikariCP | Connection pool | configuração em `application.yml` |

---

## 💼 Perguntas frequentes em entrevistas

1. **"O que é o problema N+1 do JPA e como resolver?"** — Explique com exemplo: 1 query para pedidos + N queries para itens. Cite 3 soluções: `JOIN FETCH`, `@EntityGraph`, `@BatchSize`. Demonstre que você sabe identificar o problema olhando os logs SQL.

2. **"Qual a diferença entre `ddl-auto: update` e `validate`?"** — `update` altera o schema automaticamente (perigoso em produção). `validate` apenas verifica alinhamento. Em produção, **sempre** use `validate` + Flyway para migrações versionadas.

3. **"Como funciona Optimistic Locking?"** — `@Version` adiciona coluna de versão. No UPDATE, Hibernate inclui `WHERE version = X`. Se outro processo alterou primeiro, lança `OptimisticLockException`. Use quando conflitos são raros.

4. **"Quando usar LAZY vs EAGER?"** — **Sempre LAZY por padrão.** EAGER carrega dados desnecessários e causa N+1. Quando precisar dos dados, use `JOIN FETCH` ou `@EntityGraph` explicitamente na query.

5. **"O que são JPA Specifications?"** — Implementação do pattern **Specification** (DDD) que permite compor critérios de busca dinamicamente. Ideal para filtros de busca com combinações variáveis de parâmetros.

6. **"Explique os estados do ciclo de vida de uma entidade JPA."** — **Transient:** objeto criado com `new`, JPA não conhece. **Managed:** após `persist()` ou `find()`, está no Persistence Context (1st level cache) — mudanças são detectadas automaticamente (dirty checking). **Detached:** após fechar a Session ou `detach()` — parece managed mas não é rastreado. **Removed:** marcado para deleção com `remove()`. Em entrevista, o entrevistador quer ouvir: *"Dirty checking funciona apenas em entidades Managed — se a entidade é Detached, preciso de `merge()` para reacoplar."*

7. **"O que é 1st level cache vs 2nd level cache no Hibernate?"** — **1st level cache** é o Persistence Context (por transação) — garante identity (`find(1)` duas vezes retorna a mesma instância). **2nd level cache** é compartilhado entre transações (configurável, ex: Ehcache/Caffeine) — cacheia entidades frequentemente lidas e raramente alteradas. **Query cache** cacheia resultados de queries. Trade-off: 2nd level cache adiciona complexidade de invalidação. Use apenas para dados quase estáticos (categorias, configurações).

> **Próximo passo:** [Fase 03 — Segurança](fase-03-seguranca.md) — Spring Security 6, JWT e controle de acesso baseado em roles.
