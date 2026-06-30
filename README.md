*This project has been created as part of the 42 curriculum by pchazalm.*

# Inception

## Description

Inception is a system administration project from the 42 curriculum. Its goal is to set up a small infrastructure composed of several Docker containers, each running a single service, and orchestrated with Docker Compose inside a virtual machine.

The stack provides a fully functional WordPress website served over HTTPS:

- **NGINX** — the only entry point of the infrastructure, exposed on port `443` with TLSv1.2 / TLSv1.3 only.
- **WordPress + php-fpm** — runs the WordPress application, exposing only `php-fpm` on port `9000` to NGINX.
- **MariaDB** — stores the WordPress database, reachable only by WordPress on port `3306`.

Two named Docker volumes persist the database files and the WordPress site files on the host machine under `/home/pchazalm/data`. A dedicated bridge network (`inception`) connects the three containers. Each Docker image is built from scratch from a Debian base image — no pre-built service images are pulled.

The domain `pchazalm.42.fr` is configured to point to the host's local IP address and serves the WordPress site.

## Instructions

### Prerequisites

- A Linux virtual machine (Debian / Ubuntu recommended).
- `docker`, `docker compose` and `make` installed.
- The user running the project must be able to use `sudo` (only used by `make fclean`).
- The domain name `pchazalm.42.fr` must resolve to the local IP address of the VM. Add this line to `/etc/hosts`:

  ```
  127.0.0.1   pchazalm.42.fr www.pchazalm.42.fr
  ```

### Configuration

Before building anything, copy the environment template and fill it in:

```bash
cp srcs/.env.template srcs/.env
$EDITOR srcs/.env
```

The `.env` file holds the database credentials, the WordPress admin/secondary user credentials and the domain name. It is **never** committed to git (see `.gitignore`).

> ⚠️ The WordPress administrator username **must not** contain `admin` / `Admin` / `administrator` / `Administrator` (e.g. `admin`, `Admin42`, `administrator-1` are all forbidden).

### Build & launch

Everything is driven by the `Makefile` at the root of the repository:

| Command       | Description                                                                 |
|---------------|-----------------------------------------------------------------------------|
| `make`        | Creates the host data directories and builds & starts all containers.       |
| `make down`   | Stops and removes the containers (volumes are kept).                        |
| `make clean`  | Runs `down` then prunes unused Docker resources.                            |
| `make fclean` | Runs `down`, prunes everything (including volumes) and deletes host data.   |
| `make re`     | Runs `fclean` then rebuilds everything from scratch.                        |

Once the containers are running, open `https://pchazalm.42.fr` in a browser (you will get a self-signed certificate warning, which is expected). The WordPress admin panel is reachable at `https://pchazalm.42.fr/wp-admin`.

## Resources

Classic references used while building this project:

- [Usefull guide that explain everything](https://tuto.grademe.fr/inception/#docker)
- [Sabartho guide](https://github.com/TFHD/Inception)

Other reference that i didn't use but really helpfull
- [Docker Compose reference](https://docs.docker.com/compose/compose-file/)
- [Dockerfile best practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [NGINX `ssl_protocols` directive](https://nginx.org/en/docs/http/ngx_http_ssl_module.html)
- [WP-CLI handbook](https://make.wordpress.org/cli/handbook/)
- [MariaDB server documentation](https://mariadb.com/kb/en/documentation/)

### How AI was used


- Explaining how `php-fpm`, `fastcgi_pass` and NGINX cooperate, and how `init_file` works in MariaDB.
- Helping write this documentation (README, user doc, developer doc).

## Project description

### Use of Docker

The whole infrastructure relies on **Docker** and **Docker Compose**:

- **One container per service**, with one Dockerfile per service, all built locally from a Debian base image — no images are pulled from Docker Hub for the services themselves.
- Containers communicate through a **dedicated bridge network** (`inception`), so only NGINX is reachable from the host (on `443`).
- Persistent data lives in **named Docker volumes** declared in `docker-compose.yml`, themselves backed by directories under `/home/pchazalm/data` on the host.
- All containers use `restart: on-failure` so they automatically come back up after a crash.
- No `network: host`, no `--link`, no `latest` tag, no infinite-loop hack (`tail -f`, `sleep infinity`, …).

### Sources included in the project

```
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
└── srcs/
    ├── .env                 (not committed)
    ├── .env.template
    ├── .gitignore
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/   (Dockerfile, entrypoint.sh, init.sql.template, conf/50-server.cnf)
        ├── nginx/     (Dockerfile, conf/nginx.conf)
        └── wordpress/ (Dockerfile, script.sh, conf/www.conf)
```

### Main design choices

- **Debian** chosen over Alpine for familiarity with the `apt` ecosystem and easier debugging.
- **MariaDB initialization** is done through the `init_file` server option, which loads a SQL file rendered from a template at container start (`envsubst`). This avoids embedding credentials in the image and replays cleanly even on a fresh volume.
- **WordPress** is fully installed at first run by `wp-cli` (download core, generate `wp-config.php`, install the site, create both users) and then the script `exec`s `php-fpm` as PID 1.
- **NGINX** holds a self-signed certificate generated at build time and only allows TLSv1.2 / TLSv1.3.
- **No secrets in the repository.** All credentials live in `srcs/.env`, which is ignored by git.

### Virtual Machines vs Docker

A **virtual machine** virtualizes an entire operating system on top of a hypervisor: it has its own kernel, its own boot process and a full filesystem. It is heavy (gigabytes of disk, hundreds of MB of RAM just to idle), slow to start, but provides very strong isolation.

A **container** virtualizes only the user space on top of the host kernel using Linux namespaces and cgroups. It starts in milliseconds, weighs tens of MB and shares the host kernel, which makes it much cheaper to run many of them in parallel. The trade-off is weaker isolation than a VM and a hard dependency on the host kernel.

For Inception, containers are the right tool: each service is a small, well-defined process that doesn't need a full OS around it. The whole stack still runs inside a VM, as required by the subject, to keep the host machine clean.

### Secrets vs Environment Variables

**Environment variables** (typically loaded from a `.env` file) are convenient and supported natively by Docker Compose, but they have downsides: they are visible to anyone who can run `docker inspect` on the container, they often leak into logs, and they are inherited by every child process.

**Docker secrets** are files mounted into the container at a well-known path (e.g. `/run/secrets/db_password`) with restricted permissions. They are not exposed via `docker inspect`, are not visible as environment variables, and are designed to hold sensitive data (passwords, API keys, certificates).

In this project, non-sensitive configuration (domain name, database name, usernames) lives in `srcs/.env`, while the file itself is git-ignored to keep credentials out of the repository. A production-grade setup would push the password values to Docker secrets; here the requirement of "no credentials in the repository" is satisfied by the combination `.env` + `.gitignore`.

### Docker Network vs Host Network

With `network_mode: host`, a container shares the host's network namespace: it sees the host's interfaces and any port it binds is directly opened on the host. There is no isolation, no internal DNS, and port collisions with the host become possible. This mode is also explicitly forbidden by the subject.

With a **user-defined Docker network** (here a `bridge`), each container gets its own network namespace and an internal IP on a virtual switch. Docker provides automatic DNS-based service discovery (containers reach each other by service name, e.g. `mariadb`, `wordpress`), and only the ports explicitly published (here `443` on NGINX) are exposed to the host. This is what the project uses: NGINX is the single entry point, while MariaDB and WordPress remain unreachable from outside the `inception` network.

### Docker Volumes vs Bind Mounts

A **bind mount** maps a precise path on the host directly into the container. The host path is fully managed by the user (permissions, lifecycle, backups, …) and the container sees exactly what is on disk. Bind mounts are simple but tightly couple a container to a specific host layout.

A **named Docker volume** is managed by Docker itself: its lifecycle is controlled through `docker volume` commands, it can be inspected, backed up and shared between containers in a portable way, and it is decoupled from any specific host path.

The subject requires **named volumes** for the WordPress files and the MariaDB data, while also requiring that data physically lives under `/home/pchazalm/data`. This project declares two named volumes (`mariadb` and `wordpress`) in `docker-compose.yml` and uses the `local` driver to point them at `/home/pchazalm/data/mariadb` and `/home/pchazalm/data/wordpress` on the host — keeping the named-volume contract while still satisfying the host-path requirement.
