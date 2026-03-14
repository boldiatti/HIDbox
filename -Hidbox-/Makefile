CC = clang
AR = ar
CFLAGS = -O2 -march=armv8-a -mtune=cortex-a53 -Iinclude -fPIC
LDFLAGS = -L. -Wl,-rpath,/mnt/SDCARD/App/hidbox/lib
LIBS = -lpthread -lrt -lm

# SDL2 detection (optional)
SDL_CFLAGS = $(shell pkg-config --cflags sdl2 2>/dev/null || echo "")
SDL_LIBS   = $(shell pkg-config --libs sdl2 2>/dev/null || echo "-lSDL2")

# Bluetooth library (must be present on target)
BLUEZ_LIBS = -lbluetooth

# Source files
LIB_SRCS = src/evdev.c src/hid_report.c src/usb_gadget.c src/bt_hid.c \
           src/ipc.c src/profile.c src/calibration.c src/descriptors.c \
           src/reconnect.c src/udev_monitor.c src/utils.c src/logger.c \
           src/skin_manager.c
LIB_OBJS = $(LIB_SRCS:.c=.o)
LIB_HIDBOX = libhidbox.a

all: dirs hidboxd hidbox-ui hidbox-config hidbox-ipc hidbox-profile \
     hidbox-usb hidbox-bt hidbox-watchdog

dirs:
	mkdir -p bin lib include

$(LIB_HIDBOX): $(LIB_OBJS)
	$(AR) rcs $@ $^

src/%.o: src/%.c include/hidbox.h
	$(CC) $(CFLAGS) $(SDL_CFLAGS) -c $< -o $@

hidboxd: tools/hidboxd.c $(LIB_HIDBOX)
	$(CC) $(CFLAGS) $< -o bin/$@ $(LIB_HIDBOX) $(LDFLAGS) $(LIBS) $(BLUEZ_LIBS)

hidbox-ui: tools/hidbox-ui.c $(LIB_HIDBOX)
	$(CC) $(CFLAGS) $(SDL_CFLAGS) $< -o bin/$@ $(LIB_HIDBOX) $(SDL_LIBS) $(LDFLAGS) $(LIBS)

hidbox-config: tools/hidbox-config.c $(LIB_HIDBOX)
	$(CC) $(CFLAGS) $< -o bin/$@ $(LIB_HIDBOX) $(LDFLAGS) $(LIBS)

hidbox-ipc: tools/hidbox-ipc.c $(LIB_HIDBOX)
	$(CC) $(CFLAGS) $< -o bin/$@ $(LIB_HIDBOX) $(LDFLAGS) $(LIBS)

hidbox-profile: tools/hidbox-profile.c $(LIB_HIDBOX)
	$(CC) $(CFLAGS) $< -o bin/$@ $(LIB_HIDBOX) $(LDFLAGS) $(LIBS)

hidbox-usb: tools/hidbox-usb.c $(LIB_HIDBOX)
	$(CC) $(CFLAGS) $< -o bin/$@ $(LIB_HIDBOX) $(LDFLAGS) $(LIBS)

hidbox-bt: tools/hidbox-bt.c $(LIB_HIDBOX)
	$(CC) $(CFLAGS) $< -o bin/$@ $(LIB_HIDBOX) $(BLUEZ_LIBS) $(LDFLAGS) $(LIBS)

hidbox-watchdog: tools/hidbox-watchdog.c $(LIB_HIDBOX)
	$(CC) $(CFLAGS) $< -o bin/$@ $(LIB_HIDBOX) $(LDFLAGS) $(LIBS)

clean:
	rm -f src/*.o $(LIB_HIDBOX) bin/*

.PHONY: all clean dirs