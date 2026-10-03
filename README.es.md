# Metal Gear 2: Solid Snake — partidas en el Yamanooto

*[English](README.md)*

Metal Gear 2 graba en el **Game Master 2** o en disco. El parche le hace creer que tiene el Game Master 2 al lado y **contesta él** a sus llamadas, escribiendo en la flash del cartucho los **tres ficheros** del juego (SNAK1, SNAK2 y SNAK3). Ni Game Master 2 ni disquetera.

**39** bytes cambiados en **3** tramos · driver de **8 KB** · un sector de **64 KB** · no se distribuye ninguna ROM

## Cómo se juega

Como con el Game Master 2: el menú de grabar del propio juego ofrece el cartucho en vez de las contraseñas, con sus tres ficheros, y se carga desde el mismo sitio.

## Lo que hace falta

- **La ROM del juego**, que este repositorio no distribuye: *Metal Gear 2: Solid Snake* (Konami, 1990, RC-767), la japonesa, 524.288 bytes, sha256 `43b7fab533abeb87313919ec1fc7bc732d7b0ebfacede1e4f89d8295160384f2`. El parcheador comprueba cada sitio, así que con otro volcado se niega en vez de estropearlo.
- **Python 3.**
- **Un Yamanooto** de 2 MB o de 8 MB, en un MSX2.

## Montar la imagen

```
python tools/imagen.py metalgear2.rom
```

Sale `metalgear2_yamanooto.rom` (640 KB), lista para grabar en el cartucho desde el principio de la flash: arranca el juego solo, sin menú. **Grabarla sustituye el menú y los juegos que tenga el cartucho.** En openMSX, con una máquina MSX2:

```
openmsx -machine <un MSX2> -cart metalgear2_yamanooto.rom -romtype Yamanooto
```

`make test` pasa los 4 tests: los `.bin` salen de sus `.asm`, el parcheador rechaza otra ROM y, con la ROM en la raíz, fuera de los tramos que declara el parcheador el juego es el original byte a byte y la imagen es la de referencia.

## Cómo funciona por dentro

- En 0x5DD4, la rutina que busca el Game Master 2 en las ranuras se cambia por 7 bytes que dicen que está en la ranura del propio juego.
- En 0x186D4, la única rutina con la que el juego llama a otra ranura, en vez de saltar a la del Game Master 2 pone el driver ([launcher/mg2_driver.asm](launcher/mg2_driver.asm), 8 KB añadidos como banco 0x40) en la ventana 0x8000 con el registro SCC 0x9000 y lo llama.
- El driver contesta como el Game Master 2: lee (función 0x08) y escribe (0x09) los ficheros; el resto de funciones responden que todo ha ido bien, que es lo único que el juego mira.
- El juego ya es Konami SCC, el modo con el que arranca el Yamanooto: desde el principio de la flash arranca solo.
- Cada fichero es `[0xA5][largo de 2][115 bytes de datos]`, cada 0x100 bytes de un sector de 64 KB de la flash (banco relativo 0x48). Para escribir uno se copian los tres a la RAM, se borra el sector y se vuelven a programar desde un motor en RAM (0xE500).

## De dónde sale

Sale de [nPackR](https://github.com/antxiko/msx-yamanooto-npackr), que lo usa para meter el juego en una colección. Aquí va suelto: la imagen arranca el juego directamente, sin menú. Licencia GPL v3 ([LICENSE](LICENSE)) y una nota de uso no comercial ([NOTICE.md](NOTICE.md)).

## Probado

En openMSX.
