<#
.SYNOPSIS
    Prepara o ambiente de desenvolvimento do FoodHub Order Service.

.DESCRIPTION
    - Para o PostgreSQL local (se estiver rodando) para liberar a porta 5432
    - Inicia o container Docker foodhub-postgres
    - Configura as variáveis de ambiente (JAVA_HOME, MAVEN_HOME, PATH)

.EXAMPLE
    .\dev-env.ps1           # Inicia o ambiente
    .\dev-env.ps1 -Stop     # Para o container e restaura o PostgreSQL local
#>
param(
    [switch]$Stop
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "`n[DEV-ENV] $msg" -ForegroundColor Cyan }

# ============================================================
# STOP MODE: desliga o container e restaura o PG local
# ============================================================
if ($Stop) {
    Write-Step "Parando container foodhub-postgres..."
    docker stop foodhub-postgres 2>$null
    Write-Host "  Container parado." -ForegroundColor Green

    Write-Step "Restaurando servico PostgreSQL local..."
    $pgService = Get-Service -Name "postgresql*" -ErrorAction SilentlyContinue
    if ($pgService -and $pgService.Status -ne 'Running') {
        Start-Process powershell -Verb RunAs -ArgumentList '-Command', "Start-Service $($pgService.Name)" -Wait
        Write-Host "  Servico $($pgService.Name) iniciado." -ForegroundColor Green
    } else {
        Write-Host "  Nenhum servico PostgreSQL local encontrado ou ja esta rodando." -ForegroundColor Yellow
    }
    return
}

# ============================================================
# START MODE
# ============================================================

# 1. Para o PostgreSQL local se estiver rodando (libera porta 5432)
Write-Step "Verificando PostgreSQL local..."
$pgService = Get-Service -Name "postgresql*" -ErrorAction SilentlyContinue
if ($pgService -and $pgService.Status -eq 'Running') {
    Write-Host "  PostgreSQL local detectado: $($pgService.DisplayName) [Running]" -ForegroundColor Yellow
    Write-Host "  Parando servico (requer permissao de admin)..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList '-Command', "Stop-Service $($pgService.Name)" -Wait
    Start-Sleep -Seconds 2

    $pgService = Get-Service -Name "postgresql*"
    if ($pgService.Status -eq 'Stopped') {
        Write-Host "  Servico parado com sucesso." -ForegroundColor Green
    } else {
        Write-Host "  AVISO: Servico ainda rodando. A porta 5432 pode estar em conflito." -ForegroundColor Red
    }
} else {
    Write-Host "  Nenhum PostgreSQL local rodando." -ForegroundColor Green
}

# 2. Inicia o container Docker
Write-Step "Verificando container foodhub-postgres..."
$container = docker ps -a --filter "name=foodhub-postgres" --format "{{.Status}}" 2>$null

if (-not $container) {
    Write-Host "  Container nao existe. Criando..." -ForegroundColor Yellow
    docker run -d `
        --name foodhub-postgres `
        -p 5432:5432 `
        -e POSTGRES_USER=foodhub `
        -e POSTGRES_PASSWORD=foodhub123 `
        -e POSTGRES_DB=foodhub_orders `
        -v foodhub-pgdata:/var/lib/postgresql/data `
        postgres:16-alpine | Out-Null
    Write-Host "  Container criado e iniciado." -ForegroundColor Green
} elseif ($container -like "Up*") {
    Write-Host "  Container ja esta rodando." -ForegroundColor Green
} else {
    Write-Host "  Container existe mas esta parado. Iniciando..." -ForegroundColor Yellow
    docker start foodhub-postgres | Out-Null
    Write-Host "  Container iniciado." -ForegroundColor Green
}

# Aguarda o PostgreSQL aceitar conexoes
Write-Host "  Aguardando PostgreSQL aceitar conexoes..." -ForegroundColor Yellow
$maxRetries = 10
for ($i = 1; $i -le $maxRetries; $i++) {
    $result = docker exec foodhub-postgres pg_isready -U foodhub 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  PostgreSQL pronto!" -ForegroundColor Green
        break
    }
    if ($i -eq $maxRetries) {
        Write-Host "  AVISO: PostgreSQL nao respondeu apos $maxRetries tentativas." -ForegroundColor Red
    }
    Start-Sleep -Seconds 1
}

# 3. Configura variaveis de ambiente
Write-Step "Configurando variaveis de ambiente..."
$env:JAVA_HOME = "C:\Program Files\Microsoft\jdk-21.0.10.7-hotspot"
$env:MAVEN_HOME = [Environment]::GetEnvironmentVariable("MAVEN_HOME", "User")
$env:Path = [Environment]::GetEnvironmentVariable("Path", "User") + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")

Write-Host "  JAVA_HOME = $env:JAVA_HOME" -ForegroundColor Gray
Write-Host "  MAVEN_HOME = $env:MAVEN_HOME" -ForegroundColor Gray

# 4. Resumo
Write-Step "Ambiente pronto!"
Write-Host ""
Write-Host "  Comandos uteis:" -ForegroundColor White
Write-Host "    cd backend; mvn spring-boot:run `"-Dspring-boot.run.profiles=dev`"" -ForegroundColor Gray
Write-Host "    .\dev-env.ps1 -Stop    # Para o ambiente e restaura PG local" -ForegroundColor Gray
Write-Host ""
