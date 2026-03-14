#include "hidbox.h"
#include <stdio.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>

#define PROFILES_DIR "/mnt/SDCARD/App/hidbox/share/profiles"

void list_profiles(void) {
    DIR *d = opendir(PROFILES_DIR);
    if (!d) {
        perror("opendir");
        return;
    }
    struct dirent *entry;
    while ((entry = readdir(d)) != NULL) {
        if (entry->d_type == DT_REG) {
            char *dot = strrchr(entry->d_name, '.');
            if (dot && strcmp(dot, ".json") == 0) {
                *dot = '\0';
                printf("%s\n", entry->d_name);
            }
        }
    }
    closedir(d);
}

void show_profile(const char *name) {
    char path[256];
    snprintf(path, sizeof(path), "%s/%s.json", PROFILES_DIR, name);
    FILE *f = fopen(path, "r");
    if (!f) {
        fprintf(stderr, "Profile '%s' not found.\n", name);
        return;
    }
    char buf[1024];
    size_t n;
    while ((n = fread(buf, 1, sizeof(buf), f)) > 0)
        fwrite(buf, 1, n, stdout);
    fclose(f);
}

int main(int argc, char **argv) {
    if (argc == 1) {
        printf("Usage: %s [list|show <name>]\n", argv[0]);
        return 0;
    }
    if (strcmp(argv[1], "list") == 0) {
        list_profiles();
    } else if (strcmp(argv[1], "show") == 0 && argc == 3) {
        show_profile(argv[2]);
    } else {
        fprintf(stderr, "Invalid command.\n");
        return 1;
    }
    return 0;
}