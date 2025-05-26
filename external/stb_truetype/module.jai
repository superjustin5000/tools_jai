#if OS == .WINDOWS ||  OS == .PS5 {
#load "windows.jai";
#scope_module
    FILE :: void;
} else #if OS == .LINUX || OS == .MACOS {
#load "unix.jai";
#import "POSIX";
} else {
#assert false;
}