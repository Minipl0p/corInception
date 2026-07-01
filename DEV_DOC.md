# DEV_DOC — Inception

This document is intended for a developer who needs to set up, build, modify or debug the Inception stack. It complements `README.md` (overview) and `USER_DOC.md` (end-user guide).

## 1. Setting up the environment from scratch

### 1.1. Host prerequisites

- A Linux VM (Debian or Ubuntu recommended).
- `git`, `make`, `docker` and `docker compose` plugin installed.
- A user with `sudo` rights (only used by `make fclean` to remove host data).
- Free TCP ports on the host: `443`.
- The domain `pchazalm.42.fr` must resolve to the VM's local IP. Add to `/etc/hosts`:

  ```
  127.0.0.1   pchazalm.42.fr www.pchazalm.42.fr
  ```

### 1.2. Clone the repository

```bash
git clone <repo-url> Inception
cd Inception
```

The expected layout is:

```
Inception/
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
└── srcs/
    ├── .env                 (you create this — not committed)
    ├── .env.template
    ├── .gitignore
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── entrypoint.sh
        │   ├── init.sql.template
        │   └── conf/50-server.cnf
        ├── nginx/
        │   ├── Dockerfile
        │   └── conf/nginx.conf
        └── wordpress/
            ├── Dockerfile
            ├── script.sh
            └── conf/www.conf
```

### 1.3. Configuration files

Only one file needs to be created by hand: **`srcs/.env`**.

```bash
cp srcs/.env.template srcs/.env
$EDITOR srcs/.env
```

Fill every variable listed in the template (DB credentials, domain, WP admin + secondary user). The `WP_USER` value **must not** contain `admin`, `Admin`, `administrator` or `Administrator`.

`srcs/.env` is listed in `srcs/.gitignore` and **must never be committed**.

### 1.4. Where data is stored on the host

```
/home/pchazalm/data/
├── mariadb/      ← MariaDB datadir (mounted as the `mariadb` named volume)
└── wordpress/    ← WordPress site files (mounted as the `wordpress` named volume)
```

These directories are created automatically by `make` and removed by `make fclean`.

## 2. Building and launching the project

### 2.1. `Makefile` targets

| Target        | Effect                                                                                       |
|---------------|----------------------------------------------------------------------------------------------|
| `make` / `make all` | Creates host data directories, then `cd srcs && docker compose up --build -d`.         |
| `make down`   | `cd srcs && docker compose down` — stops and removes containers, keeps named volumes.        |
| `make clean`  | Runs `down` then `docker system prune -f` (removes dangling images / networks).              |
| `make fclean` | Runs `down`, `docker system prune -af --volumes`, then `sudo rm -rf` of the data directories.|
| `make re`     | `fclean` + `all`.                                                                            |

### 2.2. Underlying Docker Compose commands

Everything lives in `srcs/docker-compose.yml`. From the `srcs/` directory you can also run Compose directly:

```bash
# Build images without starting
docker compose build

# Start in foreground (logs in the terminal)
docker compose up --build

# Start in background
docker compose up --build -d

# Stop and remove containers (keep volumes)
docker compose down

# Stop and remove containers AND volumes
docker compose down -v
```

### 2.3. Build order and dependencies

Service dependencies declared in `docker-compose.yml`:

- `nginx` `depends_on` `wordpress`
- `wordpress` `depends_on` `mariadb`

`depends_on` only guarantees **container start order**, not application readiness. At the very first launch, NGINX may serve a default page for a few seconds while WordPress is still initializing — this is expected, just refresh.

## 3. Managing containers and volumes

### 3.1. Listing what is running

```bash
# Containers (should show nginx, wordpress, mariadb)
docker ps

# Images
docker images | grep -E 'nginx|wordpress|mariadb'

# Volumes
docker volume ls | grep -E 'mariadb|wordpress'

# Networks
docker network ls | grep inception
```

### 3.2. Logs

```bash
docker logs -f nginx
docker logs -f wordpress
docker logs -f mariadb
```

### 3.3. Entering a container

```bash
docker exec -it nginx     bash
docker exec -it wordpress bash
docker exec -it mariadb   bash
```

### 3.4. Useful WordPress / DB commands

```bash
# List WordPress users via wp-cli (inside the wordpress container)
docker exec -it wordpress ./wp-cli.phar user list --allow-root

# Open a MariaDB shell as root
docker exec -it mariadb mariadb -uroot -p
```

### 3.5. Restarting a single service

```bash
cd srcs
docker compose restart nginx
docker compose up -d --build wordpress
```

### 3.6. Rebuilding from scratch

```bash
make fclean
make
```

This destroys all volumes and data; use it when changing a Dockerfile in a way that affects the initial WordPress install (`script.sh`) or the SQL bootstrap (`init.sql.template`).

## 4. Where the project data is stored and how it persists

### 4.1. Named volumes

Two named volumes are declared in `srcs/docker-compose.yml`:

| Volume name | Mount point inside container | Host path                              |
|-------------|------------------------------|----------------------------------------|
| `mariadb`   | `/var/lib/mysql`             | `/home/pchazalm/data/mariadb`          |
| `wordpress` | `/var/www/html`              | `/home/pchazalm/data/wordpress`        |

The volumes use the `local` driver with `driver_opts` pointing at the host paths, so they are still managed as Docker named volumes (visible in `docker volume ls`), but their data physically lives in `/home/pchazalm/data` as required by the subject.

### 4.2. Persistence rules

| Action          | MariaDB data | WordPress files |
|-----------------|--------------|------------------|
| `make down`     | Kept         | Kept             |
| `make clean`    | Kept         | Kept             |
| `make fclean`   | **Deleted**  | **Deleted**      |
| `make re`       | **Deleted** then recreated empty | **Deleted** then recreated empty |

### 4.3. Backups

Because data is plain files under `/home/pchazalm/data`, a backup is just a `tar` of that directory while the stack is stopped:

```bash
make down
sudo tar czf inception-backup.tgz -C /home/pchazalm data
make
```

## 5. Notes for contributors

- Never commit `srcs/.env` or any file under `secrets/` if you add one.
- Do not use the `latest` Docker tag; pin the Debian release used in every Dockerfile.
- Each service has exactly one Dockerfile, located under `srcs/requirements/<service>/`.
- Containers must not run an infinite-loop hack (`tail -f`, `sleep infinity`, `while true`, …). The entry points in this project either `exec` the real daemon as PID 1 (`mysqld`, `php-fpm`) or run the daemon directly in the foreground (`nginx -g 'daemon off;'`).
- The `inception` network is a user-defined `bridge`; `network_mode: host` and `--link` are forbidden by the subject and not used here.
