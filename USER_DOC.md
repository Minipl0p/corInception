# USER_DOC — Inception

This document is intended for an end user or administrator of the Inception stack. It does **not** require any knowledge of Docker internals.

## 1. What the stack provides

The Inception stack runs a complete WordPress website on your machine, served over HTTPS. It is composed of three services:

| Service   | Role                                                                 |
|-----------|----------------------------------------------------------------------|
| NGINX     | HTTPS web server, the only door into the stack (port `443`).         |
| WordPress | WordPress + `php-fpm`, runs the website itself.                      |
| MariaDB   | Database server, stores all WordPress data (posts, users, settings). |

All three services run in their own isolated Docker containers and talk to each other through a private Docker network. Only NGINX is reachable from outside.

## 2. Starting and stopping the project

All commands must be run from the **root of the repository** (the directory that contains the `Makefile`).

### Start the stack

```bash
make
```

This command:

1. Creates the data directories on the host (`/home/pchazalm/data/mariadb` and `/home/pchazalm/data/wordpress`).
2. Builds the three Docker images from the local `Dockerfile`s.
3. Starts all three containers in the background.

The first start takes a few minutes (image build + WordPress installation). Subsequent starts are almost instant.

### Stop the stack

```bash
make down
```

The containers are stopped and removed, but **your data is preserved** (database content, uploaded files, themes, plugins).

### Reset everything (⚠ destroys data)

```bash
make fclean
```

This stops the containers, removes the Docker images and **deletes the data directories** on the host. The next `make` will reinstall WordPress from scratch.

```bash
make re
```

Shortcut for `fclean` then `make`.

## 3. Accessing the website and the admin panel

Once `make` is finished:

| What                       | URL                                       |
|----------------------------|-------------------------------------------|
| Public website             | `https://pchazalm.42.fr`                  |
| WordPress administration   | `https://pchazalm.42.fr/wp-admin`         |

> 💡 The domain `pchazalm.42.fr` must resolve to your local machine. Make sure your `/etc/hosts` file contains:
>
> ```
> 127.0.0.1   pchazalm.42.fr www.pchazalm.42.fr
> ```

> ⚠ The site uses a **self-signed TLS certificate**, so your browser will display a security warning the first time. This is expected: accept it manually (or add a permanent exception) to reach the site.

Log in to `/wp-admin` with the credentials defined in `srcs/.env` (`WP_USER` / `WP_PASS`). A secondary editor account (`WP_USER2` / `WP_PASS2`) is also created automatically.

## 4. Locating and managing credentials

All credentials are read from a single file: **`srcs/.env`**.

This file is **never** committed to git (it is listed in `.gitignore`). A template is provided as `srcs/.env.template`; copy it and fill it in:

```bash
cp srcs/.env.template srcs/.env
$EDITOR srcs/.env
```

The variables you must define are:

| Variable          | Used for                                            |
|-------------------|-----------------------------------------------------|
| `DB_NAME`         | Name of the MariaDB database used by WordPress.     |
| `DB_USER`         | MariaDB user used by WordPress (not root).          |
| `DB_PASSWORD`     | Password for `DB_USER`.                             |
| `DB_ADMIN_PASS`   | Password for the MariaDB `root` account.            |
| `DOMAIN_NAME`     | Public domain (`pchazalm.42.fr` by default).        |
| `WP_USER`         | WordPress administrator login.                      |
| `WP_PASS`         | WordPress administrator password.                   |
| `WP_MAIL`         | WordPress administrator email.                      |
| `WP_USER2`        | Login of the secondary (editor) WordPress user.     |
| `WP_PASS2`        | Password of the secondary user.                     |
| `WP_MAIL2`        | Email of the secondary user.                        |

> ⚠ **Important:** `WP_USER` must not contain `admin` / `Admin` / `administrator` / `Administrator` (e.g. `admin`, `Admin1`, `administrator-x` are rejected by the subject).

To rotate a password, edit `srcs/.env`, then either change the password from inside WordPress / MariaDB, or run `make re` (this will destroy data).

## 5. Checking that the services are running

### Quick check from the host

```bash
docker ps
```

You should see three containers running, named `nginx`, `wordpress` and `mariadb`, all with status `Up`.

### Per-service checks

- **NGINX is up and serving HTTPS:**

  ```bash
  curl -kI https://pchazalm.42.fr
  ```

  Expected: an HTTP response (`200`, `301` or `302`).

- **WordPress responds (through NGINX):** open `https://pchazalm.42.fr` in a browser — you should see the WordPress site.

- **MariaDB is healthy:**

  ```bash
  docker exec -it mariadb mariadb -uroot -p -e "SHOW DATABASES;"
  ```

  Type the value of `DB_ADMIN_PASS`. You should see the database listed in `DB_NAME`.

### Reading logs

```bash
docker logs nginx
docker logs wordpress
docker logs mariadb
```

Add `-f` to follow them live (e.g. `docker logs -f wordpress`).

### Your data on the host

| Data                  | Host location                               |
|-----------------------|---------------------------------------------|
| MariaDB database      | `/home/pchazalm/data/mariadb`               |
| WordPress site files  | `/home/pchazalm/data/wordpress`             |

These directories survive `make down` and `make clean`, but are **deleted** by `make fclean`.
