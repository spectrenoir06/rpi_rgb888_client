# rpi_rgb888_client

## deps

- sudo apt install luajit
- sudo apt install luarocks
- luarocks5.1 install luasocket
- luarocks5.1 install luaposix
- luarocks5.1 install lpack
- luarocks5.1 install middleclass

## run
```
sudo luajit main.lua PCM 100 1
```


```
sudo luajit main.lua MODE LEDs_NB RGBW
```

- mode: PCM, PWM, PWMx2
- LEDs_NB: LEDs number total
- RGBW: if LEDs are RGBW then put 1
