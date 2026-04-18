# Guia de Inicialização do Projeto — VS Code

> Como configurar o VS Code, compilar o projeto FoodHub e debugar a aplicação Spring Boot passo a passo.

---

## Pré-requisitos

| Ferramenta | Versão Mínima | Verificação |
|---|---|---|
| JDK | 21 | `java -version` |
| Maven | 3.9+ | `mvn -version` (ou use o wrapper `mvnw`) |
| VS Code | Última estável | `code --version` |
| PostgreSQL | 15+ | `psql --version` |
| Git | 2.x | `git --version` |

### Instalando o JDK 21 (Windows)

```powershell
winget install Microsoft.OpenJDK.21
```

Após a instalação, confirme:

```powershell
java -version
# openjdk version "21.0.x" ...
```

### Instalando o Maven (opcional — projeto inclui wrapper)

O projeto inclui `mvnw` / `mvnw.cmd`, então Maven global é opcional. Caso queira instalar:

```powershell
winget install Apache.Maven
```

---

## 1. Extensões Obrigatórias

Instale as extensões abaixo no VS Code. Você pode colar os comandos no terminal:

```powershell
code --install-extension vscjava.vscode-java-pack
code --install-extension vmware.vscode-boot-dev-pack
code --install-extension vscjava.vscode-lombok
code --install-extension redhat.vscode-xml
```

| Extensão | ID | Função |
|---|---|---|
| Extension Pack for Java | `vscjava.vscode-java-pack` | Suporte Java completo (Language Support, Debugger, Test Runner, Maven, IntelliSense) |
| Spring Boot Extension Pack | `vmware.vscode-boot-dev-pack` | Spring Boot Tools, Spring Initializr, Spring Boot Dashboard |
| Lombok Annotations Support | `vscjava.vscode-lombok` | Reconhecimento de `@Getter`, `@Builder`, `@RequiredArgsConstructor`, etc. |
| XML (Red Hat) | `redhat.vscode-xml` | Autocompletar e validação em `pom.xml` |

---

## 2. Configuração do Workspace

### 2.1 Settings (`.vscode/settings.json`)

O arquivo já está configurado no projeto. Abaixo, o que cada seção faz:

```jsonc
{
  // ─── Java Runtime ───────────────────────────────────────────
  // Define o JDK usado pelo Language Server e pelo projeto
  "java.jdt.ls.java.home": "C:\\Program Files\\Microsoft\\jdk-21.0.10.7-hotspot",
  "java.configuration.runtimes": [
    {
      "name": "JavaSE-21",
      "path": "C:\\Program Files\\Microsoft\\jdk-21.0.10.7-hotspot",
      "default": true
    }
  ],

  // ─── Java Project ──────────────────────────────────────────
  // Atualiza classpath automaticamente ao editar pom.xml
  "java.configuration.updateBuildConfiguration": "automatic",
  "java.compile.nullAnalysis.mode": "automatic",
  "java.autobuild.enabled": true,
  // Organiza imports ao salvar
  "editor.codeActionsOnSave": {
    "source.organizeImports": "explicit"
  },

  // ─── Maven ─────────────────────────────────────────────────
  "maven.executable.path": "C:\\Users\\<seu-user>\\tools\\maven\\bin\\mvn.cmd",
  "maven.terminal.useJavaHome": true,

  // ─── Spring Boot Tools ─────────────────────────────────────
  "boot-java.java.reconcilers": true,

  // ─── Editor (Java) ─────────────────────────────────────────
  "[java]": {
    "editor.formatOnSave": true,
    "editor.defaultFormatter": "redhat.java"
  },

  // ─── Debug ─────────────────────────────────────────────────
  "java.debug.settings.hotCodeReplace": "auto",
  "java.debug.settings.enableRunDebugCodeLens": true,
  "java.debug.settings.console": "integratedTerminal"
}
```

> **Importante:** Ajuste os caminhos do JDK e Maven para o seu sistema. Use `where java` e `where mvn` no PowerShell para descobrir os caminhos corretos.

### 2.2 Ajustes Necessários

Ao abrir o projeto pela primeira vez, o VS Code pode levar alguns minutos para:

1. Indexar o projeto Java (veja a barra de status: "Java: Loading...")
2. Baixar dependências do Maven
3. Compilar o projeto em background

Aguarde até que a barra de status mostre apenas o ícone do Java sem indicadores de loading.

---

## 3. Compilando o Projeto

### Via terminal integrado

```powershell
cd backend
.\mvnw.cmd clean compile
```

### Via Maven Explorer (sidebar)

1. Abra a aba **Maven** na sidebar esquerda
2. Expanda `order-service` → **Lifecycle**
3. Clique duplo em `compile`

### Executando os testes

```powershell
.\mvnw.cmd test
```

### Gerando o JAR

```powershell
.\mvnw.cmd clean package -DskipTests
```

O JAR será gerado em `target/order-service-0.0.1-SNAPSHOT.jar`.

---

## 4. Executando a Aplicação

### Opção A — Spring Boot Dashboard

1. Abra a aba **Spring Boot Dashboard** na sidebar
2. O `order-service` aparecerá na lista
3. Clique no botão ▶ (play) para iniciar

### Opção B — Terminal

```powershell
cd backend
.\mvnw.cmd spring-boot:run
```

### Opção C — CodeLens (Run|Debug)

1. Abra `OrderServiceApplication.java`
2. Acima do método `main()`, clique em **Run** ou **Debug**

---

## 5. Debug — Configuração e Uso

### 5.1 Launch Configurations (`.vscode/launch.json`)

O projeto possui três configurações de debug pré-definidas:

```jsonc
{
  "version": "0.2.0",
  "configurations": [
    {
      // 1. Debug local com perfil dev
      "type": "java",
      "name": "OrderService (Debug)",
      "request": "launch",
      "mainClass": "com.foodhub.order.OrderServiceApplication",
      "projectName": "order-service",
      "vmArgs": "-Dspring.profiles.active=dev",
      "console": "integratedTerminal"
    },
    {
      // 2. Attach em app rodando remotamente (ex: Docker)
      "type": "java",
      "name": "OrderService (Remote Debug)",
      "request": "attach",
      "hostName": "localhost",
      "port": 5005,
      "projectName": "order-service"
    },
    {
      // 3. Debug do arquivo Java atualmente aberto
      "type": "java",
      "name": "Current File",
      "request": "launch",
      "mainClass": "${file}"
    }
  ]
}
```

### 5.2 Iniciando o Debug

1. Pressione `F5` ou abra **Run and Debug** (`Ctrl+Shift+D`)
2. Selecione **"OrderService (Debug)"** no dropdown
3. Clique no botão ▶ verde

A aplicação inicia com o perfil `dev` ativo.

### 5.3 Breakpoints

| Tipo | Como criar | Uso |
|---|---|---|
| **Line breakpoint** | Clique na margem esquerda (gutter) do editor | Pausa na linha exata |
| **Conditional breakpoint** | Clique direito na margem → "Add Conditional Breakpoint" | Pausa apenas quando a condição é verdadeira (ex: `orderId == 5`) |
| **Logpoint** | Clique direito na margem → "Add Logpoint" | Imprime no Debug Console sem pausar a execução |
| **Data breakpoint** | Durante debug, clique direito em variável → "Break on Value Change" | Pausa quando a variável muda de valor |
| **Exception breakpoint** | No painel "Breakpoints", marque os tipos de exceção | Pausa quando a exceção ocorre |

### 5.4 Painel de Debug

Quando o debug está ativo, você tem acesso a:

| Painel | Função |
|---|---|
| **Variables** | Valores das variáveis locais e de instância no ponto de parada |
| **Watch** | Expressões customizadas para monitorar (ex: `order.getTotal()`) |
| **Call Stack** | Pilha de chamadas — mostra como você chegou naquele ponto |
| **Breakpoints** | Lista todos os breakpoints ativos |
| **Debug Console** | Permite avaliar expressões Java em tempo real no contexto do breakpoint |

### 5.5 Controles de Navegação

| Atalho | Ação | Quando usar |
|---|---|---|
| `F5` | **Continue** | Continua a execução até o próximo breakpoint |
| `F10` | **Step Over** | Executa a linha atual sem entrar em métodos |
| `F11` | **Step Into** | Entra dentro do método chamado na linha atual |
| `Shift+F11` | **Step Out** | Sai do método atual e retorna ao chamador |
| `Ctrl+Shift+F5` | **Restart** | Reinicia a sessão de debug |
| `Shift+F5` | **Stop** | Encerra a sessão de debug |

### 5.6 Hot Code Replace (HCR)

Com a configuração `"java.debug.settings.hotCodeReplace": "auto"`, você pode:

1. Alterar código Java enquanto o debug está ativo
2. Salvar o arquivo (`Ctrl+S`)
3. O código é **automaticamente recompilado e injetado na JVM em execução**
4. Sem necessidade de reiniciar a aplicação

**Limitações do HCR:**
- Funciona para alterações dentro de métodos (corpo de métodos)
- Não funciona para mudanças estruturais (adicionar campos, métodos, alterar assinaturas)
- Requer que `java.autobuild.enabled` esteja `true`

### 5.7 Debug Remoto (Docker / Servidor)

Para debugar uma aplicação rodando em Docker ou servidor remoto:

**1. Inicie a JVM com a flag de debug:**

```bash
java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005 \
     -jar order-service-0.0.1-SNAPSHOT.jar
```

Ou no `docker-compose.yml`:

```yaml
services:
  order-service:
    environment:
      JAVA_TOOL_OPTIONS: "-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005"
    ports:
      - "5005:5005"
```

**2. No VS Code, selecione "OrderService (Remote Debug)" e pressione F5.**

O debugger se conecta à JVM remota na porta 5005. Todos os breakpoints, watch expressions e hot code replace funcionam normalmente.

---

## 6. Troubleshooting

| Problema | Solução |
|---|---|
| "Java: Loading..." não termina | Abra o Command Palette (`Ctrl+Shift+P`) → "Java: Clean Java Language Server Workspace" |
| Breakpoints não param | Verifique se o projeto compilou sem erros. Execute `.\mvnw.cmd clean compile` |
| Lombok não reconhecido | Confirme que a extensão `vscjava.vscode-lombok` está instalada e ativa |
| "Could not find or load main class" | Command Palette → "Java: Clean Java Language Server Workspace" → reinicie o VS Code |
| Hot Code Replace falha | Verifique que `java.autobuild.enabled` é `true` e que a mudança é suportada (apenas corpo de método) |
| Maven não encontrado | Confirme o caminho em `maven.executable.path` no `settings.json`, ou use o wrapper `.\mvnw.cmd` |
| Porta 8081 já em uso | `netstat -ano \| findstr :8081` para encontrar o processo, `Stop-Process -Id <PID>` para encerrar |

---

## 7. Atalhos Úteis para Desenvolvimento Java

| Atalho | Ação |
|---|---|
| `Ctrl+Shift+P` | Command Palette |
| `Ctrl+Space` | Autocompletar |
| `F12` | Ir para definição |
| `Shift+F12` | Encontrar todas as referências |
| `Ctrl+.` | Quick Fix / Ações de código |
| `Ctrl+Shift+O` | Ir para símbolo no arquivo |
| `Ctrl+T` | Ir para símbolo no workspace |
| `Alt+Shift+F` | Formatar documento |
| `Ctrl+Shift+F` | Buscar no projeto inteiro |
| `F2` | Renomear símbolo (refactoring) |

---

## Próximos Passos

Com o ambiente configurado, você está pronto para começar a implementação:

1. **[Fase 00 — Visão Geral](backend/fase-00-visao-geral.md)** — Entenda a arquitetura antes de escrever código
2. **[Fase 01 — Fundação](backend/fase-01-fundacao.md)** — Crie o CRUD funcional do order-service
