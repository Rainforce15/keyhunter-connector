@ECHO OFF

cl /nologo /MD /O2 -c -Fosrc\keyhunter_test.obj src\keyhunter_test.c -IQ:\src\libwebsockets\include -IQ:\src\openssl-1.1.0e-vs2015_64\include
link /nologo /out:bin\keyhunter_test.exe src\keyhunter.obj Q:\src\libwebsockets\lib\Release\websockets.lib lua51_all.lib
