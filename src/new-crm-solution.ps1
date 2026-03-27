<#
.SYNOPSIS
  Gera uma nova solução CRM com a mesma estrutura deste repositório (AtomoHub CRM).
.DESCRIPTION
  Script interativo para criar uma solução estilo AtomoHub CRM, perguntando:
  - Versão do .NET (net6.0 até net10.0)
  - Tipo de app Web (WebApi ou MVC)
  - ORM (EFCore ou Dapper)
  - Nome da solução
  Cria projetos: Domain, Data, Service, CrossCutting, Shared, ViewModel, Web.
  Instala pacotes compatíveis com a versão escolhida e gera Dockerfile/.dockerignore.

.USAGE
  PowerShell:
    ./scripts/new-crm-solution.ps1
    ./scripts/new-crm-solution.ps1 -SolutionName "MyCrm" -TargetFramework "net8.0" -WebKind "webapi" -OrmKind "dapper"
#>

[CmdletBinding()]
param(
  [string]$SolutionName,
  [ValidateSet('net6.0','net7.0','net8.0','net9.0','net10.0')]
  [string]$TargetFramework,
  [ValidateSet('webapi','mvc')]
  [string]$WebKind,
  [ValidateSet('efcore','dapper')]
  [string]$OrmKind
)

# ─────────────────────────────────────────────────────────────
# FUNÇÕES AUXILIARES
# ─────────────────────────────────────────────────────────────
function Read-IfEmpty([string]$Value, [string]$Message) {
  if ([string]::IsNullOrWhiteSpace($Value)) { Read-Host $Message } else { $Value }
}

function New-CsFile([string]$BasePath, [string]$RelativePath, [string]$Content) {
  $fullPath = Join-Path $BasePath $RelativePath
  $dir = Split-Path $fullPath -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  Set-Content -Path $fullPath -Value $Content -Encoding UTF8
}

# ─────────────────────────────────────────────────────────────
# MAPA DE VERSÕES POR TFM
# ─────────────────────────────────────────────────────────────
$PkgMap = @{
  'net6.0'  = @{ EF='6.0.36';  Dapper='2.1.35'; Pomelo='6.0.3';  Automapper='12.0.1'; FluentVal='11.9.0'; Scrutor='4.2.2'; Serilog='6.0.0';  SerilogFile='5.0.0'; Swashbuckle='6.5.0'; NewtonsoftJson='13.0.3'; SqlClient='5.2.2'; Npgsql='6.0.29'; SqlitePkg='6.0.36'; MvcViewFeatures='2.2.0'; SignalR='6.0.36'; MsDiAbstractions='6.0.0'; CodeGenDesign='6.0.17'; AspIdentityEF='6.0.36'; EFDesign='6.0.36'; MsExtConfig='6.0.1'; MsExtConfigJson='6.0.0'; Moq='4.20.70'; Coverlet='6.0.0' }
  'net7.0'  = @{ EF='7.0.20';  Dapper='2.1.35'; Pomelo='7.0.0';  Automapper='12.0.1'; FluentVal='11.9.0'; Scrutor='4.2.2'; Serilog='7.0.0';  SerilogFile='5.0.0'; Swashbuckle='6.5.0'; NewtonsoftJson='13.0.3'; SqlClient='5.2.2'; Npgsql='7.0.18'; SqlitePkg='7.0.20'; MvcViewFeatures='2.2.0'; SignalR='7.0.20'; MsDiAbstractions='7.0.0'; CodeGenDesign='7.0.12'; AspIdentityEF='7.0.20'; EFDesign='7.0.20'; MsExtConfig='7.0.0'; MsExtConfigJson='7.0.0'; Moq='4.20.70'; Coverlet='6.0.0' }
  'net8.0'  = @{ EF='8.0.11';  Dapper='2.1.35'; Pomelo='8.0.2';  Automapper='13.0.1'; FluentVal='11.9.0'; Scrutor='6.1.0'; Serilog='8.0.4';  SerilogFile='5.0.0'; Swashbuckle='6.9.0'; NewtonsoftJson='13.0.3'; SqlClient='5.2.2'; Npgsql='8.0.5';  SqlitePkg='8.0.11'; MvcViewFeatures='2.2.0'; SignalR='8.0.11'; MsDiAbstractions='8.0.2'; CodeGenDesign='8.0.7';  AspIdentityEF='8.0.11'; EFDesign='8.0.11'; MsExtConfig='8.0.0'; MsExtConfigJson='8.0.0'; Moq='4.20.70'; Coverlet='6.0.0' }
  'net9.0'  = @{ EF='9.0.4';   Dapper='2.1.35'; Pomelo='9.0.0';  Automapper='13.0.1'; FluentVal='11.9.2'; Scrutor='6.1.0'; Serilog='9.0.0';  SerilogFile='6.0.0'; Swashbuckle='7.2.0'; NewtonsoftJson='13.0.3'; SqlClient='6.0.1'; Npgsql='9.0.4';  SqlitePkg='9.0.4';  MvcViewFeatures='2.2.0'; SignalR='9.0.4';  MsDiAbstractions='9.0.4'; CodeGenDesign='9.0.0';  AspIdentityEF='9.0.4';  EFDesign='9.0.4';  MsExtConfig='9.0.0'; MsExtConfigJson='9.0.0'; Moq='4.20.72'; Coverlet='6.0.2' }
  'net10.0' = @{ EF='10.0.0';  Dapper='2.2.0';  Pomelo='10.0.0'; Automapper='13.0.1'; FluentVal='11.10.0';Scrutor='6.1.0'; Serilog='9.0.0';  SerilogFile='6.0.0'; Swashbuckle='7.3.0'; NewtonsoftJson='13.0.3'; SqlClient='6.0.1'; Npgsql='10.0.0'; SqlitePkg='10.0.0'; MvcViewFeatures='2.2.0'; SignalR='10.0.0'; MsDiAbstractions='10.0.0';CodeGenDesign='10.0.0'; AspIdentityEF='10.0.0'; EFDesign='10.0.0'; MsExtConfig='10.0.0';MsExtConfigJson='10.0.0';Moq='4.20.72'; Coverlet='6.0.2' }
}

# ─────────────────────────────────────────────────────────────
# INPUTS INTERATIVOS
# ─────────────────────────────────────────────────────────────
$SolutionName    = Read-IfEmpty $SolutionName    'Nome da solução (ex.: MyCrm)'
$TargetFramework = Read-IfEmpty $TargetFramework 'Versão do .NET (net6.0, net7.0, net8.0, net9.0, net10.0)'
$WebKind         = Read-IfEmpty $WebKind         'Tipo Web (webapi | mvc)'
$OrmKind         = Read-IfEmpty $OrmKind         'ORM (efcore | dapper)'
$CreateTests     = Read-Host                     'Criar projeto de testes (y/N)?'
$CreateDocker    = Read-Host                     'Gerar Dockerfile e .dockerignore (y/N)?'

$pkg = $PkgMap[$TargetFramework]
if (-not $pkg) { Write-Error "TFM '$TargetFramework' inválido."; exit 1 }

# Versão numérica para imagens Docker (ex: "9" de "net9.0")
$sdkMajor = $TargetFramework -replace 'net(\d+)\.0','$1'

Write-Host ""
Write-Host "Criando '$SolutionName' | TFM: $TargetFramework | Web: $WebKind | ORM: $OrmKind" -ForegroundColor Cyan

# ─────────────────────────────────────────────────────────────
# ESTRUTURA DE PASTAS
# ─────────────────────────────────────────────────────────────
$root     = Join-Path (Get-Location) $SolutionName
$backend  = Join-Path $root 'src/Backend'
$frontend = Join-Path $root 'src/Frontend'
New-Item -ItemType Directory -Force -Path $backend  | Out-Null
New-Item -ItemType Directory -Force -Path $frontend | Out-Null

Push-Location $backend

# ─────────────────────────────────────────────────────────────
# SOLUTION
# ─────────────────────────────────────────────────────────────
& dotnet new sln -n $SolutionName | Out-Null

# ─────────────────────────────────────────────────────────────
# NOMES DOS PROJETOS
# ─────────────────────────────────────────────────────────────
$projDomain       = "${SolutionName}.Domain"
$projData         = "${SolutionName}.Data"
$projService      = "${SolutionName}.Service"
$projCrossCutting = "${SolutionName}.CrossCutting"
$projShared       = "${SolutionName}.Shared"
$projViewModel    = "${SolutionName}.ViewModel"
$projWeb          = if ($WebKind -eq 'webapi') { "${SolutionName}.WebApi" } else { "${SolutionName}.Web" }

# ─────────────────────────────────────────────────────────────
# CRIAR PROJETOS
# ─────────────────────────────────────────────────────────────
Write-Host "`n▶ Criando projetos..." -ForegroundColor Yellow

function New-ClassLib([string]$Name) {
  & dotnet new classlib -n $Name -f $TargetFramework | Out-Null
  Write-Host "  ✓ $Name" -ForegroundColor DarkGreen
}

New-ClassLib $projDomain
New-ClassLib $projData
New-ClassLib $projService
New-ClassLib $projCrossCutting
New-ClassLib $projShared
New-ClassLib $projViewModel

if ($WebKind -eq 'webapi') {
  & dotnet new webapi -n $projWeb -f $TargetFramework | Out-Null
} else {
  & dotnet new mvc -n $projWeb -f $TargetFramework | Out-Null
}
Write-Host "  ✓ $projWeb" -ForegroundColor DarkGreen

# ─────────────────────────────────────────────────────────────
# ADICIONAR À SOLUTION
# ─────────────────────────────────────────────────────────────
Write-Host "`n▶ Adicionando à solution..." -ForegroundColor Yellow
& dotnet sln add @(
  "$projDomain/$projDomain.csproj",
  "$projData/$projData.csproj",
  "$projService/$projService.csproj",
  "$projCrossCutting/$projCrossCutting.csproj",
  "$projShared/$projShared.csproj",
  "$projViewModel/$projViewModel.csproj",
  "$projWeb/$projWeb.csproj"
) | Out-Null

# ─────────────────────────────────────────────────────────────
# PACOTES NUGET
# ─────────────────────────────────────────────────────────────
Write-Host "`n▶ Instalando pacotes NuGet..." -ForegroundColor Yellow

function Add-Pkg([string]$ProjDir, [string]$Package, [string]$Version) {
  Write-Host "  + [$ProjDir] $Package $Version" -ForegroundColor DarkCyan
  & dotnet add "$ProjDir/$ProjDir.csproj" package $Package --version $Version | Out-Null
}

# Domain
Add-Pkg $projDomain 'FluentValidation'                                    $pkg.FluentVal
Add-Pkg $projDomain 'Microsoft.AspNetCore.Identity.EntityFrameworkCore'   $pkg.AspIdentityEF

# Data — pacotes base sempre presentes
Add-Pkg $projData 'Microsoft.Extensions.Configuration'       $pkg.MsExtConfig
Add-Pkg $projData 'Microsoft.Extensions.Configuration.Json'  $pkg.MsExtConfigJson

if ($OrmKind -eq 'efcore') {
  Add-Pkg $projData 'Microsoft.EntityFrameworkCore'           $pkg.EF
  Add-Pkg $projData 'Microsoft.EntityFrameworkCore.SqlServer' $pkg.EF
  Add-Pkg $projData 'Microsoft.EntityFrameworkCore.Tools'     $pkg.EFDesign
  Add-Pkg $projData 'Pomelo.EntityFrameworkCore.MySql'        $pkg.Pomelo
} else {
  # Dapper — estrutura OnlineAuction.Data
  Add-Pkg $projData 'Dapper'                    $pkg.Dapper
  Add-Pkg $projData 'Microsoft.Data.SqlClient'  $pkg.SqlClient
}

# Service
Add-Pkg $projService 'AutoMapper'                   $pkg.Automapper
Add-Pkg $projService 'Microsoft.AspNetCore.SignalR' $pkg.SignalR

# CrossCutting
Add-Pkg $projCrossCutting 'AutoMapper'                                          $pkg.Automapper
Add-Pkg $projCrossCutting 'FluentValidation.AspNetCore'                         $pkg.FluentVal
Add-Pkg $projCrossCutting 'Microsoft.Extensions.DependencyInjection.Abstractions' $pkg.MsDiAbstractions
Add-Pkg $projCrossCutting 'Scrutor'                                             $pkg.Scrutor

if ($OrmKind -eq 'efcore') {
  Add-Pkg $projCrossCutting 'Microsoft.EntityFrameworkCore.SqlServer' $pkg.EF
  Add-Pkg $projCrossCutting 'Pomelo.EntityFrameworkCore.MySql'        $pkg.Pomelo
} else {
  Add-Pkg $projCrossCutting 'Microsoft.Data.SqlClient' $pkg.SqlClient
}

# Shared
Add-Pkg $projShared 'Microsoft.AspNetCore.Mvc.ViewFeatures' $pkg.MvcViewFeatures

# Web
Add-Pkg $projWeb 'Serilog.AspNetCore'                                   $pkg.Serilog
Add-Pkg $projWeb 'Serilog.Sinks.File'                                   $pkg.SerilogFile
Add-Pkg $projWeb 'Microsoft.VisualStudio.Web.CodeGeneration.Design'     $pkg.CodeGenDesign
Add-Pkg $projWeb 'Microsoft.EntityFrameworkCore.Design'                 $pkg.EFDesign
Add-Pkg $projWeb 'Newtonsoft.Json'                                      $pkg.NewtonsoftJson

if ($WebKind -eq 'webapi') {
  Add-Pkg $projWeb 'Swashbuckle.AspNetCore' $pkg.Swashbuckle
}

# ─────────────────────────────────────────────────────────────
# REFERÊNCIAS ENTRE PROJETOS
# ─────────────────────────────────────────────────────────────
Write-Host "`n▶ Configurando referências..." -ForegroundColor Yellow

& dotnet add "$projCrossCutting/$projCrossCutting.csproj" reference @(
  "$projData/$projData.csproj",
  "$projService/$projService.csproj"
) | Out-Null
& dotnet add "$projShared/$projShared.csproj" reference "$projDomain/$projDomain.csproj" | Out-Null
& dotnet add "$projService/$projService.csproj" reference @(
  "$projShared/$projShared.csproj",
  "$projViewModel/$projViewModel.csproj",
  "$projDomain/$projDomain.csproj"
) | Out-Null
& dotnet add "$projData/$projData.csproj" reference "$projDomain/$projDomain.csproj" | Out-Null
& dotnet add "$projWeb/$projWeb.csproj" reference @(
  "$projCrossCutting/$projCrossCutting.csproj",
  "$projShared/$projShared.csproj",
  "$projViewModel/$projViewModel.csproj",
  "$projDomain/$projDomain.csproj"
) | Out-Null

Write-Host "  ✓ Referências configuradas" -ForegroundColor DarkGreen

# ─────────────────────────────────────────────────────────────
# PROJETO DE TESTES (OPCIONAL)
# ─────────────────────────────────────────────────────────────
if ($CreateTests -match '^(y|Y)') {
  $projTests = "${SolutionName}.Service.Tests"
  Write-Host "`n▶ Criando projeto de testes '$projTests' (NUnit)..." -ForegroundColor Yellow
  & dotnet new nunit -n $projTests -f $TargetFramework | Out-Null
  Push-Location $projTests
  & dotnet add package Moq             --version $pkg.Moq     | Out-Null
  & dotnet add package coverlet.collector --version $pkg.Coverlet | Out-Null
  Pop-Location
  & dotnet add "$projTests/$projTests.csproj" reference "$projService/$projService.csproj" | Out-Null
  & dotnet sln add "$projTests/$projTests.csproj" | Out-Null
  Write-Host "  ✓ $projTests" -ForegroundColor DarkGreen
}

# ─────────────────────────────────────────────────────────────
# CROSSCUTTING — ESTRUTURA DE PASTAS E ARQUIVOS
# ─────────────────────────────────────────────────────────────
Write-Host "`n▶ Gerando estrutura CrossCutting..." -ForegroundColor Yellow

$crossPath = (Resolve-Path -Path (Join-Path (Get-Location) $projCrossCutting)).Path
$nsRoot    = "$SolutionName.CrossCutting"

$defaultClass = Join-Path $crossPath 'Class1.cs'
if (Test-Path $defaultClass) { Remove-Item $defaultClass -Force }

@(
  'DependencyInjection/AutoMapper/Config',
  'DependencyInjection/DbConfig',
  'DependencyInjection/Repository',
  'DependencyInjection/Service',
  'DependencyInjection/Validation/Base'
) | ForEach-Object { New-Item -ItemType Directory -Force -Path (Join-Path $crossPath $_) | Out-Null }

# DbConfig — conteúdo varia por ORM
if ($OrmKind -eq 'efcore') {
  $contentDb = @"
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace $nsRoot.DependencyInjection.DbConfig;

public static class DbDependencyExtensions
{
    public static IServiceCollection AddSqlServerDependency(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        // TODO: Substitua YourDbContext pelo seu DbContext real
        // services.AddDbContextPool<YourDbContext>(options =>
        //     options.UseSqlServer(configuration.GetConnectionString("DefaultConnection")));
        return services;
    }
}
"@
} else {
  # Dapper — padrão OnlineAuction.Data: IDbConnectionFactory + SqlConnection
  $contentDb = @"
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using System.Data;

namespace $nsRoot.DependencyInjection.DbConfig;

/// <summary>
/// Factory de conexão Dapper (padrão OnlineAuction.Data).
/// Registra IDbConnectionFactory como Scoped para uso nos repositórios.
/// </summary>
public interface IDbConnectionFactory
{
    IDbConnection CreateConnection();
}

public sealed class SqlConnectionFactory : IDbConnectionFactory
{
    private readonly string _connectionString;

    public SqlConnectionFactory(IConfiguration configuration)
        => _connectionString = configuration.GetConnectionString("DefaultConnection")
           ?? throw new InvalidOperationException("ConnectionString 'DefaultConnection' não encontrada.");

    public IDbConnection CreateConnection() => new SqlConnection(_connectionString);
}

public static class DbDependencyExtensions
{
    public static IServiceCollection AddSqlServerDependency(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.AddScoped<IDbConnectionFactory, SqlConnectionFactory>();
        return services;
    }
}
"@
}

$contentRepository = @"
using Microsoft.Extensions.DependencyInjection;

namespace $nsRoot.DependencyInjection.Repository;

public static class RepositoryDependencyExtensions
{
    public static IServiceCollection AddSqlRepositoryDependency(this IServiceCollection services)
    {
        // TODO: Registrar repositórios da camada Data via Scrutor/DI
        // Exemplo: services.AddScoped<IClienteRepository, ClienteRepository>();
        return services;
    }
}
"@

$contentService = @"
using Microsoft.Extensions.DependencyInjection;

namespace $nsRoot.DependencyInjection.Service;

public static class ServiceDependencyExtensions
{
    public static IServiceCollection AddServiceDependency(this IServiceCollection services)
    {
        // TODO: Registrar serviços da camada Service via Scrutor/DI
        return services;
    }
}
"@

$contentMapper = @"
using Microsoft.Extensions.DependencyInjection;

namespace $nsRoot.DependencyInjection.AutoMapper.Config;

public static class MapperConfigurationExtensions
{
    public static IServiceCollection AddMapperConfiguration(this IServiceCollection services)
    {
        services.AddAutoMapper(AppDomain.CurrentDomain.GetAssemblies());
        return services;
    }
}
"@

$contentValidation = @"
using Microsoft.Extensions.DependencyInjection;

namespace $nsRoot.DependencyInjection.Validation.Base;

public static class ValidationExtensions
{
    public static IServiceCollection AddValidators(this IServiceCollection services)
    {
        // TODO: Registrar validadores FluentValidation
        return services;
    }
}
"@

New-CsFile $crossPath 'DependencyInjection/Service/ServiceDependencyExtensions.cs'              $contentService
New-CsFile $crossPath 'DependencyInjection/Repository/RepositoryDependencyExtensions.cs'        $contentRepository
New-CsFile $crossPath 'DependencyInjection/DbConfig/DbDependencyExtensions.cs'                  $contentDb
New-CsFile $crossPath 'DependencyInjection/AutoMapper/Config/MapperConfigurationExtensions.cs'  $contentMapper
New-CsFile $crossPath 'DependencyInjection/Validation/Base/ValidationExtensions.cs'             $contentValidation

Write-Host "  ✓ CrossCutting gerado" -ForegroundColor DarkGreen

# ─────────────────────────────────────────────────────────────
# DAPPER — RepositoryBase no projeto Data (estilo OnlineAuction.Data)
# ─────────────────────────────────────────────────────────────
if ($OrmKind -eq 'dapper') {
  Write-Host "`n▶ Gerando estrutura Dapper (Data)..." -ForegroundColor Yellow

  $dataPath = (Resolve-Path -Path (Join-Path (Get-Location) $projData)).Path
  $nsData   = "$SolutionName.Data"

  @('Repositories','Scripts') | ForEach-Object {
    New-Item -ItemType Directory -Force -Path (Join-Path $dataPath $_) | Out-Null
  }

  $defaultDataClass = Join-Path $dataPath 'Class1.cs'
  if (Test-Path $defaultDataClass) { Remove-Item $defaultDataClass -Force }

  $repoBase = @"
using Dapper;
using $nsRoot.DependencyInjection.DbConfig;
using System.Data;

namespace $nsData.Repositories;

/// <summary>
/// Repositório base Dapper — espelha a estrutura do OnlineAuction.Data.
/// Herança: class ClienteRepository : RepositoryBase<Cliente>
/// </summary>
public abstract class RepositoryBase<T> where T : class
{
    protected readonly IDbConnectionFactory _factory;
    protected abstract string TableName { get; }

    protected RepositoryBase(IDbConnectionFactory factory) => _factory = factory;

    protected IDbConnection OpenConnection() => _factory.CreateConnection();

    public virtual async Task<T?> GetByIdAsync(int id, CancellationToken ct = default)
    {
        using var conn = OpenConnection();
        return await conn.QueryFirstOrDefaultAsync<T>(
            new CommandDefinition($"SELECT * FROM {TableName} WHERE Id = @Id", new { Id = id }, cancellationToken: ct));
    }

    public virtual async Task<IEnumerable<T>> GetAllAsync(CancellationToken ct = default)
    {
        using var conn = OpenConnection();
        return await conn.QueryAsync<T>(
            new CommandDefinition($"SELECT * FROM {TableName}", cancellationToken: ct));
    }

    public virtual async Task<int> AddAsync(T entity, CancellationToken ct = default)
    {
        using var conn = OpenConnection();
        // TODO: Substitua pela query INSERT específica da entidade
        return await conn.ExecuteAsync(
            new CommandDefinition($"/* INSERT INTO {TableName} (...) VALUES (...) */", entity, cancellationToken: ct));
    }

    public virtual async Task<int> UpdateAsync(T entity, CancellationToken ct = default)
    {
        using var conn = OpenConnection();
        // TODO: Substitua pela query UPDATE específica da entidade
        return await conn.ExecuteAsync(
            new CommandDefinition($"/* UPDATE {TableName} SET ... WHERE Id = @Id */", entity, cancellationToken: ct));
    }

    public virtual async Task<int> DeleteAsync(int id, CancellationToken ct = default)
    {
        using var conn = OpenConnection();
        return await conn.ExecuteAsync(
            new CommandDefinition($"DELETE FROM {TableName} WHERE Id = @Id", new { Id = id }, cancellationToken: ct));
    }

    /// <summary>Executa query dentro de uma transaction explícita.</summary>
    protected async Task<int> ExecuteInTransactionAsync(
        Func<IDbConnection, IDbTransaction, Task<int>> action,
        CancellationToken ct = default)
    {
        using var conn = OpenConnection();
        conn.Open();
        using var tx = conn.BeginTransaction();
        try
        {
            var result = await action(conn, tx);
            tx.Commit();
            return result;
        }
        catch
        {
            tx.Rollback();
            throw;
        }
    }
}
"@

  New-CsFile $dataPath 'Repositories/RepositoryBase.cs' $repoBase
  Write-Host "  ✓ RepositoryBase<T> gerado em Data/Repositories" -ForegroundColor DarkGreen
}

# ─────────────────────────────────────────────────────────────
# SHARED — CurrentDirectoryHelper (MVC)
# ─────────────────────────────────────────────────────────────
if ($WebKind -eq 'mvc') {
  $sharedPath = (Resolve-Path -Path (Join-Path (Get-Location) $projShared)).Path
  $sharedDefault = Join-Path $sharedPath 'Class1.cs'
  if (Test-Path $sharedDefault) { Remove-Item $sharedDefault -Force }

  $helperContent = @"
using System.Reflection;

namespace ${SolutionName}.Shared.Helper.CurrentDirectory;

public static class CurrentDirectoryHelper
{
    public static void SetCurrentDirectory()
    {
        var currentDirectory = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
        if (!string.IsNullOrEmpty(currentDirectory))
            Directory.SetCurrentDirectory(currentDirectory);
    }
}
"@
  New-CsFile $sharedPath 'Helper/CurrentDirectory/CurrentDirectoryHelper.cs' $helperContent
}

# ─────────────────────────────────────────────────────────────
# PROGRAM.CS CUSTOMIZADO
# ─────────────────────────────────────────────────────────────
Write-Host "`n▶ Gerando Program.cs..." -ForegroundColor Yellow

$webPath       = (Resolve-Path -Path (Join-Path (Get-Location) $projWeb)).Path
$programCsPath = Join-Path $webPath 'Program.cs'

if ($WebKind -eq 'mvc') {
  $programContent = @"
using ${SolutionName}.CrossCutting.DependencyInjection.AutoMapper.Config;
using ${SolutionName}.CrossCutting.DependencyInjection.DbConfig;
using ${SolutionName}.CrossCutting.DependencyInjection.Repository;
using ${SolutionName}.CrossCutting.DependencyInjection.Service;
using ${SolutionName}.CrossCutting.DependencyInjection.Validation.Base;
using ${SolutionName}.Shared.Helper.CurrentDirectory;
using Microsoft.AspNetCore.Authentication.Cookies;
using Serilog;
using System.Text.Json.Serialization;

var builder = WebApplication.CreateBuilder(args);

CurrentDirectoryHelper.SetCurrentDirectory();

Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .WriteTo.File("Log\\log-.txt", rollingInterval: RollingInterval.Day)
    .CreateLogger();

builder.Services.AddControllers()
    .AddJsonOptions(x => x.JsonSerializerOptions.ReferenceHandler = ReferenceHandler.IgnoreCycles);
builder.Services.AddControllersWithViews();

builder.Services.AddSqlServerDependency(builder.Configuration);
builder.Services.AddSqlRepositoryDependency();
builder.Services.AddServiceDependency();
builder.Services.AddMapperConfiguration();
builder.Services.AddValidators();

builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.LoginPath = "/Account/Login";
        options.Cookie.Name = "${SolutionName}";
        options.AccessDeniedPath = new PathString("/Home/NotAuthentication/401");
    });

var app = builder.Build();

Log.Information("Atualizando a base de dados do sistema");
// builder.Services.UpdateDatabase(app);

if (!app.Environment.IsDevelopment())
    app.UseExceptionHandler("/Home/Error");

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();
app.UseCookiePolicy();
app.MapControllerRoute(name: "default", pattern: "{controller=Account}/{action=Login}");

await app.RunAsync();
"@
} else {
  $programContent = @"
using ${SolutionName}.CrossCutting.DependencyInjection.AutoMapper.Config;
using ${SolutionName}.CrossCutting.DependencyInjection.DbConfig;
using ${SolutionName}.CrossCutting.DependencyInjection.Repository;
using ${SolutionName}.CrossCutting.DependencyInjection.Service;
using ${SolutionName}.CrossCutting.DependencyInjection.Validation.Base;
using Serilog;
using System.Text.Json.Serialization;

var builder = WebApplication.CreateBuilder(args);

Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .WriteTo.File("Log\\log-.txt", rollingInterval: RollingInterval.Day)
    .CreateLogger();

builder.Services.AddControllers()
    .AddJsonOptions(x => x.JsonSerializerOptions.ReferenceHandler = ReferenceHandler.IgnoreCycles);

builder.Services.AddSqlServerDependency(builder.Configuration);
builder.Services.AddSqlRepositoryDependency();
builder.Services.AddServiceDependency();
builder.Services.AddMapperConfiguration();
builder.Services.AddValidators();

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

Log.Information("Atualizando a base de dados do sistema");
// builder.Services.UpdateDatabase(app);

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseAuthorization();
app.MapControllers();

await app.RunAsync();
"@
}

Set-Content -Path $programCsPath -Value $programContent -Encoding UTF8
Write-Host "  ✓ Program.cs gerado" -ForegroundColor DarkGreen

# ─────────────────────────────────────────────────────────────
# DOCKERFILE + .DOCKERIGNORE — em src/Backend/{projWeb}
# ─────────────────────────────────────────────────────────────
if ($CreateDocker -match '^(y|Y)') {
  Write-Host "`n▶ Gerando Dockerfile e .dockerignore..." -ForegroundColor Yellow

  $expose = if ($WebKind -eq 'webapi') { "EXPOSE 8080`nEXPOSE 8081" } else { "EXPOSE 8080" }

  $dockerfile = @"
# ── Base ──────────────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/aspnet:${sdkMajor} AS base
WORKDIR /app
${expose}

# ── Build ─────────────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/sdk:${sdkMajor} AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src

COPY ["src/Backend/${projWeb}/${projWeb}.csproj",          "src/Backend/${projWeb}/"]
COPY ["src/Backend/${projDomain}/${projDomain}.csproj",    "src/Backend/${projDomain}/"]
COPY ["src/Backend/${projData}/${projData}.csproj",        "src/Backend/${projData}/"]
COPY ["src/Backend/${projService}/${projService}.csproj",  "src/Backend/${projService}/"]
COPY ["src/Backend/${projCrossCutting}/${projCrossCutting}.csproj", "src/Backend/${projCrossCutting}/"]
COPY ["src/Backend/${projShared}/${projShared}.csproj",    "src/Backend/${projShared}/"]
COPY ["src/Backend/${projViewModel}/${projViewModel}.csproj", "src/Backend/${projViewModel}/"]

RUN dotnet restore "src/Backend/${projWeb}/${projWeb}.csproj"
COPY . .

WORKDIR "/src/src/Backend/${projWeb}"
RUN dotnet build "${projWeb}.csproj" -c `$BUILD_CONFIGURATION -o /app/build

# ── Publish ───────────────────────────────────────────────────
FROM build AS publish
RUN dotnet publish "${projWeb}.csproj" -c `$BUILD_CONFIGURATION -o /app/publish /p:UseAppHost=false

# ── Final ─────────────────────────────────────────────────────
FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "${projWeb}.dll"]
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
**/Log
"@

  Set-Content -Path (Join-Path $webPath 'Dockerfile')    -Value $dockerfile    -Encoding UTF8
  Set-Content -Path (Join-Path $root   '.dockerignore')  -Value $dockerignore  -Encoding UTF8
  Write-Host "  ✓ Dockerfile -> src/Backend/$projWeb/Dockerfile" -ForegroundColor DarkGreen
  Write-Host "  ✓ .dockerignore -> raiz da solution"             -ForegroundColor DarkGreen
}

# ─────────────────────────────────────────────────────────────
# .GITIGNORE
# ─────────────────────────────────────────────────────────────
$gitignore = @"
bin/
obj/
*.user
*.suo
.vs/
.env
*.log
Log/
"@
Set-Content -Path (Join-Path $root '.gitignore') -Value $gitignore -Encoding UTF8

Pop-Location # backend

# ─────────────────────────────────────────────────────────────
# RESTORE + BUILD
# ─────────────────────────────────────────────────────────────
Write-Host "`n▶ Executando dotnet restore e build..." -ForegroundColor Yellow

$slnPath = Join-Path $backend "$SolutionName.sln"
Push-Location $root

if (Test-Path $slnPath) {
  & dotnet restore $slnPath | Out-Null
  & dotnet build   $slnPath | Out-Null
} else {
  & dotnet restore | Out-Null
  & dotnet build   | Out-Null
}

# ─────────────────────────────────────────────────────────────
# EXECUÇÃO
# ─────────────────────────────────────────────────────────────
$webProjPath = Join-Path (Join-Path $backend $projWeb) "$projWeb.csproj"
if (Test-Path $webProjPath) {
  Write-Host "`n▶ Iniciando '$projWeb' com 'dotnet run'..." -ForegroundColor Yellow
  Write-Host "  Dica: pressione Ctrl+C para parar." -ForegroundColor DarkYellow
  Push-Location (Split-Path $webProjPath -Parent)
  & dotnet run
  Pop-Location
} else {
  Write-Host "Não foi possível localizar o projeto Web em: $webProjPath" -ForegroundColor Red
}

Pop-Location

# ─────────────────────────────────────────────────────────────
# RESUMO
# ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  ✅ '$SolutionName' criada com sucesso!"            -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  .NET  : $TargetFramework"
Write-Host "  Web   : $WebKind  |  ORM: $OrmKind"
Write-Host "  Pasta : $root"
if ($CreateDocker -match '^(y|Y)') {
Write-Host "  Docker: src/Backend/$projWeb/Dockerfile"
}
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
