# Kernel CachyOS con fix de teclado para AIR SRL CX307XX

Notebook **AIR SRL CX307XX** (placa `CX30000`, BIOS 1.09, Ryzen 3 3200U) con CachyOS.

## El problema

El DSDT declara la IRQ1 del teclado como `Edge, ActiveLow`, pero el kernel la ignora
en AMD Zen y usa edge/active-high. Resultado: el teclado interno no recibe
interrupciones (contador de `i8042` en `/proc/interrupts` en 0, y `atkbd` loguea
`Failed to deactivate keyboard`).

Con `acpi=noirq` anda el teclado pero se rompe el touchpad (I2C-HID + `pinctrl_amd`).

## La solución

`air-cx307xx.patch` agrega el equipo a la tabla `irq1_edge_low_force_override[]`
de `drivers/acpi/resource.c`. Con el kernel parcheado, teclado y touchpad andan
**sin** `acpi=noirq`.

## Recompilar

```bash
git clone <este-repo>
cd <este-repo>
./build.sh
```

Después, instalar (ajustar el nombre si cambió la versión):

```bash
cd ~/linux-cachyos/linux-cachyos
sudo pacman -U linux-cachyos-*-x86_64.pkg.tar.zst linux-cachyos-headers-*-x86_64.pkg.tar.zst
```

Reiniciar **sin** `acpi=noirq` y verificar:

```bash
cat /proc/cmdline                      # no debe aparecer acpi=noirq
cat /proc/interrupts | grep i8042      # el contador debe subir al escribir
```

## Notas

- **Antes de compilar**, conviene confirmar que la tabla sigue existiendo en la
  versión nueva. En el árbol descargado (`src/cachyos-*/`):
  `grep -n "irq1_edge_low_force_override" drivers/acpi/resource.c`
  Si el nombre cambió o el equipo ya figura, el parche no hace falta o hay que ajustarlo.
- Si `patch` falla por contexto distinto, aplicar la entrada a mano en esa tabla.
- Si el PKGBUILD cambia su estructura, el `sed` de `build.sh` puede dejar de
  encontrar `validpgpkeys=(`; en ese caso agregar a mano
  `source+=("air-cx307xx.patch")` debajo del array `source=(...)`.
- `makepkg -C` limpia `src/` para que el parche se aplique sobre fuentes sin tocar.
- `--skippgpcheck` omite la firma PGP (falta la clave de CachyOS en el llavero).
  Los b2sums del PKGBUILD siguen verificando la integridad. Alternativa:
  `gpg --recv-keys C3C4820857F654FE`.
- Mantener un kernel de respaldo (`linux-cachyos-lts`) y, si hace falta, arrancarlo
  con `acpi=noirq` agregado desde el menú de Limine (`e`). El LTS no lleva el parche.
- Para que una actualización no pise el kernel parcheado, en `/etc/pacman.conf`:
  `IgnorePkg = linux-cachyos linux-cachyos-headers`
- `acpi=noirq` se saca de `/etc/default/limine` (línea `KERNEL_CMDLINE[default]`)
  y se regeneran las entradas con `sudo limine-update`.

## Problemas conocidos de este sistema

- **Shell de Caelestia no arranca tras actualizar**: `noctalia-qs` declara que
  provee `quickshell-git` y ocupa `/usr/bin/qs`. Solución:
  `paru -S aur/quickshell-git` y elegir la opción `quickshell-git` (reemplaza a `noctalia-qs`).
  Si una actualización sube Qt, puede hacer falta recompilarlo.

## Upstream

El parche fue enviado a `linux-acpi@vger.kernel.org`. Si ya entró al kernel
oficial, este repo deja de ser necesario.
