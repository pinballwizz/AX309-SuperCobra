copy /b epr1265.2c + 2e + epr1267.2f + 2h + epr1269.2j + 2l scobra_prog.bin
make_vhdl_prom scobra_prog.bin ROM_PGM.vhd

make_vhdl_prom epr1274.5h ROM_OBJ_0.vhd
make_vhdl_prom epr1273.5f ROM_OBJ_1.vhd

make_vhdl_prom 5c ROM_SND_0.vhd
make_vhdl_prom 5d ROM_SND_1.vhd
make_vhdl_prom 5e ROM_SND_2.vhd

pause