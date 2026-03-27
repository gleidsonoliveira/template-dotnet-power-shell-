# ============================================================
# Create-ProjectStructure.ps1
# Gerado pelo GitHub Copilot via prompt copilot-analyze-structure
#
# USO:
#   .\Create-ProjectStructure.ps1 -SolutionName "MinhaApi" -OutputPath "C:\Dev\Projetos"
#
# PARAMETROS:
#   -SolutionName  Nome da solution e prefixo de todos os projetos
#   -OutputPath    Pasta onde a solution será criada (default: pasta atual)
#   -DotnetVersion Versão alvo: net6.0 | net7.0 | net8.0 | net9.0 | net10.0
#   -ProjectType   webapi | mvc | worker | lambda
#   -Orm           efcore | dapper | none
#   -Database      sqlserver | postgresql | sqlite
#   -UseDocker     $true | $false
# ============================================================

param(
    [string]$SolutionName  = "MinhaSolucao",
    [string]$OutputPath    = ".",
    [ValidateSet("net6.0","net7.0","net8.0","net9.0","net10.0")]
    [string]$DotnetVersion = "net8.0",
    [ValidateSet("webapi","mvc","worker","lambda")]
    [string]$ProjectType   = "webapi",
    [ValidateSet("efcore","dapper","none")]
    [string]$Orm           = "efcore",
    [ValidateSet("sqlserver","postgresql","sqlite")]
    [string]$Database      = "sqlserver",
    [bool]$UseDocker       = $true
)

# ─────────────────────────────────────────
# Mapa de versões de pacote por TFM
# ─────────────────────────────────────────
$PackageVersions = @{
    "net6.0" = @{
        EF          = "6.0.36"
        Dapper      = "2.1.35"
        Swashbuckle = "6.5.0"
        AWSLambda   = "7.0.0"
        WorkerSdk   = "6.0.36"
    }
    "net7.0" = @{
        EF          = "7.0.20"
        Dapper      = "2.1.35"
        Swashbuckle = "6.5.0"
        AWSLambda   = "7.2.2"
        WorkerSdk   = "7.0.20"
    }
    "net8.0" = @{
        EF          = "8.0.11"
        Dapper      = "2.1.35"
        Swashbuckle = "6.9.0"
        AWSLambda   = "7.3.2"
        WorkerSdk   = "8.0.11"
    }
    "net9.0" = @{
        EF          = "9.0.4"
        Dapper      = "2.1.35"
        Swashbuckle = "7.2.0"
        AWSLambda   = "7.4.0"
        WorkerSdk   = "9.0.4"
    }
    "net10.0" = @{
        EF          = "10.0.0"
        Dapper      = "2.2.0"
        Swashbuckle = "7.3.0"
        AWSLambda   = "7.5.0"
        WorkerSdk   = "10.0.0"
    }
}

$pkg = $PackageVersions[$DotnetVersion]

# Versão numérica limpa (ex: "8" de "net8.0")
$sdkMajor = $DotnetVersion -replace "net(\d+)\.0", '$1'

# Template dotnet conforme tipo de projeto
$templateMap = @{
    webapi  = "webapi"
    mvc     = "mvc"
    worker  = "worker"
    lambda  = "lambda.EmptyFunction" # requer Amazon.Lambda.Templates
}
$entryTemplate = $templateMap[$ProjectType]

# ─────────────────────────────────────────
# Funções auxiliares
# ─────────────────────────────────────────
function New-Dir($path) {
    New-Item -ItemType Directory -Force -Path $path | Out-Null
}

function New-File($path, $content = "") {
    $dir = Split-Path $path -Parent
    if ($dir) { New-Dir $dir }
    New-Item -ItemType File -Force -Path $path | Out-Null
    if ($content) { Set-Content -Path $path -Value $content -Encoding UTF8 }
}

function Add-Package($projectDir, $package, $version) {
    Write-Host "  + $package $version" -ForegroundColor DarkCyan
    dotnet add "$projectDir" package $package --version $version | Out-Null
}

function Write-Step($msg) {
    Write-Host "`n▶ $msg" -ForegroundColor Yellow
}

# ─────────────────────────────────────────
# VALIDAÇÕES
# ─────────────────────────────────────────
if ($ProjectType -eq "lambda") {
    $lambdaCheck = dotnet new --list 2>&1 | Select-String "lambda"
    if (-not $lambdaCheck) {
        Write-Host "⚠  Templates AWS Lambda não encontrados. Instalando..." -ForegroundColor Yellow
        dotnet new install Amazon.Lambda.Templates | Out-Null
    }
}

# ─────────────────────────────────────────
# PREPARAR DIRETÓRIO
# ─────────────────────────────────────────
Write-Step "Criando estrutura em '$OutputPath\$SolutionName'"

$root = Join-Path $OutputPath $SolutionName
New-Dir $root
Set-Location $root

# ─────────────────────────────────────────
# 1. SOLUTION
# ─────────────────────────────────────────
Write-Step "Criando solution"
dotnet new sln -n $SolutionName | Out-Null

# ─────────────────────────────────────────
# 2. PROJETOS
# ─────────────────────────────────────────
Write-Step "Criando projetos"

$projects = @{
    Domain         = "src\$SolutionName.Domain"
    Application    = "src\$SolutionName.Application"
    Infrastructure = "src\$SolutionName.Infrastructure"
    Data           = "src\$SolutionName.Data"
    Presentation   = "src\$SolutionName.API"
    Tests          = "tests\$SolutionName.Tests"
}

# Domain
dotnet new classlib -n "$SolutionName.Domain"         -o $projects.Domain         --framework $DotnetVersion | Out-Null
# Application
dotnet new classlib -n "$SolutionName.Application"    -o $projects.Application    --framework $DotnetVersion | Out-Null
# Infrastructure
dotnet new classlib -n "$SolutionName.Infrastructure" -o $projects.Infrastructure --framework $DotnetVersion | Out-Null
# Data
dotnet new classlib -n "$SolutionName.Data"           -o $projects.Data           --framework $DotnetVersion | Out-Null
# Apresentação
dotnet new $entryTemplate -n "$SolutionName.API"      -o $projects.Presentation   --framework $DotnetVersion | Out-Null
# Testes
dotnet new xunit -n "$SolutionName.Tests"             -o $projects.Tests          --framework $DotnetVersion | Out-Null

# ─────────────────────────────────────────
# 3. ADICIONAR À SOLUTION
# ─────────────────────────────────────────
Write-Step "Adicionando projetos à solution"
foreach ($p in $projects.Values) {
    $csproj = Get-ChildItem -Path $p -Filter "*.csproj" -Recurse | Select-Object -First 1
    if ($csproj) {
        dotnet sln add $csproj.FullName | Out-Null
        Write-Host "  ✓ $($csproj.Name)" -ForegroundColor DarkGreen
    }
}

# ─────────────────────────────────────────
# 4. REFERÊNCIAS ENTRE PROJETOS
# ─────────────────────────────────────────
Write-Step "Configurando referências"

function Get-Csproj($dir) {
    return (Get-ChildItem -Path $dir -Filter "*.csproj" -Recurse | Select-Object -First 1).FullName
}

# Application → Domain
dotnet add (Get-Csproj $projects.Application) reference (Get-Csproj $projects.Domain) | Out-Null
# Infrastructure → Application
dotnet add (Get-Csproj $projects.Infrastructure) reference (Get-Csproj $projects.Application) | Out-Null
# Data → Domain
dotnet add (Get-Csproj $projects.Data) reference (Get-Csproj $projects.Domain) | Out-Null
# API → Application + Infrastructure + Data
dotnet add (Get-Csproj $projects.Presentation) reference (Get-Csproj $projects.Application) | Out-Null
dotnet add (Get-Csproj $projects.Presentation) reference (Get-Csproj $projects.Infrastructure) | Out-Null
dotnet add (Get-Csproj $projects.Presentation) reference (Get-Csproj $projects.Data) | Out-Null
# Tests → Application
dotnet add (Get-Csproj $projects.Tests) reference (Get-Csproj $projects.Application) | Out-Null

Write-Host "  ✓ Referências configuradas" -ForegroundColor DarkGreen

# ─────────────────────────────────────────
# 5. PACOTES NUGET
# ─────────────────────────────────────────
Write-Step "Instalando pacotes NuGet"

# --- ORM ---
if ($Orm -eq "efcore") {
    $dbProvider = switch ($Database) {
        "sqlserver"  { "Microsoft.EntityFrameworkCore.SqlServer" }
        "postgresql" { "Npgsql.EntityFrameworkCore.PostgreSQL"   }
        "sqlite"     { "Microsoft.EntityFrameworkCore.Sqlite"    }
    }
    Add-Package (Get-Csproj $projects.Data) $dbProvider $pkg.EF
    Add-Package (Get-Csproj $projects.Data) "Microsoft.EntityFrameworkCore.Design" $pkg.EF
    Add-Package (Get-Csproj $projects.Data) "Microsoft.EntityFrameworkCore.Tools"  $pkg.EF
    Add-Package (Get-Csproj $projects.Presentation) "Microsoft.EntityFrameworkCore.Design" $pkg.EF
}

if ($Orm -eq "dapper") {
    $dbDriverPackage = switch ($Database) {
        "sqlserver"  { "Microsoft.Data.SqlClient" }
        "postgresql" { "Npgsql"                   }
        "sqlite"     { "Microsoft.Data.Sqlite"    }
    }
    Add-Package (Get-Csproj $projects.Data) "Dapper"          $pkg.Dapper
    Add-Package (Get-Csproj $projects.Data) $dbDriverPackage  "latest"
}

# --- API / Web ---
if ($ProjectType -eq "webapi" -or $ProjectType -eq "mvc") {
    Add-Package (Get-Csproj $projects.Presentation) "Swashbuckle.AspNetCore" $pkg.Swashbuckle
}

# --- Lambda ---
if ($ProjectType -eq "lambda") {
    Add-Package (Get-Csproj $projects.Presentation) "Amazon.Lambda.Core"            $pkg.AWSLambda
    Add-Package (Get-Csproj $projects.Presentation) "Amazon.Lambda.Serialization.SystemTextJson" $pkg.AWSLambda
}

# --- Worker ---
if ($ProjectType -eq "worker") {
    Add-Package (Get-Csproj $projects.Presentation) "Microsoft.Extensions.Hosting"  $pkg.WorkerSdk
}

# Logging padrão em todos os projetos
foreach ($p in @($projects.Application, $projects.Infrastructure)) {
    Add-Package (Get-Csproj $p) "Microsoft.Extensions.Logging.Abstractions" "8.0.0"
}

# ─────────────────────────────────────────
# 6. ESTRUTURA DE PASTAS INTERNAS
# ─────────────────────────────────────────
Write-Step "Criando pastas internas"

# Domain
@("Entities","Interfaces","ValueObjects","Enums","Exceptions") | ForEach-Object {
    New-Dir "$($projects.Domain)\$_"
}

# Application
@("UseCases","DTOs","Interfaces","Mappings","Validators") | ForEach-Object {
    New-Dir "$($projects.Application)\$_"
}

# Infrastructure
@("Services","Messaging","Logging") | ForEach-Object {
    New-Dir "$($projects.Infrastructure)\$_"
}

# Data
if ($Orm -eq "efcore") {
    @("Context","Configurations","Migrations","Repositories") | ForEach-Object {
        New-Dir "$($projects.Data)\$_"
    }
}
if ($Orm -eq "dapper") {
    @("Repositories","Connections","Scripts") | ForEach-Object {
        New-Dir "$($projects.Data)\$_"
    }
}

# Tests
@("UseCases","Repositories","Helpers") | ForEach-Object {
    New-Dir "$($projects.Tests)\$_"
}

# ─────────────────────────────────────────
# 7. ARQUIVOS BASE
# ─────────────────────────────────────────
Write-Step "Gerando arquivos base"

# --- GlobalUsings ---
$globalUsings = @"
global using System;
global using System.Collections.Generic;
global using System.Linq;
global using System.Threading;
global using System.Threading.Tasks;
"@
New-File "$($projects.Domain)\GlobalUsings.cs"         $globalUsings
New-File "$($projects.Application)\GlobalUsings.cs"    $globalUsings
New-File "$($projects.Infrastructure)\GlobalUsings.cs" $globalUsings
New-File "$($projects.Data)\GlobalUsings.cs"           $globalUsings

# --- Interface base de repositório (Domain) ---
$iRepo = @"
namespace $SolutionName.Domain.Interfaces;

public interface IRepository<T> where T : class
{
    Task<T?> GetByIdAsync(int id, CancellationToken ct = default);
    Task<IEnumerable<T>> GetAllAsync(CancellationToken ct = default);
    Task AddAsync(T entity, CancellationToken ct = default);
    Task UpdateAsync(T entity, CancellationToken ct = default);
    Task DeleteAsync(int id, CancellationToken ct = default);
}
"@
New-File "$($projects.Domain)\Interfaces\IRepository.cs" $iRepo

# --- IUnitOfWork ---
$iUow = @"
namespace $SolutionName.Domain.Interfaces;

public interface IUnitOfWork : IDisposable
{
    Task<int> CommitAsync(CancellationToken ct = default);
}
"@
New-File "$($projects.Domain)\Interfaces\IUnitOfWork.cs" $iUow

# --- Repositório base DAPPER (espelhando OnlineAuction.Data) ---
if ($Orm -eq "dapper") {
    $connFactory = @"
using Microsoft.Extensions.Configuration;
using System.Data;
$(if ($Database -eq "sqlserver") { "using Microsoft.Data.SqlClient;" })
$(if ($Database -eq "postgresql") { "using Npgsql;" })

namespace $SolutionName.Data.Connections;

public interface IDbConnectionFactory
{
    IDbConnection CreateConnection();
}

public sealed class DbConnectionFactory : IDbConnectionFactory
{
    private readonly string _connectionString;

    public DbConnectionFactory(IConfiguration configuration)
        => _connectionString = configuration.GetConnectionString("DefaultConnection")
           ?? throw new InvalidOperationException("ConnectionString 'DefaultConnection' not found.");

    public IDbConnection CreateConnection()
    {
$(if ($Database -eq "sqlserver") { "        return new SqlConnection(_connectionString);" })
$(if ($Database -eq "postgresql") { "        return new NpgsqlConnection(_connectionString);" })
    }
}
"@
    New-File "$($projects.Data)\Connections\DbConnectionFactory.cs" $connFactory

    $dapperBase = @"
using Dapper;
using $SolutionName.Domain.Interfaces;
using $SolutionName.Data.Connections;
using System.Data;

namespace $SolutionName.Data.Repositories;

public abstract class RepositoryBase<T> : IRepository<T> where T : class
{
    protected readonly IDbConnectionFactory _factory;
    protected abstract string TableName { get; }

    protected RepositoryBase(IDbConnectionFactory factory) => _factory = factory;

    public virtual async Task<T?> GetByIdAsync(int id, CancellationToken ct = default)
    {
        using var conn = _factory.CreateConnection();
        return await conn.QueryFirstOrDefaultAsync<T>(
            `$"SELECT * FROM {TableName} WHERE Id = @Id"`, new { Id = id });
    }

    public virtual async Task<IEnumerable<T>> GetAllAsync(CancellationToken ct = default)
    {
        using var conn = _factory.CreateConnection();
        return await conn.QueryAsync<T>(`$"SELECT * FROM {TableName}"`);
    }

    public virtual async Task AddAsync(T entity, CancellationToken ct = default)
    {
        using var conn = _factory.CreateConnection();
        await conn.ExecuteAsync(`$"INSERT INTO {TableName} VALUES (@entity)"`, entity);
    }

    public virtual async Task UpdateAsync(T entity, CancellationToken ct = default)
    {
        using var conn = _factory.CreateConnection();
        await conn.ExecuteAsync(`$"UPDATE {TableName} SET /* mapeie os campos */ WHERE Id = @Id"`, entity);
    }

    public virtual async Task DeleteAsync(int id, CancellationToken ct = default)
    {
        using var conn = _factory.CreateConnection();
        await conn.ExecuteAsync(`$"DELETE FROM {TableName} WHERE Id = @Id"`, new { Id = id });
    }
}
"@
    New-File "$($projects.Data)\Repositories\RepositoryBase.cs" $dapperBase
}

# --- DI Extension — Data ---
$diData = if ($Orm -eq "dapper") { @"
using Microsoft.Extensions.DependencyInjection;
using $SolutionName.Data.Connections;

namespace $SolutionName.Data;

public static class DataServiceExtensions
{
    public static IServiceCollection AddDataServices(this IServiceCollection services)
    {
        services.AddSingleton<IDbConnectionFactory, DbConnectionFactory>();
        // Registre seus repositórios aqui
        // services.AddScoped<IUserRepository, UserRepository>();
        return services;
    }
}
"@ } else { @"
using Microsoft.Extensions.DependencyInjection;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace $SolutionName.Data;

public static class DataServiceExtensions
{
    public static IServiceCollection AddDataServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.AddDbContext<AppDbContext>(opts =>
            opts.Use$(if ($Database -eq "sqlserver") {"SqlServer"}elseif ($Database -eq "postgresql") {"Npgsql"}else{"Sqlite"})(
                configuration.GetConnectionString("DefaultConnection")));
        return services;
    }
}
"@ }
New-File "$($projects.Data)\DataServiceExtensions.cs" $diData

# --- appsettings.json ---
$appSettings = @"
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=${SolutionName}Db;Trusted_Connection=True;TrustServerCertificate=True"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}
"@
New-File "$($projects.Presentation)\appsettings.json"             $appSettings
New-File "$($projects.Presentation)\appsettings.Development.json" '{ "Logging": { "LogLevel": { "Default": "Debug" } } }'

# --- Directory.Build.props (Central Package Management) ---
$buildProps = @"
<Project>
  <PropertyGroup>
    <TargetFramework>$DotnetVersion</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <TreatWarningsAsErrors>false</TreatWarningsAsErrors>
  </PropertyGroup>
</Project>
"@
New-File "Directory.Build.props" $buildProps

# ─────────────────────────────────────────
# 8. DOCKER
# ─────────────────────────────────────────
if ($UseDocker) {
    Write-Step "Gerando Dockerfile e .dockerignore"

    $apiProjectName = "$SolutionName.API"
    $apiRelPath     = "src/$apiProjectName"

    $expose  = if ($ProjectType -ne "worker") { "EXPOSE 8080`nEXPOSE 8081" } else { "" }
    $baseImg = if ($ProjectType -eq "lambda") {
        "public.ecr.aws/lambda/dotnet:$sdkMajor"
    } else {
        "mcr.microsoft.com/dotnet/aspnet:$sdkMajor AS base"
    }

    $dockerfile = @"
# ── Base ─────────────────────────────────
FROM $baseImg
WORKDIR /app
$expose

# ── Build ────────────────────────────────
FROM mcr.microsoft.com/dotnet/sdk:$sdkMajor AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src

COPY ["$apiRelPath/$apiProjectName.csproj", "$apiRelPath/"]
COPY ["src/$SolutionName.Application/$SolutionName.Application.csproj", "src/$SolutionName.Application/"]
COPY ["src/$SolutionName.Domain/$SolutionName.Domain.csproj", "src/$SolutionName.Domain/"]
COPY ["src/$SolutionName.Infrastructure/$SolutionName.Infrastructure.csproj", "src/$SolutionName.Infrastructure/"]
COPY ["src/$SolutionName.Data/$SolutionName.Data.csproj", "src/$SolutionName.Data/"]

RUN dotnet restore "$apiRelPath/$apiProjectName.csproj"
COPY . .

WORKDIR "/src/$apiRelPath"
RUN dotnet build "$apiProjectName.csproj" -c `$BUILD_CONFIGURATION -o /app/build

# ── Publish ──────────────────────────────
FROM build AS publish
RUN dotnet publish "$apiProjectName.csproj" -c `$BUILD_CONFIGURATION -o /app/publish /p:UseAppHost=false

# ── Final ────────────────────────────────
FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "$apiProjectName.dll"]
"@

    $dockerignore = @"
**/.vs
**/.git
**/.gitignore
**/.github
**/bin
**/obj
**/*.user
**/*.suo
**/Dockerfile*
**/.dockerignore
**/node_modules
**/.env
"@

    New-File "$($projects.Presentation)\Dockerfile"    $dockerfile
    New-File ".dockerignore"                            $dockerignore
    Write-Host "  ✓ Dockerfile em $($projects.Presentation)" -ForegroundColor DarkGreen
    Write-Host "  ✓ .dockerignore na raiz"              -ForegroundColor DarkGreen
}

# ─────────────────────────────────────────
# 9. .gitignore
# ─────────────────────────────────────────
$gitignore = @"
# Build
bin/
obj/
*.user
*.suo
.vs/

# Docker
Dockerfile*
.dockerignore

# Env
.env
*.local

# Logs
*.log
"@
New-File ".gitignore" $gitignore

# ─────────────────────────────────────────
# RESUMO FINAL
# ─────────────────────────────────────────
Write-Host ""
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  ✅ Estrutura '$SolutionName' criada com sucesso!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  .NET    : $DotnetVersion"
Write-Host "  Tipo    : $ProjectType"
Write-Host "  ORM     : $Orm"
Write-Host "  Banco   : $Database"
Write-Host "  Docker  : $UseDocker"
Write-Host ""
Write-Host "  Próximos passos:"
Write-Host "  1. Abra '$SolutionName.sln' no Visual Studio / Rider"
if ($Orm -eq "efcore") {
Write-Host "  2. Configure a connection string em appsettings.json"
Write-Host "  3. Execute: dotnet ef migrations add Init -p src\$SolutionName.Data -s src\$SolutionName.API"
}
if ($Orm -eq "dapper") {
Write-Host "  2. Configure a connection string em appsettings.json"
Write-Host "  3. Adicione seus repositórios em Data\Repositories herdando RepositoryBase<T>"
}
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
