FILE_PATH :: "source/stb_truetype.h";
LIB_BASE_NAME :: "libstbtruetype";

#run {
    set_build_options_dc(.{do_output=false});
    if !generate_bindings() {
        compiler_set_workspace_status(.FAILED);
    }
}

generate_bindings :: () -> bool {
    opts: Generate_Bindings_Options;
    output_filename: string;
    {
        using opts;
        
        array_add(*libnames, LIB_BASE_NAME);
        
#if OS == .WINDOWS {
            array_add(*libpaths, "windows");
            output_filename = "windows.jai";
            generate_library_declarations = false;
            footer = tprint(FOOTER_WINDOWS_TEMPLATE, LIB_BASE_NAME);
        } else {
#if OS == .LINUX {
                array_add(*libpaths, "linux");
            } else #if OS == .MACOS {
                array_add(*libpaths, "macos");
            } else {
                assert(false);
            }
            output_filename = "unix.jai";
            generate_library_declarations = false;
            footer = tprint(FOOTER_UNIX_TEMPLATE, LIB_BASE_NAME);
        }
        
        array_add(*source_files, FILE_PATH);
        
        auto_detect_enum_prefixes = true;
        log_stripped_declarations = false;
        generate_compile_time_struct_checks = false;
    }
    
    return generate_bindings(opts, output_filename);
}

FOOTER_WINDOWS_TEMPLATE :: #string END

#if OS == .WINDOWS {
    %1 :: #library "windows/%1";
} else #if OS == .PS5 {
    %1 :: #library "ps5/%1";
} else {
#assert false;
}

END

FOOTER_UNIX_TEMPLATE :: #string END

#if OS == .LINUX {
    %1 :: #library "linux/%1";
} else #if OS == .MACOS {
    %1 :: #library "macos/%1";
} else #if OS == .PS5 {
    %1 :: #library "ps5/%1";
} else {
#assert false;
}

END

#import "Basic";
#import "Bindings_Generator";
#import "Compiler";
