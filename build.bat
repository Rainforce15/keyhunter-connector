REM @ECHO OFF

cl /nologo /MD /O2 -c -Fosrc\keyhunter.obj src\keyhunter.c -IQ:\src\libwebsockets\include -IQ:\src\openssl-1.1.0e-vs2015_64\include -IQ:\src\LUA\lua-5.1.5\include

link /nologo -dll -def:src\keyhunter.def /out:bin\keyhunter.dll src\keyhunter.obj Q:\src\libwebsockets\lib\Release\websockets.lib lua51_.lib

cp bin/*.dll Keyhunter/
cp lua/*.lua Keyhunter/

cp Keyhunter/* "K:\Execs\Game\Gaming Console\bizhawk\Lua\Keyhunter Connector\"

"C:\Program Files\7-Zip\7z" a "..\Keyhunter Server\www\dl\KeyhunterConnector.zip" Keyhunter/*
