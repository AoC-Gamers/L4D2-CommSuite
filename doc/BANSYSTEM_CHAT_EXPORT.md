# Integración de exportación de chat para BanSystem

## Estado y propósito

Implementado en `l4d2_chatlog` `0.4.1` con API pública v1. Conserva
`l4d2_chatlog` como propietario de su archivo funcional diario y añade una
superficie pública mínima para que un plugin SourceMod autorizado pueda
identificarlo o crear una fotografía estable.

La integración no envía HTTP, no conoce permisos web, no contacta al Node Agent
y no convierte CommSuite en parte de BanSystem. El consumidor previsto es el
satélite externo `bansystem_chatlog`.

## Library e include

`l4d2_chatlog` registra una library pública del mismo nombre y distribuye un
include `addons/sourcemod/scripting/include/l4d2_chatlog.inc` con natives
exactas:

```sourcepawn
/**
 * Copies the current logical chat file path into the caller buffer.
 * The returned value is relative to Path_SM and is not an export capability.
 */
native bool L4D2ChatLog_GetActiveFile(char[] path, int maxLength);

/**
 * Creates a stable copy of the active daily log in the fixed export root.
 * requestId is an opaque, strictly validated identifier supplied by the
 * consumer. snapshotName returns only the created logical file name.
 */
native bool L4D2ChatLog_CreateSnapshot(
    const char[] requestId,
    char[] snapshotName,
    int maxLength
);
```

El ABI queda congelado como API v1. Load tardío es tolerable: el consumidor
comprueba feature/library y CommSuite no exige BanSystem.

## Semántica

- `GetActiveFile` llama la rotación vigente antes de responder y devuelve sólo
  un path relativo a `Path_SM` bajo `logs/chats/`.
- `CreateSnapshot` acepta sólo un UUID canónico lowercase de 36 bytes; no
  acepta slash, backslash, `..`, extensión o path aportado por el llamador.
- El destino pertenece a una raíz fija bajo
  `addons/sourcemod/data/l4d2_chatlog/exports/`.
- El nombre se deriva únicamente del request ID y una extensión conocida.
- El nombre destino es `chatlog_<uuid>.log`; un snapshot existente sólo se
  reutiliza si sus bytes todavía coinciden con el archivo activo.
- La copia usa un temporal impredecible dentro de la raíz, exige que origen y
  destino mantengan el mismo tamaño, cierra ambos handles y termina mediante
  rename. Temporal y archivo final quedan `0660`; al reutilizar un snapshot se
  reimpone `0660` antes de devolver éxito.
- Éxito significa que la copia completa fue cerrada y puede ser leída por otro
  proceso. La operación nunca devuelve el contenido por native o consola.
- Se rechaza el archivo activo sobre 8 MiB. El cleanup conserva como máximo 32
  snapshots y expira entradas administradas después de 24 horas; nunca toca el
  archivo funcional original.

`l4d2_chatlog` abre, escribe y cierra el archivo en cada línea. SourcePawn
ejecuta forwards/comandos de forma serial, por lo que una fotografía iniciada
desde un callback no compite con otra escritura SourcePawn durante ese callback.
Deploy prepara el volumen como `10001:<BANSYSTEM_CHAT_EXPORT_GID>` y `2770`;
SRCDS debe pertenecer a ese grupo. Cuando la raíz ya existe, el plugin valida el
modo exacto con `GetFilePermissions` y no intenta hacer `chmod` como mero miembro
del grupo. Si crea una raíz local, usa el bit POSIX setgid `0x0400` junto con los
flags publicados por SourceMod y reimpone `2770` después de `mkdir` para evitar
la reducción por umask.

SourceMod 1.12 no expone `chown`, consulta de GID, `lstat` ni `O_NOFOLLOW`. El
plugin no inventa un GID ni cambia ownership: el temporal creado dentro de la
raíz setgid hereda el grupo preparado por Deploy, recibe `0660` antes del rename
atómico y conserva GID/modo al renombrarse dentro del mismo directorio. Agent
debe revalidar regular-file/no-symlink y ownership/mode antes de consumir. Esta
limitación queda como gate explícito de despliegue, no como garantía fabricada.

## Naturaleza del archivo original

El archivo diario no es un archivo de campaña. Puede incluir:

- varias campañas y mapas;
- chat público y de equipo;
- conexiones, desconexiones y cambios de nombre;
- SteamID, IP y país en eventos de lifecycle;
- banners repetidos y un corte a medianoche.

Por ello BanSystem lo presenta como “registro original del servidor”. La
captura estructurada por campaña sigue consumiendo directamente
`L4D2Comm_OnChatMessage_Rendered_Post`; no parsea esta copia para construir su
modelo.

## Frontera con Node Agent

CommSuite sólo escribe en su raíz de exportación. Deploy podrá montar esa raíz
como volumen compartido específico con el Agent. El Agent debe recibir
únicamente el nombre lógico mediante un comando tipado del consumidor, validar
otra vez raíz, tipo de archivo, tamaño y checksum y encargarse de
comprimir/subir.

El reader Agent y este native comparten el ABI v1
`<dedicated-export-root>/chatlog_<job-uuid>.log`: archivo plano con el texto
legacy original, sin subdirectorio por `server_id` ni NDJSON. El consumo
runtime depende del flujo que entregue el job UUID y del montaje setgid aislado;
no se fabrican rutas ni se cambia el contenido.

No se transportan bytes por netconsole, no se monta todo el volumen del
gameserver en Agent y ninguna ruta viene del navegador o Backend.

## Validación

- rotación diaria y llamada antes del primer mensaje;
- UTF-8 y archivo vacío/no existente;
- El build Linux compila todos los plugins y el artifact público incluye
  `l4d2_chatlog.inc`.
- La validación runtime pendiente debe cubrir rotación, archivo vacío/no
  existente, snapshot activo, repetición/conflicto, traversal, exceso de tamaño,
  cleanup, herencia efectiva del GID, modos `2770`/`0660` y late load/unload.
- Traversal y nombres arbitrarios se rechazan en la grammar del UUID. La prueba
  de symlink se realiza además en Agent/Deploy, donde sí existe una primitiva de
  filesystem capaz de no seguirlo.
