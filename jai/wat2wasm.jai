#run build();

WORKING_DIR :: "/home/gui/Downloads/wabt-1.0.37-ubuntu-20.04/wabt-1.0.37/bin/";
WASM2WAT_EXE :: "wasm2wat";
WAT2WASM_EXE :: "wat2wasm";
// WAT2WASM_EXE :: "/home/gui/Downloads/wabt-1.0.37-ubuntu-20.04/wabt-1.0.37/bin/wat2wasm";
// WASM2WAT_EXE :: "/home/gui/Downloads/wabt-1.0.37-ubuntu-20.04/wabt-1.0.37/bin/wasm2wat";
STACK_POINTER_DECLARATION :: "(global $__stack_pointer (;0;) (import \"env\" \"__stack_pointer\") (mut i64))";

// PROJECT_ROOT :: "/home/gui/work/web/github/MicheDev3/webassembly_threads_proposal_overview_example";

// FIRST_MATCH :: 

build :: () {
    // 1: convert wasm to wat
    // 2: add 1 line at the top "(global $__stack_pointer (;0;) (import "env" "__stack_pointer") (mut i64))"
    // 3: remove the last line that contains __stack_pointer...
    // 4: convert back from wat to wasm

    // 0
    // get input file path, how?
    // workingDir := tprint("%/../public", #filepath);
    wasmFile := tprint("%/../public/app.wasm", #filepath);
    watFile := tprint("%/../public/app.wat", #filepath);
    // print("workingDir:%\n", workingDir);
    print("wasmFile:%.\n", wasmFile);
    print("watFile:%.\n", wasmFile);
    success := true;

    // 1
    {
        args: [..]string;
        array_add(*args, WASM2WAT_EXE);
        array_add(*args, "--enable-threads");
        array_add(*args, "--enable-memory64");
        array_add(*args, wasmFile);
        array_add(*args, "-o");
        array_add(*args, watFile);
        wasm2watCmd := tprint("% --enable-threads --enable-memory64 % -o %", WASM2WAT_EXE, wasmFile, watFile);
        print("cmd:%.\n", wasm2watCmd);
        run_result := run_command(..args, working_directory=WORKING_DIR);
        success &&= (run_result.exit_code == 0);
        if success == false { print("failed to convert to wat\n"); }
    }

    // 2
    // handler: Text_File_Handler;
    // defer deinit(*handler);

    // short_name := "whatever";
    // start_file(*handler, short_name, watFile, false);
    // if handler.failed {
    //     print("could not start_file\n");
    //     return;
    // }
    initialContent := read_entire_file(watFile);
    initialLines := split(initialContent, "\n");
    print("lines count:%\n", initialLines.count); 

    indexOfFirstImport :s64 = -1;
    // indexOfStackPointerGlobal :s64 = -1;
    lineIndex :s64 = 0;
    newLines:[..]string;
    for i:0..(initialLines.count-1) {

        // line, found := consume_next_line(*handler);
        line := initialLines[i];
        doAdd:bool=true;
        
        // if !found break;   // consume_next_line returns false for 'found' when we are done.

        if indexOfFirstImport < 0 {
            if contains(line, "(import ") {
                indexOfFirstImport = lineIndex;
                array_add(*newLines, STACK_POINTER_DECLARATION);
            }
        }
        // if indexOfStackPointerGlobal < 0 {
            if contains(line, "(global $__stack_pointer") {
                // indexOfStackPointerGlobal = lineIndex;
                doAdd=false;
            }
        // }

        if doAdd {
            array_add(*newLines, line);
        }

        lineIndex += 1;
    }
    // update the lines;
    newFileContent := join(..newLines, "\n");
    success = write_entire_file(watFile, newFileContent);
    // success &&= (run_result.exit_code == 0);
    if success == false { print("failed to write back wat file\n"); }

    // 4
    {
        args: [..]string;
        array_add(*args, WAT2WASM_EXE);
        array_add(*args, "--enable-threads");
        array_add(*args, "--enable-memory64");
        array_add(*args, watFile);
        array_add(*args, "-o");
        array_add(*args, wasmFile);
        // wa2wasmCmd := tprint("% --enable-threads --enable-memory64 % -o %", WAT2WASM_EXE, watFile, wasmFile);
        run_result := run_command(..args, working_directory=WORKING_DIR);
        success &&= (run_result.exit_code == 0);
        if success == false { print("failed to convert wat to wasm\n"); }
    }

}


#import "Basic";
#import "Process";
// #import "Text_File_Handler";
#import "String";
#import "File";