# Connect Power BI (and DBeaver) to SQL Server 2022 in Docker

SQL Server is Microsoft's own database, so **Power BI connects to it with a built-in connector**: no extra driver to install.

| Setting | Value |
|---|---|
| Server (Power BI) | `localhost,1433` ← a **comma**, not a colon |
| Host / Port (DBeaver) | `localhost` / `1433` |
| Database | `dw` (one database with 3 schemas: `bronze`, `silver`, `gold`) |
| User / Password | `de_user` / `de_pass` |
| Admin (only for setup) | `sa` / `DataEng#2026` |

> **Difference to MySQL:** in MySQL, bronze / silver / gold were 3 *databases*.
> In SQL Server we use **1 database (`dw`) with 3 schemas**, so a table is called `gold.dim_customer`.

---

## 1. Downloads (Windows PC)

| What | Link | Note |
|---|---|---|
| **Power BI Desktop** | https://www.microsoft.com/en-us/download/details.aspx?id=58494 | the SQL Server connector is built in |
| **DBeaver Community** | https://dbeaver.io/files/dbeaver-ce-latest-windows-x86_64.exe | free SQL editor (all versions: https://dbeaver.io/download/) |
| SSMS (optional) | https://learn.microsoft.com/sql/ssms/download-sql-server-management-studio-ssms | Microsoft's own SQL Server tool |
| Docker Desktop (only if Docker runs on your PC) | https://www.docker.com/products/docker-desktop/ | not needed for GitHub Codespaces |
| GitHub CLI (only for Codespaces) | https://cli.github.com/ | or `winget install --id GitHub.cli` |

---

## 2. Docker files

Put these two files in the project folder.

### `docker-compose.yml`

```yaml
# Start:  docker compose up -d
# Stop:   docker compose down        (data is kept)
# Reset:  docker compose down -v     (deletes all data)
services:
  sqlserver:
    image: mcr.microsoft.com/mssql/server:2022-latest
    container_name: project_sqlserver
    restart: unless-stopped
    environment:
      ACCEPT_EULA: "Y"
      MSSQL_SA_PASSWORD: "DataEng#2026"     # 8+ characters with upper case, lower case, a number and a symbol
      MSSQL_PID: "Developer"                # free edition with all features
    ports:
      - "1433:1433"                         # your PC: 1433 → SQL Server in the container: 1433
    volumes:
      - mssql_data:/var/opt/mssql
    healthcheck:                            # "healthy" = SQL Server is ready for connections
      test: ["CMD-SHELL", "/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P \"$$MSSQL_SA_PASSWORD\" -C -Q \"SELECT 1\" -b -o /dev/null"]
      interval: 10s
      timeout: 5s
      retries: 20
      start_period: 20s

  # Runs docker/init.sql ONCE when SQL Server is ready, then stops (that is normal).
  # SQL Server does not run init scripts by itself like MySQL does.
  sqlserver-init:
    image: mcr.microsoft.com/mssql/server:2022-latest
    depends_on:
      sqlserver:
        condition: service_healthy
    volumes:
      - ./docker/init.sql:/init.sql:ro
    entrypoint: ["/opt/mssql-tools18/bin/sqlcmd", "-S", "sqlserver", "-U", "sa", "-P", "DataEng#2026", "-C", "-i", "/init.sql"]
    restart: "no"

volumes:
  mssql_data:
```

### `docker/init.sql`

```sql
-- Creates the database, the three layers (schemas) and the user for Python, Power BI and DBeaver.
-- Safe to run again: everything checks first whether it already exists.

IF DB_ID('dw') IS NULL
    CREATE DATABASE dw;
GO

USE dw;
GO

IF SCHEMA_ID('bronze') IS NULL EXEC('CREATE SCHEMA bronze');   -- raw data, exactly as received
IF SCHEMA_ID('silver') IS NULL EXEC('CREATE SCHEMA silver');   -- cleaned and merged data
IF SCHEMA_ID('gold')   IS NULL EXEC('CREATE SCHEMA gold');     -- star schema, views, ML results (Power BI)
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'de_user')
    CREATE LOGIN de_user WITH PASSWORD = 'de_pass', CHECK_POLICY = OFF, DEFAULT_DATABASE = dw;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'de_user')
    CREATE USER de_user FOR LOGIN de_user;
ALTER ROLE db_owner ADD MEMBER de_user;          -- may create tables and views in all three schemas
GO

PRINT 'dw database with bronze, silver, gold is ready';
```

### Start and check

```bash
docker compose up -d
docker ps                                   # project_sqlserver must show "(healthy)" after ~30 seconds
docker compose logs sqlserver-init          # must end with: dw database with bronze, silver, gold is ready
```

Test the user from the command line:

```bash
docker exec -it project_sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U de_user -P de_pass -C -d dw \
  -Q "SELECT name FROM sys.schemas WHERE name IN ('bronze','silver','gold')"
```

> **GitHub Codespaces:** SQL Server needs ~2 GB of memory. A normal Codespace (2 cores, 8 GB) is fine.
> **Mac with Apple chip (M1–M4):** this image is made for Intel/AMD and runs slowly or not at all. Use Codespaces instead.

---

## 3. Reach the database from your PC

- **Docker on your own PC** → use `localhost,1433`, nothing else to do.
- **GitHub Codespaces** → open a tunnel on your PC and keep the window open:
  ```bash
  gh auth login                              # once
  gh codespace ports forward 1433:1433       # choose your codespace
  ```
  (Or open the codespace in the **VS Code desktop app** → **Ports** tab → **Forward a Port** → `1433`.)

> Is SQL Server also installed on your PC? Then 1433 is taken: use `"1434:1433"` in `docker-compose.yml`
> and `localhost,1434` everywhere.

---

## 4. Power BI Desktop

1. **Home → Get data → SQL Server** (it is in the first list, no "More…" needed).
2. **Server:** `localhost,1433` · **Database:** `dw` · **Data connectivity mode:** **Import** → **OK**.
3. Credentials: choose the **Database** tab on the left (*not* Windows, *not* Microsoft account)
   → User name `de_user` · Password `de_pass` → **Connect**.
4. Power BI may say: *"We were unable to connect to the data source using an encrypted connection"* →
   click **OK** (unencrypted is fine on your own PC; the container uses a self-signed certificate).
5. **Navigator:** open `dw` and tick only the **gold** tables and views, for example
   `gold.dim_customer`, `gold.fact_orders`, `gold.vw_monthly_kpis` → **Transform Data** or **Load**.
6. Optional: in Power Query rename `gold dim_customer` → `dim_customer` (shorter names in the report).
7. **Model view:** draw the relationships (dimension `1` → fact `*`), select `dim_date` → **Mark as date table**,
   then add your DAX measures, as described in every project README.
8. After new data: **Home → Refresh**.

**Change the connection later:** **File → Options and settings → Data source settings** → select `localhost,1433;dw`
→ **Edit Permissions** (credentials, *Encrypt connections*) or **Change Source** (server, database).

---

## 5. DBeaver Community (write and test SQL)

1. **Database → New Database Connection → SQL Server → Next**.
2. Host `localhost` · Port `1433` · Database `dw`.
3. Authentication: **SQL Server Authentication** · User `de_user` · Password `de_pass` · tick **Save password**.
4. Tick **Trust Server Certificate** (or, in the **Driver properties** tab: `trustServerCertificate` = `true`).
5. **Test Connection** → DBeaver downloads the SQL Server driver the first time → **Finish**.
6. You see `dw` → `Schemas` → `bronze`, `silver`, `gold`.
   Right-click `gold` → **View Diagram** shows the star schema.

Run a statement with `Ctrl + Enter`, the whole script with `Alt + X`.

---

## 6. Python (for when you move the notebooks to SQL Server)

```bash
pip install pymssql
```

```python
from sqlalchemy import create_engine

engine = create_engine("mssql+pymssql://de_user:de_pass@localhost:1433/dw")

df.to_sql("orders", engine, schema="bronze", if_exists="replace", index=False)    # write
pd.read_sql("SELECT TOP 10 * FROM gold.vw_monthly_kpis", engine)                 # read
```

Note: `schema="bronze"` replaces the separate `bronze` engine we used for MySQL.

SQL differences you will meet (MySQL → SQL Server):

| MySQL | SQL Server (T-SQL) |
|---|---|
| `SELECT … LIMIT 10` | `SELECT TOP 10 …` |
| `CREATE TABLE t AS SELECT …` | `SELECT … INTO gold.t FROM …` |
| `CREATE OR REPLACE VIEW` | `CREATE OR ALTER VIEW` |
| `DROP TABLE IF EXISTS t` | `DROP TABLE IF EXISTS gold.t` (same) |
| `DATE_FORMAT(d, '%Y-%m')` | `FORMAT(d, 'yyyy-MM')` |
| `YEAR(d)`, `MONTH(d)` | `YEAR(d)`, `MONTH(d)` (same) |
| `IFNULL(a, b)` | `ISNULL(a, b)` or `COALESCE(a, b)` |
| `CONCAT(a, b)` | `CONCAT(a, b)` (same) |
| `ORDER BY` inside a view | not allowed → sort in Power BI or in the query that reads the view |
| `SHOW TABLES` | `SELECT * FROM INFORMATION_SCHEMA.TABLES` |
| statements separated by `;` | in scripts also `GO` between batches (`CREATE VIEW` must be the first statement of a batch) |

---

## 7. Problems and fixes

| Problem | Fix |
|---|---|
| Container stops right after the start | Password too weak → `docker logs project_sqlserver`. Use 8+ characters with upper, lower, number and symbol. |
| `sqlcmd: no such file or directory` | Older image: use `/opt/mssql-tools/bin/sqlcmd` and remove the `-C` option. |
| *Login failed for user 'de_user'* | `init.sql` did not run → `docker compose logs sqlserver-init`, run it again: `docker compose up sqlserver-init` |
| Power BI: *A network-related or instance-specific error* | Container running (`docker ps`)? Codespaces tunnel open? Server written as `localhost,1433` (comma)? |
| *The certificate chain was issued by an authority that is not trusted* | Power BI: click **OK** for an unencrypted connection. DBeaver: **Trust Server Certificate**. |
| Power BI asks for Windows login | Choose the **Database** tab and type `de_user` / `de_pass`. |
| Port 1433 is already used | Another SQL Server runs on your PC → `"1434:1433"` and `localhost,1434`. |
| Navigator is empty | No tables yet → run the notebooks first (they write to `dw.gold`). |
| Data is gone after restart | You ran `docker compose down -v` (the `-v` deletes the data volume). Use `docker compose down`. |
