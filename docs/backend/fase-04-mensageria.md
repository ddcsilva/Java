# Fase 04 — Mensageria: Apache Kafka com Spring Kafka

> **Objetivo:** Implementar comunicação assíncrona entre microserviços usando Apache Kafka. O order-service publica eventos quando pedidos são criados; o restaurant-service e o payment-service consomem esses eventos. Ao final, você entenderá producers, consumers, serialização, retry, DLQ e boas práticas.

### 🎯 O que você vai aprender nesta fase

- Diferença entre comunicação **síncrona (REST)** e **assíncrona (Kafka)**
- Conceitos do Kafka: **broker, topic, partition, offset, consumer group**
- Configurar **Spring Kafka** (producer + consumer)
- Garantir **ordenação** de mensagens via partition key
- Implementar **retry** e **Dead Letter Queue (DLQ)**
- Kafka em modo **KRaft** (sem ZooKeeper)
- Evolução de interfaces com **SOLID** (Open/Closed principle)

---

## 4.1 Por que Mensageria?

### Comunicação Síncrona (REST) vs Assíncrona (Kafka)

```
SÍNCRONO (REST):
Order-Service → HTTP POST → Restaurant-Service
                ↓ espera resposta
                ↓ se Restaurant-Service está fora, Order-Service FALHA

ASSÍNCRONO (Kafka):
Order-Service → publica evento → [Kafka Topic] → Restaurant-Service consome
                                                → Payment-Service consome
                não espera resposta               cada um processa no seu tempo
```

| Aspecto | REST (síncrono) | Kafka (assíncrono) |
|---|---|---|
| Acoplamento | Alto (precisa saber a URL do destino) | Baixo (publica no tópico; não sabe quem consome) |
| Disponibilidade | Se o destino cair, falha | Se o destino cair, mensagem fica no tópico |
| Latência | Somada de todos os serviços na cadeia | Cada serviço processa independentemente |
| Escalabilidade | Limitada pelo gargalo mais lento | Consumers escalam horizontalmente |

### Quando usar cada um?

- **REST:** Queries (GET), quando precisa da resposta imediata (consultar saldo)
- **Kafka:** Comandos/Eventos, quando pode processar depois (pedido criado → notificar restaurante)

---

## 4.2 Conceitos do Kafka

### Broker, Topic, Partition, Offset, Consumer Group

```
PRODUCER (order-service)
    └→ Topic: order-events
        ├── Partition 0: [msg0] [msg3] [msg6] ...
        ├── Partition 1: [msg1] [msg4] [msg7] ...
        └── Partition 2: [msg2] [msg5] [msg8] ...
                              ↑
                     CONSUMER GROUP: restaurant-group
                     ├── Consumer A → lê Partition 0
                     ├── Consumer B → lê Partition 1
                     └── Consumer C → lê Partition 2
                     
                     CONSUMER GROUP: payment-group
                     ├── Consumer X → lê Partition 0, 1
                     └── Consumer Y → lê Partition 2
```

| Conceito | Explicação |
|---|---|
| **Broker** | Um servidor Kafka. Em produção, cluster com 3+ brokers |
| **Topic** | Canal de mensagens (como uma fila nomeada). Ex: `order-events` |
| **Partition** | Subdivisão de um topic. Permite paralelismo |
| **Offset** | Posição da mensagem dentro da partition (sequencial, imutável) |
| **Consumer Group** | Grupo de consumers que divide as partitions entre si |
| **Key** | Chave da mensagem. Mensagens com mesma key vão para a mesma partition (garante ordem) |

### Por que partitions importam?

- 3 partitions = até 3 consumers paralelos no mesmo grupo
- Mensagens com a mesma key (ex: `orderId`) sempre vão para a mesma partition → **ordem garantida** para um pedido específico
- Mais partitions = mais throughput, mas mais overhead

---

## 4.3 Dependências

Adicione ao `pom.xml`:

```xml
<!-- ===== MENSAGERIA ===== -->
<dependency>
    <groupId>org.springframework.kafka</groupId>
    <artifactId>spring-kafka</artifactId>
</dependency>

<!-- Para testes com Kafka embedded -->
<dependency>
    <groupId>org.springframework.kafka</groupId>
    <artifactId>spring-kafka-test</artifactId>
    <scope>test</scope>
</dependency>
```

> Versão gerenciada pelo Spring Boot parent (Spring Kafka 3.3.x para Spring Boot 3.5.x).

---

## 4.4 Configuração do Kafka no application.yml

```yaml
spring:
  kafka:
    bootstrap-servers: ${KAFKA_SERVERS:localhost:9092}
    
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.springframework.kafka.support.serializer.JsonSerializer
      acks: all                    # Espera confirmação de TODAS as réplicas
      retries: 3                   # Tenta 3 vezes em caso de falha
      properties:
        enable.idempotence: true   # Garante exatamente-uma-vez por partition
        max.in.flight.requests.per.connection: 5
        spring.json.add.type.headers: true

    consumer:
      group-id: order-service-group
      auto-offset-reset: earliest  # Se não tem offset, começa do início
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: org.springframework.kafka.support.serializer.JsonDeserializer
      properties:
        spring.json.trusted.packages: "com.foodhub.*"
        spring.json.use.type.headers: true

app:
  kafka:
    topics:
      order-created: order-events.created
      order-status-changed: order-events.status-changed
```

### Explicação de cada propriedade

| Propriedade | Valor | Por quê? |
|---|---|---|
| `acks: all` | Broker espera que todas as réplicas confirmem | Garante durabilidade — mensagem não se perde se um broker cai |
| `retries: 3` | Tenta reenviar 3 vezes | Tolerância a falhas transientes de rede |
| `enable.idempotence: true` | Broker rejeita mensagens duplicadas | Se retry reenvia, o broker detecta e ignora a duplicata |
| `auto-offset-reset: earliest` | Lê desde o início do tópico | Se o consumer é novo, não perde mensagens antigas |
| `spring.json.trusted.packages` | `com.foodhub.*` | Segurança: só desserializa classes do nosso pacote |

---

## 4.5 Configurar Tópicos Kafka

```java
package com.foodhub.order.adapter.out.config;

import org.apache.kafka.clients.admin.NewTopic;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.config.TopicBuilder;

@Configuration
public class KafkaTopicConfig {

    @Value("${app.kafka.topics.order-created}")
    private String orderCreatedTopic;

    @Value("${app.kafka.topics.order-status-changed}")
    private String orderStatusChangedTopic;

    @Bean
    public NewTopic orderCreatedTopic() {
        return TopicBuilder.name(orderCreatedTopic)
                .partitions(3)        // 3 partitions para paralelismo
                .replicas(1)          // 1 réplica (em dev; production = 3)
                .build();
    }

    @Bean
    public NewTopic orderStatusChangedTopic() {
        return TopicBuilder.name(orderStatusChangedTopic)
                .partitions(3)
                .replicas(1)
                .build();
    }

    /**
     * Dead Letter Topic: mensagens que falharam após todas as tentativas.
     */
    @Bean
    public NewTopic orderCreatedDlt() {
        return TopicBuilder.name(orderCreatedTopic + ".DLT")
                .partitions(1)
                .replicas(1)
                .build();
    }
}
```

---

## 4.6 Eventos de Domínio

### OrderCreatedEvent (já criado na Fase 01)

```java
package com.foodhub.order.domain.event;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record OrderCreatedEvent(
    Long orderId,
    Long customerId,
    Long restaurantId,
    BigDecimal totalAmount,
    LocalDateTime occurredAt
) {
    public OrderCreatedEvent(Long orderId, Long customerId,
                              Long restaurantId, BigDecimal totalAmount) {
        this(orderId, customerId, restaurantId, totalAmount, LocalDateTime.now());
    }
}
```

### OrderStatusChangedEvent (novo)

```java
package com.foodhub.order.domain.event;

import java.time.LocalDateTime;

public record OrderStatusChangedEvent(
    Long orderId,
    String previousStatus,
    String newStatus,
    LocalDateTime occurredAt
) {
    public OrderStatusChangedEvent(Long orderId, String previousStatus, String newStatus) {
        this(orderId, previousStatus, newStatus, LocalDateTime.now());
    }
}
```

### Atualizar OrderEventPublisher (interface)

A interface da Fase 01 só tinha `publish(OrderCreatedEvent)`. Agora que temos dois tipos de evento, atualize-a:

```java
package com.foodhub.order.application.port.out;

import com.foodhub.order.domain.event.OrderCreatedEvent;
import com.foodhub.order.domain.event.OrderStatusChangedEvent;

public interface OrderEventPublisher {
    void publish(OrderCreatedEvent event);
    void publish(OrderStatusChangedEvent event);
}
```

> **⚠️ IMPORTANTE: Atualize também o `LoggingOrderEventPublisher`** da Fase 01 para implementar o novo método. Sem essa atualização, o projeto **não compila**:
> ```java
> @Override
> public void publish(OrderStatusChangedEvent event) {
>     log.info("Evento publicado (log-only): StatusChanged orderId={} {} → {}",
>             event.orderId(), event.previousStatus(), event.newStatus());
> }
> ```

---

## 4.7 Producer (Publicador de Eventos)

Substitua a implementação `LoggingOrderEventPublisher` pela versão com Kafka:

```java
package com.foodhub.order.adapter.out.messaging;

import com.foodhub.order.application.port.out.OrderEventPublisher;
import com.foodhub.order.domain.event.OrderCreatedEvent;
import com.foodhub.order.domain.event.OrderStatusChangedEvent;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

@Component
public class KafkaOrderEventPublisher implements OrderEventPublisher {

    private static final Logger log = LoggerFactory.getLogger(KafkaOrderEventPublisher.class);

    private final KafkaTemplate<String, Object> kafkaTemplate;

    @Value("${app.kafka.topics.order-created}")
    private String orderCreatedTopic;

    @Value("${app.kafka.topics.order-status-changed}")
    private String orderStatusChangedTopic;

    public KafkaOrderEventPublisher(KafkaTemplate<String, Object> kafkaTemplate) {
        this.kafkaTemplate = kafkaTemplate;
    }

    @Override
    public void publish(OrderCreatedEvent event) {
        doPublish(orderCreatedTopic, event.orderId(), event, "OrderCreatedEvent");
    }

    @Override
    public void publish(OrderStatusChangedEvent event) {
        log.info("OrderStatusChangedEvent orderId={} {} → {}",
                event.orderId(), event.previousStatus(), event.newStatus());
        doPublish(orderStatusChangedTopic, event.orderId(), event, "OrderStatusChangedEvent");
    }

    private <T> void doPublish(String topic, Long orderId, T event, String eventType) {
        log.info("Publicando {} para orderId={}", eventType, orderId);
        kafkaTemplate.send(topic, String.valueOf(orderId), event)
                .whenComplete((result, ex) -> {
                    if (ex != null) {
                        log.error("Falha ao publicar {} orderId={}: {}", eventType, orderId, ex.getMessage());
                    } else {
                        log.debug("{} publicado. Topic={}, Partition={}, Offset={}",
                                eventType,
                                result.getRecordMetadata().topic(),
                                result.getRecordMetadata().partition(),
                                result.getRecordMetadata().offset());
                    }
                });
    }
}
```

### Detalhes importantes

1. **Key = orderId:** Garante que todos os eventos de um pedido vão para a mesma partition → **ordem preservada** para um pedido específico.

2. **`whenComplete()`:** Callback assíncrono. O `send()` retorna um `CompletableFuture<SendResult>`. O callback executa quando a confirmação do broker chega `(acks: all)`.

3. **Se o Kafka está fora do ar:** O producer tenta `retries: 3` vezes. Se falhar, o `ex` no callback não será null. Nesta implementação, logamos o erro. Em produção, poderia salvar em uma tabela `outbox` para retry posterior (Transactional Outbox Pattern).

---

## 4.8 Consumer (Ouvinte de Eventos)

> **📦 Módulo compartilhado:** O consumer abaixo usa `OrderCreatedEvent` do order-service. Em microserviços, há 3 formas de compartilhar a classe de evento:
> 1. **Módulo Maven compartilhado** (`foodhub-events`) — crie um jar com os eventos e adicione como dependência em ambos serviços. Abordagem mais limpa.
> 2. **Duplicar o record** — crie um `OrderCreatedEvent` idêntico no restaurant-service. Simples, mas não DRY.
> 3. **Schema Registry** (Avro/Protobuf) — contrato tipado via schema. Mais robusto para produção.
>
> Para este projeto didático, use a **opção 1 ou 2**. A opção 3 é bônus avançado.

### No restaurant-service (exemplo de consumer)

```java
package com.foodhub.restaurant.adapter.out.messaging;

import com.foodhub.order.domain.event.OrderCreatedEvent;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.kafka.support.KafkaHeaders;
import org.springframework.messaging.handler.annotation.Header;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class OrderCreatedConsumer {

    private static final Logger log = LoggerFactory.getLogger(OrderCreatedConsumer.class);

    @KafkaListener(
        topics = "${app.kafka.topics.order-created}",
        groupId = "restaurant-service-group",
        containerFactory = "kafkaListenerContainerFactory"
    )
    public void handleOrderCreated(
            @Payload OrderCreatedEvent event,
            @Header(KafkaHeaders.RECEIVED_PARTITION) int partition,
            @Header(KafkaHeaders.OFFSET) long offset) {

        log.info("Recebido OrderCreatedEvent: orderId={} partition={} offset={}",
                event.orderId(), partition, offset);

        // Lógica de negócio do restaurante:
        // 1. Verificar se o restaurante está aberto
        // 2. Confirmar disponibilidade dos itens
        // 3. Iniciar preparo
        // 4. Publicar evento de resposta (OrderConfirmedEvent ou OrderRejectedEvent)
        
        log.info("Pedido {} processado pelo restaurante {}", event.orderId(), event.restaurantId());
    }
}
```

### Consumidor com retry automático e DLQ

```java
package com.foodhub.order.adapter.out.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.config.ConcurrentKafkaListenerContainerFactory;
import org.springframework.kafka.core.ConsumerFactory;
import org.springframework.kafka.listener.CommonErrorHandler;
import org.springframework.kafka.listener.DeadLetterPublishingRecoverer;
import org.springframework.kafka.listener.DefaultErrorHandler;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.util.backoff.FixedBackOff;

@Configuration
public class KafkaConsumerConfig {

    private static final long RETRY_INTERVAL_MS = 1_000L;
    private static final long MAX_RETRY_ATTEMPTS = 3L;

    /**
     * Configura retry + Dead Letter Queue para consumidores.
     * Se uma mensagem falhar 3 vezes, vai para o tópico .DLT
     */
    @Bean
    public CommonErrorHandler kafkaErrorHandler(KafkaTemplate<String, Object> kafkaTemplate) {
        // DeadLetterPublishingRecoverer: envia mensagens falhadas para topic.DLT
        DeadLetterPublishingRecoverer recoverer = new DeadLetterPublishingRecoverer(kafkaTemplate);

        return new DefaultErrorHandler(recoverer,
                new FixedBackOff(RETRY_INTERVAL_MS, MAX_RETRY_ATTEMPTS));
    }

    @Bean
    public ConcurrentKafkaListenerContainerFactory<String, Object> kafkaListenerContainerFactory(
            ConsumerFactory<String, Object> consumerFactory,
            CommonErrorHandler kafkaErrorHandler) {

        ConcurrentKafkaListenerContainerFactory<String, Object> factory =
                new ConcurrentKafkaListenerContainerFactory<>();
        factory.setConsumerFactory(consumerFactory);
        factory.setCommonErrorHandler(kafkaErrorHandler);
        factory.setConcurrency(3); // 3 threads consumidoras (1 por partition)
        return factory;
    }
}
```

### Fluxo de uma mensagem falhada

```
Mensagem chega → Consumer tenta processar → FALHA
    ↓ (1 segundo de espera)
Retry 1 → FALHA
    ↓ (1 segundo de espera)
Retry 2 → FALHA
    ↓ (1 segundo de espera)
Retry 3 → FALHA
    ↓
DLQ: mensagem enviada para "order-events.created.DLT"
    ↓
Equipe investiga manualmente ou consumer de DLQ trata
```

---

## 4.9 Atualizar o OrderApplicationService

Publique eventos de status change:

```java
@Transactional
public OrderResponse updateOrderStatus(Long id, UpdateOrderStatusRequest request) {
    Order order = orderRepository.findById(id)
            .orElseThrow(() -> new OrderNotFoundException(id));

    String previousStatus = order.getStatus().name();
    OrderStatus targetStatus = OrderStatus.valueOf(request.status().toUpperCase());

    switch (targetStatus) {
        case CONFIRMED -> order.confirm();
        case PREPARING -> order.startPreparing();
        case READY -> order.markReady();
        case DELIVERED -> order.deliver();
        case CANCELLED -> order.cancel();
        default -> throw new IllegalArgumentException("Status inválido: " + request.status());
    }

    Order saved = orderRepository.save(order);
    log.info("Pedido {} atualizado: {} → {}", id, previousStatus, targetStatus);

    // Publicar evento de mudança de status
    eventPublisher.publish(new OrderStatusChangedEvent(
            saved.getId(), previousStatus, targetStatus.name()
    ));

    return orderMapper.toResponse(saved);
}
```

---

## 4.10 Kafka para Desenvolvimento Local

Para rodar Kafka localmente, a forma mais simples é via Docker Compose. Na Fase 07 (Docker), teremos o compose completo, mas por enquanto:

```yaml
# docker-compose-kafka.yml (uso temporário)
services:
  kafka:
    image: confluentinc/cp-kafka:7.7.0
    ports:
      - "9092:9092"
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@localhost:9093
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      CLUSTER_ID: MkU3OEVBNTcwNTJENDM2Qk
```

```bash
docker compose -f docker-compose-kafka.yml up -d
```

> **KRaft mode:** O Kafka 3.x eliminiu a dependência do ZooKeeper. Usamos `PROCESS_ROLES: broker,controller` — o próprio Kafka gerencia o cluster.

---

## 4.11 Testando com Kafka

```bash
# Listar tópicos criados
docker exec -it kafka kafka-topics --bootstrap-server localhost:9092 --list

# Consumir mensagens do tópico (debug em outro terminal)
docker exec -it kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic order-events.created \
  --from-beginning

# Criar um pedido (em outro terminal)
curl -X POST http://localhost:8081/api/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "customerId": 1,
    "restaurantId": 1,
    "items": [{"menuItemId": 101, "menuItemName": "Pizza", "quantity": 1, "unitPrice": 35.90}]
  }'

# O kafka-console-consumer deve mostrar o evento OrderCreatedEvent em JSON
```

---

## 4.12 Resumo dos Componentes Kafka

| Componente | Arquivo | Papel |
|---|---|---|
| Configuração de tópicos | `KafkaTopicConfig` | Cria tópicos + DLT na inicialização |
| Configuração de consumer | `KafkaConsumerConfig` | Retry + DLQ + concorrência |
| Events | `OrderCreatedEvent`, `OrderStatusChangedEvent` | Contratos de mensagem |
| Producer | `KafkaOrderEventPublisher` | Publica eventos nos tópicos |
| Consumer (exemplo) | `OrderCreatedConsumer` | Consome e processa eventos |
| application.yml | Kafka section | Serialização, acks, trusted packages |

---

## 💼 Perguntas frequentes em entrevistas

1. **"Diferença entre comunicação síncrona e assíncrona"** — Síncrona (REST/Feign): o chamador espera a resposta, acoplamento temporal. Assíncrona (Kafka): o produtor publica e segue, o consumidor processa quando puder. Use assíncrona para operações que não precisam de resposta imediata.

2. **"O que é uma Dead Letter Queue (DLQ) e por que usar?"** — Mensagens que falharam após todas as tentativas de retry vão para a DLQ. Sem DLQ, mensagens problemáticas bloqueiam o consumer (poison pill). Com DLQ, o processamento continua e você investiga os erros depois.

3. **"Como Kafka garante ordenação de mensagens?"** — Ordenação é garantida **dentro de uma partition**. Mensagens com a mesma key (ex: `orderId`) vão para a mesma partition. Entre partitions diferentes, não há garantia de ordem.

4. **"Diferença entre Kafka e RabbitMQ"** — Kafka: log distribuído, alta throughput, retenção de mensagens, replay possível. RabbitMQ: message broker tradicional, roteamento flexível (exchanges), mensagem removida após consumo. Para event-driven architecture com múltiplos consumidores, Kafka é mais adequado.

5. **"O que é idempotência e por que é importante em consumers?"** — Consumer idempotente produz o mesmo resultado se processar a mesma mensagem 2x. Essencial porque Kafka garante **at-least-once delivery** — duplicatas acontecem. Implemente com `eventId` único + verificação `if not exists`.

> **Próximo passo:** [Fase 05 — Testes](fase-05-testes.md) — Testes unitários, de integração e com Testcontainers.
