# 2IC80 - Lab on Offensive Security
## Group 14
### Eindhoven University of Technology

### Visualization

Underneath you can see a visualization of the attack. On the right side you can see all connected devices to the victim's machine and just after the keyboard is getting connected, the terminal is being opened and a command will be executed.

![Lab on Offensive Security](./gif/readme.gif)

### Firmware Modification Analysis - Keychron K8 Pro

This repository contains a modified version of the Keychron K8 Pro keyboard firmware that demonstrates potential security implications of compromised keyboard firmware.

#### Key Modifications from Original Firmware:

1. **Automatic Terminal Execution**
   - Added functionality to automatically open terminal after device connection
   - Implemented OS detection based on keyboard's OS switch position
   - Added automatic command execution sequence

2. **New Variables and Structures**
   ```c
   static bool terminal_sequence_active = false;
   static uint32_t terminal_timer_buffer = 0;
   static uint8_t terminal_sequence_step = 0;
   static uint8_t current_os = 0; // 0 for Mac, 1 for Windows
   ```

3. **Command Sequence Implementation**
   - Added terminal command sequences for both macOS and Windows
   - Implemented staged execution process:
     1. Open terminal (Command+Space/Win+R)
     2. Launch terminal application
     3. Execute predefined command
     4. Auto-close sequence

4. **Additional Key Combinations**
   - Extended `key_comb_list` array to include terminal launch shortcuts
   - Added specific command sequences for both operating systems

5. **Initialization Modifications**
   - Added terminal sequence initialization in `keyboard_post_init_kb`
   - Implemented OS detection based on default layer state
