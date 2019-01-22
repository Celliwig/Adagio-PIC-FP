;*******************************************************************
; IR Reciever
;
; This is designed to work with a Pioneer CU-PD078 remote. This
; remote works on the NEC IR protocol. Good info here:
;
;	https://www.sbprojects.net/knowledge/ir/nec.php
;	http://www.adrian-kingston.com/IRFormatPioneer.htm
;
; This is a PWM signal, so Timer1 is used to sample the signal (RB4)
; at regular intervals. Helpfully, this signal is also available on
; the main connector, PL1(#28).
;
; The signal is comprised:
;
;	1: AGC Burst (9ms)
;	2: Blank (4.5m)
;	3: Address (8 bit)
;	4: Address Inverted (8 bit)
;	5: Command (8 bit)
;	6: Command Inverted (8 bit)
;	7: Stop pulse
;
; The Address/Command bytes are sent both normally and inverted so
; as to allow error checking. The nominal values for a logical 1 and
; 0 are; 2.2ms and 1.1ms respectively. These values were measured
; using a bus pirate connected to PL1(#28). The signal measured on
; RB4 is inverted, so logical 0 when IR transmitted.
;
; A logical 0 has a duty cycle of about 1/2, a logical 1's duty cycle
; is near 1/3, 1/4.
;
; A 100 us sample rate should allow ample resolution of the signal.
; Clock is 4MHz so instruction cycle is 1 MHz, so CCP is set to 100.
;
; Commands are repeated every 110ms.
;
;*******************************************************************
; ir_receiver_timer_init
;
; Setup Timer1 and CCP2 to produce a 10 kHz interrupt.
;
ir_receiver_timer_init
	banksel	CCPR2H
	clrf	CCPR2H		; Setup the CCP2 registers, to generate a periodic interrupt
	movlw	0x64		; 100, to give a 10kHz interrupt
	movwf	CCPR2L

	movlw	0x0
	movwf	ADCON0		; Make sure the A/D module is disabled

				; CCP2CON Register
				; bit 7-6 Unimplemented: Read as '0'
				; bit 5-4 CCPxX:CCPxY: PWM Least Significant bits
				;	Capture mode:
				;		Unused
				;	Compare mode:
				;		Unused
				;	PWM mode:
				;		These bits are the two LSbs of the PWM duty cycle. The eight MSbs are found in CCPRxL.
				; bit 3-0 CCPxM3:CCPxM0: CCPx Mode Select bits
				;	0000 = Capture/Compare/PWM disabled (resets CCPx module)
				;	0100 = Capture mode, every falling edge
				;	0101 = Capture mode, every rising edge
				;	0110 = Capture mode, every 4th rising edge
				;	0111 = Capture mode, every 16th rising edge
				;	1000 = Compare mode, set output on match (CCPxIF bit is set)
				;	1001 = Compare mode, clear output on match (CCPxIF bit is set)
				;	1010 = Compare mode, generate software interrupt on match (CCPxIF bit is set, CCPx pin is
				;		unaffected)
				;	1011 = Compare mode, trigger special event (CCPxIF bit is set, CCPx pin is unaffected); CCP2
				;		resets TMR1; CCP2 resets TMR1 and starts an A/D conversion (if A/D module is enabled)
				;	11xx = PWM mode

	movlw	0x0b		; Compare mode (trigger special event, CCP2 resets TMR1)
	movwf	CCP2CON

	clrf	TMR1L
	clrf	TMR1H
				; T1CON Register
				; bit 7-6 Unimplemented: Read as '0'
				; bit 5-4 T1CKPS1:T1CKPS0: Timer1 Input Clock Prescale Select bits
				;	11 = 1:8 Prescale value
				;	10 = 1:4 Prescale value
				;	01 = 1:2 Prescale value
				;	00 = 1:1 Prescale value
				; bit 3 T1OSCEN: Timer1 Oscillator Enable Control bit
				;	1 = Oscillator is enabled
				;	0 = Oscillator is shut-off (the oscillator inverter is turned off to eliminate power drain)
				; bit 2 T1SYNC: Timer1 External Clock Input Synchronization Control bit
				;	When TMR1CS = 1:
				;		1 = Do not synchronize external clock input
				;		0 = Synchronize external clock input
				;	When TMR1CS = 0:
				;		This bit is ignored. Timer1 uses the internal clock when TMR1CS = 0.
				; bit 1 TMR1CS: Timer1 Clock Source Select bit
				;	1 = External clock from pin RC0/T1OSO/T1CKI (on the rising edge)
				;	0 = Internal clock (F OSC /4)
				; bit 0 TMR1ON: Timer1 On bit
				;	1 = Enables Timer1
				;	0 = Stops Timer1
	movlw	0x1		; Prescaler (1:1), Clock source (Internal), Timer1 On
	movwf	T1CON

	return

;*******************************************************************
; ir_receiver_timer_enable
;
; Enable the interrupt for the CCP2 module, disable TMR1
;
ir_receiver_timer_enable
	banksel	_mr_ir_receiver_count_true
	clrf	_mr_ir_receiver_count_true					; Clear decoder state
	clrf	_mr_ir_receiver_count_false
	clrf	_mr_ir_receiver_error_count
	clrf	_mr_ir_receiver_address
	clrf	_mr_ir_receiver_address_inverted
	clrf	_mr_ir_receiver_command
	clrf	_mr_ir_receiver_command_inverted
	clrf	_mr_ir_receiver_command_actual
	clrf	_mr_ir_receiver_command_repeat
	movlw	IR_RECEIVER_MODE_WAIT
	movwf	_mr_ir_receiver_state						; Set mode to waiting
	movlw	0x01
	movwf	_mr_ir_receiver_bit_index					; This is a bit indicator, so set to 1

	banksel	PIR1
	bcf	PIR1, TMR1IF	; Reset interrupt flag
	bcf	PIR2, CCP2IF	; Reset interrupt flag
	banksel	PIE1
	bcf	PIE1, TMR1IE	; Disable Timer1 interrupt
	bsf	PIE2, CCP2IE	; Enable CCP2 interrupt
	return

;*******************************************************************
; ir_receiver_timer_disable
;
; Disables the CCP2 interrupt
;
ir_receiver_timer_disable
	banksel	PIR2
	bcf	PIR2, CCP2IF	; Reset interrupt flag
	banksel	PIE2
	bcf	PIE2, CCP2IE	; Enable CCP2 interrupt
	return

;*******************************************************************
; ir_receiver_interrupt_handler
;
; Captures and decodes the raw IR signal. Expects it's registers to
; be in the bank 0.
;
; Registers used:
;	_mr_ir_receiver_count_true (count of the period when the signal was high, signal is inverted)
;	_mr_ir_receiver_count_false (count of the period when the signal was low, signal is inverted)
;	_mr_ir_receiver_state (Current state of the decoder)
;
ir_receiver_interrupt_handler
	banksel	_mr_ir_receiver_state

; Mode Wait
;*******************************************************************
ir_receiver_interrupt_handler_mode_wait
	btfss	_mr_ir_receiver_state, IR_RECEIVER_MODE_BIT_WAIT		; Are we waiting for a signal?
		goto	ir_receiver_interrupt_handler_mode_burst		; No, try the next mode
	btfsc	PORTB, 4							; Is there a signal?
		goto	ir_receiver_interrupt_handler_mode_wait_repeat_check	; No, see if we have timed out waiting for a repeat
	movlw	0x01
	movwf	_mr_ir_receiver_count_true					; We've already counted one 'cycle'
	movwf	_mr_ir_receiver_bit_index					; This is a bit indicator, so set 1
	clrf	_mr_ir_receiver_count_false
	clrf	_mr_ir_receiver_address
	clrf	_mr_ir_receiver_address_inverted
	clrf	_mr_ir_receiver_command
	clrf	_mr_ir_receiver_command_inverted
	clrf	_mr_ir_receiver_command_repeat
	movlw	IR_RECEIVER_MODE_BURST						; Set to the next mode
	movwf	_mr_ir_receiver_state
	goto	ir_receiver_interrupt_handler_exit				; Goto exit

ir_receiver_interrupt_handler_mode_wait_repeat_check
	incf	_mr_ir_receiver_count_false, F
	btfss	STATUS, Z
		goto	ir_receiver_interrupt_handler_exit
	incf	_mr_ir_receiver_command_repeat, F
	movf	_mr_ir_receiver_command_repeat, W				; Is the command repeating
										; Commands repeat every 110ms
										; To allow for errors, reset command after approx. 220ms
										; _mr_ir_receiver_count_false * 256 = 25.6ms
	sublw	8
	btfsc	STATUS, C
		goto	ir_receiver_interrupt_handler_exit
	clrf	_mr_ir_receiver_command_actual					; Clear existing command
	clrf	_mr_ir_receiver_command_repeat
	goto	ir_receiver_interrupt_handler_exit

; Mode Burst
;*******************************************************************
ir_receiver_interrupt_handler_mode_burst
	btfss	_mr_ir_receiver_state, IR_RECEIVER_MODE_BIT_BURST		; Are we waiting for the burst?
		goto	ir_receiver_interrupt_handler_mode_byte			; No, try the next mode
	btfss	PORTB, 4							; Check signal state
		goto	ir_receiver_interrupt_handler_mode_burst_high		; This a logic '1'
	incf	_mr_ir_receiver_count_false, F					; Otherwise increment '0' counter
	btfsc	STATUS, Z
		goto	ir_receiver_interrupt_handler_mode_invalid		; Counter's rolled over, BAD!!!
	goto	ir_receiver_interrupt_handler_exit
ir_receiver_interrupt_handler_mode_burst_high
	movf	_mr_ir_receiver_count_false, F					; Check if we had a low period
	btfss	STATUS, Z
		goto	ir_receiver_interrupt_handler_mode_burst_check		; This is the start of a byte, so check burst
	incf	_mr_ir_receiver_count_true, F					; Otherwise increment '1' counter
	btfsc	STATUS, Z
		goto	ir_receiver_interrupt_handler_mode_invalid		; Counter's rolled over, BAD!!!
	goto	ir_receiver_interrupt_handler_exit
ir_receiver_interrupt_handler_mode_burst_check
	movf	_mr_ir_receiver_count_true, W					; Check '1' counter is between 64 and 128
	andlw	0xC0								; Remove LSBs
	btfsc	STATUS, Z							; '1' counter >= 64
		goto	ir_receiver_interrupt_handler_mode_invalid
	andlw	0x40
	btfsc	STATUS, Z							; '1' counter < 128
		goto	ir_receiver_interrupt_handler_mode_invalid

	movf	_mr_ir_receiver_count_false, W					; Check '0' counter is between 32 and 64
	andlw	0xE0								; Remove LSBs
	btfsc	STATUS, Z							; '1' counter >= 32
		goto	ir_receiver_interrupt_handler_mode_invalid
	andlw	0x20
	btfsc	STATUS, Z							; '1' counter < 64
		goto	ir_receiver_interrupt_handler_mode_invalid

	clrf	_mr_ir_receiver_count_true					; Clear the sample register
	incf	_mr_ir_receiver_count_true, F
	clrf	_mr_ir_receiver_count_false
	movlw	IR_RECEIVER_MODE_ADDRESS					; Set to the next mode
	movwf	_mr_ir_receiver_state
	goto	ir_receiver_interrupt_handler_exit				; Goto exit

; Mode Address/Command
;*******************************************************************
ir_receiver_interrupt_handler_mode_byte
	movf	_mr_ir_receiver_state, W
	andlw	IR_RECEIVER_MODE_BYTE						; Is this a address/command?
	btfsc	STATUS, Z
		goto	ir_receiver_interrupt_handler_mode_stop			; No, try the next mode
	btfss	PORTB, 4							; Check signal state
		goto	ir_receiver_interrupt_handler_mode_byte_high		; This a logic '1'
	incf	_mr_ir_receiver_count_false, F					; Otherwise increment '0' counter
	btfsc	STATUS, Z
		goto	ir_receiver_interrupt_handler_mode_invalid		; Counter's rolled over, BAD!!!
	goto	ir_receiver_interrupt_handler_exit
ir_receiver_interrupt_handler_mode_byte_high
	movf	_mr_ir_receiver_count_false, F					; Check if we had a low period
	btfss	STATUS, Z
		goto	ir_receiver_interrupt_handler_mode_byte_check		; This is the start of a byte, so check byte
	incf	_mr_ir_receiver_count_true, F					; Otherwise increment '1' counter
	btfsc	STATUS, Z
		goto	ir_receiver_interrupt_handler_mode_invalid		; Counter's rolled over, BAD!!!
	goto	ir_receiver_interrupt_handler_exit
ir_receiver_interrupt_handler_mode_byte_check
	movf	_mr_ir_receiver_count_true, W					; Check '1' counter is between 4 and 8
	andlw	0xFC								; Remove LSBs
	btfsc	STATUS, Z							; '1' counter >= 4
		goto	ir_receiver_interrupt_handler_mode_invalid
	andlw	0xF8
	btfss	STATUS, Z							; '1' counter < 8
		goto	ir_receiver_interrupt_handler_mode_invalid

	movf	_mr_ir_receiver_count_false, W					; Check '0' counter is between 4 and 32
	andlw	0xFC								; Remove LSBs
	btfsc	STATUS, Z							; '0' counter >= 4
		goto	ir_receiver_interrupt_handler_mode_invalid
	andlw	0xE0
	btfss	STATUS, Z							; '0' counter < 32
		goto	ir_receiver_interrupt_handler_mode_invalid

	clrf	_mr_ir_receiver_ft_divide					; Reset divide store
	movf	_mr_ir_receiver_count_true, W
ir_receiver_interrupt_handler_mode_byte_check_divide
	incf	_mr_ir_receiver_ft_divide, F					; increment the divide store
	subwf	_mr_ir_receiver_count_false, F					; _mr_ir_receiver_count_false - _mr_ir_receiver_count_true
	btfss	STATUS, C							; Is the result positive?
		goto	ir_receiver_interrupt_handler_mode_byte_check_ratio	; Check the ratio of false to positive
	goto	ir_receiver_interrupt_handler_mode_byte_check_divide

ir_receiver_interrupt_handler_mode_byte_check_ratio
	movlw	0xF8
	andwf	_mr_ir_receiver_ft_divide, W					; Is this <= 8
	btfss	STATUS, Z
		goto	ir_receiver_interrupt_handler_mode_invalid		; Too large, so invalid
	movf	_mr_ir_receiver_ft_divide, W
	sublw	0x02								; 2 - _mr_ir_receiver_ft_divide
	btfsc	STATUS, C
		goto	ir_receiver_interrupt_handler_mode_byte_bit_false	; Ratio 2 or less, so logical false

ir_receiver_interrupt_handler_mode_byte_bit_true
	movf	_mr_ir_receiver_bit_index, W
	btfsc	_mr_ir_receiver_state, IR_RECEIVER_MODE_BIT_ADDRESS
		iorwf	_mr_ir_receiver_address, F
	btfsc	_mr_ir_receiver_state, IR_RECEIVER_MODE_BIT_ADDRESS_INV
		iorwf	_mr_ir_receiver_address_inverted, F
	btfsc	_mr_ir_receiver_state, IR_RECEIVER_MODE_BIT_COMMAND
		iorwf	_mr_ir_receiver_command, F
	btfsc	_mr_ir_receiver_state, IR_RECEIVER_MODE_BIT_COMMAND_INV
		iorwf	_mr_ir_receiver_command_inverted, F
ir_receiver_interrupt_handler_mode_byte_bit_false
	bcf	STATUS, C							; Clear carry for rotate instruction next
	rlf	_mr_ir_receiver_bit_index, F					; Select next bit
	clrf	_mr_ir_receiver_count_true					; Clear the sample register
	incf	_mr_ir_receiver_count_true, F
	clrf	_mr_ir_receiver_count_false

	movf	_mr_ir_receiver_bit_index, F					; If zero, we've rotated the bit off the byte, so new byte
	btfss	STATUS, Z
		goto	ir_receiver_interrupt_handler_exit			; Same byte, so just exit
	bcf	STATUS, C							; Clear carry for rotate instruction next
	rlf	_mr_ir_receiver_state, F					; Set to the next mode
	movlw	0x01
	movwf	_mr_ir_receiver_bit_index					; Reset bit index
	goto	ir_receiver_interrupt_handler_exit				; Goto exit

; Mode Stop
;*******************************************************************
ir_receiver_interrupt_handler_mode_stop
	btfss	PORTB, 4							; Check signal state
		goto	ir_receiver_interrupt_handler_exit			; This a logic '1', just ignore

; Process command
;*******************************************************************
	comf	_mr_ir_receiver_address_inverted, W				; Check if the address and inverted versions match
	subwf	_mr_ir_receiver_address, W
	btfss	STATUS, Z
		goto	ir_receiver_interrupt_handler_mode_invalid
	comf	_mr_ir_receiver_command_inverted, W				; Check if the command and inverted versions match
	subwf	_mr_ir_receiver_command, W
	btfss	STATUS, Z
		goto	ir_receiver_interrupt_handler_mode_invalid

	movf	_mr_ir_receiver_address, W					; Check received address against our address
	subwf	_mr_ir_receiver_address_actual, W
	btfss	STATUS, Z
		goto	ir_receiver_interrupt_handler_mode_reset		; Addresses don't match, so just reset

	movf	_mr_ir_receiver_command, W
	movwf	_mr_ir_receiver_command_actual					; Command confirmed, move to 'real' command register

	goto	ir_receiver_interrupt_handler_mode_reset			; Reset state

ir_receiver_interrupt_handler_mode_invalid
	incf	_mr_ir_receiver_error_count, F					; Increment the error count

ir_receiver_interrupt_handler_mode_reset
	clrf	_mr_ir_receiver_count_false					; Needed to detect repeated signal, or lack thereof
	movlw	IR_RECEIVER_MODE_WAIT						; Invalid signal detected, so reset state
	movwf	_mr_ir_receiver_state

ir_receiver_interrupt_handler_exit
	banksel	PIR2
	bcf	PIR2, CCP2IF							; Clear CCP2 interrupt flag

	return
