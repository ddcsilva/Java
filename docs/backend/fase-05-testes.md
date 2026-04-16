# Fase 05 — Testes Automatizados: JUnit 5, Mockito e Testcontainers

> **Objetivo:** Implementar uma estratégia de testes completa: unitários (domínio + service), de integração com MockMvc (@WebMvcTest), de repository (@DataJpaTest), e end-to-end com Testcontainers (PostgreSQL + Kafka reais). Ao final, você terá confiança total no código antes de cada deploy.

### 🎯 O que você vai aprender nesta fase

- A **pirâmide de testes** e quando usar cada tipo
- Testes unitários com **JUnit 5** (nested classes, parametrized, DisplayName)
- Mocking com **Mockito** (`@Mock`, `@InjectMocks`, `verify`)
- Testar controllers com **@WebMvcTest** + **MockMvc**
- Testar repositories com **@DataJpaTest** + **Testcontainers**
- Testes E2E com **@SpringBootTest** + containers Docker reais
- Usar **@MockitoBean** (Spring Boot 3.4+) em vez do deprecated `@MockBean`
- Organizar testes com **Tags** para execução seletiva

---

## 5.1 Pirâmide de Testes

```
         /\
        /  \        E2E / Testcontainers
       /    \       (poucos, lentos, alto custo)
      /------\
     /        \     Integração / @WebMvcTest / @DataJpaTest
    /          \    (médio, testa camadas conectadas)
   /____________\   Unitários / JUnit + Mockito
                    (muitos, rápidos, sem dependências)
```

| Tipo | Escopo | Ferramentas | Velocidade |
|---|---|---|---|
| **Unitário** | Uma classe isolada | JUnit 5 + Mockito | < 1ms/teste |
| **Integração (slice)** | Camada específica | @WebMvcTest, @DataJpaTest | ~500ms/teste |
| **E2E** | App inteira + infra | @SpringBootTest + Testcontainers | ~5-10s/teste |

---

## 5.2 Dependências de Teste

Já incluídas via `spring-boot-starter-test`. Adicione o Testcontainers:

```xml
<!-- ===== TESTCONTAINERS ===== -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-testcontainers</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>junit-jupiter</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>postgresql</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>kafka</artifactId>
    <scope>test</scope>
</dependency>
```

> Versões gerenciadas pelo BOM do Spring Boot — não declare manualmente.

---

## 5.3 Testes Unitários — Domínio

Testes do domínio são os **mais importantes** e os mais rápidos. Sem mocks, sem Spring, sem banco.

### OrderStatusTest

```java
package com.foodhub.order.domain.model;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

import static org.assertj.core.api.Assertions.assertThat;

@DisplayName("OrderStatus — Máquina de Estados")
class OrderStatusTest {

    @Nested
    @DisplayName("Transições válidas")
    class ValidTransitions {

        @Test
        @DisplayName("PENDING pode transicionar para CONFIRMED")
        void pendingToConfirmed() {
            assertThat(OrderStatus.PENDING.canTransitionTo(OrderStatus.CONFIRMED)).isTrue();
        }

        @Test
        @DisplayName("PENDING pode transicionar para CANCELLED")
        void pendingToCancelled() {
            assertThat(OrderStatus.PENDING.canTransitionTo(OrderStatus.CANCELLED)).isTrue();
        }

        @Test
        @DisplayName("CONFIRMED pode transicionar para PREPARING")
        void confirmedToPreparing() {
            assertThat(OrderStatus.CONFIRMED.canTransitionTo(OrderStatus.PREPARING)).isTrue();
        }

        @Test
        @DisplayName("READY pode transicionar para DELIVERED")
        void readyToDelivered() {
            assertThat(OrderStatus.READY.canTransitionTo(OrderStatus.DELIVERED)).isTrue();
        }
    }

    @Nested
    @DisplayName("Transições inválidas")
    class InvalidTransitions {

        @ParameterizedTest(name = "DELIVERED não pode transicionar para {0}")
        @EnumSource(OrderStatus.class)
        @DisplayName("DELIVERED é estado final")
        void deliveredIsFinal(OrderStatus target) {
            assertThat(OrderStatus.DELIVERED.canTransitionTo(target)).isFalse();
        }

        @ParameterizedTest(name = "CANCELLED não pode transicionar para {0}")
        @EnumSource(OrderStatus.class)
        @DisplayName("CANCELLED é estado final")
        void cancelledIsFinal(OrderStatus target) {
            assertThat(OrderStatus.CANCELLED.canTransitionTo(target)).isFalse();
        }

        @Test
        @DisplayName("PENDING não pode pular para DELIVERED")
        void pendingCannotJumpToDelivered() {
            assertThat(OrderStatus.PENDING.canTransitionTo(OrderStatus.DELIVERED)).isFalse();
        }
    }
}
```

### OrderTest

```java
package com.foodhub.order.domain.model;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.List;

import static org.assertj.core.api.Assertions.*;

@DisplayName("Order — Aggregate Root")
class OrderTest {

    private List<OrderItem> sampleItems;

    @BeforeEach
    void setUp() {
        sampleItems = List.of(
            new OrderItem(1L, "Pizza Margherita", 2, new BigDecimal("35.90")),
            new OrderItem(2L, "Coca-Cola 600ml", 1, new BigDecimal("8.50"))
        );
    }

    @Nested
    @DisplayName("Criação de pedido")
    class Creation {

        @Test
        @DisplayName("Deve criar pedido com status PENDING e total calculado")
        void shouldCreateOrderWithPendingStatusAndCalculatedTotal() {
            Order order = Order.create(1L, 1L, sampleItems);

            assertThat(order.getStatus()).isEqualTo(OrderStatus.PENDING);
            assertThat(order.getCustomerId()).isEqualTo(1L);
            assertThat(order.getRestaurantId()).isEqualTo(1L);
            assertThat(order.getItems()).hasSize(2);
            // 2 * 35.90 + 1 * 8.50 = 80.30
            assertThat(order.getTotalAmount()).isEqualByComparingTo(new BigDecimal("80.30"));
            assertThat(order.getCreatedAt()).isNotNull();
        }

        @Test
        @DisplayName("Deve lançar exceção se lista de itens estiver vazia")
        void shouldThrowWhenItemsEmpty() {
            assertThatThrownBy(() -> Order.create(1L, 1L, List.of()))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("ao menos um item");
        }

        @Test
        @DisplayName("Deve lançar exceção se lista de itens for null")
        void shouldThrowWhenItemsNull() {
            assertThatThrownBy(() -> Order.create(1L, 1L, null))
                    .isInstanceOf(IllegalArgumentException.class);
        }
    }

    @Nested
    @DisplayName("Transições de status")
    class StatusTransitions {

        @Test
        @DisplayName("Deve confirmar pedido PENDING")
        void shouldConfirmPendingOrder() {
            Order order = Order.create(1L, 1L, sampleItems);
            order.confirm();
            assertThat(order.getStatus()).isEqualTo(OrderStatus.CONFIRMED);
        }

        @Test
        @DisplayName("Fluxo completo: PENDING → CONFIRMED → PREPARING → READY → DELIVERED")
        void shouldFollowCompleteFlow() {
            Order order = Order.create(1L, 1L, sampleItems);

            order.confirm();
            assertThat(order.getStatus()).isEqualTo(OrderStatus.CONFIRMED);

            order.startPreparing();
            assertThat(order.getStatus()).isEqualTo(OrderStatus.PREPARING);

            order.markReady();
            assertThat(order.getStatus()).isEqualTo(OrderStatus.READY);

            order.deliver();
            assertThat(order.getStatus()).isEqualTo(OrderStatus.DELIVERED);
        }

        @Test
        @DisplayName("Não deve permitir confirmar pedido já DELIVERED")
        void shouldNotConfirmDeliveredOrder() {
            Order order = Order.create(1L, 1L, sampleItems);
            order.confirm();
            order.startPreparing();
            order.markReady();
            order.deliver();

            assertThatThrownBy(order::confirm)
                    .isInstanceOf(IllegalStateException.class)
                    .hasMessageContaining("DELIVERED")
                    .hasMessageContaining("CONFIRMED");
        }

        @Test
        @DisplayName("Deve cancelar pedido PENDING")
        void shouldCancelPendingOrder() {
            Order order = Order.create(1L, 1L, sampleItems);
            order.cancel();
            assertThat(order.getStatus()).isEqualTo(OrderStatus.CANCELLED);
        }
    }

    @Nested
    @DisplayName("Encapsulamento")
    class Encapsulation {

        @Test
        @DisplayName("Lista de items deve ser imutável")
        void itemsShouldBeUnmodifiable() {
            Order order = Order.create(1L, 1L, sampleItems);

            assertThatThrownBy(() -> order.getItems().clear())
                    .isInstanceOf(UnsupportedOperationException.class);
        }
    }
}
```

### OrderItemTest

```java
package com.foodhub.order.domain.model;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.*;

@DisplayName("OrderItem")
class OrderItemTest {

    @Test
    @DisplayName("Deve calcular subtotal corretamente")
    void shouldCalculateSubtotal() {
        OrderItem item = new OrderItem(1L, "Pizza", 3, new BigDecimal("35.90"));
        // 3 * 35.90 = 107.70
        assertThat(item.getSubtotal()).isEqualByComparingTo(new BigDecimal("107.70"));
    }

    @Test
    @DisplayName("Deve rejeitar quantidade zero")
    void shouldRejectZeroQuantity() {
        assertThatThrownBy(() -> new OrderItem(1L, "Pizza", 0, new BigDecimal("35.90")))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("positiva");
    }

    @Test
    @DisplayName("Deve rejeitar preço negativo")
    void shouldRejectNegativePrice() {
        assertThatThrownBy(() -> new OrderItem(1L, "Pizza", 1, new BigDecimal("-10.00")))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("positivo");
    }
}
```

> **AssertJ vs Hamcrest:** Usamos AssertJ (`assertThat()`) em vez de Hamcrest porque tem fluent API, auto-complete na IDE, e mensagens de erro melhores. O `spring-boot-starter-test` já inclui ambos.

---

## 5.4 Testes Unitários — Application Service (Mockito)

```java
package com.foodhub.order.application.usecase;

import com.foodhub.order.application.dto.*;
import com.foodhub.order.application.mapper.OrderMapper;
import com.foodhub.order.application.port.out.OrderEventPublisher;
import com.foodhub.order.domain.exception.OrderNotFoundException;
import com.foodhub.order.domain.model.Order;
import com.foodhub.order.domain.model.OrderItem;
import com.foodhub.order.domain.model.OrderStatus;
import com.foodhub.order.application.port.out.OrderRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class) // Não inicia o Spring — rápido!
@DisplayName("OrderApplicationService")
class OrderApplicationServiceTest {

    @Mock
    private OrderRepository orderRepository;

    @Mock
    private OrderMapper orderMapper;

    @Mock
    private OrderEventPublisher eventPublisher;

    @InjectMocks
    private OrderApplicationService orderService;

    @Nested
    @DisplayName("createOrder")
    class CreateOrder {

        @Test
        @DisplayName("Deve criar pedido e publicar evento")
        void shouldCreateOrderAndPublishEvent() {
            // Arrange
            CreateOrderRequest request = new CreateOrderRequest(
                    1L, 1L,
                    List.of(new OrderItemRequest(101L, "Pizza", 2, new BigDecimal("35.90")))
            );

            OrderResponse expectedResponse = new OrderResponse(
                    1L, 1L, 1L, "PENDING", new BigDecimal("71.80"),
                    List.of(new OrderItemResponse(1L, 101L, "Pizza", 2,
                            new BigDecimal("35.90"), new BigDecimal("71.80"))),
                    LocalDateTime.now(), LocalDateTime.now()
            );

            when(orderMapper.toOrderItems(any())).thenReturn(
                    List.of(new OrderItem(101L, "Pizza", 2, new BigDecimal("35.90")))
            );
            when(orderRepository.save(any(Order.class))).thenAnswer(invocation -> invocation.getArgument(0));
            when(orderMapper.toResponse(any(Order.class))).thenReturn(expectedResponse);

            // Act
            OrderResponse result = orderService.createOrder(request);

            // Assert
            assertThat(result.status()).isEqualTo("PENDING");
            assertThat(result.totalAmount()).isEqualByComparingTo(new BigDecimal("71.80"));

            // Verify: evento foi publicado exatamente 1 vez
            verify(eventPublisher, times(1)).publish(any());
            // Verify: pedido foi salvo no repositório
            verify(orderRepository, times(1)).save(any(Order.class));
        }
    }

    @Nested
    @DisplayName("getOrderById")
    class GetOrderById {

        @Test
        @DisplayName("Deve retornar pedido quando existe")
        void shouldReturnOrderWhenExists() {
            // Arrange
            Long orderId = 1L;
            Order order = Order.create(1L, 1L,
                    List.of(new OrderItem(101L, "Pizza", 1, new BigDecimal("35.90"))));

            OrderResponse expectedResponse = new OrderResponse(
                    orderId, 1L, 1L, "PENDING", new BigDecimal("35.90"),
                    List.of(), LocalDateTime.now(), LocalDateTime.now()
            );

            when(orderRepository.findByIdWithItems(orderId)).thenReturn(Optional.of(order));
            when(orderMapper.toResponse(order)).thenReturn(expectedResponse);

            // Act
            OrderResponse result = orderService.getOrderById(orderId);

            // Assert
            assertThat(result.id()).isEqualTo(orderId);
        }

        @Test
        @DisplayName("Deve lançar OrderNotFoundException quando não existe")
        void shouldThrowWhenNotFound() {
            when(orderRepository.findByIdWithItems(999L)).thenReturn(Optional.empty());

            assertThatThrownBy(() -> orderService.getOrderById(999L))
                    .isInstanceOf(OrderNotFoundException.class)
                    .hasMessageContaining("999");
        }
    }
}
```

### Explicação do Mockito

| Anotação/Método | Função |
|---|---|
| `@ExtendWith(MockitoExtension.class)` | Inicializa os mocks sem Spring (rápido) |
| `@Mock` | Cria um mock (objeto falso) |
| `@InjectMocks` | Injeta os mocks no objeto sendo testado |
| `when(...).thenReturn(...)` | Define o comportamento do mock |
| `verify(mock, times(n))` | Verifica que o método foi chamado N vezes |
| `any()` | Matcher: aceita qualquer argumento |

---

## 5.5 Testes de Controller (@WebMvcTest)

`@WebMvcTest` carrega **apenas** o controller + filtros Spring MVC. Não precisa de banco, Kafka, etc.

```java
package com.foodhub.order.adapter.in.web.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.foodhub.order.application.dto.*;
import com.foodhub.order.application.usecase.OrderApplicationService;
import com.foodhub.order.domain.exception.OrderNotFoundException;
import com.foodhub.order.adapter.in.web.security.JwtService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(OrderController.class)
@DisplayName("OrderController — Testes de API")
class OrderControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockitoBean
    private OrderApplicationService orderService;

    @MockitoBean
    private JwtService jwtService; // Mocka o JwtService para o filtro de segurança

    @Nested
    @DisplayName("POST /api/orders")
    class CreateOrderEndpoint {

        @Test
        @WithMockUser(roles = "USER")
        @DisplayName("Deve criar pedido e retornar 201")
        void shouldCreateOrderAndReturn201() throws Exception {
            CreateOrderRequest request = new CreateOrderRequest(
                    1L, 1L,
                    List.of(new OrderItemRequest(101L, "Pizza", 2, new BigDecimal("35.90")))
            );

            OrderResponse response = new OrderResponse(
                    1L, 1L, 1L, "PENDING", new BigDecimal("71.80"),
                    List.of(new OrderItemResponse(1L, 101L, "Pizza", 2,
                            new BigDecimal("35.90"), new BigDecimal("71.80"))),
                    LocalDateTime.now(), LocalDateTime.now()
            );

            when(orderService.createOrder(any())).thenReturn(response);

            mockMvc.perform(post("/api/orders")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(request)))
                    .andExpect(status().isCreated())
                    .andExpect(jsonPath("$.id").value(1))
                    .andExpect(jsonPath("$.status").value("PENDING"))
                    .andExpect(jsonPath("$.totalAmount").value(71.80));
        }

        @Test
        @WithMockUser(roles = "USER")
        @DisplayName("Deve retornar 400 quando request inválido")
        void shouldReturn400WhenInvalid() throws Exception {
            // Request sem items (campo obrigatório)
            String invalidJson = """
                {
                    "customerId": 1,
                    "restaurantId": 1,
                    "items": []
                }
                """;

            mockMvc.perform(post("/api/orders")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(invalidJson))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.title").value("Erro de validação"));
        }

        @Test
        @DisplayName("Deve retornar 401 sem autenticação")
        void shouldReturn401WithoutAuth() throws Exception {
            mockMvc.perform(post("/api/orders")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("{}"))
                    .andExpect(status().isUnauthorized());
        }
    }

    @Nested
    @DisplayName("GET /api/orders/{id}")
    class GetOrderEndpoint {

        @Test
        @WithMockUser
        @DisplayName("Deve retornar 404 quando pedido não existe")
        void shouldReturn404WhenNotFound() throws Exception {
            when(orderService.getOrderById(999L))
                    .thenThrow(new OrderNotFoundException(999L));

            mockMvc.perform(get("/api/orders/999"))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.title").value("Recurso não encontrado"))
                    .andExpect(jsonPath("$.detail").value("Pedido não encontrado com id: 999"));
        }
    }
}
```

### `@WithMockUser` — Simulando Autenticação

Em vez de gerar JWTs reais nos testes, `@WithMockUser(roles = "USER")` popula o `SecurityContext` com um usuário fictício. Limpo e rápido.

### `@MockitoBean` vs `@MockBean` (Migração Spring Boot 3.4+)

A partir do Spring Boot 3.4, a anotação `@MockBean` (de `org.springframework.boot.test.mock.bean`) foi **deprecated**. Use `@MockitoBean` (de `org.springframework.test.context.bean.override.mockito`):

```java
// ❌ Antigo (deprecated no Spring Boot 3.4+)
import org.springframework.boot.test.mock.bean.MockBean;
@MockBean private OrderService orderService;

// ✅ Novo (Spring Boot 3.4+)
import org.springframework.test.context.bean.override.mockito.MockitoBean;
@MockitoBean private OrderService orderService;
```

A funcionalidade é idêntica — a diferença é que `@MockitoBean` está no **Spring Framework** (não no Spring Boot), tornando-o disponível em mais contextos.

---

## 5.6 Testes de Repository (@DataJpaTest)

`@DataJpaTest` carrega **apenas** JPA: Hibernate, DataSource, repositories. Usa H2 in-memory por padrão, mas vamos usar Testcontainers para PostgreSQL real.

```java
package com.foodhub.order.application.port.out;

import com.foodhub.order.domain.model.Order;
import com.foodhub.order.domain.model.OrderItem;
import com.foodhub.order.domain.model.OrderStatus;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;

@DataJpaTest
@Testcontainers
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE) // Não substituir por H2
@DisplayName("OrderRepository — Testes de Persistência")
class OrderRepositoryTest {

    @Container
    @ServiceConnection // Spring Boot 3.1+ auto-configura DataSource a partir do container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @Autowired
    private OrderRepository orderRepository;

    private Order savedOrder;

    @BeforeEach
    void setUp() {
        orderRepository.deleteAll();

        List<OrderItem> items = List.of(
                new OrderItem(101L, "Pizza Margherita", 2, new BigDecimal("35.90")),
                new OrderItem(102L, "Coca-Cola 600ml", 1, new BigDecimal("8.50"))
        );
        Order order = Order.create(1L, 1L, items);
        savedOrder = orderRepository.save(order);
    }

    @Test
    @DisplayName("Deve salvar e recuperar pedido com items via JOIN FETCH")
    void shouldSaveAndFindWithItems() {
        Optional<Order> found = orderRepository.findByIdWithItems(savedOrder.getId());

        assertThat(found).isPresent();
        assertThat(found.get().getItems()).hasSize(2);
        assertThat(found.get().getTotalAmount()).isEqualByComparingTo(new BigDecimal("80.30"));
    }

    @Test
    @DisplayName("Deve buscar pedidos por customerId paginados")
    void shouldFindByCustomerIdPaginated() {
        // Criar mais pedidos para o customer
        for (int i = 0; i < 5; i++) {
            Order order = Order.create(1L, 1L,
                    List.of(new OrderItem(101L, "Item", 1, new BigDecimal("10.00"))));
            orderRepository.save(order);
        }

        Page<Order> page = orderRepository.findByCustomerId(1L, PageRequest.of(0, 3));

        assertThat(page.getContent()).hasSize(3);
        assertThat(page.getTotalElements()).isEqualTo(6); // 1 do setUp + 5 do loop
        assertThat(page.getTotalPages()).isEqualTo(2);
    }

    @Test
    @DisplayName("Deve buscar por status")
    void shouldFindByStatus() {
        List<Order> orders = orderRepository.findByStatus(OrderStatus.PENDING);

        assertThat(orders).hasSize(1);
        assertThat(orders.getFirst().getStatus()).isEqualTo(OrderStatus.PENDING);
    }

    @Test
    @DisplayName("findByIdWithItems deve retornar empty para ID inexistente")
    void shouldReturnEmptyForNonExistentId() {
        Optional<Order> found = orderRepository.findByIdWithItems(999L);
        assertThat(found).isEmpty();
    }
}
```

### `@ServiceConnection` — Magia do Spring Boot 3.1+

Antes do Spring Boot 3.1, conectar Testcontainers exigia `@DynamicPropertySource` manual:

```java
// Forma ANTIGA (ainda funciona, mas é verboso)
@DynamicPropertySource
static void overrideProps(DynamicPropertyRegistry registry) {
    registry.add("spring.datasource.url", postgres::getJdbcUrl);
    registry.add("spring.datasource.username", postgres::getUsername);
    registry.add("spring.datasource.password", postgres::getPassword);
}
```

Com `@ServiceConnection`, o Spring Boot detecta o container automaticamente e configura o DataSource. **Muito mais limpo.**

---

## 5.7 Testes E2E com @SpringBootTest + Testcontainers

Carrega a **aplicação inteira** com banco PostgreSQL real e Kafka real via containers Docker.

```java
package com.foodhub.order;

import com.foodhub.order.application.dto.*;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.http.*;
import org.testcontainers.containers.KafkaContainer;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

import java.math.BigDecimal;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
@DisplayName("Order Service — Testes E2E")
class OrderServiceE2ETest {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @Container
    @ServiceConnection
    static KafkaContainer kafka = new KafkaContainer(
            DockerImageName.parse("confluentinc/cp-kafka:7.7.0"));

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    @DisplayName("Fluxo completo: criar pedido → consultar → confirmar → marcar entregue")
    void shouldCompleteFullOrderFlow() {
        // 1. Gerar token
        var tokenRequest = new AuthTokenRequest(1L, "USER");
        ResponseEntity<AuthTokenResponse> tokenResponse = restTemplate.postForEntity(
                "/api/auth/token", tokenRequest, AuthTokenResponse.class);
        assertThat(tokenResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        String token = tokenResponse.getBody().token();

        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(token);
        headers.setContentType(MediaType.APPLICATION_JSON);

        // 2. Criar pedido
        CreateOrderRequest createRequest = new CreateOrderRequest(
                1L, 1L,
                List.of(new OrderItemRequest(101L, "Pizza Margherita", 2, new BigDecimal("35.90")))
        );

        ResponseEntity<OrderResponse> createResponse = restTemplate.exchange(
                "/api/orders", HttpMethod.POST,
                new HttpEntity<>(createRequest, headers), OrderResponse.class);

        assertThat(createResponse.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(createResponse.getBody().status()).isEqualTo("PENDING");
        Long orderId = createResponse.getBody().id();

        // 3. Consultar pedido
        ResponseEntity<OrderResponse> getResponse = restTemplate.exchange(
                "/api/orders/" + orderId, HttpMethod.GET,
                new HttpEntity<>(headers), OrderResponse.class);

        assertThat(getResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(getResponse.getBody().id()).isEqualTo(orderId);

        // 4. Gerar token de ADMIN para atualizar status
        var adminTokenRequest = new AuthTokenRequest(100L, "ADMIN");
        ResponseEntity<AuthTokenResponse> adminTokenResponse = restTemplate.postForEntity(
                "/api/auth/token", adminTokenRequest, AuthTokenResponse.class);
        String adminToken = adminTokenResponse.getBody().token();

        HttpHeaders adminHeaders = new HttpHeaders();
        adminHeaders.setBearerAuth(adminToken);
        adminHeaders.setContentType(MediaType.APPLICATION_JSON);

        // 5. Confirmar pedido
        ResponseEntity<OrderResponse> confirmResponse = restTemplate.exchange(
                "/api/orders/" + orderId + "/status", HttpMethod.PATCH,
                new HttpEntity<>(new UpdateOrderStatusRequest("CONFIRMED"), adminHeaders),
                OrderResponse.class);

        assertThat(confirmResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(confirmResponse.getBody().status()).isEqualTo("CONFIRMED");
    }

    // Records auxiliares para auth endpoint
    record AuthTokenRequest(Long userId, String role) {}
    record AuthTokenResponse(String token) {}
}
```

---

## 5.8 Organização de Testes

```
src/test/java/com/foodhub/order/
├── domain/
│   └── model/
│       ├── OrderStatusTest.java    ← Unitário (sem Spring)
│       ├── OrderTest.java          ← Unitário (sem Spring)
│       └── OrderItemTest.java      ← Unitário (sem Spring)
├── domain/
│   └── repository/
│       └── OrderRepositoryTest.java ← @DataJpaTest (JPA slice)
├── application/
│   └── service/
│       └── OrderApplicationServiceTest.java ← Unitário (Mockito)
├── api/
│   └── controller/
│       └── OrderControllerTest.java ← @WebMvcTest (MVC slice)
└── OrderServiceE2ETest.java         ← @SpringBootTest (E2E)
```

---

## 5.9 Executando os Testes

```bash
# Todos os testes
mvn test

# Somente testes unitários (sem Docker)
mvn test -Dgroups="unit"

# Somente testes de integração (com Testcontainers)
mvn test -Dgroups="integration"

# Relatório de cobertura (se usar JaCoCo)
mvn verify
```

### Configurando grupos (JUnit 5 Tags)

Para separar unitários de integração:

```java
@Tag("unit") // Nos testes unitários
class OrderTest { ... }

@Tag("integration") // Nos testes com Testcontainers
@DataJpaTest
class OrderRepositoryTest { ... }
```

---

## 5.10 Resumo: O que cada test slice faz

| Slice | Annotation | O que carrega | Tempo |
|---|---|---|---|
| Nenhum (unitário) | `@ExtendWith(MockitoExtension)` | Nada do Spring | ~1ms |
| Controller | `@WebMvcTest` | MVC + filtros + validação | ~2s |
| Repository | `@DataJpaTest` | JPA + Flyway + Testcontainers | ~5s |
| Full | `@SpringBootTest` | Tudo + Testcontainers | ~10s |

---

## 💼 Perguntas frequentes em entrevistas

1. **"Diferença entre testes unitários e de integração"** — Unitários testam uma classe isolada (mock nas dependências), rodam em milissegundos, sem I/O. Integração testam a interação real entre componentes (banco, Kafka), são mais lentos mas pegam bugs que unitários não pegam.

2. **"O que é a pirâmide de testes?"** — Base larga de unitários (rápidos, baratos), camada média de integração, topo fino de E2E. Inversão da pirâmide (muitos E2E, poucos unitários) causa suíte lenta e frágil.

3. **"O que é `@WebMvcTest` e o que ele NÃO carrega?"** — Carrega apenas a camada MVC: controllers, filtros, validação, serialização JSON. **Não carrega** services, repositories, nem banco. Dependências do controller devem ser mockadas com `@MockitoBean`.

4. **"Quando usar Mock vs container real (Testcontainers)?"** — Mock para testes unitários e de controller (velocidade). Container real para testes de repository (queries SQL reais, Flyway migrations, constraints do banco). H2 esconde bugs de compatibilidade com PostgreSQL.

5. **"O que é Testcontainers?"** — Biblioteca que sobe containers Docker reais durante os testes. Garante que seus testes de integração rodam contra o mesmo banco/Kafka que produção. Container é criado antes do teste e destruído depois.

> **Próximo passo:** [Fase 06 — Documentação da API](fase-06-documentacao-api.md) — SpringDoc OpenAPI 2 com Swagger UI.
