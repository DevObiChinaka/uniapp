# UniApp — Smart Attendance System

A university attendance-management project organized into a backend and a frontend. The project explores ways to record and review attendance using mobile and web-based workflows.

## Project Overview

The repository contains a backend application, a frontend application, and supporting documentation for administrative user management.

## Intended Capabilities

- Attendance-management workflows
- QR-code attendance support
- Geolocation checks
- Facial-recognition integration
- Administrative user-management features

The exact availability and maturity of each capability should be verified against the current implementation before relying on it in production.

## Repository Structure

- `backend/` — server-side application
- `frontend/` — client-side application
- `ADMIN_USER_MANAGEMENT.md` — supporting notes for administrative user management

## Technology

The project includes a Django/Python backend and a mobile-oriented frontend. The wider implementation has used Flutter, Dart, PostgreSQL, Firebase, and ML Kit; consult the dependency files in each component for the current versions and exact configuration.

## Local Development

Because the backend and frontend are separate components, follow the setup instructions and dependency files inside each directory. Configure database and external-service credentials through environment variables or local configuration; do not commit secrets.

## Security and Privacy Considerations

Attendance data, location information, and facial-recognition data can be sensitive. Before using this system with real students, document consent and data-retention practices, restrict access to attendance records, secure API endpoints, and test the accuracy and failure modes of each verification method.

## Maintainer

[DevObiChinaka on GitHub](https://github.com/DevObiChinaka)

## Documentation TODO

A reproducible setup guide should specify exact backend/frontend commands, required environment variable names, database migrations, test commands, and which features are complete versus experimental.
