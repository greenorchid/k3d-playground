FROM postgres:16-alpine
ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD=postgres
ENV POSTGRES_DB=testdb
COPY init.sql /docker-entrypoint-initdb.d/
# Official Postgres image uses a custom entrypoint.
# We use numeric UID 70 (postgres in alpine) for runAsNonRoot compatibility.
USER 70
