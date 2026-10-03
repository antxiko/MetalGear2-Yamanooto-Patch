"""Lo que distingue a este parche de los otros de la misma maquinaria."""
NOMBRE = "Metal Gear 2: Solid Snake"
ROM = "metalgear2.rom"                    # RC-767, Konami SCC, 512 KB
TAM_ROM = 0x80000
SHA256_ROM = "43b7fab533abeb87313919ec1fc7bc732d7b0ebfacede1e4f89d8295160384f2"
PARCHEADOR = "packager/mg2_to_yamanooto.py"
TAM_PARCHEADO = 0x80000 + 0x2000         # + el driver como banco 0x40
FUENTES = ["mg2_engine.asm", "mg2_driver.asm"]
INCLUYE = {"mg2_driver.asm": ["mg2_engine.bin"]}
SALIDA = "metalgear2_yamanooto_2MB.rom"
SHA256_IMAGEN = "a9f7ad99022cf7ade65b35d5affad1bc49c34755342093d442546c3730a278b0"
