@echo off
taskkill /IM Helicity.exe /T /F
ren Helicity.exe oldHelicity.bin
ren HelicityTemp.exe Helicity.exe
start Helicity.exe
exit