
# How to Compile

Build Parameters:

	- optimise: whether build with optimisation on. Default = true
	- internal: whether to build internal code paths. Default = false;
	- max-thread-count: maximum number of threads. Default = 32
	- platform: whether platform to build. Required = (wasm|win64|linux)
	- backend: whether backend to use. Ignored for wasm. Default = x64
	- wasm-toolchain-path: wasm toolchain. Required
	- wasm-nr-pages: how many pages the wasm memory will have. Default = 10000

e.g: `jai jai/build.jai - -optimise -platform wasm -max-thread-count 16 -wasm-toolchain-path "/home/gui/Downloads/wabt-1.0.37-ubuntu-20.04/wabt-1.0.37/bin"`
e.g: `jai jai/build.jai - -optimise -backend llvm -platform win64 -max-thread-count 32`
e.g: `jai jai/build.jai - -optimise -backend llvm -platform linux -max-thread-count 24`

# Wasm

Based on the example from https://github.com/WebAssembly/threads/blob/main/proposals/threads/Overview.md

### How to Run

You can start the server by running the python script `server.py` on a terminal; e.g: `python server.py`
You can view the web app using the following url `http://localhost:8085/` (use the browser dev console to view any logs)

### Requirements

- Jai compiler  (version currently tested: jai-beta-2-014)
- WASM compiler (compiler currently tested: wabt-1.0.37)
- A browser which supports memory64 (you might need to enable it) and SharedArrayBuffer
