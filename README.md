# Portal Prefeitura Jardel Alves

Monorepo do portal municipal com backend Spring Boot e frontend Angular.

## Estado atual

- Backend com Spring Boot 3.3, Java 21, seguranca basica, CORS, tratamento global de erros e endpoint `GET /api/status`.
- Frontend com scaffold Angular standalone e tela inicial responsiva.
- Modulos de dominio ainda estao como esqueletos e devem ser implementados por prioridade funcional.

## Backend

Pre-requisitos:

- Java 21
- Maven 3.9+
- SQL Server e Redis para o perfil `dev`

Com banco local:

```bash
cd backend
mvn spring-boot:run
```

Sem banco, apenas para validar os endpoints basicos:

```bash
cd backend
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

Endpoints iniciais:

- `GET http://localhost:8080/api/status`
- `GET http://localhost:8080/api/actuator/health`
- `GET http://localhost:8080/api/swagger-ui.html`

## Frontend

Pre-requisitos:

- Node.js 20+
- npm

```bash
cd frontend
npm install
npm start
```

A aplicacao abre em `http://localhost:4200`.

## Proximas prioridades tecnicas

1. Implementar entidades, repositories, services e controllers por modulo de negocio.
2. Criar migracoes Flyway antes de ativar CRUD real.
3. Conectar os componentes Angular aos endpoints conforme os modulos forem estabilizados.
