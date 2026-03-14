void process_command(HIDBoxDaemon* daemon, const char* cmd) {
    if (strstr(cmd, "toggle_bt")) {
        daemon->bt_enabled = !daemon->bt_enabled;
        // optionally reinit if turning on and not connected
    }
    // other commands...
}