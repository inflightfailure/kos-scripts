import krpc
import serial
import time
import struct
import sys

def connect_to_ksp(max_attempts=5, retry_delay=5):
    attempt = 0
    while attempt < max_attempts:
        try:
            print(f"Attempting to connect to KSP (attempt {attempt + 1}/{max_attempts})...")
            conn = krpc.connect(name='Teensy Altitude Relay')
            print("Connected successfully!")
            return conn
        except ConnectionRefusedError:
            attempt += 1
            if attempt < max_attempts:
                print(f"Connection failed. Retrying in {retry_delay} seconds...")
                time.sleep(retry_delay)
            else:
                print("Failed to connect after maximum attempts.")
                print("Please ensure:")
                print("1. KSP is running")
                print("2. kRPC mod is installed")
                print("3. kRPC server is enabled in-game")
                sys.exit(1)

# Connect to KSP and wait for active vessel
conn = connect_to_ksp()

def wait_for_vessel(max_attempts=20, retry_delay=1):
    attempt = 0
    while attempt < max_attempts:
        try:
            vessel = conn.space_center.active_vessel
            print("Connected to active vessel!")
            return vessel
        except (ValueError, AttributeError):
            attempt += 1
            if attempt < max_attempts:
                print(f"No active vessel found. Retrying in {retry_delay} seconds... ({attempt}/{max_attempts})")
                time.sleep(retry_delay)
            else:
                print("Failed to find active vessel after maximum attempts.")
                print("Please ensure:")
                print("1. A vessel is loaded in the game")
                print("2. You are not in the space center view")
                print("3. The vessel has a kRPC server part")
                sys.exit(1)

vessel = wait_for_vessel()

def find_serial_port():
    """Find the first available USB serial port."""
    import glob
    ports = glob.glob('/dev/ttyUSB*') + glob.glob('/dev/ttyACM*')
    if not ports:
        print("No USB serial ports found!")
        print("Please ensure:")
        print("1. Your USB device is connected")
        print("2. You have permissions to access serial ports")
        print("   Run: sudo usermod -a -G dialout $USER")
        print("   Then log out and back in")
        sys.exit(1)
    return ports[0]

try:
    port = find_serial_port()
    print(f"Using serial port: {port}")
    ser = serial.Serial(port, 9600, timeout=1)
except serial.SerialException as e:
    print(f"Error opening serial port: {e}")
    print("If permission denied, run:")
    print("sudo usermod -a -G dialout $USER")
    sys.exit(1)

use_mean = False

while True:
    # Check for incoming toggle command
    if ser.in_waiting:
        command = ser.read().decode()
        if command == 'T':  # T = Toggle
            print("Toggle command received. Switching altitude mode.")
            use_mean = not use_mean

    # Get total and available ElectricCharge resources
    electric_charge = vessel.resources.amount('ElectricCharge')
    electric_charge_max = vessel.resources.max('ElectricCharge')

    # Calculate percentage
    if electric_charge_max > 0:
        charge_percent = int((electric_charge / electric_charge_max) * 100)
    else:
        charge_percent = 0
    print(f"Charge amount: {electric_charge}, Max: {electric_charge_max}, Percent: {charge_percent}")

    alt = int(vessel.flight().mean_altitude if use_mean else vessel.flight().surface_altitude)
    apoapsis = int(vessel.orbit.apoapsis_altitude)
    ser.write(f"{alt}:{charge_percent}\n".encode())
    time.sleep(0.5)  # 0.1 causes annoying flicker

