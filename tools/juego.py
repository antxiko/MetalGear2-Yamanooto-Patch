"""Lo que distingue a este parche de los otros de la misma maquinaria."""
NOMBRE = "Metal Gear 2: Solid Snake"
ROM = "metalgear2.rom"                    # RC-767, Konami SCC, 512 KB
TAM_ROM = 0x80000
SHA256_ROM = "43b7fab533abeb87313919ec1fc7bc732d7b0ebfacede1e4f89d8295160384f2"
PARCHEADOR = "packager/mg2_to_yamanooto.py"
TAM_PARCHEADO = 0x80000 + 0x2000         # + el driver como banco 0x40
FUENTES = ["mg2_engine.asm", "mg2_driver.asm"]
INCLUYE = {"mg2_driver.asm": ["mg2_engine.bin"]}
SALIDA = "metalgear2_yamanooto.rom"
SECTOR = 0x48 * 0x2000                   # el sector de 64 KB donde graba
TAM_IMAGEN = SECTOR + 0x10000           # 640 KB, para el offset 0 de la flash
SHA256_IMAGEN = "5ea619f3ab976bfd9805195def2d0a82f18c2d1c1a7e7848d9bcbdca203b27b0"

# Los tramos que el parcheador declara (offset, largo): fuera de ellos, el
# juego parcheado es la ROM original byte a byte (tests/test_parche.py)
import sys as _s, pathlib as _p                        # noqa: E402
_s.path.insert(0, str(_p.Path(__file__).resolve().parent.parent / "packager"))
import mg2_to_yamanooto as _q                          # noqa: E402
ZONAS = [(_q.P1_OFF, len(_q.P1_NEW)), (_q.P2_OFF, len(_q.P2_NEW))]
