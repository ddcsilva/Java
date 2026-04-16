# Fase 03 — Segurança: Spring Security 6 + JWT

> **Objetivo:** Implementar autenticação stateless com JWT, autorização baseada em roles, filtro de segurança customizado e proteção de endpoints. Ao final desta fase, o order-service terá controle de acesso completo.

### 🎯 O que você vai aprender nesta fase

- Diferença entre **autenticação** e **autorização**
- Estrutura interna de um **JWT** (header, payload, signature)
- Criar e validar tokens com **JJWT 0.12.x**
- Implementar um **filtro de segurança** (`OncePerRequestFilter`)
- Configurar `SecurityFilterChain` no **Spring Security 6** (nova API)
- Usar `@PreAuthorize` para **autorização a nível de método**
- Entender por que **CSRF é desabilitado** em APIs stateless
- Configurar **CORS** para frontend

---

## 3.1 Conceitos Fundamentais

### Autenticação vs Autorização

| Conceito | Pergunta | Exemplo |
|---|---|---|
| **Autenticação** (AuthN) | "Quem é você?" | Login com email/senha → recebe JWT |
| **Autorização** (AuthZ) | "O que você pode fazer?" | ROLE_ADMIN pode deletar; ROLE_USER só consulta |

### Por que JWT em microserviços?

Em monolitos, a sessão fica no servidor (HttpSession). Em microserviços, sessionless é essencial:
- Cada serviço é independente — não há sessão compartilhada
- JWT é **auto-contido**: carrega user ID, roles e expiração dentro do token
- Qualquer serviço pode validar o token sem consultar um banco central
- Escalabilidade horizontal: load balancer envia requests para qualquer instância

### Estrutura de um JWT

```
eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIiwicm9sZXMiOiJVU0VSIn0.abc123
|_______ Header ________|.| _____________ Payload ______________|.| Sig |
```

| Parte | Conteúdo |
|---|---|
| **Header** | Algoritmo (`HS256`) e tipo (`JWT`) |
| **Payload** | Claims: `sub` (subject/userId), `roles`, `iat`, `exp` |
| **Signature** | HMAC-SHA256 do header+payload com uma secret key |

---

## 3.2 Dependências de Segurança

Adicione ao `pom.xml` do order-service:

```xml
<!-- ===== SEGURANÇA ===== -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-security</artifactId>
</dependency>

<!-- JJWT: biblioteca para criar e validar JWTs -->
<dependency>
    <groupId>io.jsonwebtoken</groupId>
    <artifactId>jjwt-api</artifactId>
    <version>0.12.6</version>
</dependency>
<dependency>
    <groupId>io.jsonwebtoken</groupId>
    <artifactId>jjwt-impl</artifactId>
    <version>0.12.6</version>
    <scope>runtime</scope>
</dependency>
<dependency>
    <groupId>io.jsonwebtoken</groupId>
    <artifactId>jjwt-jackson</artifactId>
    <version>0.12.6</version>
    <scope>runtime</scope>
</dependency>
```

> **Por que JJWT e não Spring Security OAuth2?** — O `spring-boot-starter-oauth2-resource-server` é mais completo e integrado, mas JJWT dá controle total e é muito pedido em entrevistas. Na prática enterprise, muitas empresas usam JJWT diretamente. Ambos são válidos.

---

## 3.3 Configuração de Segurança no application.yml

```yaml
app:
  security:
    jwt:
      # Secret key para HS256 — deve ter no mínimo 256 bits (32 bytes)
      # Em produção: use variável de ambiente ou Spring Cloud Config
      secret-key: ${JWT_SECRET:minha-chave-secreta-super-segura-com-pelo-menos-32-caracteres}
      expiration-ms: 3600000  # 1 hora
```

> **SEGURANÇA:** Nunca comite a secret key real no repositório. Use `${JWT_SECRET}` que lê da variável de ambiente. O valor após `:` é o fallback para desenvolvimento local.

---

## 3.4 Propriedades de Segurança (Config Tipada)

```java
package com.foodhub.order.adapter.in.web.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app.security.jwt")
public record JwtProperties(
    String secretKey,
    long expirationMs
) {}
```

Habilitar no `OrderServiceApplication`:

```java
@SpringBootApplication
@EnableConfigurationProperties(JwtProperties.class)
public class OrderServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(OrderServiceApplication.class, args);
    }
}
```

> **Record como @ConfigurationProperties:** Spring Boot 3.x suporta nativamente usando constructor binding (que é automático para records).

---

## 3.5 JwtService — Geração e Validação de Tokens

```java
package com.foodhub.order.adapter.in.web.security;

import com.foodhub.order.adapter.in.web.config.JwtProperties;
import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

@Service
@RequiredArgsConstructor
public class JwtService {

    private final JwtProperties jwtProperties;

    /**
     * Gera um JWT com userId e role no payload.
     */
    public String generateToken(Long userId, String role) {
        Date now = new Date();
        Date expiration = new Date(now.getTime() + jwtProperties.expirationMs());

        return Jwts.builder()
                .subject(String.valueOf(userId))
                .claim("role", role)
                .issuedAt(now)
                .expiration(expiration)
                .signWith(getSigningKey())
                .compact();
    }

    /**
     * Extrai o userId (subject) do token.
     */
    public Long extractUserId(String token) {
        Claims claims = extractAllClaims(token);
        return Long.parseLong(claims.getSubject());
    }

    /**
     * Extrai a role do token.
     */
    public String extractRole(String token) {
        Claims claims = extractAllClaims(token);
        return claims.get("role", String.class);
    }

    /**
     * Valida o token: assinatura e expiração.
     * Retorna true se válido, false caso contrário.
     */
    public boolean isTokenValid(String token) {
        try {
            extractAllClaims(token);
            return true;
        } catch (JwtException | IllegalArgumentException e) {
            return false;
        }
    }

    private Claims extractAllClaims(String token) {
        return Jwts.parser()
                .verifyWith(getSigningKey())
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }

    private SecretKey getSigningKey() {
        byte[] keyBytes = jwtProperties.secretKey().getBytes(StandardCharsets.UTF_8);
        return Keys.hmacShaKeyFor(keyBytes);
    }
}
```

### Explicação detalhada

1. **`generateToken()`** — Cria um JWT com:
   - `subject` = userId (quem está autenticado)
   - `claim("role")` = role do usuário (ADMIN, USER, RESTAURANT)
   - `issuedAt` = quando foi criado
   - `expiration` = quando expira
   - `signWith` = assinatura HMAC com a secret key

2. **`isTokenValid()`** — O JJWT verifica automaticamente:
   - A assinatura é válida? (não foi adulterado)
   - O token expirou? (compara `exp` com `now`)
   - Se qualquer verificação falhar, lança `JwtException`

3. **`getSigningKey()`** — Converte a string da secret key em `SecretKey`. O método `Keys.hmacShaKeyFor()` valida que a chave tem tamanho suficiente para HMAC-SHA256.

---

## 3.6 JwtAuthenticationFilter

```java
package com.foodhub.order.adapter.in.web.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.lang.NonNull;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

/**
 * Filtro que intercepta TODAS as requests, extrai o JWT do header Authorization,
 * valida, e popula o SecurityContext com o usuário autenticado.
 */
@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private static final String BEARER_PREFIX = "Bearer ";

    private final JwtService jwtService;

    @Override
    protected void doFilterInternal(
            @NonNull HttpServletRequest request,
            @NonNull HttpServletResponse response,
            @NonNull FilterChain filterChain) throws ServletException, IOException {

        String authHeader = request.getHeader("Authorization");

        if (authHeader == null || !authHeader.startsWith(BEARER_PREFIX)) {
            filterChain.doFilter(request, response);
            return;
        }

        String token = authHeader.substring(BEARER_PREFIX.length());

        // 4. Valida o token
        if (jwtService.isTokenValid(token)) {
            Long userId = jwtService.extractUserId(token);
            String role = jwtService.extractRole(token);

            // 5. Cria o Authentication e popula o SecurityContext
            UsernamePasswordAuthenticationToken authentication =
                    new UsernamePasswordAuthenticationToken(
                            userId,                                          // principal
                            null,                                            // credentials (não precisa para JWT)
                            List.of(new SimpleGrantedAuthority("ROLE_" + role)) // authorities
                    );

            SecurityContextHolder.getContext().setAuthentication(authentication);
        }

        // 6. Continua a cadeia de filtros
        filterChain.doFilter(request, response);
    }
}
```

### Fluxo de uma request autenticada

```
Request → JwtAuthenticationFilter → SecurityFilterChain → Controller
         ↓
    1. Extrai "Bearer xxx" do header
    2. Valida assinatura + expiração
    3. Extrai userId + role
    4. Cria Authentication no SecurityContext
         ↓
    Controller pode acessar via:
    - @AuthenticationPrincipal Long userId
    - SecurityContextHolder.getContext().getAuthentication()
```

---

## 3.7 SecurityConfig — Configuração do Spring Security 6

```java
package com.foodhub.order.adapter.in.web.security;

import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity // Habilita @PreAuthorize nos controllers
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtAuthenticationFilter;

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        return http
            // CSRF desabilitado: APIs stateless com JWT não precisam de CSRF
            // (CSRF protege contra formulários HTML, não APIs REST)
            .csrf(csrf -> csrf.disable())

            // Desabilita sessão HTTP (stateless)
            .sessionManagement(session ->
                session.sessionCreationPolicy(SessionCreationPolicy.STATELESS)
            )

            // Regras de autorização por endpoint
            .authorizeHttpRequests(auth -> auth
                // Endpoints públicos (sem autenticação)
                .requestMatchers("/api/auth/**").permitAll()
                .requestMatchers("/actuator/health").permitAll()
                .requestMatchers("/swagger-ui/**", "/v3/api-docs/**").permitAll()

                // Endpoints por role
                .requestMatchers(HttpMethod.POST, "/api/orders").hasAnyRole("USER", "ADMIN")
                .requestMatchers(HttpMethod.PATCH, "/api/orders/*/status").hasAnyRole("RESTAURANT", "ADMIN")
                .requestMatchers(HttpMethod.GET, "/api/orders/**").authenticated()

                // Qualquer outra request precisa de autenticação
                .anyRequest().authenticated()
            )

            // Adiciona o filtro JWT ANTES do filtro padrão do Spring Security
            .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class)

            .build();
    }
}
```

### Explicação das regras

| Endpoint | Acesso | Justificativa |
|---|---|---|
| `POST /api/auth/**` | Público | Login/registro (ainda não tem token) |
| `GET /actuator/health` | Público | Health check do load balancer/Kubernetes |
| `GET /swagger-ui/**` | Público | Documentação (pode proteger em prod) |
| `POST /api/orders` | USER ou ADMIN | Criar pedido |
| `PATCH /api/orders/*/status` | RESTAURANT ou ADMIN | Restaurante atualiza status |
| `GET /api/orders/**` | Autenticado | Qualquer usuário logado pode ver pedidos |

### Por que desabilitar CSRF?

CSRF (Cross-Site Request Forgery) é um ataque onde um site malicioso envia uma request usando os cookies do usuário para outro site. A proteção CSRF exige um token sincronizado entre frontend e backend.

**APIs REST com JWT não precisam de CSRF porque:**
1. O JWT é enviado no header `Authorization`, não em cookies
2. Um site malicioso não consegue adicionar headers customizados a requests cross-origin (CORS impede)
3. A proteção CSRF é projetada para formulários HTML (que usam cookies automaticamente)

---

## 3.8 Endpoint de Autenticação (Simplificado)

Para este projeto, criamos um endpoint simplificado que gera tokens. Em produção, haveria um **auth-service** dedicado com tabelas de usuários, bcrypt para senhas, refresh tokens, etc.

```java
package com.foodhub.order.adapter.in.web.controller;

import com.foodhub.order.adapter.in.web.security.JwtService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final JwtService jwtService;

    /**
     * Endpoint simplificado para gerar tokens de teste.
     * Em produção, isso consultaria a tabela de usuários + verificaria senha com BCrypt.
     */
    @PostMapping("/token")
    public ResponseEntity<TokenResponse> generateToken(@Valid @RequestBody TokenRequest request) {
        String token = jwtService.generateToken(request.userId(), request.role());
        return ResponseEntity.ok(new TokenResponse(token));
    }

    public record TokenRequest(
        @NotNull Long userId,
        @NotBlank String role
    ) {}

    public record TokenResponse(String token) {}
}
```

> **⚠️ ATENÇÃO — NUNCA USE ESTE ENDPOINT EM PRODUÇÃO!** Este endpoint gera tokens para qualquer userId e role sem verificar credenciais. Qualquer pessoa pode se autenticar como ADMIN. Ele existe **exclusivamente** para facilitar o desenvolvimento e os testes desta fase. Em um sistema real, você teria:
> 1. Tabela `users` com email, senha (hash BCrypt) e roles
> 2. Endpoint `POST /api/auth/login` que recebe email + senha
> 3. Verificação com `BCryptPasswordEncoder.matches()`
> 4. Geração do token somente após autenticação bem-sucedida
> 
> Se quiser adicionar autenticação real ao projeto, crie um `auth-service` dedicado como exercício extra.
```

### Testando a autenticação

```bash
# 1. Gerar token (endpoint público)
TOKEN=$(curl -s -X POST http://localhost:8081/api/auth/token \
  -H "Content-Type: application/json" \
  -d '{"userId": 1, "role": "USER"}' | jq -r '.token')

echo $TOKEN

# 2. Criar pedido com token
curl -X POST http://localhost:8081/api/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "customerId": 1,
    "restaurantId": 1,
    "items": [
      {"menuItemId": 101, "menuItemName": "Pizza Margherita", "quantity": 2, "unitPrice": 35.90}
    ]
  }'

# 3. Tentar sem token (deve retornar 401)
curl -v -X POST http://localhost:8081/api/orders \
  -H "Content-Type: application/json" \
  -d '{"customerId": 1, "restaurantId": 1, "items": [...]}'

# 4. Tentar com role errada (RESTAURANT tentando criar pedido → 403)
RESTAURANT_TOKEN=$(curl -s -X POST http://localhost:8081/api/auth/token \
  -H "Content-Type: application/json" \
  -d '{"userId": 100, "role": "RESTAURANT"}' | jq -r '.token')

curl -v -X POST http://localhost:8081/api/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $RESTAURANT_TOKEN" \
  -d '{"customerId": 1, "restaurantId": 1, "items": [...]}'
# → 403 Forbidden (RESTAURANT não tem ROLE_USER nem ROLE_ADMIN)
```

---

## 3.9 Segurança a Nível de Método com @PreAuthorize

`@EnableMethodSecurity` na `SecurityConfig` habilita anotações nos controllers/services:

```java
@RestController
@RequestMapping("/api/admin/orders")
@RequiredArgsConstructor
public class AdminOrderController {

    private final OrderApplicationService orderService;

    @GetMapping
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Page<OrderResponse>> listAllOrders(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size) {
        PageRequest pageRequest = PageRequest.of(page, size, Sort.by("createdAt").descending());
        return ResponseEntity.ok(orderService.listOrders(pageRequest));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Void> deleteOrder(@PathVariable Long id) {
        orderService.deleteOrder(id);
        return ResponseEntity.noContent().build();
    }
}
```

### @PreAuthorize vs Regras no SecurityFilterChain

| Abordagem | Quando usar |
|---|---|
| `SecurityFilterChain` (URL-based) | Regras gerais: todo `/api/admin/**` requer ADMIN |
| `@PreAuthorize` (Method-based) | Regras específicas: apenas este método requer permissão extra |

Na prática, use **ambos**: regras gerais na SecurityFilterChain, refinamentos com @PreAuthorize.

---

## 3.10 Extraindo o Usuário Autenticado

```java
@GetMapping("/my-orders")
public ResponseEntity<Page<OrderResponse>> myOrders(
        @AuthenticationPrincipal Long userId,  // Extrai o principal diretamente
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = DEFAULT_PAGE_SIZE) int size) {
    PageRequest pageRequest = PageRequest.of(page, size, Sort.by("createdAt").descending());
    return ResponseEntity.ok(orderService.listOrdersByCustomer(userId, pageRequest));
}
```

O `@AuthenticationPrincipal` extrai o `principal` do `SecurityContext`, que nós setamos no `JwtAuthenticationFilter` como o `userId`.

---

## 3.11 Exception Handler para Erros de Segurança

Adicione ao `GlobalExceptionHandler`:

```java
@ExceptionHandler(org.springframework.security.access.AccessDeniedException.class)
public ProblemDetail handleAccessDenied(AccessDeniedException ex) {
    ProblemDetail problem = ProblemDetail.forStatusAndDetail(
        HttpStatus.FORBIDDEN, "Você não tem permissão para acessar este recurso"
    );
    problem.setTitle("Acesso negado");
    problem.setType(URI.create("https://foodhub.com/errors/forbidden"));
    problem.setProperty("timestamp", Instant.now());
    return problem;
}
```

---

## 3.12 CORS (Cross-Origin Resource Sharing)

Se o frontend (React, Angular) roda em domínio diferente:

```java
@Bean
public CorsConfigurationSource corsConfigurationSource() {
    CorsConfiguration configuration = new CorsConfiguration();
    configuration.setAllowedOrigins(List.of("http://localhost:3000")); // Frontend
    configuration.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
    configuration.setAllowedHeaders(List.of("Authorization", "Content-Type"));
    configuration.setExposedHeaders(List.of("Authorization"));
    configuration.setMaxAge(3600L);

    UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/api/**", configuration);
    return source;
}
```

E adicione CORS na SecurityFilterChain:

```java
http.cors(cors -> cors.configurationSource(corsConfigurationSource()))
```

---

## 3.13 Checklist de Segurança

| Item | Status | Observação |
|---|---|---|
| JWT com HMAC-SHA256 | ✅ | Assinatura com secret key |
| Token expira em 1 hora | ✅ | Configurável via properties |
| Secret key via variável de ambiente | ✅ | `${JWT_SECRET}` |
| CSRF desabilitado (API stateless) | ✅ | Justificado |
| Sessão STATELESS | ✅ | Sem HttpSession |
| Endpoints públicos definidos | ✅ | `/auth`, `/health`, `/swagger` |
| Roles por HTTP method | ✅ | POST=USER, PATCH=RESTAURANT |
| @PreAuthorize para admin | ✅ | Endpoints de administração |
| CORS configurado | ✅ | Para frontend em outro domínio |

---

## 3.14 Resumo da Fase

| Componente | Classe | Responsabilidade |
|---|---|---|
| JWT Properties | `JwtProperties` | Configuração tipada (secret, expiration) |
| JWT Service | `JwtService` | Gerar e validar tokens JWT |
| Auth Filter | `JwtAuthenticationFilter` | Interceptar requests, validar JWT |
| Security Config | `SecurityConfig` | Regras de autorização por endpoint |
| Auth Controller | `AuthController` | Endpoints de login/token |

---

## 💼 Perguntas frequentes em entrevistas

1. **"Como funciona JWT? Quais as 3 partes?"** — Header (algoritmo), Payload (claims: userId, roles, exp), Signature (HMAC-SHA256 com secret). O servidor **não armazena sessão** — toda informação está no token.

2. **"Diferença entre autenticação e autorização"** — Autenticação = "quem é você?" (JWT válido). Autorização = "o que você pode fazer?" (roles: USER, ADMIN, RESTAURANT). Spring Security trata ambos na `SecurityFilterChain`.

3. **"Por que desabilitar CSRF em APIs REST stateless?"** — CSRF protege contra requests forjados via cookies de sessão. Como APIs REST usam `Authorization: Bearer` (sem cookies), CSRF não se aplica. Desabilitar é correto e seguro neste contexto.

4. **"O que é CORS e quando é necessário?"** — Cross-Origin Resource Sharing. Necessário quando frontend (React em `localhost:3000`) e backend (Spring em `localhost:8081`) estão em origens diferentes. O browser bloqueia por padrão — CORS libera explicitamente.

5. **"Como implementar refresh tokens?"** — Access token (curta duração, ~15min) + Refresh token (longa duração, ~7d, armazenado em banco). Quando o access expira, o client envia o refresh token para obter um novo par. O refresh token pode ser revogado.

6. **"Qual a diferença entre OAuth2 e JWT?"** — Não são comparáveis diretamente. **OAuth2** é um **protocolo de autorização** (define fluxos como Authorization Code, Client Credentials). **JWT** é um **formato de token** (Header.Payload.Signature). OAuth2 pode usar JWT como formato de token. No FoodHub, usamos JWT sem OAuth2 porque é comunicação interna entre SPA e API própria. OAuth2 seria necessário se integrássemos login com Google/GitHub.

7. **"Se um JWT é comprometido, como revogar?"** — JWT é stateless — não há como "revogar" nativamente. Soluções: (1) **vida curta** (15min) + refresh token rotacionado, (2) **blacklist** de tokens revogados em Redis (verifica em cada request), (3) **versão de sessão** no banco — incrementa ao fazer logout, rejeita tokens com versão antiga. Trade-off: blacklist/versão adicionam estado, perdendo parte da vantagem stateless.

> **Próximo passo:** [Fase 04 — Mensageria](fase-04-mensageria.md) — Apache Kafka para comunicação assíncrona entre microserviços.
