# Sistema de Build

## Objetivo

Este repositorio usa el mismo enfoque de build local y CI aplicado en otros repos de SourceMod del stack de AoC:

- mismo flujo logico para local y CI
- mismo script Python para Windows y Linux
- `make` como interfaz corta
- soporte automatico para WSL cuando el repo vive bajo `/mnt/`

## Archivos principales

- `Makefile`
- `plugin-package-map.json`
- `scripts/fetch-sourcemod.py`
- `scripts/build-local.py`
- `scripts/stage-artifact.py`
- `scripts/package-release.py`
- `scripts/ci-build-sourcemod.sh`
- `scripts/ci-validate-artifact.sh`
- `scripts/ci-package-release-assets.sh`
- `.github/workflows/sourcemod-build.yml`
- `.github/workflows/release.yml`

## Targets

- `make deps-smx`
- `make build-smx`
- `make package-smx`
- `make release`
- `make clean`
- `make clean-all`

## Layout

Los binarios compilados quedan en:

- `addons/sourcemod/plugins/l4d2_commsuite/`

Actualmente el repo compila:

- `l4d2_commcore.sp`
- `l4d2_commguard.sp`
- `l4d2_commrelay.sp`
- `l4d2_chatnoise.sp`
- `l4d2_chatlog.sp`

## Seleccion explicita de runtime

`plugin-package-map.json` define:

- que plugins se compilan
- en que subdirectorio de `plugins/` se publican
- que fuentes, includes y configs se incluyen en el artifact

Las claves principales son:

- `build.plugins`
- `artifact.addons.sourcemod.configs`
- `artifact.addons.sourcemod.scripting.files`
- `artifact.addons.sourcemod.scripting.dirs`
- `artifact.addons.sourcemod.scripting.include`

En `CommSuite`, el bundle publica:

- plugins compilados bajo `plugins/l4d2_commsuite/`
- contratos publicos de `include/`
- fuentes necesarias para desarrollo
- SQL init en `configs/sql-init-commsuite/`

## WSL

Si el repositorio esta bajo `/mnt/`, `build-local.py` usa automaticamente un workspace temporal Linux para evitar la penalizacion de I/O tipica de WSL sobre discos montados de Windows.

## CI

El workflow principal separa el camino `smx` en jobs explicitos:

- `deps-smx`
- `build-smx`
- `release`

Y el workflow de tags reutiliza el mismo camino antes de crear la release versionada `sourcemod/vX.Y.Z`.
