# Fase 08 — Spring Cloud: Gateway, Eureka, Config Server e Resilience4j

> **Objetivo:** Implementar os serviços de infraestrutura do ecossistema Spring Cloud: API Gateway (roteamento), Eureka (service discovery), Config Server (configuração centralizada), OpenFeign (comunicação síncrona) e Resilience4j (circuit breaker + retry). Ao final, os microserviços se encontram automaticamente e se comunicam de forma resiliente.

---

## 🎯 O que você vai aprender nesta fase

- Implementar **API Gateway** com roteamento e load balancing
- Configurar **Service Discovery** com Eureka (registro e resolução automáticos)
- Centralizar configurações com **Config Server** (Git-backed)
- Comunicar microserviços de forma declarativa com **OpenFeign**
- Implementar **Circuit Breaker** e **Retry** com Resilience4j
- Configurar **fallback** para resiliência quando serviços estão fora do ar

---

## 8.1 Visão Geral da Arquitetura Spring Cloud

```
                         ┌──────────────┐
                         │ Config Server│ :8888
                         │  (configs)   │
                         └──────┬───────┘
                                │ configs via Git/classpath
    Clientes  ──────────►┌──────┴───────┐
    (frontend,           │ API Gateway  │ :8080
     mobile)             │  (routing)   │
                         └──────┬───────┘
                                │ roteia por path
                    ┌───────────┼───────────┐
                    ▼           ▼           ▼
              ┌──────────┐┌──────────┐┌──────────┐
              │  Order   ││Restaurant││ Payment  │
              │ Service  ││ Service  ││ Service  │
              │  :8081   ││  :8082   ││  :8083   │
              └────┬─────┘└──────────┘└──────────┘
                   │ registra
                   ▼
             ┌──────────┐
             │  Eureka  │ :8761
             │ (registry)│
             └──────────┘
```

| Componente | Função |
|---|---|
| **API Gateway** | Ponto de entrada único. Roteia `/api/orders/**` → order-service, `/api/restaurants/**` → restaurant-service |
| **Eureka** | Registro de serviços. Cada serviço se registra e descobre os outros |
| **Config Server** | Centraliza application.yml de todos os serviços em um repositório Git |
| **OpenFeign** | Cliente HTTP declarativo para comunicação REST entre serviços |
| **Resilience4j** | Circuit breaker, retry, rate limiter — previne falhas em cascata |

---

## 8.2 Serviço 1: Eureka Server (Service Discovery)

### Criar o projeto

```bash
curl https://start.spring.io/starter.zip \
  -d type=maven-project \
  -d bootVersion=3.5.x \
  -d groupId=com.foodhub \
  -d artifactId=eureka-server \
  -d packageName=com.foodhub.eureka \
  -d javaVersion=21 \
  -d dependencies=cloud-eureka-server \
  -o eureka-server.zip
```

### pom.xml — Dependence Management para Spring Cloud

```xml
<properties>
    <java.version>21</java.version>
    <spring-cloud.version>2025.0.1</spring-cloud.version>
</properties>

<dependencies>
    <dependency>
        <groupId>org.springframework.cloud</groupId>
        <artifactId>spring-cloud-starter-netflix-eureka-server</artifactId>
    </dependency>
</dependencies>

<dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-dependencies</artifactId>
            <version>${spring-cloud.version}</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
    </dependencies>
</dependencyManagement>
```

> **Compatibilidade Spring Cloud ↔ Spring Boot:**
> | Spring Boot | Spring Cloud |
> |---|---|
> | 3.5.x | **2025.0.x (Northfields)** |
> | 3.4.x | 2024.0.x (Moorgate) |
> | 3.3.x | 2023.0.x (Leyton) |

### Classe principal

```java
package com.foodhub.eureka;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.netflix.eureka.server.EnableEurekaServer;

@SpringBootApplication
@EnableEurekaServer
public class EurekaServerApplication {
    public static void main(String[] args) {
        SpringApplication.run(EurekaServerApplication.class, args);
    }
}
```

### application.yml

```yaml
server:
  port: 8761

spring:
  application:
    name: eureka-server

eureka:
  client:
    register-with-eureka: false  # Não se registra nele mesmo
    fetch-registry: false        # Não busca registro (ele É o registro)
  server:
    enable-self-preservation: false  # Desabilitar em dev (em prod, manter true)
```

### Dashboard

Acesse http://localhost:8761 — você verá todos os serviços registrados.

---

## 8.3 Registrando Microserviços no Eureka

Adicione ao `pom.xml` do **order-service** (e dos outros microserviços):

```xml
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-netflix-eureka-client</artifactId>
</dependency>
```

E o BOM do Spring Cloud no `<dependencyManagement>`:

```xml
<dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-dependencies</artifactId>
            <version>2025.0.1</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
    </dependencies>
</dependencyManagement>
```

No `application.yml` do order-service:

```yaml
eureka:
  client:
    service-url:
      defaultZone: ${EUREKA_URI:http://localhost:8761/eureka}
  instance:
    prefer-ip-address: true                # Registra IP em vez de hostname
    instance-id: ${spring.application.name}:${random.value}  # ID único por instância
```

Ao iniciar, o order-service se registra automaticamente no Eureka com o nome `order-service`.

---

## 8.4 Serviço 2: Config Server (Configuração Centralizada)

### Criar o projeto

```bash
curl https://start.spring.io/starter.zip \
  -d type=maven-project \
  -d bootVersion=3.5.x \
  -d groupId=com.foodhub \
  -d artifactId=config-server \
  -d packageName=com.foodhub.config \
  -d javaVersion=21 \
  -d dependencies=cloud-config-server,cloud-eureka \
  -o config-server.zip
```

### Classe principal

```java
package com.foodhub.config;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.config.server.EnableConfigServer;

@SpringBootApplication
@EnableConfigServer
public class ConfigServerApplication {
    public static void main(String[] args) {
        SpringApplication.run(ConfigServerApplication.class, args);
    }
}
```

### application.yml

```yaml
server:
  port: 8888

spring:
  application:
    name: config-server
  
  cloud:
    config:
      server:
        # Opção 1: Configs armazenadas em um repo Git
        git:
          uri: https://github.com/seu-usuario/foodhub-config
          default-label: main
          clone-on-start: true
        # Opção 2: Configs no classpath (para desenvolvimento)
        # native:
        #   search-locations: classpath:/configs/

  # Se usando native profile:
  # profiles:
  #   active: native

eureka:
  client:
    service-url:
      defaultZone: http://localhost:8761/eureka
```

### Estrutura de configs no Git

```
foodhub-config/
├── application.yml              ← Config compartilhada por TODOS os serviços
├── order-service.yml            ← Config específica do order-service
├── order-service-docker.yml     ← Config do order-service no profile docker
├── restaurant-service.yml
└── payment-service.yml
```

### Exemplo: application.yml (compartilhado)

```yaml
# Config compartilhada por todos os microserviços
app:
  security:
    jwt:
      secret-key: ${JWT_SECRET:chave-compartilhada-32-chars-min}
      expiration-ms: 3600000
```

### Usando Config Server nos microserviços

No `application.yml` do order-service:

```yaml
spring:
  config:
    import: optional:configserver:http://localhost:8888
```

O `optional:` faz com que o serviço ainda inicie se o Config Server não estiver disponível (usa configs locais).

---

## 8.5 Serviço 3: API Gateway (Spring Cloud Gateway)

> **⚠️ Importante:** O Spring Cloud Gateway é baseado em **Spring WebFlux** (reativo), não em Spring MVC. O projeto `api-gateway` não deve ter `spring-boot-starter-web` como dependência — use apenas `spring-cloud-starter-gateway`. Controllers tradicionais (`@RestController`) não funcionam aqui.

### Criar o projeto

```bash
curl https://start.spring.io/starter.zip \
  -d type=maven-project \
  -d bootVersion=3.5.x \
  -d groupId=com.foodhub \
  -d artifactId=api-gateway \
  -d packageName=com.foodhub.gateway \
  -d javaVersion=21 \
  -d dependencies=cloud-gateway,cloud-eureka \
  -o api-gateway.zip
```

### application.yml com rotas

```yaml
server:
  port: 8080

spring:
  application:
    name: api-gateway

  cloud:
    gateway:
      routes:
        - id: order-service
          uri: lb://order-service      # lb:// = usar Eureka para descobrir instâncias
          predicates:
            - Path=/api/orders/**
          filters:
            - StripPrefix=0

        - id: restaurant-service
          uri: lb://restaurant-service
          predicates:
            - Path=/api/restaurants/**
          filters:
            - StripPrefix=0

        - id: payment-service
          uri: lb://payment-service
          predicates:
            - Path=/api/payments/**
          filters:
            - StripPrefix=0

        - id: order-service-swagger
          uri: lb://order-service
          predicates:
            - Path=/order-service/v3/api-docs
          filters:
            - RewritePath=/order-service/(?<remaining>.*), /${remaining}

      discovery:
        locator:
          enabled: true    # Auto-descoberta de serviços via Eureka
          lower-case-service-id: true

eureka:
  client:
    service-url:
      defaultZone: ${EUREKA_URI:http://localhost:8761/eureka}
```

### Como funciona o `lb://`

1. O cliente faz `GET http://gateway:8080/api/orders/1`
2. O Gateway vê que `/api/orders/**` corresponde à rota `order-service`
3. `lb://order-service` — o Gateway consulta o **Eureka** para descobrir as instâncias do `order-service`
4. Se há 2 instâncias (8081, 8091), o Gateway faz **load balancing** automaticamente
5. Encaminha a request para `http://192.168.1.100:8081/api/orders/1`

### Rate Limiting no Gateway (Opcional)

```yaml
filters:
  - name: RequestRateLimiter
    args:
      redis-rate-limiter.replenishRate: 10
      redis-rate-limiter.burstCapacity: 20
```

---

## 8.6 OpenFeign — Comunicação Síncrona entre Serviços

Para quando um serviço precisa **chamar** outro diretamente (ex: order-service consultar restaurant-service).

### Dependência

No `pom.xml` do order-service:

```xml
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-openfeign</artifactId>
</dependency>
```

### Habilitar Feign

```java
@SpringBootApplication
@EnableFeignClients
public class OrderServiceApplication { ... }
```

### Declarar o Feign Client

> **🏗️ Arquitetura Hexagonal (Ports & Adapters):** Na fase-00, definimos a interface `RestaurantPort` em `application/port/out/` como uma **porta de saída**. O `@FeignClient` abaixo é o **adaptador de saída** que implementa essa porta. Em produção, mantenha a interface de porta e faça o Feign Client implementá-la. Para simplicidade didática, usamos a interface do Feign diretamente.

```java
package com.foodhub.order.adapter.out.client;

import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;

@FeignClient(
    name = "restaurant-service",  // Deve corresponder ao spring.application.name
    fallbackFactory = RestaurantClientFallback.class
)
public interface RestaurantClient {

    @GetMapping("/api/restaurants/{id}")
    RestaurantResponse getRestaurant(@PathVariable("id") Long id);

    @GetMapping("/api/restaurants/{id}/available")
    boolean isRestaurantAvailable(@PathVariable("id") Long id);
}
```

```java
public record RestaurantResponse(
    Long id,
    String name,
    boolean active,
    String address
) {}
```

### Usando o Feign Client

```java
@Service
@RequiredArgsConstructor
public class OrderApplicationService {

    private final RestaurantClient restaurantClient;

    @Transactional
    public OrderResponse createOrder(CreateOrderRequest request) {
        // Verificar se restaurante existe e está aberto
        RestaurantResponse restaurant = restaurantClient.getRestaurant(request.restaurantId());
        if (!restaurant.active()) {
            throw new IllegalStateException("Restaurante " + restaurant.name() + " está fechado");
        }
        // ... criar pedido
    }
}
```

> **Feign resolve o nome `restaurant-service` via Eureka** — você não precisa saber a URL/porta do restaurante. Basta usar o nome do serviço.

---

## 8.7 Resilience4j — Circuit Breaker e Retry

### Dependência

```xml
<!-- Resilience4j com Spring Boot 3 -->
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-circuitbreaker-resilience4j</artifactId>
</dependency>
```

### Configuração

```yaml
resilience4j:
  circuitbreaker:
    instances:
      restaurant-service:
        register-health-indicator: true
        sliding-window-size: 10         # Monitora as últimas 10 chamadas
        failure-rate-threshold: 50       # Abre o circuito se 50%+ falharem
        wait-duration-in-open-state: 30s # Espera 30s antes de tentar novamente
        permitted-number-of-calls-in-half-open-state: 3
        minimum-number-of-calls: 5

  retry:
    instances:
      restaurant-service:
        max-attempts: 3
        wait-duration: 1s
        retry-exceptions:
          - java.io.IOException
          - java.util.concurrent.TimeoutException
```

### O que é Circuit Breaker?

Inspirado em circuitos elétricos:

```
FECHADO (normal)           ABERTO (falha)            SEMI-ABERTO
┌──────────────┐          ┌──────────────┐          ┌──────────────┐
│ Chamadas     │  50%+    │ Chamadas     │  30s     │ Tenta 3      │
│ passam       │ falhas → │ bloqueadas   │ espera → │ chamadas     │
│ normalmente  │          │ retornam     │          │ de teste     │
│              │          │ fallback     │          │              │
└──────────────┘          └──────────────┘          └──────────────┘
                                                     │ sucesso → FECHADO
                                                     │ falha → ABERTO
```

**Sem circuit breaker:** order-service chama restaurant-service → restaurant cai → order espera timeout (30s) → cada request fica presa → threads esgotam → order-service também cai → **efeito cascata**.

**Com circuit breaker:** Após 5 falhas seguidas, o circuito abre → retorna fallback imediatamente (sem esperar) → após 30s, tenta novamente → se funcionar, fecha o circuito.

### Usando com Feign Client

#### Fallback Factory

```java
package com.foodhub.order.adapter.out.client;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cloud.openfeign.FallbackFactory;
import org.springframework.stereotype.Component;

@Component
public class RestaurantClientFallback implements FallbackFactory<RestaurantClient> {

    private static final Logger log = LoggerFactory.getLogger(RestaurantClientFallback.class);

    @Override
    public RestaurantClient create(Throwable cause) {
        log.error("Fallback do RestaurantClient ativado: {}", cause.getMessage());

        return new RestaurantClient() {
            @Override
            public RestaurantResponse getRestaurant(Long id) {
                // Retorna uma resposta degradada em vez de falhar
                log.warn("Retornando resposta degradada para restaurante {}", id);
                return new RestaurantResponse(id, "Restaurante Indisponível", false, "");
            }

            @Override
            public boolean isRestaurantAvailable(Long id) {
                return false; // Assume indisponível como fallback seguro
            }
        };
    }
}
```

Habilitar fallback do Feign:

```yaml
spring:
  cloud:
    openfeign:
      circuitbreaker:
        enabled: true
```

### Usando @CircuitBreaker direto no Service

Alternativa ao Feign fallback — útil para qualquer método:

```java
@Service
@RequiredArgsConstructor
public class OrderApplicationService {

    @CircuitBreaker(name = "restaurant-service", fallbackMethod = "createOrderFallback")
    @Retry(name = "restaurant-service")
    public OrderResponse createOrder(CreateOrderRequest request) {
        // ... chamada normal
    }

    private OrderResponse createOrderFallback(CreateOrderRequest request, Throwable ex) {
        log.warn("Fallback: criando pedido sem verificar restaurante. Motivo: {}", ex.getMessage());
        // Cria pedido sem validação de restaurante (degradação graciosa)
        // ... lógica simplificada
    }
}
```

---

## 8.8 Docker Compose Atualizado com Spring Cloud

Adicione ao `docker-compose.yml`:

```yaml
  # ==================== EUREKA SERVER ====================
  eureka-server:
    build:
      context: ./eureka-server
      dockerfile: Dockerfile
    container_name: foodhub-eureka
    ports:
      - "8761:8761"
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:8761/actuator/health"]
      interval: 15s
      timeout: 5s
      retries: 5
      start_period: 30s
    networks:
      - foodhub-network

  # ==================== CONFIG SERVER ====================
  config-server:
    build:
      context: ./config-server
      dockerfile: Dockerfile
    container_name: foodhub-config
    ports:
      - "8888:8888"
    environment:
      EUREKA_CLIENT_SERVICEURL_DEFAULTZONE: http://eureka-server:8761/eureka
    depends_on:
      eureka-server:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:8888/actuator/health"]
      interval: 15s
      timeout: 5s
      retries: 5
      start_period: 30s
    networks:
      - foodhub-network

  # ==================== API GATEWAY ====================
  api-gateway:
    build:
      context: ./api-gateway
      dockerfile: Dockerfile
    container_name: foodhub-gateway
    ports:
      - "8080:8080"
    environment:
      EUREKA_CLIENT_SERVICEURL_DEFAULTZONE: http://eureka-server:8761/eureka
    depends_on:
      eureka-server:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:8080/actuator/health"]
      interval: 15s
      timeout: 5s
      retries: 3
      start_period: 30s
    networks:
      - foodhub-network
```

E atualize os microserviços para se registrarem no Eureka:

```yaml
  order-service:
    environment:
      # ... (existentes)
      EUREKA_CLIENT_SERVICEURL_DEFAULTZONE: http://eureka-server:8761/eureka
    depends_on:
      postgres:
        condition: service_healthy
      kafka:
        condition: service_healthy
      eureka-server:
        condition: service_healthy
```

### Ordem de inicialização

```
1. postgres, kafka     (infra, sem dependências)
2. eureka-server       (após infra estar saudável)
3. config-server       (após eureka)
4. api-gateway         (após eureka)
5. order-service       (após postgres, kafka, eureka)
6. restaurant-service  (após postgres, kafka, eureka)
7. payment-service     (após postgres, kafka, eureka)
```

---

## 8.9 Testando o Fluxo Completo

```bash
# Subir todo o ecossistema
docker compose up -d --build

# Verificar registro no Eureka
curl http://localhost:8761/eureka/apps | xmllint --format -

# Acessar order-service via Gateway (porta 8080, não 8081)
curl http://localhost:8080/api/orders

# O Gateway roteia automaticamente para o order-service

# Swagger do order-service via Gateway
# http://localhost:8080/order-service/v3/api-docs
```

---

## 8.10 Resumo dos Projetos Spring Cloud

| Projeto | Porta | Função | Dependência principal |
|---|---|---|---|
| eureka-server | 8761 | Registro de serviços | `spring-cloud-starter-netflix-eureka-server` |
| config-server | 8888 | Configuração centralizada | `spring-cloud-config-server` |
| api-gateway | 8080 | Roteamento + load balancing | `spring-cloud-starter-gateway` |
| (nos microserviços) | — | Discovery client | `spring-cloud-starter-netflix-eureka-client` |
| (nos microserviços) | — | Comunicação REST | `spring-cloud-starter-openfeign` |
| (nos microserviços) | — | Resiliência | `spring-cloud-starter-circuitbreaker-resilience4j` |

---

## 💼 Perguntas frequentes em entrevistas

1. **"O que é Circuit Breaker e quando é acionado?"** — Padrão que evita cascading failures. Estados: CLOSED (normal) → OPEN (muitas falhas, rejeita requests) → HALF_OPEN (testa se o serviço voltou). Acionado quando a taxa de falha ultrapassa o threshold configurado (ex: 50% em 10 chamadas).

2. **"Diferença entre API Gateway e Load Balancer"** — Load Balancer distribui tráfego entre instâncias. API Gateway faz isso **mais** roteamento por path, autenticação, rate limiting, circuit breaker, transformação de headers. Gateway é a "porta de entrada inteligente" dos microserviços.

3. **"Por que usar Service Discovery em vez de IPs fixos?"** — Em ambientes cloud/containers, instâncias sobem e descem dinamicamente. IPs mudam. Com Eureka, cada serviço se registra ao iniciar e o cliente resolve o endereço automaticamente. Zero configuração manual.

4. **"O que é Config Server e por que centralizar configurações?"** — Centraliza `application.yml` de todos os serviços em um repositório Git. Vantagens: alteração sem redeploy (refresh), versionamento via Git, secrets compartilhados, configuração por ambiente (dev/staging/prod).

5. **"OpenFeign vs RestTemplate vs WebClient"** — RestTemplate: síncrono, legado (não recomendado). WebClient: reativo/assíncrono, mais moderno. OpenFeign: declarativo (interface + anotações), integra com Eureka e Resilience4j automaticamente. Para microserviços Spring Cloud, **OpenFeign é o padrão**.

> **Próximo passo:** [Fase 09 — CI/CD](fase-09-cicd.md) — Pipeline automatizado com GitHub Actions.
