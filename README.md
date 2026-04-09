# k3d Microservices Playground

A simple 3-tier microservices demo running on `k3d`.

## Components
- **Frontend**: Node.js (Express)
- **Middleware**: Python (FastAPI)
- **Database**: PostgreSQL 16

## Pre-Requisites
- Docker
- k3d
- kubectl

## Quick Start
1. **Deploy**:
   ```bash
   ./deploy.sh
   ```
2. **Access**:
   [http://localhost:8080](http://localhost:8080)

## Timings
A GET request to `/` returns:
- `frontend_execution_time`: Local processing time.
- `middleware_rest_query_time`: Time taken for the REST call to FastAPI.
- `db_execution_time_ms`: Time taken for the DB query (returned by middleware).
