#!/usr/bin/env python3
import os, struct, fcntl, time

UI_SET_EVBIT = 0x40045564
UI_SET_KEYBIT = 0x40045565
UI_DEV_CREATE = 0x5501
UI_DEV_DESTROY = 0x5502

EV_SYN = 0
EV_KEY = 1
KEY_LEFTSHIFT = 42
SYN_REPORT = 0

def send_shift():
    try:
        fd = os.open('/dev/uinput', os.O_WRONLY | os.O_NONBLOCK)
    except Exception:
        return
    try:
        fcntl.ioctl(fd, UI_SET_EVBIT, EV_KEY)
        fcntl.ioctl(fd, UI_SET_KEYBIT, KEY_LEFTSHIFT)
        uinput_user_dev = struct.pack('80sHHHH1028s', b'virtual-keyboard', 0x03, 0x01, 0x01, 0x01, b'\x00' * 1028)
        os.write(fd, uinput_user_dev)
        fcntl.ioctl(fd, UI_DEV_CREATE)
        time.sleep(0.05)
        event_press = struct.pack('qqHHi', 0, 0, EV_KEY, KEY_LEFTSHIFT, 1)
        event_syn = struct.pack('qqHHi', 0, 0, EV_SYN, SYN_REPORT, 0)
        event_release = struct.pack('qqHHi', 0, 0, EV_KEY, KEY_LEFTSHIFT, 0)
        os.write(fd, event_press)
        os.write(fd, event_syn)
        time.sleep(0.05)
        os.write(fd, event_release)
        os.write(fd, event_syn)
        time.sleep(0.05)
        fcntl.ioctl(fd, UI_DEV_DESTROY)
    finally:
        os.close(fd)

if __name__ == '__main__':
    send_shift()
