
#import "Compiler";

build_static_library :: () {
    
    set_build_options_dc(.{do_output=false});
    
    w := compiler_create_workspace("Static Lib Workspace");
    options := get_build_options();
    options.output_executable_name = "asset_builder";
    options.output_path            = "../../build_jai/"; // relative to THIS file.
    options.output_type            = .STATIC_LIBRARY;
    
    set_optimization(*options, .DEBUG);
    set_build_options(options, w);
    set_build_options_dc(.{do_output=true}, w);
    
    add_build_file("asset_builder.jai", w);
    
}

#run build_static_library();