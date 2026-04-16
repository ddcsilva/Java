# Fase 06 — Documentação da API: SpringDoc OpenAPI 2 + Swagger UI

> **Objetivo:** Documentar a API REST automaticamente usando SpringDoc OpenAPI 2.x, com Swagger UI interativo, agrupamento por tags, esquema de segurança JWT, e exemplos de request/response.

---

## 🎯 O que você vai aprender nesta fase

- Configurar **SpringDoc OpenAPI 2.x** com Spring Boot 3
- Documentar endpoints com `@Operation`, `@ApiResponse`, `@Tag`
- Documentar DTOs com `@Schema` e examples realistas
- Configurar esquema de segurança **JWT** no Swagger UI
- Agrupar APIs por domínio/serviço
- Gerar **client SDKs** automaticamente a partir do spec OpenAPI

---

## 6.1 Por que Documentar a API?

- **Frontend teams** precisam saber quais endpoints existem, quais parâmetros mandar, e o formato da resposta
- **QA** usa a documentação para criar testes
- **Outros microserviços** que consomem a API precisam do contrato
- **Entrevistadores** procuram Swagger/OpenAPI como sinal de profissionalismo
- **API-First:** Pode gerar clients (TypeScript, Kotlin) automaticamente a partir do spec

---

## 6.2 Dependência

```xml
<!-- SpringDoc OpenAPI 2.x para Spring Boot 3 -->
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
    <version>2.8.6</version>
</dependency>
```

> **Importante:** Para Spring Boot 3.x, use `springdoc-openapi-starter-webmvc-ui` (versão 2.x). A versão 1.x (`springdoc-openapi-ui`) é para Spring Boot 2.x e **não funciona** com Spring Boot 3.

---

## 6.3 Configuração no application.yml

```yaml
springdoc:
  api-docs:
    path: /v3/api-docs          # Endpoint JSON do OpenAPI spec
  swagger-ui:
    path: /swagger-ui.html      # URL do Swagger UI
    operationsSorter: method    # Ordena por HTTP method
    tagsSorter: alpha           # Ordena tags alfabeticamente
    tryItOutEnabled: true       # Habilita "Try it out" por padrão
  show-actuator: false          # Não mostrar endpoints do Actuator no Swagger
```

---

## 6.4 Configuração Java do OpenAPI

```java
package com.foodhub.order.infrastructure.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.License;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI customOpenAPI() {
        final String securitySchemeName = "Bearer JWT";

        return new OpenAPI()
                .info(new Info()
                        .title("FoodHub Order Service API")
                        .description("""
                            API de gerenciamento de pedidos do FoodHub.
                            
                            ## Autenticação
                            Use o endpoint `/api/auth/token` para obter um JWT.
                            Clique em "Authorize" e insira: `Bearer <seu-token>`
                            
                            ## Status do Pedido
                            Fluxo: PENDING → CONFIRMED → PREPARING → READY → DELIVERED
                            """)
                        .version("1.0.0")
                        .contact(new Contact()
                                .name("FoodHub Team")
                                .email("dev@foodhub.com"))
                        .license(new License()
                                .name("MIT")))
                // Adiciona o botão "Authorize" no Swagger UI
                .addSecurityItem(new SecurityRequirement().addList(securitySchemeName))
                .components(new Components()
                        .addSecuritySchemes(securitySchemeName,
                                new SecurityScheme()
                                        .name(securitySchemeName)
                                        .type(SecurityScheme.Type.HTTP)
                                        .scheme("bearer")
                                        .bearerFormat("JWT")
                                        .description("Insira o token JWT obtido via /api/auth/token")));
    }
}
```

---

## 6.5 Anotações nos Controllers

### OrderController documentado

```java
package com.foodhub.order.api.controller;

import com.foodhub.order.application.dto.*;
import com.foodhub.order.application.service.OrderApplicationService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/orders")
@RequiredArgsConstructor
@Tag(name = "Pedidos", description = "Gerenciamento de pedidos do FoodHub")
public class OrderController {

    private static final String DEFAULT_PAGE_SIZE = "20";

    private final OrderApplicationService orderService;

    @Operation(
        summary = "Criar novo pedido",
        description = "Cria um pedido com status PENDING e publica evento OrderCreated no Kafka"
    )
    @ApiResponses({
        @ApiResponse(responseCode = "201", description = "Pedido criado com sucesso",
            content = @Content(schema = @Schema(implementation = OrderResponse.class))),
        @ApiResponse(responseCode = "400", description = "Dados inválidos",
            content = @Content(schema = @Schema(implementation = ProblemDetail.class))),
        @ApiResponse(responseCode = "401", description = "Não autenticado")
    })
    @PostMapping
    public ResponseEntity<OrderResponse> createOrder(
            @Valid @RequestBody CreateOrderRequest request) {
        OrderResponse response = orderService.createOrder(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @Operation(summary = "Buscar pedido por ID", description = "Retorna pedido com todos os itens (JOIN FETCH)")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "Pedido encontrado"),
        @ApiResponse(responseCode = "404", description = "Pedido não encontrado",
            content = @Content(schema = @Schema(implementation = ProblemDetail.class)))
    })
    @GetMapping("/{id}")
    public ResponseEntity<OrderResponse> getOrder(
            @Parameter(description = "ID do pedido", example = "1")
            @PathVariable Long id) {
        return ResponseEntity.ok(orderService.getOrderById(id));
    }

    @Operation(summary = "Listar pedidos", description = "Retorna pedidos paginados ordenados por data de criação decrescente")
    @GetMapping
    public ResponseEntity<Page<OrderResponse>> listOrders(
            @Parameter(description = "Número da página (0-based)", example = "0")
            @RequestParam(defaultValue = "0") int page,
            @Parameter(description = "Tamanho da página", example = "20")
            @RequestParam(defaultValue = DEFAULT_PAGE_SIZE) int size) {
        PageRequest pageRequest = PageRequest.of(page, size, Sort.by("createdAt").descending());
        return ResponseEntity.ok(orderService.listOrders(pageRequest));
    }

    @Operation(
        summary = "Atualizar status do pedido",
        description = """
            Atualiza o status seguindo a máquina de estados:
            PENDING → CONFIRMED → PREPARING → READY → DELIVERED
            Cancelamento possível em: PENDING, CONFIRMED, PREPARING
            """
    )
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "Status atualizado"),
        @ApiResponse(responseCode = "404", description = "Pedido não encontrado"),
        @ApiResponse(responseCode = "409", description = "Transição de status inválida")
    })
    @PatchMapping("/{id}/status")
    public ResponseEntity<OrderResponse> updateStatus(
            @PathVariable Long id,
            @Valid @RequestBody UpdateOrderStatusRequest request) {
        return ResponseEntity.ok(orderService.updateOrderStatus(id, request));
    }
}
```

---

## 6.6 Anotações nos DTOs

```java
package com.foodhub.order.application.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.util.List;

@Schema(description = "Dados para criação de um novo pedido")
public record CreateOrderRequest(
    @Schema(description = "ID do cliente", example = "1")
    @NotNull(message = "customerId é obrigatório")
    Long customerId,

    @Schema(description = "ID do restaurante", example = "1")
    @NotNull(message = "restaurantId é obrigatório")
    Long restaurantId,

    @Schema(description = "Lista de itens do pedido (mínimo 1)")
    @NotEmpty(message = "O pedido deve ter ao menos um item")
    @Valid
    List<OrderItemRequest> items
) {}
```

```java
@Schema(description = "Item do pedido")
public record OrderItemRequest(
    @Schema(description = "ID do item no cardápio", example = "101")
    @NotNull Long menuItemId,

    @Schema(description = "Nome do item (snapshot)", example = "Pizza Margherita")
    @NotBlank String menuItemName,

    @Schema(description = "Quantidade", example = "2", minimum = "1")
    @NotNull @Positive Integer quantity,

    @Schema(description = "Preço unitário em BRL", example = "35.90")
    @NotNull @Positive BigDecimal unitPrice
) {}
```

---

## 6.7 Acessando o Swagger UI

Após iniciar a aplicação:

| Recurso | URL |
|---|---|
| Swagger UI | http://localhost:8081/swagger-ui.html |
| OpenAPI JSON | http://localhost:8081/v3/api-docs |
| OpenAPI YAML | http://localhost:8081/v3/api-docs.yaml |

### Usando o Swagger UI

1. Acesse http://localhost:8081/swagger-ui.html
2. Clique em **Authorize** (ícone de cadeado)
3. No campo, insira: `Bearer <seu-token-jwt>`
4. Clique em **Authorize** → **Close**
5. Agora todos os endpoints enviam o token automaticamente
6. Clique em **Try it out** em qualquer endpoint para testar

---

## 6.8 Agrupando APIs (Múltiplos Serviços)

Se quiser separar a documentação em grupos:

```yaml
springdoc:
  group-configs:
    - group: orders
      display-name: Pedidos
      paths-to-match: /api/orders/**
    - group: auth
      display-name: Autenticação
      paths-to-match: /api/auth/**
```

Cada grupo aparece como um dropdown no Swagger UI.

---

## 6.9 Liberar Swagger no Spring Security

Já fizemos isso na Fase 03, mas recapitulando — na `SecurityConfig`:

```java
.requestMatchers("/swagger-ui/**", "/v3/api-docs/**").permitAll()
```

Sem isso, o Swagger UI retorna 401/403.

---

## 6.10 Gerando Client SDKs (Bônus)

Com o spec OpenAPI em mãos, é possível gerar clients automaticamente:

```bash
# Gerar client TypeScript para o frontend
npx @openapitools/openapi-generator-cli generate \
  -i http://localhost:8081/v3/api-docs \
  -g typescript-axios \
  -o generated-client/

# Gerar client Kotlin
npx @openapitools/openapi-generator-cli generate \
  -i http://localhost:8081/v3/api-docs \
  -g kotlin \
  -o generated-client-kotlin/
```

---

## 6.11 Resumo

| Configuração | Arquivo |
|---|---|
| Dependência Maven | `pom.xml` — `springdoc-openapi-starter-webmvc-ui:2.8.6` |
| Config YAML | `application.yml` — seção `springdoc` |
| Config Java | `OpenApiConfig` — Info, segurança JWT, descrição |
| Anotações controller | `@Operation`, `@ApiResponse`, `@Tag` |
| Anotações DTO | `@Schema` com examples |
| Segurança | Endpoints do Swagger liberados no SecurityFilterChain |

---

## 💼 Perguntas frequentes em entrevistas

1. **"Diferença entre Swagger e OpenAPI"** — OpenAPI é a **especificação** (padrão da indústria para descrever APIs REST). Swagger é o **ecossistema de ferramentas** (Swagger UI, Swagger Editor, Codegen). SpringDoc gera a spec OpenAPI automaticamente a partir das anotações.

2. **"Por que documentar APIs?"** — Contrato entre frontend e backend, facilita onboarding de novos devs, permite gerar client SDKs automaticamente, serve como testes exploratórios via Swagger UI. Em empresas enterprise, é requisito obrigatório.

3. **"O que é API-First?"** — Abordagem onde o contrato OpenAPI é definido **antes** da implementação. O spec vira a source of truth. Permite que frontend e backend trabalhem em paralelo.

> **Próximo passo:** [Fase 07 — Docker](fase-07-docker.md) — Containerização e Docker Compose com todos os serviços.
