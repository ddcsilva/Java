# 📚 FoodHub — Documentação

> Documentação completa do projeto FoodHub — backend (Java Spring Boot) e frontend (React).

---

## Estrutura

```
docs/
├── backend/                         ← Microserviços Java Spring Boot (11 fases)
├── frontend/                        ← SPA React + TypeScript (11 fases)
├── guia-inicializacao-vscode.md     ← Setup do VS Code + Debug
└── README.md                        ← Este arquivo
```

---

## 🚀 Começando

Antes de mergulhar nas fases, configure seu ambiente de desenvolvimento:

📖 **[Guia de Inicialização — VS Code →](guia-inicializacao-vscode.md)**

> Extensões, configuração, compilação, execução e debug completo.

---

## Backend — Java Spring Boot

Microserviços com arquitetura hexagonal, Spring Boot 3, PostgreSQL, Kafka, Docker e CI/CD.

📖 **[Ir para a documentação do backend →](backend/README.md)**

| Fase | Tema |
|---|---|
| 00 | Visão geral, arquitetura hexagonal, stack |
| 01 | Fundação do order-service |
| 02 | Persistência (JPA, Flyway) |
| 03 | Segurança (JWT, Spring Security) |
| 04 | Mensageria (Kafka) |
| 05 | Testes (JUnit, Testcontainers) |
| 06 | Documentação API (OpenAPI) |
| 07 | Docker (multi-stage, Compose) |
| 08 | Spring Cloud (Gateway, Eureka) |
| 09 | CI/CD (GitHub Actions) |
| 10 | Observabilidade (Prometheus, Grafana) |

---

## Frontend — React

SPA com React 19, TypeScript, Vite, Tailwind CSS, TanStack Query e Feature-Sliced Design.

📖 **[Ir para a documentação do frontend →](frontend/README.md)**

| Fase | Tema |
|---|---|
| 00 | Visão geral, stack, arquitetura FSD |
| 01 | Fundação (Vite + React + TS) |
| 02 | Componentes e estilização |
| 03 | Roteamento (React Router) |
| 04 | Estado global (Zustand) |
| 05 | Integração API (Axios + TanStack Query) |
| 06 | Autenticação (JWT) |
| 07 | Formulários (React Hook Form + Zod) |
| 08 | Testes (Vitest + Testing Library) |
| 09 | Performance |
| 10 | Build, Docker e CI/CD |

---

## Como usar

1. Comece pelo **backend** ou **frontend** — são independentes
2. Leia a **Fase 00** de cada um para entender a visão geral
3. Siga as fases em ordem numérica (00 → 01 → ... → 10)
4. Cada fase tem: conceitos, código, tabelas de referência e perguntas de entrevista
