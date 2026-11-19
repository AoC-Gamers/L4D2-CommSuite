# L4D2-CommSuite

Suite SourceMod de comunicación para Left 4 Dead 2. Centraliza los hooks de chat y permite añadir restricciones, relay y auditoría por separado.

| Plugin | Función |
|---|---|
| `l4d2_commcore` | Procesa el chat y expone hooks para integraciones. |
| `l4d2_commguard` | Unifica bloqueos de chat y voz de proveedores compatibles. |
| `l4d2_commrelay` | Reenvía chat de equipo a espectadores y SourceTV y permite relay de voz para espectadores. |
| `l4d2_chatnoise` | Filtra mensajes de sistema y de administración en el chat. |
| `l4d2_chatlog` | Audita mensajes y conexiones a archivo, con registro SQL opcional de conexiones. |

Consulta la [guía de instalación](docs/installation/README.md) para elegir módulos y configurar proveedores.
Los flujos de chat, voz y auditoría están en el [índice de documentación](docs/README.md).

## Licencia

El código y los aportes originales de lechuga se distribuyen bajo [GPL-3.0-only](LICENSE). Las atribuciones y los términos de terceros se recogen en [NOTICES.md](NOTICES.md).
