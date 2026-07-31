/*
 * NTPWEdit Enterprise command-line entry point.
 * GPL-2.0-or-later, consistent with the upstream NTPWEdit project.
 */
#include "cli.h"

int main(int argc, char **argv)
{
    return ntpwcli_run(argc, argv);
}
