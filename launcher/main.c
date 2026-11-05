// HomeCrafter Plus for Mac — app executable (Contents/MacOS/HomeCrafter Plus).
// A signed Mach-O front door that runs Contents/Resources/launch.sh, which does
// the real work (see that file). A compiled stub instead of a shell-script
// CFBundleExecutable keeps codesign/notarization straightforward.
#include <mach-o/dyld.h>
#include <libgen.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(void) {
    char exe[PATH_MAX], real[PATH_MAX], script[PATH_MAX];
    uint32_t size = sizeof exe;
    if (_NSGetExecutablePath(exe, &size) != 0 || !realpath(exe, real)) return 1;
    char *macos = dirname(real);              // .../Contents/MacOS
    char contents[PATH_MAX];
    strlcpy(contents, macos, sizeof contents);
    char *c = dirname(contents);              // .../Contents
    snprintf(script, sizeof script, "%s/Resources/launch.sh", c);
    execl("/bin/zsh", "zsh", script, (char *)NULL);
    perror("execl");
    return 1;
}
