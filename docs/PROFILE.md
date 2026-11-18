# FTV-002 · Perfil técnico

Revisión A · 2026-11-18 · Perfil `machuca-pi7524`.

## 1. Requisitos y trazabilidad

| ID | Requisito | Verificación |
|---|---|---|
| REQ-01 | Aceptar MiTV-MSSP3/machuca; mutar solo PI.7524 | Preflight de identidad |
| REQ-02 | Abrir Projectivy con HOME | Resolución de intent y prueba desde otra pantalla |
| REQ-03 | Guardar estado antes de mutar y no sobrescribirlo | Pruebas de respaldo y segunda aplicación |
| REQ-04 | Desactivar únicamente la lista cerrada siguiente | Lectura de estado por usuario 0 |
| REQ-05 | Restaurar valores originales, incluidos ausentes | Comparación con línea base |
| REQ-06 | Mantener componentes funcionales fuera del perfil | Revisión de comandos; pruebas audiovisuales pendientes |

## 2. Lista de cambios

| Paquete | Propósito del cambio |
|---|---|
| `com.google.android.tvlauncher` | Evitar que el inicio Google capture HOME |
| `com.google.android.leanbacklauncher` | Desactivar el inicio antiguo alternativo |
| `com.mitv.tvhome.atv` | Desactivar PatchWall |
| `com.mitv.tvhome.michannel` | Desactivar el componente de canales de PatchWall |
| `com.miui.tv.analytics` | Reducir analítica de Xiaomi |
| `com.xiaomi.statistic` | Reducir estadísticas de Xiaomi |
| `com.google.android.tvrecommendations` | Desactivar recomendaciones de Google TV |
| `com.google.android.leanbacklauncher.recommendations` | Desactivar recomendaciones del inicio antiguo |

Método: `pm disable-user --user 0`. No se desinstalan paquetes ni se borran sus datos. Escalas globales `window_animation_scale`, `transition_animation_scale` y `animator_duration_scale`: **0**. HOME: `com.spocky.projengmenu/.ui.home.MainActivity`.

En el ensayo, `set-home-activity` aceptó el cambio pero Google conservó prioridad. Desactivar los launchers antiguos resolvió esa interferencia. Projectivy debe arrancar correctamente antes de desactivarlos.

## 3. Límites operativos

- No se cambian límites de procesos, opciones GPU, resolución, brillo, memoria virtual, firmware ni restricciones térmicas.
- No hay bloqueo DNS ni filtrado de tráfico. Las aplicaciones conservadas pueden seguir recogiendo datos y mostrando publicidad.
- Android 9 y el parche de 2021 siguen siendo una limitación de seguridad; reducir telemetría no equivale a actualizar el sistema.
- La línea base contiene la serie del dispositivo: es privada. Está excluida de Git, pero sigue siendo responsabilidad del operador protegerla y no compartirla.
- La restauración requiere el mismo dispositivo/firmware y ADB accesible. No es un mecanismo de recuperación de un televisor que no arranca.
- Actualizaciones o cambios posteriores de paquetes pueden requerir reevaluar el perfil.
