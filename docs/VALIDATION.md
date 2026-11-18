# Validación

Perfil: MiTV-MSSP3 55″ · machuca/v53s · PI.7524 · Projectivy 4.73. Muestra: una unidad.

| Prueba en hardware | Resultado |
|---|---|
| Apertura de Projectivy | PASS |
| HOME desde Ajustes mediante KEYCODE_HOME | PASS |
| HOME tras reinicio mediante KEYCODE_HOME | PASS |
| Ocho paquetes desactivados y tres animaciones a cero | PASS, persistente tras reinicio |
| Componentes de TV, entradas, Cast, Netflix, GMS y actualizaciones habilitados | PASS: comprobación de paquetes |
| Botones físicos Home y Mi/PatchWall | Pendiente |
| TDT, HDMI/CEC, audio, DRM, HDR, casting y voz | Pendiente de prueba audiovisual |
| Rendimiento y tráfico antes/después | No medidos de forma controlada |
| Ciclo completo Apply/Restore del script en hardware | Pendiente |

## Pruebas automatizadas

```powershell
pwsh -NoProfile -File tests/Run-Tests.ps1
```

Usan ADB simulado, sin conectar con una televisión. Verifican inspección, `WhatIf`, aplicación, verificación, respaldo no sobrescribible, restauración exacta, rechazo de modelo/serie ajenos y recuperación tras un fallo parcial. La misma prueba se ejecuta mediante GitHub Actions.
