# Workshop Organizer Web API

Welcome to the Workshop Organizer Web API! This application is designed to facilitate workshops open to the public. Whether you’re organizing coding bootcamps, art classes, or any other type of workshop, this API will help manage registrations, schedules, and resources.

## Table of Contents

1. Context
2. Technical Overview
3. Building and Running
4. Testing
5. Packaging
6. Publishing to GitLab Registry

## Context

Workshops play a crucial role in fostering learning and collaboration. Our application aims to streamline the workshop organization process, making it easier for organizers to manage participants, sessions, and materials. Whether you're a seasoned workshop host or just starting out, this API has got you covered!

## Technical Overview

- **Java Development Kit (JDK):** We use **JDK 21**, tested with **Adoptium**, to power our application.
- **Database:** Our backend relies on a **PostgreSQL 13** database for data storage.
- **Build Tool:** We leverage **Gradle 8.7** for managing dependencies and building the project.
- **Spring Boot:** Our application is based on **Spring Boot 3.2.4**, which provides a robust framework for creating RESTful APIs.
- **Application Server:** Our application can run on Tomcat server that require version 10.1.24.

## Building and Running

To compile and run the application locally, follow these steps:

1. Ensure you have JDK 21 installed.
2. Clone this repository.
3. Navigate to the project root directory.
4. Execute the following command to compile the Java code :
   ```bash
   ./gradlew clean compileJava
   ```
5. To run the application locally, either:
   Execute the main method in the Application class from your IDE.
   Use the Spring Boot Gradle Plugin :
   ```bash
   ./gradlew bootRun
   ```
   For production, package the application as WAR and use a tomcat server

To run the application and its PostgreSQL database with Docker:

```bash
cp .env.example .env      # then set a real POSTGRES_PASSWORD
docker compose up -d --build
curl http://localhost:8080/api/workshops
```

The database is seeded from `db/*.sql` on first start and persisted in the `pgdata` volume (`docker compose down -v` resets it).

### Developer shortcuts

A `Makefile` wraps the common commands for local development (`make help` lists them): `make install`, `make up`, `make down`, `make logs`, `make health`, `make test`, `make backup`, `make restore FILE=...`, `make psql`. It is a convenience only: every target is a plain `docker compose` or script call.

## Backup and restore

`scripts/backup.sh` dumps the database (`pg_dump` custom format) into `backups/`, writes a SHA-256 checksum, checks that the dump is readable and deletes dumps older than 7 days. `BACKUP_DIR` and `RETENTION_DAYS` override the defaults.

```bash
scripts/backup.sh
# nightly, from cron (crontab -e):
# 0 2 * * * /opt/workshop-api/scripts/backup.sh >> /var/log/workshop-backup.log 2>&1
```

`scripts/restore.sh` verifies the checksum, saves the current database to `backups/pre-restore/`, stops the API, restores in a single transaction and checks that the API answers again:

```bash
scripts/restore.sh backups/workshopsdb_20261114-020000.dump          # asks for confirmation
scripts/restore.sh backups/workshopsdb_20261114-020000.dump --yes    # non-interactive
```

Dumps contain all the data: they are created readable by their owner only and must be copied off the server (see the operations runbook).

## Configuration

You can configure the application with these environment variables

- SPRING_DATASOURCE_URL: JDBC URI for DB access (ex. jdbc:postgresql://db:5432/mydatabase)
- SPRING_DATASOURCE_USERNAME: Database user name used by the application
- SPRING_DATASOURCE_PASSWORD: Database user password used by the application

## Testing

We take testing seriously! To verify the correctness of our application, run the following command:

```bash
./gradlew clean test
```

During execution junit reports are generated in the `build/test-results/test` folder.

You can also use the unified test script (same script as the Angular app), which copies the JUnit XML reports into `test-results/`:

```bash
./run-tests.sh
```

## Packaging

When you’re ready to package the application for deployment, create a deployable WAR file:

```bash
./gradlew bootWar
```

The generated war file can be used with many application servers such as Tomcat, Wildfly...

## Publishing to GitLab Registry

To publish your application to a GitLab registry, follow these steps:

1. Set up your GitLab project.
2. Ensure you have the following environment variables configured:

   - GITLAB_PROJECT_ID: The ID of your GitLab project.
   - GITLAB_TOKEN_NAME: The name of the GitLab access token.
   - GITLAB_TOKEN: Your GitLab access token.

3. Execute the following command to publish your application:
   ```bash
   ./gradlew publish
   ```
   Remember to replace placeholders with actual values specific to your project.

Feel free to enhance this README with additional details, such as API endpoints, security considerations, and deployment instructions. Happy organizing! 🚀

## Continuous Integration

The pipeline is defined in `.github/workflows/ci.yml`. The same file is used, unchanged, in the Angular and Java repositories: a first `detect` job finds the project type (`package.json` or `build.gradle`) and the other jobs adapt with conditions.

| Job | What it does |
|---|---|
| `detect` | Detects the project type (`node` or `gradle`) |
| `test` | Installs the toolchain (with dependency cache), runs `./run-tests.sh`, uploads `test-results/` as an artifact and publishes the JUnit report in the run summary, even when tests fail |
| `build` | Builds the Docker image, smoke-tests it (the container must really answer), then pushes it to `ghcr.io` |
| `release` | On `main` only: [semantic-release](https://semantic-release.gitbook.io/) creates the version tag and the GitHub Release from the commit messages, then tags the tested image with that version |

It runs on every push to `main` and `ci/**` branches, and on pull requests targeting `main` (pull requests are built and tested, never pushed).

### Image tags

Images are published to `ghcr.io/m0l42/<repository>`:

- `<branch>-<short sha>` for every push, e.g. `ci-workflow-1a2b3c4` or `main-1a2b3c4`
- `X.Y.Z` and `latest` for each release on `main`

### Versioning

Versions come from [Conventional Commits](https://www.conventionalcommits.org/): `fix:` bumps the patch, `feat:` the minor, `BREAKING CHANGE:` the major. The git tag is the source of truth; the version field in the build file is not updated.
