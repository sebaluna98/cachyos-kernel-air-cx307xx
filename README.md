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

## Antes de empezar

- **Tiempo:** la compilación tarda unas 3 horas en un Ryzen 3 3200U. Dejá la
  notebook enchufada (`build.sh` ya bloquea la suspensión mientras compila).
- **Memoria:** con 8 GB de RAM y LTO, el enlazado final es lo más exigente. Si el
  equipo se cuelga ahí, cerrar todo lo demás o agregar swap/zram.
- **Kernel de respaldo:** instalar `linux-cachyos-lts` antes de reemplazar el
  kernel principal. El paquete nuevo pisa a `linux-cachyos`, y si algo falla
  hay que poder arrancar otro kernel desde Limine.
  `sudo pacman -S linux-cachyos-lts linux-cachyos-lts-headers`
  (el LTS no lleva el parche: ver notas).

## Recompilar

```bash
git clone https://github.com/sebaluna98/cachyos-kernel-air-cx307xx.git
cd cachyos-kernel-air-cx307xx
bash build.sh
```

Después, instalar (ajustar el nombre si cambió la versión):

```bash
cd ~/linux-cachyos/linux-cachyos
ls -lh *.pkg.tar.zst
sudo pacman -U linux-cachyos-[0-9]*-x86_64.pkg.tar.zst linux-cachyos-headers-[0-9]*-x86_64.pkg.tar.zst
```

El `ls` es para confirmar que los dos paquetes existen antes de instalar.

Reiniciar **sin** `acpi=noirq` y verificar:

```bash
cat /proc/cmdline                      # no debe aparecer acpi=noirq
cat /proc/interrupts | grep i8042      # el contador debe subir al escribir
```

## Sacar `acpi=noirq` de Limine

Está en `/etc/default/limine`, en la línea `KERNEL_CMDLINE[default]+=" acpi=noirq"`.

```bash
sudo cp /etc/default/limine /etc/default/limine.bak
sudo sed -i 's/ acpi=noirq//' /etc/default/limine
grep -n "noirq" /etc/default/limine     # no debe devolver nada
sudo limine-update
```

Si `limine-update` no existe, reinstalar el kernel con `pacman -U` dispara los
hooks que regeneran `limine.conf`. Las entradas de snapshots de Snapper pueden
seguir mostrando `acpi=noirq`: son copias del pasado y no importan.

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
- El kernel LTS no lleva el parche: si se arranca sin `acpi=noirq`, el teclado
  interno no anda. Para usarlo, editar la entrada con `e` en Limine y agregar
  `acpi=noirq` solo para ese arranque.
- Para que una actualización no pise el kernel parcheado, en `/etc/pacman.conf`
  (sección `[options]`, descomentando la línea):
  `IgnorePkg   = linux-cachyos linux-cachyos-headers`
  Con eso hay que recompilar a mano cuando se quiera actualizar el kernel.
- Si se usó `systemctl mask` para bloquear la suspensión durante la compilación,
  revertirlo al terminar:
  `sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target`

## Problemas conocidos de este sistema

- **Shell de Caelestia no arranca tras actualizar**: `noctalia-qs` declara que
  provee `quickshell-git` y ocupa `/usr/bin/qs`. Solución:
  `paru -S aur/quickshell-git` y elegir la opción `quickshell-git` (reemplaza a `noctalia-qs`).
  Si una actualización sube Qt, puede hacer falta recompilarlo.

## Estado

El parche todavía no está en el kernel oficial. Si algún día entra, este
repositorio deja de ser necesario.
