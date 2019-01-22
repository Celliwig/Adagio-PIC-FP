# Adagio-PIC-FP
PIC code for Adagio front panel.

# Overview
This project was created as I had a Crestron Adagio AAS-2 Audio Server with a broken motherboard, and the idea was born to replace the broken motherboard with a Raspberry Pi. After a little investigation it was clear that the panel was based around a PIC 16F874, further more the SSP I2C port of the PIC is connected to the front panel IDC header making connection to the Pi easy. It was consider using the existing firmware, however that would require reverse engineering it, which would be costly time wise without any guarantee of a pratical solution at the end (potential problems include the character data transfer interface, IR receiver protocol and matching it to a new remote, and power control which doesn't exist in the original configuration). 
