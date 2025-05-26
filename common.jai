#import "Basic";

#load "types.jai";
#load "constants.jai";
#load "mathh.jai";

invalid_code_path :: (reason: string, args: .. Any) {
    assert(false, reason, args);
}