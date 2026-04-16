# Fase 07 — Docker: Containerização e Docker Compose

> **Objetivo:** Containerizar o order-service com Dockerfile multi-stage otimizado, criar um Docker Compose completo com todos os serviços de infraestrutura (PostgreSQL, Kafka, Eureka, Config Server, Gateway), scripts de inicialização e health checks.

---

## 🎯 O que você vai aprender nesta fase

- Criar **Dockerfile multi-stage** otimizado (build com JDK → runtime com JRE)
- Configurar **Docker Compose** com todos os serviços do ecossistema
- Implementar **health checks** e dependências entre containers
- Criar scripts de inicialização para múltiplos bancos PostgreSQL
- Configurar **profiles Spring** para ambiente Docker (`application-docker.yml`)
- Otimizar **layer caching** para builds rápidos (~10s vs ~2min)

---

## 7.1 Por que Docker?

| Sem Docker | Com Docker |
|---|---|
| "Na minha máquina funciona" | Mesmo ambiente em dev, staging e prod |
| Instalar PostgreSQL, Kafka manualmente | `docker compose up` — tudo pronto |
| Conflito de versões entre projetos | Cada container é isolado |
| Setup de 2 horas para novo membro | Setup de 5 minutos |

---

## 7.2 Dockerfile — Multi-Stage Build

Crie `order-service/Dockerfile`:

```dockerfile
# ============================================
# Stage 1: Build — Compila o projeto com Maven
# ============================================
FROM eclipse-temurin:21-jdk-alpine AS builder

WORKDIR /app

# Copiar arquivos de dependências primeiro (cache de layers)
COPY pom.xml .
COPY .mvn/ .mvn/
COPY mvnw .

# Baixar dependências (cached se pom.xml não mudou)
RUN chmod +x mvnw && ./mvnw dependency:go-offline -B

# Copiar código-fonte
COPY src/ src/

# Compilar (sem testes — testes rodam no CI)
RUN ./mvnw package -DskipTests -B

# ============================================
# Stage 2: Runtime — Imagem mínima para rodar
# ============================================
FROM eclipse-temurin:21-jre-alpine AS runtime

# Segurança: não rodar como root
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copiar apenas o JAR do stage anterior
COPY --from=builder /app/target/*.jar app.jar

# Mudar para usuário não-root
USER appuser

# Porta da aplicação
EXPOSE 8081

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:8081/actuator/health || exit 1

# JVM flags otimizados para containers
ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-Djava.security.egd=file:/dev/./urandom", \
  "-jar", "app.jar"]
```

### Explicação detalhada

**Stage 1 (builder):**
- Usa `jdk-alpine` (com compilador Java)
- Copia `pom.xml` primeiro → Docker cacheia a layer de dependências. Se só o código mudou, as dependências não são baixadas novamente
- `dependency:go-offline` baixa **tudo** de uma vez
- `package -DskipTests` gera o JAR

**Stage 2 (runtime):**
- Usa `jre-alpine` (sem compilador, ~60% menor que JDK)
- Cria usuário `appuser` — **nunca rode containers como root**
- `HEALTHCHECK` permite ao Docker (e Docker Compose) saber se o serviço está saudável
- `-XX:+UseContainerSupport` faz a JVM respeitar os limites de memória do container (habilitado por padrão desde JDK 10+, mas incluímos explicitamente para clareza)
- `-XX:MaxRAMPercentage=75.0` usa 75% da memória disponível para a JVM (deixa 25% para overhead do SO)

### Tamanhos comparativos

| Imagem | Tamanho |
|---|---|
| `eclipse-temurin:21-jdk` (sem Alpine) | ~450MB |
| `eclipse-temurin:21-jdk-alpine` | ~300MB |
| `eclipse-temurin:21-jre-alpine` (runtime) | ~180MB |
| Nosso JAR final | ~50MB |
| **Imagem final (runtime + JAR)** | **~230MB** |

---

## 7.3 .dockerignore

Crie `order-service/.dockerignore`:

```
target/
!target/*.jar
.git
.gitignore
.idea
*.iml
.vscode
docker-compose*.yml
README.md
docs/
```

---

## 7.4 Build e Teste do Container

```bash
# Build da imagem
docker build -t foodhub/order-service:latest .

# Rodar o container (precisa de PostgreSQL e Kafka acessíveis)
docker run -d \
  --name order-service \
  -p 8081:8081 \
  -e SPRING_DATASOURCE_URL=jdbc:postgresql://host.docker.internal:5432/foodhub_orders \
  -e SPRING_DATASOURCE_USERNAME=foodhub \
  -e SPRING_DATASOURCE_PASSWORD=foodhub123 \
  -e SPRING_KAFKA_BOOTSTRAP_SERVERS=host.docker.internal:9092 \
  foodhub/order-service:latest

# Verificar logs
docker logs -f order-service

# Verificar health
docker inspect --format='{{json .State.Health}}' order-service
```

---

## 7.5 Docker Compose — Todos os Serviços

> **📝 Nota:** O compose inclui `restaurant-service` e `payment-service`. Esses serviços seguem a mesma estrutura do `order-service` (pom.xml, Dockerfile, entidades, etc.). Use os modelos de dados definidos na Fase 00 e os padrões aprendidos nas fases anteriores para implementá-los como exercício.

Crie `docker-compose.yml` na raiz do projeto:

```yaml
services:

  # ==================== BANCO DE DADOS ====================
  postgres:
    image: postgres:16-alpine
    container_name: foodhub-postgres
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: foodhub
      POSTGRES_PASSWORD: foodhub123
      POSTGRES_DB: foodhub_orders  # Banco principal (criado automaticamente)
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./infrastructure/postgres/init-databases.sql:/docker-entrypoint-initdb.d/init-databases.sql:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U foodhub"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - foodhub-network

  # ==================== KAFKA (KRaft mode) ====================
  kafka:
    image: confluentinc/cp-kafka:7.7.0
    container_name: foodhub-kafka
    ports:
      - "9092:9092"
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:29092,CONTROLLER://0.0.0.0:9093,PLAINTEXT_HOST://0.0.0.0:9092
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:29092,PLAINTEXT_HOST://localhost:9092
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka:9093
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_INTER_BROKER_LISTENER_NAME: PLAINTEXT
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
      CLUSTER_ID: MkU3OEVBNTcwNTJENDM2Qk
    volumes:
      - kafka-data:/var/lib/kafka/data
    healthcheck:
      test: ["CMD", "kafka-broker-api-versions", "--bootstrap-server", "localhost:9092"]
      interval: 15s
      timeout: 10s
      retries: 5
      start_period: 30s
    networks:
      - foodhub-network

  # ==================== KAFKA UI (Debug) ====================
  kafka-ui:
    image: provectuslabs/kafka-ui:latest
    container_name: foodhub-kafka-ui
    ports:
      - "8090:8080"
    environment:
      KAFKA_CLUSTERS_0_NAME: foodhub-local
      KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: kafka:29092
    depends_on:
      kafka:
        condition: service_healthy
    networks:
      - foodhub-network

  # ==================== ORDER SERVICE ====================
  order-service:
    build:
      context: ./order-service
      dockerfile: Dockerfile
    container_name: foodhub-order-service
    ports:
      - "8081:8081"
    environment:
      SPRING_PROFILES_ACTIVE: docker
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/foodhub_orders
      SPRING_DATASOURCE_USERNAME: foodhub
      SPRING_DATASOURCE_PASSWORD: foodhub123
      SPRING_KAFKA_BOOTSTRAP_SERVERS: kafka:29092
      JWT_SECRET: minha-chave-secreta-super-segura-com-pelo-menos-32-caracteres
    depends_on:
      postgres:
        condition: service_healthy
      kafka:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:8081/actuator/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 40s
    networks:
      - foodhub-network

  # ==================== RESTAURANT SERVICE ====================
  restaurant-service:
    build:
      context: ./restaurant-service
      dockerfile: Dockerfile
    container_name: foodhub-restaurant-service
    ports:
      - "8082:8082"
    environment:
      SPRING_PROFILES_ACTIVE: docker
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/foodhub_restaurants
      SPRING_DATASOURCE_USERNAME: foodhub
      SPRING_DATASOURCE_PASSWORD: foodhub123
      SPRING_KAFKA_BOOTSTRAP_SERVERS: kafka:29092
      JWT_SECRET: minha-chave-secreta-super-segura-com-pelo-menos-32-caracteres
    depends_on:
      postgres:
        condition: service_healthy
      kafka:
        condition: service_healthy
    networks:
      - foodhub-network

  # ==================== PAYMENT SERVICE ====================
  payment-service:
    build:
      context: ./payment-service
      dockerfile: Dockerfile
    container_name: foodhub-payment-service
    ports:
      - "8083:8083"
    environment:
      SPRING_PROFILES_ACTIVE: docker
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/foodhub_payments
      SPRING_DATASOURCE_USERNAME: foodhub
      SPRING_DATASOURCE_PASSWORD: foodhub123
      SPRING_KAFKA_BOOTSTRAP_SERVERS: kafka:29092
      JWT_SECRET: minha-chave-secreta-super-segura-com-pelo-menos-32-caracteres
    depends_on:
      postgres:
        condition: service_healthy
      kafka:
        condition: service_healthy
    networks:
      - foodhub-network

volumes:
  postgres-data:
  kafka-data:

networks:
  foodhub-network:
    driver: bridge
```

---

## 7.6 Script de Inicialização do PostgreSQL

Crie `infrastructure/postgres/init-databases.sql`:

```sql
-- Este script é executado automaticamente pelo container PostgreSQL
-- via docker-entrypoint-initdb.d/ (somente na primeira inicialização)

-- O banco padrão (POSTGRES_DB) já é criado pelo container.
-- Aqui criamos os bancos adicionais.

SELECT 'CREATE DATABASE foodhub_orders'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'foodhub_orders')\gexec

SELECT 'CREATE DATABASE foodhub_restaurants'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'foodhub_restaurants')\gexec

SELECT 'CREATE DATABASE foodhub_payments'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'foodhub_payments')\gexec

-- Garantir permissões
GRANT ALL PRIVILEGES ON DATABASE foodhub_orders TO foodhub;
GRANT ALL PRIVILEGES ON DATABASE foodhub_restaurants TO foodhub;
GRANT ALL PRIVILEGES ON DATABASE foodhub_payments TO foodhub;
```

> **Por que múltiplos bancos?** — Padrão **Database-per-Service**: cada microserviço tem seu próprio banco. Nenhum serviço acessa o banco de outro. A comunicação entre serviços é via Kafka ou REST.

---

## 7.7 Profile Docker (application-docker.yml)

Crie `order-service/src/main/resources/application-docker.yml`:

```yaml
# Overrides para execução dentro do Docker
# Ativado via SPRING_PROFILES_ACTIVE=docker

spring:
  jpa:
    show-sql: false

logging:
  level:
    root: INFO
    com.foodhub: INFO
```

As propriedades de datasource e Kafka vêm das **variáveis de ambiente** do Docker Compose, que sobrescrevem o `application.yml` base (Spring Boot hierarquia de propriedades).

---

## 7.8 Operações com Docker Compose

```bash
# Subir tudo (build + start)
docker compose up -d --build

# Ver logs de todos os serviços
docker compose logs -f

# Ver logs de um serviço específico
docker compose logs -f order-service

# Ver status dos containers + health
docker compose ps

# Parar tudo (mantém volumes)
docker compose down

# Parar e APAGAR dados (⚠️ destrutivo)
docker compose down -v

# Rebuild de um serviço específico
docker compose up -d --build order-service

# Escalar um serviço (múltiplas instâncias)
docker compose up -d --scale order-service=3
```

---

## 7.9 Health Checks — Por que são essenciais

### Problema sem health checks

```
postgres inicia em 5 segundos
order-service inicia em 2 segundos
→ order-service tenta conectar ao PostgreSQL que ainda não está pronto
→ CRASH: Connection refused
```

### Solução com health checks e depends_on condition

```yaml
postgres:
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U foodhub"]
    interval: 10s       # Verifica a cada 10s
    timeout: 5s         # Considera falha se demorar mais de 5s
    retries: 5          # Tenta 5 vezes antes de marcar unhealthy
    
order-service:
  depends_on:
    postgres:
      condition: service_healthy  # Só inicia quando postgres está healthy
```

O Docker Compose espera o PostgreSQL responder ao `pg_isready` antes de iniciar o order-service.

---

## 7.10 Dependência do Spring Boot Actuator (para Health Check)

```xml
<!-- Não esqueça de adicionar ao pom.xml se ainda não tem -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
```

E no `application.yml`:

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info
  endpoint:
    health:
      show-details: when-authorized  # Detalhes só para admins
```

---

## 7.11 Dicas de Performance Docker

### Layer Caching

O Dockerfile está otimizado para cache:

```
Layer 1: Base image (JDK Alpine)           ← Raramente muda
Layer 2: pom.xml (dependências)            ← Muda quando adiciona lib
Layer 3: dependency:go-offline             ← Cached se pom.xml não mudou
Layer 4: Código-fonte                      ← Muda sempre
Layer 5: package                           ← Recompila
```

Se você só mudou código Java, as layers 1-3 vêm do cache. O build leva ~10s em vez de ~2min.

### Imagens menores

| Abordagem | Economia |
|---|---|
| Multi-stage build | ~200MB (JDK não vai para runtime) |
| Alpine Linux | ~100MB vs Ubuntu |
| JRE em vez de JDK | ~120MB |
| `.dockerignore` | Evita copiar target/, .git, etc. |

---

## 7.12 Resumo

| Componente | Arquivo | Função |
|---|---|---|
| Dockerfile | `order-service/Dockerfile` | Multi-stage build (JDK → JRE) |
| Docker Ignore | `.dockerignore` | Exclui arquivos desnecessários do build |
| Docker Compose | `docker-compose.yml` | Orquestra todos os serviços |
| Init Script | `infrastructure/postgres/init-databases.sql` | Cria bancos no PostgreSQL |
| Profile Docker | `application-docker.yml` | Overrides para ambiente Docker |
| Health Check | Dockerfile + Compose | Garante startup ordenada |

**Serviços no Compose:**
| Serviço | Porta | Função |
|---|---|---|
| PostgreSQL | 5432 | Banco de dados |
| Kafka (KRaft) | 9092 | Mensageria |
| Kafka UI | 8090 | UI para debug do Kafka |
| order-service | 8081 | Microserviço de pedidos |
| restaurant-service | 8082 | Microserviço de restaurantes |
| payment-service | 8083 | Microserviço de pagamentos |

---

## 💼 Perguntas frequentes em entrevistas

1. **"O que é multi-stage build e por que usar?"** — Separa build (JDK + Maven, ~800MB) de runtime (apenas JRE, ~200MB). A imagem final é menor, mais segura (sem ferramentas de compilação) e mais rápida para deploy.

2. **"Como funciona layer caching no Docker?"** — Cada instrução no Dockerfile cria uma layer. Se uma layer não mudou, Docker usa o cache. Por isso copiamos `pom.xml` antes do código-fonte — dependências mudam raramente, código muda sempre.

3. **"Diferença entre CMD e ENTRYPOINT"** — `ENTRYPOINT` define o executável principal (não é sobrescrito facilmente). `CMD` define argumentos padrão (pode ser sobrescrito). Padrão para Java: `ENTRYPOINT ["java", "-jar", "app.jar"]`.

4. **"Docker Compose vs Kubernetes — quando usar cada um?"** — Compose para desenvolvimento local e ambientes simples. Kubernetes para produção com auto-scaling, self-healing, rolling updates, e orquestração de dezenas/centenas de containers.

5. **"Como garantir que o app só inicia depois do banco estar pronto?"** — `depends_on` com `condition: service_healthy` + health check no container do PostgreSQL (`pg_isready`). Sem health check, `depends_on` apenas garante que o container **iniciou**, não que está **pronto**.

> **Próximo passo:** [Fase 08 — Spring Cloud](fase-08-spring-cloud.md) — API Gateway, Service Discovery, Config Server e Resilience4j.
