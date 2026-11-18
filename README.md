# free-mitv-mssp3

Projectivy como menú principal, animaciones desactivadas y reducción de recomendaciones y telemetría de Xiaomi mediante ADB. Cambios reversibles, sin root ni flasheo.

| Compatibilidad | Valor |
|---|---|
| Modelo | Xiaomi MiTV-MSSP3 · 55″ · machuca |
| Firmware | Android TV 9 · PI.7524 release-keys |
| PC | Windows · PowerShell 7 · Android SDK Platform-Tools |
| Launcher probado | Projectivy 4.73 |
| Versión | 0.1.0 |

## 1. Cambios

- **Home abre Projectivy** en lugar del menú de Google.
- Desactiva los launchers antiguos de Google y PatchWall.
- Desactiva componentes separados de analítica de Xiaomi y recomendaciones de Google.
- Pone a cero las tres escalas de animación de Android.
- Guarda los valores originales para poder restaurarlos.

Lista exacta de paquetes y ajustes: [perfil técnico](docs/PROFILE.md).

## 2. Preparar la televisión

1. Abre **Ajustes → Preferencias del dispositivo → Información → Compilación**.
2. Pulsa **siete veces** sobre Compilación para activar las opciones de desarrollador.
3. Vuelve a **Preferencias del dispositivo → Opciones de desarrollador** y activa **Depuración USB**. En el firmware probado habilita el acceso ADB por red en el puerto 5555; los nombres del menú pueden variar.
4. Instala **Projectivy Launcher** desde Google Play o las [publicaciones oficiales](https://github.com/spocky/miproja1/releases) y ábrelo una vez.
5. Conecta el PC y la TV a la misma red local de confianza. Consulta la IP de la TV en sus ajustes de red.

## 3. Conectar

Instala [PowerShell 7](https://github.com/PowerShell/PowerShell/releases) y [Android SDK Platform-Tools](https://developer.android.com/tools/releases/platform-tools). Añade `adb` al PATH. Abre PowerShell 7 en la carpeta del proyecto:

```powershell
$tvIp = Read-Host 'IP local de la televisión'
$tv = "${tvIp}:5555"
adb connect $tv
adb devices -l
```

Acepta **«Permitir depuración USB»** en la TV, también si conectas por Wi-Fi. El estado debe ser `device`.

| Problema | Acción |
|---|---|
| `unauthorized` | Acepta la autorización en la pantalla de la TV. |
| `offline` | Desconecta con `adb disconnect $tv` y vuelve a conectar. |
| Conexión rechazada | Revisa la IP, la depuración y que ambos dispositivos estén en la misma red. |

## 4. Aplicar

```powershell
./scripts/Free-TV.ps1 -Action Inspect -Device $tv
./scripts/Free-TV.ps1 -Action Apply -Device $tv -WhatIf
./scripts/Free-TV.ps1 -Action Apply -Device $tv
./scripts/Free-TV.ps1 -Action Verify -Device $tv
```

`-WhatIf` comprueba requisitos sin aplicar cambios. `Apply` exige el modelo y firmware indicados, Projectivy habilitado y todos los paquetes del perfil. Guarda primero `state/baseline.json` y no sobrescribe un respaldo existente. Si ya existe, usa `Verify` o `Restore`.

Si ADB no está en el PATH, añade `-Adb 'ruta/al/adb.exe'` a cada comando del script. `-ServerPort` selecciona el puerto del servidor ADB del PC, por defecto 5037.

## 5. Comprobar y finalizar

Pulsa **Home** desde Ajustes y otra aplicación: debe abrir Projectivy. Reinicia la TV, reconecta y repite `Verify`. Comprueba las funciones que utilices: TDT, HDMI/CEC, sonido, voz, casting y streaming.

Al terminar, desactiva la depuración en la TV y ejecuta `adb disconnect $tv`. No expongas ADB a Internet. Para realizar más cambios, vuelve a activar y autorizar la depuración.

## 6. Restaurar

```powershell
./scripts/Free-TV.ps1 -Action Restore -Device $tv
```

Restaura el inicio, los estados de los paquetes y las animaciones desde `state/baseline.json`. Requiere el mismo dispositivo y firmware. Si la aplicación de cambios queda incompleta por un error, ejecuta `Restore`; no hay reversión automática. Conserva el respaldo local: contiene el identificador del dispositivo y está excluido de Git. No es una copia del firmware ni de los datos de las aplicaciones.

## 7. Limitaciones

- Validado en una unidad. Otros modelos y firmwares no están admitidos para cambios.
- Home y los ajustes persistieron tras reiniciar. El botón dedicado Mi/PatchWall y el inicio automático al encender no están validados; una aplicación puede recuperar el primer plano.
- No cambia el sistema operativo, resolución, ajustes de imagen, DRM ni componentes de TV, HDMI, casting y streaming. Su funcionamiento audiovisual completo no está certificado.
- No elimina toda la telemetría ni los anuncios dentro de las aplicaciones. No incorpora filtrado de red ni parches de seguridad.

[Validación](docs/VALIDATION.md) · [Créditos](NOTICE.md) · [Licencia MIT](LICENSE)
