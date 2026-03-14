#include "hidbox.h"
#include <stdio.h>
#include <string.h>
#include <getopt.h>

void print_usage(const char *prog) {
    printf("Usage: %s [options]\n", prog);
    printf("Options:\n");
    printf("  -g, --get <key>        Get config value\n");
    printf("  -s, --set <key=value>  Set config value\n");
    printf("  -l, --list              List all config\n");
    printf("  -h, --help              Show this help\n");
}

int main(int argc, char **argv) {
    static struct option long_opts[] = {
        {"get", required_argument, 0, 'g'},
        {"set", required_argument, 0, 's'},
        {"list", no_argument, 0, 'l'},
        {"help", no_argument, 0, 'h'},
        {0,0,0,0}
    };
    int c;
    while ((c = getopt_long(argc, argv, "g:s:lh", long_opts, NULL)) != -1) {
        switch (c) {
            case 'g':
                printf("Get %s: not implemented\n", optarg);
                break;
            case 's':
                printf("Set %s: not implemented\n", optarg);
                break;
            case 'l':
                printf("Config listing not implemented\n");
                break;
            case 'h':
                print_usage(argv[0]);
                return 0;
            default:
                print_usage(argv[0]);
                return 1;
        }
    }
    if (argc == 1) print_usage(argv[0]);
    return 0;
}