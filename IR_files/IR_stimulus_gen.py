time_counter = 0

#burst_low = 9510
burst_low = (8550 * 4)
burst_high = (4150 * 4)

false_low = (650 * 4)
false_high = (540 * 4)

true_low = (650 * 4)
true_high = (1700 * 4)

stop_low = (650 * 4)
repeat_high = (2590 * 4)

def ir_encode(address, command):
	global time_counter, burst_low, burst_high, stop_low, repeat_high

	print(str(time_counter) + ", 0,")
	time_counter += burst_low
	print(str(time_counter) + ", 1,")
	time_counter += burst_high

	ir_encode_byte(address)
	ir_encode_byte(0xFF ^ address)
	ir_encode_byte(command)
	ir_encode_byte(0xFF ^ command)

	print(str(time_counter) + ", 0,")
	time_counter += stop_low
	print(str(time_counter) + ", 1,")
	time_counter += repeat_high


def ir_encode_byte(value):
	global time_counter

	if (value & 1):
		ir_encode_bit(True)
	else:
		ir_encode_bit(False)
	if (value & 2):
		ir_encode_bit(True)
	else:
		ir_encode_bit(False)
	if (value & 4):
		ir_encode_bit(True)
	else:
		ir_encode_bit(False)
	if (value & 8):
		ir_encode_bit(True)
	else:
		ir_encode_bit(False)
	if (value & 16):
		ir_encode_bit(True)
	else:
		ir_encode_bit(False)
	if (value & 32):
		ir_encode_bit(True)
	else:
		ir_encode_bit(False)
	if (value & 64):
		ir_encode_bit(True)
	else:
		ir_encode_bit(False)
	if (value & 128):
		ir_encode_bit(True)
	else:
		ir_encode_bit(False)

def ir_encode_bit(value):
	global time_counter, false_low, false_high, true_low, true_high

	if (value):
		print(str(time_counter) + ", 0,")
		time_counter += true_low
		print(str(time_counter) + ", 1,")
		time_counter += true_high
	else:
		print(str(time_counter) + ", 0,")
		time_counter += false_low
		print(str(time_counter) + ", 1,")
		time_counter += false_high

def main():
	pioneer_address = 0x03
	pioneer_command = 0x00

	for x in range(0,19):
		ir_encode(pioneer_address, pioneer_command)

if __name__ == '__main__':
	main()
