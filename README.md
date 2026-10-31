# Curso de Árabe Moderno Estándar (AME)

Curso autodidacta de AME, por escrito y en español, con Claude como profesor. El foco es entender la **estructura** del idioma; no se trabajan la comprensión oral ni la expresión oral.

## Cómo se usa

- **Sesión interactiva**: abre Claude Code en este repo y escribe `siguiente lección`. Claude coge el siguiente issue abierto, da la clase (unos 15 minutos), guarda la lección en `lecciones/`, apunta el progreso y cierra el issue.
- **Sesión por comentarios**: comenta `@claude` en un issue. Claude responde en el propio issue con la explicación y los ejercicios, o con la corrección de lo que hayas enviado.

## Qué hay aquí

| Ruta | Contenido |
|---|---|
| `CLAUDE.md` | Instrucciones permanentes para Claude: perfil del alumno, pedagogía, protocolos y plantilla de lección |
| `temario.md` | Temario completo en 4 bloques |
| `progreso.md` | Registro de sesiones, una línea por sesión |
| `lecciones/bloque-N/` | Una lección cerrada por fichero (`NN-tema.md`) |
| `scripts/crear-issues.sh` | Crea (o actualiza) los milestones, las labels y los issues. Es idempotente |
| `.github/workflows/claude.yml` | Action que responde a `@claude` en los issues |

El plan de trabajo vive en los **issues**, agrupados por milestone (un bloque por trimestre).
