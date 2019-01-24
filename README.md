# Adagio-PIC-FP
PIC code for Adagio front panel.

# Overview
This project was created as I had a Crestron Adagio AAS-2 Audio Server with a broken motherboard, and the idea was born to replace the broken motherboard with a Raspberry Pi. After a little investigation it was clear that the panel was based around a PIC 16F874, further more the SSP I2C port of the PIC is connected to the front panel IDC header making connection to the Pi easy. It was consider using the existing firmware, however that would require reverse engineering it, which would be costly time wise without any guarantee of a pratical solution at the end (potential problems include the character data transfer interface, IR receiver protocol and matching it to a new remote, and power control which doesn't exist in the original configuration). 

# Hardware
The front panel is designed around a PIC 16F1874 which has 4K of flash rom, 128 bytes of EEPROM storage and 192 bytes of RAM. A standard character LCD (Hitatchi 44780 clone) and 18 buttons provide the user interface, with the addition of an IR receiver (38 khz carrier) for remote support. A dual potentiometer (DS1845) provides programmatic control of the LCD brightness and contrast over an I2C interface.

## LCD
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

## Buttons
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
