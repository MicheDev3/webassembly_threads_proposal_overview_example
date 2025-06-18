
# How to Compile

Build Parameters:

	- optimise: whether build with optimisation on. Default = true
	- internal: whether to build internal code paths. Default = false;
	- max-thread-count: maximum number of threads. Default = 32
	- platform: whether platform to build. Required = (wasm|win64|linux)
	- backend: whether backend to use. Ignored for wasm. Default = x64
	- wasm-compiler-path: compiler to generate wasm files from wat. Default = "wat2wasm"
	- wasm-nr-pages: how many pages the wasm memory will have. Default = 100

e.g: `jai jai/build.jai - -platform wasm`

more complete: `jai jai/build.jai - -internal -platform wasm -wasm-compiler-path "W:\freelance\polygonjs\wabt\1.0.37\bin\wat2wasm.exe" -wasm-nr-pages 1000 -max-thread-count 32 && jai jai/wat2wasm.jai`
or for linux: `jai jai/build.jai - -internal -platform wasm -wasm-compiler-path "/home/gui/Downloads/wabt-1.0.37-ubuntu-20.04/wabt-1.0.37/bin/wat2wasm" -wasm-nr-pages 1000 -max-thread-count 24 && jai jai/wat2wasm.jai`

NOTE: Linux is not currently implemented

# Wasm

Based on the example from https://github.com/WebAssembly/threads/blob/main/proposals/threads/Overview.md

### How to Run

You can start the server by running the python script `server.py` on a terminal; e.g: `python server.py`
You can view the web app using the following url `http://localhost:8085/` (use the browser dev console to view any logs)

### Requirements

- Jai compiler  (version currently tested: jai-beta-2-014)
- WASM compiler (compiler currently tested: wabt-1.0.37)
- A browser which supports memory64 (you might need to enable it) and SharedArrayBuffer
