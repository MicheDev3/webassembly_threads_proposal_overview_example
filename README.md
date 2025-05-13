Based on the example from https://github.com/WebAssembly/threads/blob/main/proposals/threads/Overview.md

# How to Compile

You can compile the project by running `jai jai/build.jai` which will compile Jai into WASM and generate and compile any WAT file required
Parameters (they must be defined in this order):

	- wasm-compiler-path: compiler to generate wasm files for wat. Default: "wat2wasm"
	- memory-pages: how many pages the memory will have. Default: 100
	- max-number-of-workers: maximum number of workers. Default: 32

e.g: `jai jai/build.jai - path\to\wat2wasm 20 64` 

# How to Run

You can start the server by running the python script `server.py` on a terminal; e.g: `python server.py`
You can view the web app using the following url `http://localhost:8085/` (use the browser dev console to view any logs)

# Requirements

- Jai compiler (version currently tested: jai-beta-2-009)
- WASM compiler (compiler currently tested: wat2wasm)

# Useful links for further research

- https://web.dev/articles/webassembly-threads very good doc
- https://webassembly.github.io/wabt/demo/wat2wasm/ to quickly test conversions wat to wasm, and the options required in the command line
- https://surma.dev/postits/wasi-threads/ This seems to describe how to spawn a thread from wasm directly. I don't yet know what wasi is.
- https://emscripten.org/docs/porting/pthreads.html how emscripten handles threads
- https://github.com/GoogleChromeLabs/comlink could help manage workers more easily.
- https://web.dev/articles/cross-origin-isolation-guide doc on cross isolation, which is required to have shared memory