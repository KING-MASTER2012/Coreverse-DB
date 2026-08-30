<p style="text-align: center">
  <img src="assets/emblems/coreverse-emblem.svg" alt="Coreverse Emblem" width="160">
</p>

<h1 style="text-align: center">Coreverse DB</h1>

<p style="text-align: center">
  <strong>Centralized database and data-access infrastructure for the Coreverse ecosystem.</strong>
</p>

<p style="text-align: center">
  Secure · Modular · API-driven · Migration-based
</p>

---

<p style="text-align: center">
  <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/postgresql/postgresql-original.svg" width="56" height="56" alt="PostgreSQL">
  &nbsp;&nbsp;
  <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/supabase/supabase-original.svg" width="56" height="56" alt="Supabase">
  &nbsp;&nbsp;
  <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/denojs/denojs-original.svg" width="56" height="56" alt="Deno">
  &nbsp;&nbsp;
  <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/docker/docker-original.svg" width="56" height="56" alt="Docker">
  &nbsp;&nbsp;
  <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/git/git-original.svg" width="56" height="56" alt="Git">
</p>

<p style="text-align: center">
  <sub>
    PostgreSQL 17 · Supabase · Deno 2 · Docker · Git
  </sub>
</p>

<p style="text-align: center">
  <a href="https://www.postgresql.org/">PostgreSQL</a> ·
  <a href="https://supabase.com/">Supabase</a> ·
  <a href="https://deno.com/">Deno</a> ·
  <a href="https://www.openapis.org/">OpenAPI</a> ·
  <a href="https://www.docker.com/">Docker</a>
</p>

---

## ✨ Overview

**Coreverse DB** is the centralized database and backend layer of the **Coreverse ecosystem**.

It provides a secure, structured, and version-controlled data platform for Coreverse applications and services, including:

* Engine release distribution
* User profiles and identity
* Teams and memberships
* Project metadata
* Community news
* Polls and voting
* Discussions and replies
* API access
* File storage integration

Coreverse DB intentionally separates clients from the underlying PostgreSQL implementation.

```text
┌──────────────────────┐  ┌─────────────────────┐
│  Coreverse Website   │  │  Coreverse Launcher │
└──────────┬───────────┘  └──────────┬──────────┘
           │                         │
           ▼                         ▼            
     ┌──────────────────────────────────────┐
     │            Coreverse DB API          │
     │        Supabase Edge Functions       │
     └──────────────────┬───────────────────┘
                        │
                        ▼
     ┌──────────────────────────────────────┐
     │             PostgreSQL 17            │
     │                                      │
     │  releases · identity · content       │
     │  RLS · Functions · Triggers          │
     └──────────────────┬───────────────────┘
                        │
                        ▼
               ┌─────────────────┐
               │ Supabase Storage│
               └─────────────────┘
```

Applications consume the Coreverse DB API rather than connecting directly to PostgreSQL.

---

## 🚀 Key Features

| Feature                         | Description                                                                    |
|---------------------------------| ------------------------------------------------------------------------------ |
| 🔐 **Database-level Security**  | PostgreSQL Row Level Security, controlled functions, constraints, and triggers |
| 👤 **Identity Management**      | Profiles, teams, memberships, invitations, and ownership transfers             |
| 📦 **Release Management**       | Engine versions, platform artifacts, requirements, and SHA-256 verification    |
| 📰 **Community Content**        | News, polls, discussions, and replies                                          |
| 🗃️ **Project Metadata**         | Ownership, team association, archive metadata, and integrity information       |
| 📡 **OpenAPI Contract**         | Explicit OpenAPI 3.1 API specification                                         |
| 🧪 **Testing**                  | pgTAP database tests and Deno Edge Function tests                              |
| 🔄 **Migration-driven Schema**  | Reproducible Supabase migrations                                               |
| ☁️ **Storage Integration**      | Supabase Storage for binary/project assets                                     |
| ⚡ **Edge Runtime**             | Deno 2-based Supabase Edge Functions                                           |

---

## 🧱 Technology Stack

| Layer             | Technology                  |
| ----------------- | --------------------------- |
| Database          | **PostgreSQL 17**           |
| Backend Platform  | **Supabase**                |
| API Runtime       | **Supabase Edge Functions** |
| Edge Runtime      | **Deno 2**                  |
| Database Language | **PL/pgSQL**                |
| API Specification | **OpenAPI 3.1**             |
| Authentication    | **Supabase Auth**           |
| File Storage      | **Supabase Storage**        |
| Database Testing  | **pgTAP**                   |
| Function Testing  | **Deno Test**               |
| Documentation     | **mdBook**                  |

---

# 🏗️ Architecture

Coreverse DB is organized around independent database domains.

| Domain          | Responsibility                              | PostgreSQL Schema |
| --------------- | ------------------------------------------- | ----------------- |
| 📦 **Releases** | Engine releases and downloadable artifacts  | `releases`        |
| 👤 **Identity** | Profiles, teams, memberships, and projects  | `identity`        |
| 📰 **Content**  | News, polls, discussions, and replies       | `content`         |
| 🔒 **Private**  | Internal security and authorization helpers | `private`         |

### Releases

The `releases` domain manages Coreverse Engine release metadata and downloadable artifacts.

Each release contains general metadata, while artifacts are represented independently per platform and architecture.

| Platform | Architectures     |
| -------- | ----------------- |
| Windows  | `x86_64`, `arm64` |
| Linux    | `x86_64`, `arm64` |
| macOS    | `x86_64`, `arm64` |

Artifacts contain download URLs, SHA-256 hashes, file sizes, minimum requirements, and compiler metadata.

### Identity

The `identity` domain manages application-level identity and collaboration.

```text
identity
├── profiles
├── teams
├── team_members
├── team_membership_requests
├── projects
└── platform_roles
```

Authentication is delegated to Supabase Auth. Coreverse DB never stores passwords.

Team operations are protected through RLS and controlled database functions.

### Content

The `content` domain powers Coreverse community and website functionality.

```text
content
├── news
├── polls
├── poll_options
├── poll_votes
├── discussions
└── discussion_replies
```

The authorization model distinguishes between ordinary users and platform-level moderators/admins.

Individual poll votes remain protected while aggregate results can be publicly exposed.

---

# 🔐 Security Model

Coreverse DB uses **defense in depth**, combining PostgreSQL RLS, database constraints, triggers, controlled functions, and Supabase authentication.

| Mechanism                      | Purpose                               |
| ------------------------------ | ------------------------------------- |
| **Row Level Security**         | Per-row authorization                 |
| **SECURITY DEFINER Functions** | Controlled privileged operations      |
| **Constraints**                | Database-level data integrity         |
| **Triggers**                   | Cross-row / lifecycle integrity rules |
| **Supabase Auth**              | Authentication and user identity      |
| **Least Privilege Grants**     | Restrict direct database operations   |

---

# 📡 API

The public API is formally defined using **OpenAPI 3.1**.

```text
openapi/
├── paths/
├── schemas/
└── openapi.yaml
```

### API Areas

| Endpoint       | Purpose                        |
| -------------- | ------------------------------ |
| `/releases`    | Engine releases and artifacts  |
| `/teams`       | Team management                |
| `/requests`    | Membership request actions     |
| `/profiles/me` | Current user's profile         |
| `/projects`    | Project metadata and downloads |
| `/news`        | Platform news                  |
| `/polls`       | Polls, voting, and results     |
| `/discussions` | Discussions and replies        |

---

# 📁 Repository Structure

```text
Coreverse-DB/
│
├── assets/
│   └── emblems/
│       └── coreverse-emblem.svg
│
├── docs/
│   ├── src/
│   └── book.toml
│
├── openapi/
│   ├── paths/
│   ├── schemas/
│   └── openapi.yaml
│
├── supabase/
│   ├── functions/
│   ├── migrations/
│   ├── tests/
│   ├── seed.sql
│   └── config.toml
│
├── .env.example
├── deno.json
├── deno.lock
├── LICENSE
└── README.md
```

---

# 🛠️ Development

## Requirements

| Tool             | Purpose                               |
| ---------------- | ------------------------------------- |
| **Git**          | Source control                        |
| **Docker**       | Local Supabase infrastructure         |
| **Supabase CLI** | Database and local backend management |
| **Deno 2**       | Edge Function runtime and testing     |

## Clone

```bash
git clone https://github.com/KING-MASTER2012/Coreverse-DB.git
cd Coreverse-DB
```

## Environment

### Linux / macOS

```bash
cp .env.example .env
```

### Windows PowerShell

```powershell
Copy-Item .env.example .env
```

Never commit credentials, service-role keys, OAuth secrets, JWT signing keys, or other sensitive values.

---

## ▶️ Start Local Supabase

```bash
supabase start
```

| Service         |    Port |
| --------------- | ------: |
| Supabase API    | `54321` |
| PostgreSQL      | `54322` |
| Supabase Studio | `54323` |
| Mail Testing UI | `54324` |

---

## ♻️ Reset the Database

```bash
supabase db reset
```

This recreates the local database from the project's migrations and seed data.

---

## ⚡ Edge Functions

Development:

```bash
deno task dev
```

Testing:

```bash
deno task test
```

---

# 🧪 Testing

Testing is divided into database-level and Edge Function tests.

### Database Testing

Database tests use **pgTAP** and cover areas such as:

* RLS behavior
* Authorization boundaries
* Database functions
* Constraints
* Triggers
* Data integrity
* State transitions

### Edge Function Testing

```bash
deno task test
```

---

# 🔄 Database Migrations

Schema changes are tracked through timestamped Supabase migrations.

```text
supabase/migrations/
├── <timestamp>_<description>.sql
├── <timestamp>_<description>.sql
└── ...
```

Migrations should remain deterministic, ordered, reproducible, and reviewable.

---

# 📚 Documentation

Coreverse DB documentation is maintained with **mdBook**.

```text
docs/
├── src/
└── book.toml
```

Documentation title:

> **Coreverse DB Documentation**

---

# 📐 Design Principles

| Principle                      | Goal                                                  |
| ------------------------------ | ----------------------------------------------------- |
| **Database Authority**         | PostgreSQL is authoritative for data integrity        |
| **Server-side Authorization**  | Security decisions never rely solely on clients       |
| **RLS-first Security**         | Row-level access is enforced by PostgreSQL            |
| **Transactional Operations**   | Multi-step state changes occur atomically             |
| **API Decoupling**             | Clients depend on the API rather than internal tables |
| **Migration-driven Evolution** | Schema changes remain reproducible                    |
| **Explicit Contracts**         | API behavior is documented through OpenAPI            |
| **Separated Storage**          | Binary assets live in object storage                  |
| **Least Privilege**            | Database roles receive only required permissions      |

---

# 🔗 Coreverse Ecosystem

| Project                | Role                                 |
| ---------------------- | ------------------------------------ |
| **Coreverse Engine**   | Engine and runtime                   |
| **Coreverse Launcher** | Engine installation and distribution |
| **Coreverse Website**  | Public website and community         |
| **Coreverse DB**       | Centralized data and backend layer   |

---

# 📌 Project Status

> **Development / Early Stage**

Coreverse DB is actively evolving alongside the rest of the Coreverse ecosystem.

Database schemas, API contracts, RLS policies, migrations, and internal implementation details may change between development versions.

Production integrations should rely on versioned API and database contracts rather than unreleased internal behavior.

---

# 📄 License

Coreverse DB is licensed under the **GNU General Public License v3.0**.

See [`LICENSE`](LICENSE) for the complete license text.

---

<p style="text-align: center">
  <img src="assets/emblems/coreverse-emblem.svg" alt="Coreverse" width="72">
  <br>
  <strong>Coreverse DB</strong>
  <br>
  <sub>Centralized data infrastructure for the Coreverse ecosystem.</sub>
</p>
