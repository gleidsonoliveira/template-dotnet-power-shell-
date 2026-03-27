# GitHub Copilot — Analisar e Replicar Estrutura CRM (AtomoHub Pattern)

> Cole no **GitHub Copilot Chat** com `@workspace`, ou salve em `.github/copilot-instructions.md`.  
> O agente **não inventa arquitetura**. Ele lê o projeto existente, faz perguntas, e gera o script PowerShell `new-crm-solution.ps1` atualizado.  
> Use os agentes disponíveis na pasta `.github/agents/` para cada etapa.

---

## PASSO 1 — ANÁLISE SILENCIOSA DO WORKSPACE

Execute antes de qualquer pergunta. Não exiba resultado ainda.

```
@workspace Analise e mapeie internamente:

1. Camadas encontradas e tipo de cada projeto .csproj
   (Domain, Data, Service, CrossCutting, Shared, ViewModel, Web/WebApi)

2. Estrutura de pastas dentro de CrossCutting:
   - DependencyInjection/AutoMapper/Config
   - DependencyInjection/DbConfig
   - DependencyInjection/Repository
   - DependencyInjection/Service
   - DependencyInjection/Validation/Base

3. ORM detectado:
   - EF Core → presença de DbContext, UseSqlServer/UseMySql, Migrations
   - Dapper → presença de IDbConnection, SqlConnection, QueryAsync/ExecuteAsync
   - Ambos → registre os dois

4. Pacotes NuGet por projeto (nome + versão atual)

5. Referências entre projetos (quem referencia quem)

6. Program.cs do projeto Web — registre os middlewares e extensões usadas

7. Existência de Dockerfile e .dockerignore no projeto de apresentação

8. Versão do .NET em uso (TargetFramework de cada .csproj)
```

Armazene esse mapa. Siga para o Passo 2.

---

## PASSO 2 — PERGUNTAS (faça todas de uma vez)

```
Analisei a estrutura. Preciso confirmar algumas informações antes de gerar o script:

1. Versão do .NET do NOVO projeto:
   [ ] net6.0  [ ] net7.0  [ ] net8.0  [ ] net9.0  [ ] net10.0

2. Tipo do projeto de apresentação:
   [ ] WebApi (controllers + Swagger)
   [ ] MVC (controllers + Views + Cookie Auth)

3. ORM a utilizar:
   [ ] EF Core (DbContext, Migrations)
   [ ] Dapper  (IDbConnectionFactory + RepositoryBase<T> estilo OnlineAuction.Data)

4. Banco de dados:
   [ ] SQL Server   [ ] MySQL/MariaDB (Pomelo)   [ ] PostgreSQL

5. Criar projeto de testes NUnit?
   [ ] Sim (com Moq + coverlet)   [ ] Não

6. Gerar Dockerfile e .dockerignore?
   [ ] Sim   [ ] Não

7. Deseja manter a estrutura exatamente como detectada, ou posso sugerir melhorias?
   [ ] Manter fiel   [ ] Aceito sugestões pontuais (sem mudar camadas)
```

---

## PASSO 3 — REGRAS DE GERAÇÃO

### 3.1 Estrutura de projetos (fiel ao padrão detectado)

```
src/
  Backend/
    {Solution}.Domain         → classlib
    {Solution}.Data           → classlib
    {Solution}.Service        → classlib
    {Solution}.CrossCutting   → classlib
    {Solution}.Shared         → classlib
    {Solution}.ViewModel      → classlib
    {Solution}.WebApi         → webapi   (ou .Web → mvc)
  Frontend/                   → pasta reservada
```

### 3.2 Referências entre projetos (não alterar sem pedido explícito)

```
CrossCutting → Data, Service
Shared       → Domain
Service      → Shared, ViewModel, Domain
Data         → Domain
Web/WebApi   → CrossCutting, Shared, ViewModel, Domain
Tests        → Service
```

### 3.3 Versões de pacotes por TFM

Sempre use a versão estável mais recente compatível com o TFM escolhido.  
Referência de mapeamento obrigatório:

| Pacote                                        | net6   | net7   | net8   | net9   | net10  |
|-----------------------------------------------|--------|--------|--------|--------|--------|
| EF Core / Identity EF                         | 6.0.36 | 7.0.20 | 8.0.11 | 9.0.4  | 10.0.0 |
| Pomelo.EntityFrameworkCore.MySql              | 6.0.3  | 7.0.0  | 8.0.2  | 9.0.0  | 10.0.0 |
| Dapper                                        | 2.1.35 | 2.1.35 | 2.1.35 | 2.1.35 | 2.2.0  |
| Microsoft.Data.SqlClient                      | 5.2.2  | 5.2.2  | 5.2.2  | 6.0.1  | 6.0.1  |
| AutoMapper                                    | 12.0.1 | 12.0.1 | 13.0.1 | 13.0.1 | 13.0.1 |
| FluentValidation / FluentValidation.AspNetCore| 11.9.0 | 11.9.0 | 11.9.0 | 11.9.2 | 11.10.0|
| Scrutor                                       | 4.2.2  | 4.2.2  | 6.1.0  | 6.1.0  | 6.1.0  |
| Serilog.AspNetCore                            | 6.0.0  | 7.0.0  | 8.0.4  | 9.0.0  | 9.0.0  |
| Swashbuckle.AspNetCore                        | 6.5.0  | 6.5.0  | 6.9.0  | 7.2.0  | 7.3.0  |
| Moq                                           | 4.20.70| 4.20.70| 4.20.70| 4.20.72| 4.20.72|

### 3.4 CrossCutting — arquivos obrigatórios

Gerar sempre, independente do ORM:

```
DependencyInjection/
  AutoMapper/Config/MapperConfigurationExtensions.cs
  DbConfig/DbDependencyExtensions.cs          ← varia por ORM (ver 3.5)
  Repository/RepositoryDependencyExtensions.cs
  Service/ServiceDependencyExtensions.cs
  Validation/Base/ValidationExtensions.cs
```

### 3.5 Se ORM = Dapper

Gerar em **CrossCutting/DependencyInjection/DbConfig**:
- `IDbConnectionFactory` + `SqlConnectionFactory` (abre `SqlConnection` via connection string)
- `DbDependencyExtensions.AddSqlServerDependency()` registrando `IDbConnectionFactory` como `Scoped`

Gerar em **Data/Repositories**:
- `RepositoryBase<T>` com:
  - `protected abstract string TableName { get; }`
  - `GetByIdAsync`, `GetAllAsync`, `AddAsync`, `UpdateAsync`, `DeleteAsync` via `Dapper.CommandDefinition`
  - `ExecuteInTransactionAsync(Func<IDbConnection, IDbTransaction, Task<int>>)` para operações transacionais
  - Uso de `IDbConnectionFactory` injetado (sem `new SqlConnection` direto)

### 3.6 Se ORM = EF Core

Gerar em **CrossCutting/DependencyInjection/DbConfig**:
- `DbDependencyExtensions.AddSqlServerDependency()` com `AddDbContextPool<YourDbContext>`
- Stub com `TODO` para o nome real do DbContext

### 3.7 Program.cs — padrão fiel ao original

**MVC:**
```csharp
// Inclui: CurrentDirectoryHelper.SetCurrentDirectory()
// Serilog File, AddControllersWithViews, Cookie Auth
// AddSqlServerDependency, AddSqlRepositoryDependency,
// AddServiceDependency, AddMapperConfiguration, AddValidators
// MapControllerRoute → Account/Login
```

**WebApi:**
```csharp
// Inclui: Serilog File, AddControllers + IgnoreCycles
// AddSqlServerDependency, AddSqlRepositoryDependency,
// AddServiceDependency, AddMapperConfiguration, AddValidators
// AddSwaggerGen, UseSwagger/UseSwaggerUI (apenas em Development)
```

### 3.8 Dockerfile (somente se solicitado)

Gerar dentro de `src/Backend/{Solution}.WebApi` ou `src/Backend/{Solution}.Web`.

```dockerfile
# ── Base ──────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/aspnet:{MAJOR} AS base
WORKDIR /app
EXPOSE 8080
EXPOSE 8081   # somente WebApi

# ── Build ─────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/sdk:{MAJOR} AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src

# COPY de todos os .csproj da solution (um por linha)
COPY ["src/Backend/{Web}/{Web}.csproj",                 "src/Backend/{Web}/"]
COPY ["src/Backend/{Domain}/{Domain}.csproj",           "src/Backend/{Domain}/"]
COPY ["src/Backend/{Data}/{Data}.csproj",               "src/Backend/{Data}/"]
COPY ["src/Backend/{Service}/{Service}.csproj",         "src/Backend/{Service}/"]
COPY ["src/Backend/{CrossCutting}/{CrossCutting}.csproj","src/Backend/{CrossCutting}/"]
COPY ["src/Backend/{Shared}/{Shared}.csproj",           "src/Backend/{Shared}/"]
COPY ["src/Backend/{ViewModel}/{ViewModel}.csproj",     "src/Backend/{ViewModel}/"]

RUN dotnet restore "src/Backend/{Web}/{Web}.csproj"
COPY . .
WORKDIR "/src/src/Backend/{Web}"
RUN dotnet build "{Web}.csproj" -c $BUILD_CONFIGURATION -o /app/build

# ── Publish ───────────────────────────────────────────
FROM build AS publish
RUN dotnet publish "{Web}.csproj" -c $BUILD_CONFIGURATION -o /app/publish /p:UseAppHost=false

# ── Final ─────────────────────────────────────────────
FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "{Web}.dll"]
```

**.dockerignore** (na raiz da solution):
```
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
```

---

## PASSO 4 — GERAÇÃO DO SCRIPT

Gere o arquivo `new-crm-solution.ps1` completo, seguindo exatamente:

1. **Parâmetros** com `[ValidateSet]` incluindo net6.0 até net10.0
2. **`$PkgMap`** — hashtable com versões por TFM (tabela do Passo 3.3)
3. **`Read-IfEmpty`** para inputs interativos opcionais
4. Perguntas interativas: `$CreateTests` e `$CreateDocker` via `Read-Host`
5. Criação de projetos na ordem: Domain → Data → Service → CrossCutting → Shared → ViewModel → Web
6. `dotnet sln add` em array único
7. `dotnet add package` por projeto usando versões do `$PkgMap[$TargetFramework]`
8. Referências entre projetos (exatamente as do Passo 3.2)
9. Geração dos arquivos CrossCutting com `New-CsFile`
10. Se Dapper: gerar `RepositoryBase<T>` em `Data/Repositories/`
11. Se MVC: gerar `CurrentDirectoryHelper` em `Shared/Helper/CurrentDirectory/`
12. `Program.cs` customizado conforme tipo de projeto
13. Se Docker: Dockerfile em `src/Backend/{Web}/` + `.dockerignore` na raiz
14. `.gitignore` na raiz
15. `dotnet restore` + `dotnet build` + `dotnet run`
16. Resumo final colorido com todos os parâmetros usados

**Regras do script:**
- Idempotente: usa `-Force` em todos os `New-Item`
- Sem hardcode de versões fora do `$PkgMap`
- Comentários em português
- `| Out-Null` em todos os comandos dotnet (exceto `dotnet run`)
- `Write-Host` com `-ForegroundColor` para cada etapa

---

## PASSO 5 — ENTREGA

Entregue nesta ordem, sem texto extra:

1. **Tabela de análise:** Projeto | Tipo | ORM detectado | Pacotes principais | Versão atual
2. **`new-crm-solution.ps1`** completo e funcional
3. (Se solicitado) Lista de melhorias aplicadas com justificativa de uma linha cada
