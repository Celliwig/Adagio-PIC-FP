;*******************************************************************
; Screen buffer
;
; Various routines to facilitate the implementation of a screen
; buffer for a LCD display

;*******************************************************************
; Configures Timer2 to produce a 20 Hz interrupt to update the LCD.
; Timer2 used, this can preclude the use of the PIC as an SPI master.
;
; Clock is 4MHz/ so instruction cycle is 1 MHz
; 1000000 / (16 (Pre) * 223 (PR2) * 14 (Post)) = 20.019 Hz (near enough)
;
screen_timer_init
	banksel	PR2
	movlw	0xdf				; 233
	movwf	PR2				; Set the period register

						; T2CON Register
						; bit 7 Unimplemented: Read as '0'
						; bit 6-3 TOUTPS3:TOUTPS0: Timer2 Output Postscale Select bits
						;	0000 = 1:1 Postscale
						;	0001 = 1:2 Postscale
						;	0010 = 1:3 Postscale
						;	•
						;	•
						;	1111 = 1:16 Postscale
						; bit 2 TMR2ON: Timer2 On bit
						;	1 = Timer2 is on
						;	0 = Timer2 is off
						; bit 1-0 T2CKPS1:T2CKPS0: Timer2 Clock Prescale Select bits
						;	00 = Prescaler is 1
						;	01 = Prescaler is 4
						;	1x = Prescaler is 16
	banksel	T2CON
	movlw	77				; Prescaler (16), Postscaler (14), Timer2 on
	movwf	T2CON
	return

;*******************************************************************
; Clear and enable Timer2 interrupts
screen_timer_enable
	banksel	PIR1
	bcf	PIR1, TMR2IF
	banksel	PIE1
	bsf	PIE1, TMR2IE
	return

;*******************************************************************
; Clear and disable Timer2 interrupts
screen_timer_disable
	banksel	PIR1
	bcf	PIR1, TMR2IF
	banksel	PIE1
	bcf	PIE1, TMR2IE
	return

;*******************************************************************
; Clears (fills with spaces) the screen buffer

screen_clear
	banksel	_mr_screen_buffer_line1

	movlw	_mr_screen_buffer_line1		; Load the address of the first character of the screen buffer
	movwf	FSR				; Move this to the FSR

screen_clear_loop
	movlw	0x20				; ASCII space
	movwf	INDF				; move space to address pointed to by FSR
	incf	FSR, F				; increment address pointer
	movlw	(_mr_screen_buffer_line1 + 80)	; load end address of the buffer
	subwf	FSR, W
	btfss	STATUS, Z			; check if they are the same address
	goto	screen_clear_loop		; if they are, keep looping

	return

;*******************************************************************
; Write the screen buffer to the lcd
screen_write_2_lcd
	call	LCD_PORT_CONFIGURE

	movlw	LCD_CMD_SET_DDRAM | SCR_ROW0 | SCR_COL0
	call	LCD_WRITE_CMD

	banksel	_mr_screen_buffer_line1
	movlw	_mr_screen_buffer_line1
	movwf	FSR
	movlw	0x28					; We're writing 2 lines of data
	movwf   _mr_screen_buffer_loop
screen_write_2_lcd_lines13
	movf	INDF, W
	call	LCD_WRITE_DATA
	incf	FSR, F
	banksel	_mr_screen_buffer_loop
	decfsz	_mr_screen_buffer_loop, F
		goto	screen_write_2_lcd_lines13

	movlw	LCD_CMD_SET_DDRAM | SCR_ROW1 | SCR_COL0
	call	LCD_WRITE_CMD

	banksel	_mr_screen_buffer_line2
	movlw	_mr_screen_buffer_line2
	movwf	FSR
	movlw	0x28					; We're writing 2 lines of data
	movwf   _mr_screen_buffer_loop
screen_write_2_lcd_lines24
	movf	INDF, W
	call	LCD_WRITE_DATA
	incf	FSR, F
	banksel	_mr_screen_buffer_loop
	decfsz	_mr_screen_buffer_loop, F
		goto	screen_write_2_lcd_lines24

	call	LCD_PORT_RESTORE

	return


;*******************************************************************
; Draw a decorative border around the screen (lcd buffer)

screen_draw_border
	call	screen_clear

	banksel	_mr_screen_buffer_line1

	movlw	_mr_screen_buffer_line1
	movwf	FSR
	movlw	0x15
	movwf	_mr_screen_buffer_loop
	movlw	0x2A					; Ascii '*'
screen_draw_border_l13
	movwf	INDF
	incf	FSR, F
	decfsz	_mr_screen_buffer_loop, F
		goto	screen_draw_border_l13
	movf	FSR, W
	addlw	0x12
	movwf	FSR
	movlw	0x2A					; Ascii '*'
	movwf	INDF

	movlw	_mr_screen_buffer_line2
	movwf	FSR
	movlw	0x2A					; Ascii '*'
	movwf	INDF
	movf	FSR, W
	addlw	0x13
	movwf	FSR
	movlw	0x15
	movwf	_mr_screen_buffer_loop
	movlw	0x2A					; Ascii '*'
screen_draw_border_l24
	movwf	INDF
	incf	FSR, F
	decfsz	_mr_screen_buffer_loop, F
		goto	screen_draw_border_l24

	return

;*******************************************************************
; screen_write_byte_as_hex
;
; The purpose of this routine is to convert the byte in W to a 2 digit
; ASCII string representing the hexadecimal value of the byte. The FSR
; must be pointing to the correct position in the screen buffer.
;
; Memory used
;    _mr_screen_buffer_loop, _mr_screen_buffer_temp
;
screen_write_byte_as_hex
	banksel	_mr_screen_buffer_loop
	clrf	_mr_screen_buffer_loop		; Used as temporary storage to keep track of loop count
	movwf	_mr_screen_buffer_temp		; Save byte to be written here
wbah1:
	swapf	_mr_screen_buffer_temp,W	; Write the high nibble first.
	andlw	0x0f				; Get the lower nibble of W
	addlw	-0xa				; If it is >= 0xa, then
	btfsc	STATUS, C			;    the carry will get set.
	addlw	'A'-'9' - 1			; The digit is between 0xa and 0xf
	addlw	'9'+ 1				; Convert it to ASCII
	movwf	INDF				; write digit to screen buffer
	incf	FSR, F				; increment buffer pointer
	btfsc	_mr_screen_buffer_loop,1	; This bit is clear the first time through the loop.
	return
	swapf	_mr_screen_buffer_temp,F	; Get the low nibble
	bsf	_mr_screen_buffer_loop,1	; Set so next time through we will return.
	goto	wbah1

;;*******************************************************************
;;write_word_as_hex
;; The purpose of this routine is to convert the word pointed to by W to a
;; 4 digit ASCII string representing the hexadecimal value of the word.
;; Note, words are stored in RAM with the least significant byte first.
;;
;; Memory used
;;    _mr_str_buffer2
;; Calls
;;    write_byte_as_hex
;;
;write_word_as_hex
;        MOVWF   FSR                     ;W points to the word
;        MOVWF   _mr_str_buffer2                 ;Save a copy of the pointer
;        INCF    FSR, F                  ;Point to the MSB
;        MOVF    INDF,W                  ;Get the MSB
;        CALL    write_byte_as_hex       ;And print it.
;        MOVF    _mr_str_buffer2,W               ;Get pointer to the word.
;        MOVWF   FSR                     ;W now points to the LSB
;        MOVF    INDF,W                  ;Get the LSB
;        goto    write_byte_as_hex       ;And print it.

;*******************************************************************
; screen_write_eeprom_2_buffer
;
; Copies a zero terminated string from the EEPROM to the screen
; buffer. FSR needs to be configured to point to the correct
; location in the screen buffer. W register points to the offset in
; ROM.
;
screen_write_eeprom_2_buffer
	banksel	EEADR
	movwf	EEADR			; Write EEPROM offset address
screen_write_eeprom_2_buffer_read
	banksel	EECON1
	bcf	EECON1, EEPGD		; Select EEPROM memory
	bsf	EECON1, RD		; Start read operation
	banksel	EEADR
	incf	EEADR, F
	movf	EEDATA, W		; Read data

	btfsc	STATUS, Z
		goto	screen_write_eeprom_2_buffer_exit
	banksel	_mr_screen_buffer_line1
	movwf	INDF
	incf	FSR, F
	goto	screen_write_eeprom_2_buffer_read

screen_write_eeprom_2_buffer_exit
	return
