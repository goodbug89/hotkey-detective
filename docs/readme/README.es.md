<h1 align="center">HotkeyDetective</h1>

<p align="center">
  <strong>Descubre qué app se quedó con tu atajo de teclado.</strong><br>
  macOS no ofrece forma de preguntarlo. Esta herramienta sí.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-000?logo=apple&logoColor=white" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white" alt="Swift 5">
  <img src="https://img.shields.io/badge/License-MIT-blue" alt="MIT">
</p>

<p align="center">
  <strong>Idioma:</strong>
  <a href="../../README.md">English</a> ·
  <a href="README.ko.md">한국어</a> ·
  <a href="README.ja.md">日本語</a> ·
  <a href="README.zh-Hans.md">简体中文</a> ·
  <a href="README.zh-Hant.md">繁體中文</a> ·
  <a href="README.de.md">Deutsch</a> ·
  <a href="README.fr.md">Français</a> ·
  <strong>Español</strong> ·
  <a href="README.it.md">Italiano</a> ·
  <a href="README.pt-BR.md">Português</a> ·
  <a href="README.ru.md">Русский</a> ·
  <a href="README.ar.md">العربية</a> ·
  <a href="README.th.md">ไทย</a> ·
  <a href="README.tr.md">Türkçe</a> ·
  <a href="README.vi.md">Tiếng Việt</a>
</p>

---

Pulsas ⇧⌘4 y no ocurre nada. Alguna app se lo ha quedado, ¿pero cuál? macOS no tiene ninguna API que lo responda, y en Ajustes del Sistema tampoco se puede consultar.

HotkeyDetective reúne pruebas, emite un veredicto y muestra su razonamiento:

```
⇧⌘4
Guardar imagen del área seleccionada (sistema) lo está usando
  ●●●●  Sistema    El atajo del sistema n.º 30 está activado como ⇧⌘4
```

## Cómo funciona

No existe una única fuente fiable sobre «quién es el dueño de este atajo», así que la app recoge señales independientes y las pondera:

| Fuente | Qué demuestra | Fuerza |
| --- | --- | --- |
| **Atajos del sistema** | La propia tabla de macOS asigna esta combinación | Segura |
| **Configuración de app** | El archivo de ajustes de una app conocida asigna esta combinación | Alta (baja si la app no está abierta) |
| **Escaneo de configuración** | Los ajustes de una app coinciden con un formato de almacenamiento conocido | Media |
| **Reacción** | Una app abrió una ventana o pasó al frente justo tras la pulsación | Alta |
| **Sonda de atajo** | Algún proceso mantiene un registro de atajo Carbon | Solo observación |

El veredicto es `confirmado`, `probable`, `en disputa`, `ocupado pero sin identificar` o `libre`. Cada afirmación muestra las pruebas en las que se apoya, así que juzgas tú en lugar de confiar en una caja negra.

Una distinción importa: una **reacción** demuestra que una app *recibió* la tecla, no que la *registrara*. Una reacción puede respaldar a un dueño, pero nunca disputarlo. Sin esa regla, ⌘Space se leería como «el sistema y Spotlight están peleando» cuando no pasa nada malo.

## Instalación

Requiere macOS 14 o posterior.

```bash
git clone https://github.com/goodbug89/hotkey-detective.git
cd hotkey-detective
Scripts/bundle.sh
open build/HotkeyDetective.app
```

La compilación firma con un certificado Developer ID si tu llavero tiene uno; si no, usa firma ad hoc. Las compilaciones ad hoc pierden los permisos en cada recompilación — consulta [BUILDING.md](../../BUILDING.md).

## Permisos

La sonda necesita **Accesibilidad** y **Monitorización de entrada**. macOS exige ambos para un event tap de teclado de solo escucha.

Las pulsaciones se observan; nunca se interceptan, registran ni almacenan. El tap se crea con `.listenOnly`, de modo que el verdadero dueño sigue recibiendo la tecla: en eso se basa precisamente la detección de reacciones. Tras una sonda solo queda la combinación que consultaste. En este repositorio no hay código de red.

Sin permisos la app funciona en **modo limitado**: eliges una combinación manualmente y responde solo con archivos de ajustes.

## Límites conocidos

- **La sonda de atajos Carbon no ve otros procesos.** `RegisterEventHotKey` solo informa de conflictos dentro del propio proceso, así que el veredicto «ocupado pero sin identificar» es prácticamente inalcanzable. Una app que registra un atajo, no muestra ventana y guarda su configuración en un formato desconocido permanece invisible.
- **Los nombres de funciones del sistema están en inglés salvo en coreano.** macOS guarda sus traducciones en un lugar que no podemos leer, e inventar las nuestras discreparía de lo que ves en Ajustes del Sistema.
- **El escaneo de configuración reconoce dos formatos** (la biblioteca `KeyboardShortcuts` y diccionarios estilo `MASShortcut`). Las apps con formato propio necesitan un analizador dedicado — [se agradecen contribuciones](../../CONTRIBUTING.md).

## Quién lo hace

HotkeyDetective lo desarrolla el equipo de **[Unifyl](https://unifyl.app)**, un gestor de archivos de doble panel para macOS.

## Licencia

MIT — [LICENSE](../../LICENSE)

