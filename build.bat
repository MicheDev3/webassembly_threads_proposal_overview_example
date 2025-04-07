@echo off

wat2wasm --enable-threads wasm/atomics.wat -o public/atomics.wasm
wat2wasm --enable-threads wasm/example.wat -o public/example.wasm