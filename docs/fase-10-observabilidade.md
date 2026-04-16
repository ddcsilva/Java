# Fase 10 — Observabilidade: Actuator, Micrometer, Prometheus e Grafana

> **Objetivo:** Implementar observabilidade completa: métricas (Micrometer + Prometheus), dashboards (Grafana), health checks (Actuator), logging estruturado e tracing distribuído. Cobrir também conceitos de deploy em nuvem (AWS/Azure).

### 🎯 O que você vai aprender nesta fase

- Os **3 pilares da observabilidade** (logs, métricas, traces)
- Configurar **Spring Boot Actuator** (health checks, liveness/readiness probes)
- Criar **métricas customizadas** com Micrometer (Counter, Gauge, Timer)
- Montar stack **Prometheus + Grafana** com Docker Compose
- Escrever **queries PromQL** para dashboards
- Implementar **logging estruturado** com JSON (Logstash Encoder)
- Correlacionar logs com traces via **MDC + traceId**
- Configurar **tracing distribuído** com Micrometer Tracing + Zipkin
- Entender o mapeamento de componentes locais para **AWS/Azure**

---

## 10.1 Os 3 Pilares da Observabilidade

```
         Observabilidade
        ┌──────┼──────┐
        ▼      ▼      ▼
     Logs   Métricas  Traces
        │      │      │
    O que     Como    Onde
   aconteceu  está   passou
```

| Pilar | Pergunta | Ferramenta |
|---|---|---|
| **Logs** | "O que aconteceu no serviço X às 14:30?" | SLF4J + Logback (ou Logstash) |
| **Métricas** | "Qual a latência média do endpoint?" | Micrometer + Prometheus + Grafana |
| **Traces** | "Onde a request demorou na cadeia de serviços?" | Micrometer Tracing + Zipkin |

---

## 10.2 Spring Boot Actuator

### Dependência (já adicionada na Fase 07)

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
```

### Configuração

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus,env,loggers
      base-path: /actuator

  endpoint:
    health:
      show-details: when-authorized   # Detalhes só para admin
      show-components: when-authorized
      probes:
        enabled: true                  # /actuator/health/liveness, /readiness

  health:
    diskspace:
      enabled: true
    db:
      enabled: true                    # Health do PostgreSQL
    kafka:
      enabled: true                    # Health do Kafka

  info:
    env:
      enabled: true
    java:
      enabled: true
    os:
      enabled: true
```

### Endpoints disponíveis

| Endpoint | Função |
|---|---|
| `/actuator/health` | Status geral (UP/DOWN) |
| `/actuator/health/liveness` | Kubernetes liveness probe |
| `/actuator/health/readiness` | Kubernetes readiness probe |
| `/actuator/metrics` | Lista todas as métricas disponíveis |
| `/actuator/metrics/{nome}` | Detalhe de uma métrica específica |
| `/actuator/prometheus` | Métricas no formato Prometheus |
| `/actuator/info` | Info da aplicação (versão, JDK, etc.) |
| `/actuator/loggers` | Ver/alterar nível de log em runtime |
| `/actuator/env` | Variáveis de ambiente (cuidado em prod!) |

### Health Check detalhado

```bash
curl http://localhost:8081/actuator/health | jq
```

```json
{
  "status": "UP",
  "components": {
    "db": {
      "status": "UP",
      "details": {
        "database": "PostgreSQL",
        "validationQuery": "isValid()"
      }
    },
    "diskSpace": {
      "status": "UP",
      "details": {
        "total": 499963174912,
        "free": 352842137600
      }
    },
    "kafka": {
      "status": "UP"
    }
  }
}
```

### Alterar log level em runtime (sem restart!)

```bash
# Ver nível atual
curl http://localhost:8081/actuator/loggers/com.foodhub

# Mudar para DEBUG em tempo real
curl -X POST http://localhost:8081/actuator/loggers/com.foodhub \
  -H "Content-Type: application/json" \
  -d '{"configuredLevel": "DEBUG"}'

# Voltar para INFO
curl -X POST http://localhost:8081/actuator/loggers/com.foodhub \
  -H "Content-Type: application/json" \
  -d '{"configuredLevel": "INFO"}'
```

> **Extremamente útil em produção:** Debug sem deploy, sem restart, sem downtime.

---

## 10.3 Micrometer + Prometheus

### Dependências

```xml
<!-- Micrometer core (já incluído pelo Actuator) -->
<!-- Micrometer registry para Prometheus -->
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>
```

### Métricas expostas automaticamente

Com Actuator + Micrometer + Prometheus, você automaticamente tem:

| Métrica | Tipo | O que mede |
|---|---|---|
| `http_server_requests_seconds` | Timer | Latência de cada endpoint HTTP |
| `jvm_memory_used_bytes` | Gauge | Memória JVM em uso |
| `jvm_threads_live_threads` | Gauge | Threads ativas |
| `hikaricp_connections_active` | Gauge | Conexões de banco em uso |
| `spring_kafka_producer_record_send_total` | Counter | Mensagens Kafka produzidas |
| `jvm_gc_pause_seconds` | Timer | Pausas do Garbage Collector |

### Métricas customizadas

```java
package com.foodhub.order.adapter.out.metrics;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import org.springframework.stereotype.Component;

@Component
public class OrderMetrics {

    private final Counter ordersCreatedCounter;
    private final Counter ordersCancelledCounter;
    private final Timer orderProcessingTimer;

    public OrderMetrics(MeterRegistry registry) {
        this.ordersCreatedCounter = Counter.builder("foodhub.orders.created")
                .description("Total de pedidos criados")
                .tag("service", "order-service")
                .register(registry);

        this.ordersCancelledCounter = Counter.builder("foodhub.orders.cancelled")
                .description("Total de pedidos cancelados")
                .tag("service", "order-service")
                .register(registry);

        this.orderProcessingTimer = Timer.builder("foodhub.order.processing.time")
                .description("Tempo de processamento de um pedido")
                .tag("service", "order-service")
                .register(registry);
    }

    public void incrementOrdersCreated() {
        ordersCreatedCounter.increment();
    }

    public void incrementOrdersCancelled() {
        ordersCancelledCounter.increment();
    }

    public Timer.Sample startTimer() {
        return Timer.start();
    }

    public void stopTimer(Timer.Sample sample) {
        sample.stop(orderProcessingTimer);
    }
}
```

### Usando no Service

```java
@Service
@RequiredArgsConstructor
public class OrderApplicationService {

    private final OrderMetrics metrics;

    @Transactional
    public OrderResponse createOrder(CreateOrderRequest request) {
        Timer.Sample timer = metrics.startTimer();

        try {
            // ... lógica de criação
            metrics.incrementOrdersCreated();
            return orderMapper.toResponse(saved);
        } finally {
            metrics.stopTimer(timer);
        }
    }
}
```

### Verificar métricas

```bash
# Formato Prometheus (texto)
curl http://localhost:8081/actuator/prometheus | grep foodhub

# Saída:
# foodhub_orders_created_total{service="order-service"} 42.0
# foodhub_orders_cancelled_total{service="order-service"} 3.0
# foodhub_order_processing_time_seconds_count{service="order-service"} 42
# foodhub_order_processing_time_seconds_sum{service="order-service"} 1.234
```

---

## 10.4 Prometheus + Grafana no Docker Compose

### Adicionar ao docker-compose.yml

```yaml
  # ==================== PROMETHEUS ====================
  prometheus:
    image: prom/prometheus:v2.54.0
    container_name: foodhub-prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./infrastructure/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.retention.time=7d'
    networks:
      - foodhub-network

  # ==================== GRAFANA ====================
  grafana:
    image: grafana/grafana:11.2.0
    container_name: foodhub-grafana
    ports:
      - "3000:3000"
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: admin
    volumes:
      - grafana-data:/var/lib/grafana
      - ./infrastructure/grafana/provisioning:/etc/grafana/provisioning:ro
    depends_on:
      - prometheus
    networks:
      - foodhub-network

volumes:
  # ... (existentes)
  prometheus-data:
  grafana-data:
```

### Configuração do Prometheus

Crie `infrastructure/prometheus/prometheus.yml`:

```yaml
global:
  scrape_interval: 15s       # Coleta métricas a cada 15 segundos
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'order-service'
    metrics_path: '/actuator/prometheus'
    static_configs:
      - targets: ['order-service:8081']
        labels:
          application: 'order-service'

  - job_name: 'restaurant-service'
    metrics_path: '/actuator/prometheus'
    static_configs:
      - targets: ['restaurant-service:8082']
        labels:
          application: 'restaurant-service'

  - job_name: 'payment-service'
    metrics_path: '/actuator/prometheus'
    static_configs:
      - targets: ['payment-service:8083']
        labels:
          application: 'payment-service'

  - job_name: 'api-gateway'
    metrics_path: '/actuator/prometheus'
    static_configs:
      - targets: ['api-gateway:8080']
        labels:
          application: 'api-gateway'
```

### Provisioning do Grafana

Crie `infrastructure/grafana/provisioning/datasources/datasource.yml`:

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
```

---

## 10.5 Dashboard Grafana

Acesse http://localhost:3000 (admin/admin).

### Queries Prometheus úteis para o dashboard

| Painel | PromQL |
|---|---|
| Requests/segundo | `rate(http_server_requests_seconds_count[5m])` |
| Latência p95 | `histogram_quantile(0.95, rate(http_server_requests_seconds_bucket[5m]))` |
| Latência p99 | `histogram_quantile(0.99, rate(http_server_requests_seconds_bucket[5m]))` |
| Taxa de erro (5xx) | `rate(http_server_requests_seconds_count{status=~"5.."}[5m])` |
| Memória JVM | `jvm_memory_used_bytes{area="heap"}` |
| Conexões DB ativas | `hikaricp_connections_active` |
| GC pauses | `rate(jvm_gc_pause_seconds_sum[5m])` |
| Pedidos criados/min | `rate(foodhub_orders_created_total[1m]) * 60` |

### Dashboard pré-construído

Importe o dashboard **Spring Boot Statistics** do Grafana:
1. Grafana → Dashboards → Import
2. ID: **19004** (ou busque "Spring Boot 3.x Statistics")
3. Selecione o datasource Prometheus
4. Pronto — métricas da JVM, HTTP e Hikari aparecerão automaticamente

---

## 10.6 Logging Estruturado

### Logback com JSON (para produção)

Crie `src/main/resources/logback-spring.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <!-- Console legível para desenvolvimento -->
    <springProfile name="default,dev">
        <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
            <encoder>
                <pattern>%d{HH:mm:ss.SSS} %highlight(%-5level) [%thread] %cyan(%logger{36}) - %msg%n</pattern>
            </encoder>
        </appender>

        <root level="INFO">
            <appender-ref ref="CONSOLE"/>
        </root>
    </springProfile>

    <!-- JSON estruturado para Docker/Cloud -->
    <springProfile name="docker,prod">
        <appender name="JSON" class="ch.qos.logback.core.ConsoleAppender">
            <encoder class="net.logstash.logback.encoder.LogstashEncoder">
                <customFields>{"service":"order-service"}</customFields>
            </encoder>
        </appender>

        <root level="INFO">
            <appender-ref ref="JSON"/>
        </root>
    </springProfile>
</configuration>
```

Dependência para JSON logging:

```xml
<dependency>
    <groupId>net.logstash.logback</groupId>
    <artifactId>logstash-logback-encoder</artifactId>
    <version>8.0</version>
</dependency>
```

### Saída JSON (profile docker/prod)

```json
{
  "@timestamp": "2026-04-15T10:30:00.123Z",
  "level": "INFO",
  "thread": "http-nio-8081-exec-1",
  "logger": "c.f.o.a.s.OrderApplicationService",
  "message": "Pedido criado com id=42",
  "service": "order-service"
}
```

> **Por que JSON?** — Container orchestrators (Docker, Kubernetes) e serviços de log (CloudWatch, ELK, Datadog) Parse JSON automaticamente. Logs em texto puro perdem metadados.

### Correlação de logs com Trace ID (MDC)

Quando o Micrometer Tracing está ativo, o `traceId` e `spanId` são automaticamente adicionados ao **MDC** (Mapped Diagnostic Context) do SLF4J. Para incluí-los no output:

**Formato texto (dev):**

```xml
<pattern>%d{HH:mm:ss.SSS} %highlight(%-5level) [%thread] [%X{traceId:-},%X{spanId:-}] %cyan(%logger{36}) - %msg%n</pattern>
```

**Formato JSON (prod):** O Logstash Encoder inclui o MDC automaticamente. O output fica:

```json
{
  "@timestamp": "2026-04-15T10:30:00.123Z",
  "level": "INFO",
  "logger": "c.f.o.a.s.OrderApplicationService",
  "message": "Pedido criado com id=42",
  "service": "order-service",
  "traceId": "6a3e960325e7c4c5f3a2d8b2e9f00a11",
  "spanId": "f3a2d8b2e9f00a11"
}
```

> **Isso é o que liga logs a traces:** Quando você vê um erro no Grafana/Kibana, copia o `traceId` e busca no Zipkin para ver o caminho completo da request entre todos os serviços. Sem o `traceId` nos logs, essa correlação é impossível.

---

## 10.7 Tracing Distribuído (Micrometer Tracing)

### O problema

Uma request entra no Gateway, passa pelo order-service, que chama restaurant-service via Feign, que publica no Kafka... se algo der erro, **como saber onde?**

### Solução: Trace ID

```
Request → Gateway → order-service → restaurant-service
          trace-id: abc123  trace-id: abc123  trace-id: abc123
          span-id:  001     span-id:  002     span-id:  003
```

Todos os serviços compartilham o mesmo `trace-id`. Filtrando por ele, você vê o caminho completo.

### Dependências

```xml
<!-- Micrometer Tracing com bridge para Brave (Zipkin) -->
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-tracing-bridge-brave</artifactId>
</dependency>
<dependency>
    <groupId>io.zipkin.reporter2</groupId>
    <artifactId>zipkin-reporter-brave</artifactId>
</dependency>
```

### Configuração

```yaml
management:
  tracing:
    sampling:
      probability: 1.0  # 100% das requests (em prod, use 0.1 = 10%)
  zipkin:
    tracing:
      endpoint: http://zipkin:9411/api/v2/spans
```

### Docker Compose — Zipkin

```yaml
  zipkin:
    image: openzipkin/zipkin:3
    container_name: foodhub-zipkin
    ports:
      - "9411:9411"
    networks:
      - foodhub-network
```

Acesse http://localhost:9411 para visualizar traces.

---

## 10.8 Preparação para Cloud (AWS/Azure)

### AWS — Serviços equivalentes

| Componente local | AWS equivalente |
|---|---|
| Docker Compose | **ECS (Fargate)** ou **EKS (Kubernetes)** |
| PostgreSQL | **RDS PostgreSQL** |
| Kafka | **Amazon MSK** (Managed Kafka) |
| Prometheus + Grafana | **CloudWatch** ou **Amazon Managed Grafana** |
| Eureka | **AWS Cloud Map** (ou manter Eureka em ECS) |
| Config Server | **AWS Systems Manager Parameter Store** |
| Docker Registry | **ECR** (Elastic Container Registry) |
| CI/CD | **AWS CodePipeline** (ou manter GitHub Actions) |
| Load Balancer | **ALB** (Application Load Balancer) |

### Azure — Serviços equivalentes

| Componente local | Azure equivalente |
|---|---|
| Docker Compose | **Azure Container Apps** ou **AKS** |
| PostgreSQL | **Azure Database for PostgreSQL** |
| Kafka | **Azure Event Hubs** (compatível com Kafka) |
| Prometheus + Grafana | **Azure Monitor** + **Azure Managed Grafana** |
| Config Server | **Azure App Configuration** |
| Docker Registry | **ACR** (Azure Container Registry) |

### application.yml para produção (exemplo AWS)

```yaml
spring:
  config:
    import: optional:aws-parameterstore:/foodhub/order-service/

  datasource:
    url: jdbc:postgresql://${RDS_HOSTNAME}:${RDS_PORT}/${RDS_DB_NAME}
    username: ${RDS_USERNAME}
    password: ${RDS_PASSWORD}

  kafka:
    bootstrap-servers: ${MSK_BOOTSTRAP_SERVERS}

management:
  tracing:
    sampling:
      probability: 0.1  # 10% em produção (custo)
```

---

## 10.9 Mapa de Portas Final do Projeto

| Serviço | Porta | URL |
|---|---|---|
| API Gateway | 8080 | http://localhost:8080 |
| Order Service | 8081 | http://localhost:8081 |
| Restaurant Service | 8082 | http://localhost:8082 |
| Payment Service | 8083 | http://localhost:8083 |
| Eureka Dashboard | 8761 | http://localhost:8761 |
| Config Server | 8888 | http://localhost:8888 |
| PostgreSQL | 5432 | jdbc:postgresql://localhost:5432 |
| Kafka | 9092 | localhost:9092 |
| Kafka UI | 8090 | http://localhost:8090 |
| Prometheus | 9090 | http://localhost:9090 |
| Grafana | 3000 | http://localhost:3000 |
| Zipkin | 9411 | http://localhost:9411 |

---

## 10.10 Checklist Final — Competências Enterprise

| Competência | Fase | Status |
|---|---|---|
| Java 21 (Records, Pattern Matching, Text Blocks) | 01 | ✅ |
| Spring Boot 3.5.x | 01 | ✅ |
| Spring MVC (REST API, Controllers) | 01 | ✅ |
| Bean Validation (JSR 380) | 01 | ✅ |
| Spring Data JPA + Hibernate 6 | 01, 02 | ✅ |
| Flyway (Schema Versioning) | 01, 02 | ✅ |
| PostgreSQL | 01, 02 | ✅ |
| N+1 Problem + Solutions | 02 | ✅ |
| Optimistic Locking (@Version) | 02 | ✅ |
| JPA Specifications | 02 | ✅ |
| JPA Projections | 02 | ✅ |
| Transaction Management | 02 | ✅ |
| Spring Security 6 | 03 | ✅ |
| JWT (JJWT) | 03 | ✅ |
| Role-based Authorization | 03 | ✅ |
| Apache Kafka (Spring Kafka) | 04 | ✅ |
| Event-Driven Architecture | 04 | ✅ |
| Dead Letter Queue (DLQ) | 04 | ✅ |
| JUnit 5 | 05 | ✅ |
| Mockito | 05 | ✅ |
| @WebMvcTest | 05 | ✅ |
| @DataJpaTest | 05 | ✅ |
| Testcontainers | 05 | ✅ |
| SpringDoc OpenAPI (Swagger) | 06 | ✅ |
| Docker + Docker Compose | 07 | ✅ |
| Multi-Stage Build | 07 | ✅ |
| Spring Cloud Gateway | 08 | ✅ |
| Eureka (Service Discovery) | 08 | ✅ |
| Config Server | 08 | ✅ |
| OpenFeign | 08 | ✅ |
| Resilience4j (Circuit Breaker) | 08 | ✅ |
| GitHub Actions CI/CD | 09 | ✅ |
| JaCoCo (Code Coverage) | 09 | ✅ |
| Spring Actuator | 10 | ✅ |
| Micrometer + Prometheus | 10 | ✅ |
| Grafana Dashboards | 10 | ✅ |
| Distributed Tracing | 10 | ✅ |
| Structured Logging | 10 | ✅ |
| DDD / Arquitetura Hexagonal | Todas | ✅ |
| SOLID Principles | Todas | ✅ |
| Design Patterns (Factory, Strategy, Observer) | Todas | ✅ |
| Maven | Todas | ✅ |
| Git / Git Flow | 01, 09 | ✅ |

---

## 💼 Perguntas frequentes em entrevistas

1. **"Diferença entre logs, métricas e traces"** — Logs: eventos textuais detalhados (debug). Métricas: valores numéricos agregados ao longo do tempo (counters, gauges, histograms). Traces: caminho de uma request através de múltiplos serviços. Os três pilares se complementam — use logs para detalhe, métricas para alertas, traces para diagnóstico distribuído.

2. **"O que é Distributed Tracing e como funciona?"** — Cada request recebe um `traceId` único no gateway. Esse ID é propagado para todos os serviços downstream (via headers HTTP e Kafka). No Zipkin/Jaeger, você busca por `traceId` e vê o caminho completo com latência de cada serviço.

3. **"Como funciona o Prometheus? (pull model)"** — Prometheus **puxa** métricas dos serviços (scrape) em intervalos regulares (ex: 15s), ao contrário do push model (onde o serviço envia). Vantagens: o serviço não precisa saber do Prometheus, falha no Prometheus não afeta o serviço.

4. **"O que é o padrão RED?"** — Rate (requests/segundo), Errors (taxa de erro), Duration (latência p50/p95/p99). Todo serviço deve expor essas 3 métricas. È o mínimo para saber se um serviço está saudável.

5. **"Como correlacionar logs entre microserviços?"** — Micrometer Tracing injeta `traceId` e `spanId` no MDC (Mapped Diagnostic Context) do SLF4J. Configurando o pattern do Logback para incluir `%X{traceId}`, todos os logs de uma mesma request compartilham o mesmo ID — permitindo filtrar no Kibana/CloudWatch por `traceId`.

---

## Conclusão

Você agora tem um **projeto enterprise completo** cobrindo todas as tecnologias pedidas nas vagas de Java no Brasil. Cada fase é independente — implemente na ordem, commite, e vá construindo seu portfólio.

**Dica final:** Em entrevistas, não diga "eu segui um tutorial". Diga: "Eu construí um sistema de pedidos com microserviços, onde tive que resolver problemas de N+1 com JPA, implementar circuit breaker para evitar cascading failures, e configurar uma pipeline CI/CD com Testcontainers". Aponte para seu GitHub com este projeto. Boa sorte!
