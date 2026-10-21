# SQL Server Setup – Simple Guide

| Setting | Value |
|---|---|
| Server | `127.0.0.1,1433` |
| Database | `Datacube` |
| Admin login | `sa` / `DataCube123!` (setup only) |
| App login | `datacube_analytics` / `Analytics_Pass123!` (Python, Power BI, DBeaver) |
| Schemas | `bronze`, `silver`, `gold` |
| Container | `superstore_sqlserver` |

---

## 1. Start SQL Server (in the codespace)

```bash
docker compose up -d
docker ps          # superstore_sqlserver must show "(healthy)" after ~30 sec
```

> Always use `-d`. Without it, the terminal shows live logs and `Ctrl+C` **stops SQL Server**.
> If you forgot `-d`, press **`d`** to detach — the container keeps running.

> The `sa` password in the Python code must match `MSSQL_SA_PASSWORD` in `docker-compose.yml`.

---


## 2. Connect your PC to the codespace (VS Code desktop)

Power BI and DBeaver run on your PC, but SQL Server runs in the codespace.
VS Code desktop builds the connection between them automatically.

### First time only

1. Install **VS Code** from code.visualstudio.com.
2. In VS Code: **Extensions** → install **Remote explorer** → sign in to GitHub.

### Every time

1. Open VS Code → **Remote Explorer** (left bar) → choose **GitHub Codespaces** at the top.
2. Right-click your codespace (**Global_Superstore- · fictional adventure**) → **Connect in Current Window**.
   *Or:* in the browser codespace, **☰ menu → Open in VS Code Desktop**.
3. Wait until the bottom-left corner shows **Codespaces: fictional adventure**.
4. Start SQL Server if needed: `docker compose up -d`.
5. Open the **Ports** tab (bottom panel). Row **1433** must show:

   | Port | Forwarded Address | Visibility |
   |---|---|---|
   | 1433 | `127.0.0.1:1433` | Private |

6. **Keep VS Code open** while you use Power BI or DBeaver. Closing VS Code closes the connection.


---

## 4. Power BI

### Connect

1. **Get data → SQL Server**
2. Server: `127.0.0.1,1433` · Database: `Datacube`
3. Data Connectivity mode: **Import** (see below)
4. Login: **Database** tab (not Windows) → `datacube_analytics` / `Analytics_Pass123!` → **Connect**
5. "Encrypted connection" warning → click **OK**
6. Select only the **gold** tables → **Load**
7. In **Model view**: connect dimensions to facts (1 → *), mark `dim_date` as date table
8. New data? → **Refresh** (VS Code must be open and connected)



**Import** copies the data into the Power BI file.

- ✅ Fast: visuals load instantly
- ✅ Works offline: VS Code only needs to be open when you click **Refresh**
- ✅ All DAX and Power Query features work
- ❌ Data is a snapshot: click **Refresh** to get new data
- ❌ The `.pbix` file gets bigger with large tables

**DirectQuery** keeps the data in SQL Server. Every click on a visual sends a query to the database.

- ✅ Always shows the latest data
- ✅ Handles very large tables
- ❌ Slower: every visual waits for SQL Server
- ❌ VS Code and the codespace must be running the whole time
- ❌ Some DAX functions and Power Query steps are not allowed

| | Import | DirectQuery |
|---|---|---|
| Speed | Fast | Slower |
| Data freshness | After Refresh | Live |
| Needs connection | Only for Refresh | Always |
| DAX / Power Query | Everything | Limited |
| Best for | This project | Huge or real-time data |

**For this project, use Import.**

---

## 5. DBeaver

1. **New Database Connection → SQL Server**
2. Host `127.0.0.1` · Port `1433` · Database `Datacube`
3. User `datacube_analytics` · Password `Analytics_Pass123!` · tick **Save password**
4. Tick **Trust Server Certificate**
5. **Test Connection** → **Finish**

Run one line: `Ctrl + Enter` · Run all: `Alt + X`

---


