# Fase 09 — CI/CD: Pipeline Automatizado com GitHub Actions

> **Objetivo:** Configurar uma pipeline de Integração Contínua e Entrega Contínua (CI/CD) usando GitHub Actions. A pipeline compila, testa (unitários + integração com Testcontainers), analisa qualidade, builda imagens Docker e faz deploy automatizado.

---

## 🎯 O que você vai aprender nesta fase

- Criar **pipeline CI/CD** completa com GitHub Actions
- Configurar build e testes automatizados (unitários + integração)
- Rodar **Testcontainers no CI** (Docker-in-Docker)
- Integrar **JaCoCo** para cobertura de código com threshold mínimo
- Buildar e publicar **imagens Docker** automaticamente no GHCR
- Implementar deploy com ambientes **staging → prod** (com aprovação manual)

---

## 9.1 O que é CI/CD?

```
        CI (Continuous Integration)                    CD (Continuous Delivery/Deploy)
┌──────────────────────────────────────────┐  ┌──────────────────────────────────────┐
│  Push → Build → Test → Quality Check     │  │  Build Image → Push Registry → Deploy│
│         ↓                                │  │       ↓                              │
│  Feedback rápido: "seu código quebrou    │  │  Automaticamente: staging → prod     │
│  algo" (em minutos, não em dias)         │  │  (ou com aprovação manual para prod) │
└──────────────────────────────────────────┘  └──────────────────────────────────────┘
```

| Conceito | Significado |
|---|---|
| **CI** | Todo push dispara build + testes automaticamente |
| **CD (Delivery)** | Artefato está sempre pronto para deploy (manual) |
| **CD (Deploy)** | Deploy automático em produção sem intervenção |

---

## 9.2 Estrutura do Workflow

Crie `.github/workflows/ci.yml`:

```yaml
name: FoodHub CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  JAVA_VERSION: '21'
  DOCKER_REGISTRY: ghcr.io
  IMAGE_PREFIX: ${{ github.repository_owner }}/foodhub

jobs:
  # ====================================
  # Job 1: Build e Testes
  # ====================================
  test:
    name: Build & Test
    runs-on: ubuntu-latest

    strategy:
      matrix:
        service: [order-service, restaurant-service, payment-service]

    defaults:
      run:
        working-directory: ${{ matrix.service }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup JDK 21
        uses: actions/setup-java@v4
        with:
          java-version: ${{ env.JAVA_VERSION }}
          distribution: 'temurin'
          cache: 'maven'

      - name: Build & Run Tests
        run: mvn verify -B -V
        # -B = batch mode (sem download progress bars)
        # -V = exibe versão do Maven
        # verify = compila + testa + verifica (inclui integration-test)

      - name: Upload Test Reports
        if: always()  # Mesmo se os testes falharem
        uses: actions/upload-artifact@v4
        with:
          name: test-reports-${{ matrix.service }}
          path: ${{ matrix.service }}/target/surefire-reports/
          retention-days: 7

      - name: Upload Coverage Report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: coverage-${{ matrix.service }}
          path: ${{ matrix.service }}/target/site/jacoco/
          retention-days: 7

  # ====================================
  # Job 2: Análise de Qualidade
  # ====================================
  quality:
    name: Code Quality
    runs-on: ubuntu-latest
    needs: test

    strategy:
      matrix:
        service: [order-service, restaurant-service, payment-service]

    defaults:
      run:
        working-directory: ${{ matrix.service }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup JDK 21
        uses: actions/setup-java@v4
        with:
          java-version: ${{ env.JAVA_VERSION }}
          distribution: 'temurin'
          cache: 'maven'

      - name: Run SpotBugs
        run: mvn spotbugs:check -B
        continue-on-error: true  # Não bloqueia pipeline, mas reporta

      - name: Check Code Formatting
        run: mvn checkstyle:check -B
        continue-on-error: true

  # ====================================
  # Job 3: Build Docker Images
  # ====================================
  docker:
    name: Build & Push Docker Image
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/main'  # Só na main

    permissions:
      contents: read
      packages: write

    strategy:
      matrix:
        service: [order-service, restaurant-service, payment-service, api-gateway, eureka-server, config-server]

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.DOCKER_REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.DOCKER_REGISTRY }}/${{ env.IMAGE_PREFIX }}/${{ matrix.service }}
          tags: |
            type=sha,prefix=
            type=ref,event=branch
            latest

      - name: Build and Push
        uses: docker/build-push-action@v6
        with:
          context: ./${{ matrix.service }}
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  # ====================================
  # Job 4: Deploy (Staging)
  # ====================================
  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    needs: docker
    if: github.ref == 'refs/heads/main'
    environment: staging

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Deploy to Staging
        run: |
          echo "Deploy to staging environment"
          # Exemplo com Docker Compose remoto:
          # ssh ${{ secrets.STAGING_HOST }} "cd /opt/foodhub && docker compose pull && docker compose up -d"
          
          # Exemplo com Kubernetes:
          # kubectl set image deployment/order-service order-service=${{ env.DOCKER_REGISTRY }}/${{ env.IMAGE_PREFIX }}/order-service:${{ github.sha }}

  # ====================================
  # Job 5: Deploy (Production) — Manual
  # ====================================
  deploy-prod:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: deploy-staging
    if: github.ref == 'refs/heads/main'
    environment: production  # Requer aprovação manual no GitHub

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Deploy to Production
        run: |
          echo "Deploy to production environment"
          # Mesmo padrão do staging, mas com variáveis de produção
```

---

## 9.3 Entendendo o Pipeline

### Fluxo visual

```
Push para main
    │
    ▼
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│   Test   │────▶│ Quality  │     │  Docker  │────▶│ Deploy   │
│ (3 jobs) │     │ (3 jobs) │     │ (6 jobs) │     │ Staging  │
│ parallel │     │ parallel │     │ parallel │     │          │
└──────────┘     └──────────┘     └──────────┘     └────┬─────┘
                                                        │ aprovação
                                                        ▼
                                                   ┌──────────┐
                                                   │ Deploy   │
                                                   │ Prod     │
                                                   └──────────┘
```

### Matrix Strategy

```yaml
strategy:
  matrix:
    service: [order-service, restaurant-service, payment-service]
```

Isso cria **3 jobs paralelos** — um para cada serviço. Sem matrix, teríamos que duplicar o job manualmente.

---

## 9.4 JaCoCo — Cobertura de Testes

Adicione ao `pom.xml` de cada microserviço:

```xml
<plugin>
    <groupId>org.jacoco</groupId>
    <artifactId>jacoco-maven-plugin</artifactId>
    <version>0.8.12</version>
    <executions>
        <execution>
            <id>prepare-agent</id>
            <goals>
                <goal>prepare-agent</goal>
            </goals>
        </execution>
        <execution>
            <id>report</id>
            <phase>verify</phase>
            <goals>
                <goal>report</goal>
            </goals>
        </execution>
        <execution>
            <id>check</id>
            <phase>verify</phase>
            <goals>
                <goal>check</goal>
            </goals>
            <configuration>
                <rules>
                    <rule>
                        <element>BUNDLE</element>
                        <limits>
                            <limit>
                                <counter>LINE</counter>
                                <value>COVEREDRATIO</value>
                                <minimum>0.70</minimum> <!-- 70% mínimo -->
                            </limit>
                        </limits>
                    </rule>
                </rules>
            </configuration>
        </execution>
    </executions>
</plugin>
```

Isso gera um relatório em `target/site/jacoco/index.html` e **falha o build se cobertura < 70%**. O relatório é salvo como artifact no GitHub Actions.

---

## 9.5 SpotBugs — Análise Estática

```xml
<plugin>
    <groupId>com.github.spotbugs</groupId>
    <artifactId>spotbugs-maven-plugin</artifactId>
    <version>4.8.6.6</version>
    <configuration>
        <effort>Max</effort>
        <threshold>Medium</threshold>
    </configuration>
</plugin>
```

SpotBugs detecta:
- Null pointer dereferences
- Recursos não fechados (streams, connections)
- Comparações incorretas (== em vez de .equals())
- Código morto

---

## 9.6 Secrets e Environments no GitHub

### Configurar Secrets

No repositório GitHub: **Settings → Secrets and variables → Actions**

| Secret | Valor | Usado por |
|---|---|---|
| `JWT_SECRET` | `chave-super-segura-32-chars...` | Deploy |
| `DB_PASSWORD` | Senha do banco de produção | Deploy |
| `STAGING_HOST` | `user@staging.foodhub.com` | Deploy Staging |

### Configurar Environments

**Settings → Environments**

1. **staging**: Deploy automático
2. **production**: Requer aprovação manual (adicione reviewers)

---

## 9.7 Workflow para Pull Requests

Crie `.github/workflows/pr-check.yml`:

```yaml
name: PR Checks

on:
  pull_request:
    branches: [main, develop]

jobs:
  test:
    name: Validate PR
    runs-on: ubuntu-latest

    strategy:
      matrix:
        service: [order-service, restaurant-service, payment-service]

    defaults:
      run:
        working-directory: ${{ matrix.service }}

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'
          cache: 'maven'

      - name: Compile
        run: mvn compile -B

      - name: Unit Tests
        run: mvn test -B

      - name: Integration Tests
        run: mvn verify -B -Dgroups=integration

      - name: Comment PR with Test Results
        if: always()
        uses: mikepenz/action-junit-report@v4
        with:
          report_paths: '**/target/surefire-reports/TEST-*.xml'
          check_name: Test Results (${{ matrix.service }})
```

Este workflow:
1. Roda em toda PR para main/develop
2. Compila, roda testes unitários e de integração
3. Comenta na PR com resultados dos testes

---

## 9.8 Git Flow Simplificado

```
main (produção)
  │
  ├── develop (integração)
  │     │
  │     ├── feature/add-payment-method
  │     ├── feature/add-order-tracking
  │     └── bugfix/fix-order-total
  │
  └── hotfix/critical-security-patch
```

| Branch | Trigger | Pipeline |
|---|---|---|
| `feature/*` → PR para develop | PR Check | Compile + Test |
| `develop` → PR para main | PR Check + CI | Compile + Test + Quality |
| Push para `main` | CI/CD completo | Test → Quality → Docker → Deploy Staging → Deploy Prod |

---

## 9.9 Cache de Dependências Maven

O `actions/setup-java@v4` com `cache: 'maven'` cacheia automaticamente o `~/.m2/repository`. Na segunda execução, o download de dependências pula.

**Impacto real:**
- Primeira execução: ~3min (download de dependências)
- Execuções seguintes: ~30s (cache hit)

---

## 9.10 Resumo

| Arquivo | Função |
|---|---|
| `.github/workflows/ci.yml` | Pipeline principal: test → quality → docker → deploy |
| `.github/workflows/pr-check.yml` | Validação de PRs: compile + test |
| JaCoCo plugin (`pom.xml`) | Cobertura de testes (mínimo 70%) |
| SpotBugs plugin (`pom.xml`) | Análise estática de bugs |
| GitHub Environments | Staging (auto) + Production (manual approval) |
| GitHub Secrets | JWT_SECRET, DB_PASSWORD, etc. |

### Pipeline em números

| Etapa | Tempo aprox. |
|---|---|
| Checkout + Setup JDK | 15s |
| Download dependências (cache miss) | 3min |
| Download dependências (cache hit) | 5s |
| Compile | 15s |
| Testes unitários | 10s |
| Testes integração (Testcontainers) | 2min |
| Build Docker image | 1min |
| Push Docker image | 30s |
| **Total (cache hit)** | **~4min** |

---

## 💼 Perguntas frequentes em entrevistas

1. **"Diferença entre CI e CD"** — CI (Continuous Integration): todo push dispara build + testes automaticamente, feedback em minutos. CD (Delivery): artefato sempre pronto para deploy manual. CD (Deploy): deploy automático em produção sem intervenção humana.

2. **"Como rodar testes com banco de dados no CI?"** — Testcontainers + Docker-in-Docker (DinD). O CI roda o Docker daemon, Testcontainers sobe containers PostgreSQL/Kafka durante os testes. Idêntico ao ambiente de produção — sem H2 em memória.

3. **"O que é JaCoCo e como funciona?"** — Java Code Coverage Agent. Instrumenta o bytecode durante os testes e gera relatório de quais linhas/branches foram executadas. Configure threshold mínimo (ex: 80%) para o build falhar se a cobertura cair.

4. **"GitHub Actions vs Jenkins — quando usar cada um?"** — GitHub Actions: SaaS, zero infraestrutura, integração nativa com GitHub, YAML declarativo. Jenkins: self-hosted, máximo controle, plugins extensivos, pipeline as code (Jenkinsfile). Para projetos no GitHub, Actions é mais simples.

5. **"O que são GitHub Environments e protection rules?"** — Environments (staging, production) permitem variáveis/secrets por ambiente e **required reviewers** — deploy em prod só acontece após aprovação manual. Essencial para compliance e auditoria.

> **Próximo passo:** [Fase 10 — Observabilidade](fase-10-observabilidade.md) — Actuator, Micrometer, Prometheus, Grafana e preparação para cloud.
