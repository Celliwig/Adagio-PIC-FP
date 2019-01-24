# Adagio-PIC-FP
PIC code for Adagio front panel.

# Overview
This project was created as I had a Crestron Adagio AAS-2 Audio Server with a broken motherboard, and the idea was born to replace the broken motherboard with a Raspberry Pi. After a little investigation it was clear that the panel was based around a PIC 16F874, further more the SSP i2c port of the PIC is connected to the front panel IDC header making connection to the Pi easy. It was consider using the existing firmware, however that would require reverse engineering it, which would be costly time wise without any guarantee of a pratical solution at the end (potential problems include the character data transfer interface, IR receiver protocol and matching it to a new remote, and power control which doesn't exist in the original configuration). 

# Hardware
The front panel is designed around a PIC 16F1874 which has 4K of flash rom, 128 bytes of EEPROM storage and 192 bytes of RAM. A standard character LCD (Hitatchi 44780 clone) and 18 buttons provide the user interface, with the addition of an IR receiver (38 khz carrier) for remote support. A dual potentiometer (DS1845) provides programmatic control of the LCD brightness and contrast over an i2c interface. Interfacing is provided by a 40 pin IDC header (PL1), see docs/Adagio Front Panel.ods for the pinout. A 6 pin crimp style connector (PL2) provides power to board, and this also doubles as an ISP (in system programming) interface.

# Firmware design
The new firmware must give full access to all of the exising hardware, and in addition implement 'power' control. This requires implementation of power on/off states, and additional interfacing to RPi. The various signals are:
 - RPi reset (RPi RUN pin)
 - RPi initiate shutdown (RPi GPIO pin - see RPi overlay gpio-shutdown)
 - RPi shutdown confirmed (RPi GPIO pin - see RPi overlay gpio-poweroff)
 - PSU enable
 
### I2C
The main interface to the RPi is through the i2c interface, however the situation is complicated by the fact that the PIC also has to control the LCD brightness/contrast when switching between power on and off states. This requires that the PIC be either the master or a slave in the appropriate mode. One advantage of the 16F874 is that one of the available periphals is an i2c module, which reduces the complexity of the required code.

### Screen
To reduce the amout of time the PIC spends servicing an i2c command from the RPi (writing to the screen requires wasting time waiting for the data values to become valid) a screen buffer was implemented. One of the onboard timer modules is then used to generate a periodic interrupt to set a flag to cause a screen update.

### IR
Another of the available timers is used to generate an interrupt to sample RB4. This is processed looking for a valid (according to the NEC protocol) command.

### LCD + Buttons
Because the buttons and the LCD share data lines (RD0-7) it was decided to handle button scanning and LCD updates within the main loop, thereby guaranteeing mutual exclusion. These could have been seperated but the mutexs required would have overly complicated the code for little gain.

### RPi signals
One source of conflict is that the panel is running at 5 volts, while the RPi runs (interface wise) at 3.3 volts. Accidentally applying 5 volts to the RPi could be terminal. However the 2 signals that are inputs to the RPi, reset and shutdown init, are (or can be configured) active low. So the solution is to configure those pins as inputs in their inactive state (high impedance), then switching them to outputs having already configured their state to being low when needed. The other signal, shutdown confirmed, is fed as is to PIC external interrupt, being just within range for the PI to detect.

# Test Mode
To help testing of both the firmware and hardware interface to the RPi a test mode was created, it can be accessed by holding down play while pressing power. Available tests are:
 - Button - Test front panel buttons.
 - LCD - Simple test of the LCD display.
 - IR - Shows the address and data (with corresponding FP command) from a remote (if it's compatible).
 - Power - Allows the toggling of RPi reset, RPi shutdown init, PSU enable.
 - i2c Master - Increment/decrement brightness/contrast of the lcd.
 - i2c Slave - Shows data sent from the RPi.
 
 N.B. While implementing a firmware that was fully programmable in regard to translating IR commands to the equivalent FP commands was deemed impractical, the IR remote address is stored in the EEPROM and can be easily reprogrammed while in the IR test mode by simply registering a valid command from the remote (the received address will update) and then pressing eject.
 
# Pic pin assignment
### LCD
| Function | LCD Pin | PIC Pin |
| --------:| -------:| -------:|
|    DB7   |     3   |   RD7   |
|    DB6   |     4   |   RD6   |
|    DB5   |     5   |   RD5   |
|    DB4   |     6   |   RD4   |
|    DB3   |     7   |   RD3   |
|    DB2   |     8   |   RD2   |
|    DB1   |     9   |   RD1   |
|    DB0   |    10   |   RD0   |
|  Enable  |    11   |   RC7   |
|    R/W   |    12   |   RC6   |
|    RS    |    13   |   RC5   |

### Buttons
Part of the button matrix is shared with the lcd data lines (RD0-7). RB1, RB2, and RC2 are used to select the different button banks.

| Pic Pin |   RB1    |   RB2    |   RC2    |
| -------:| --------:| --------:| --------:|
|   RD0   | Previous |    Up    |   Power  |
|   RD1   | Display4 |  Right   |   Play   |
|   RD2   | Display3 |    -     |   Left   |
|   RD3   |   Mode   |    -     |   CD/HD  |
|   RD4   |   Next   |    -     | Display2 |
|   RD5   |   Stop   |    -     |   Down   |
|   RD6   | Display1 |    -     |  Select  |
|   RD7   |   Eject  |    -     |   Pause  |

### LEDs
 - RE2 = Power
 - RC1 = Online
 
### Additional
 - RB4 = IR receiver
 - RA5 = RPi reset
 - RB7 = RPi Shutdown Init
 - RB0 = RPi Shutdown Confirmed
 - RC0 = PSU Enable
