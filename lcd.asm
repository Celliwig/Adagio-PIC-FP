;********************************************************************************
;
; The file contains code to control an LCD module.
;
; Originally developed by T. Scott Dattalo (see gpsim)
;
;********************************************************************************

;*******************************************************************
;
; EQUates


T0CKI           equ     H'0004'
UF_SELECTED_FIELD       equ     0x0f
UF_SELECT_MODE          equ     4
UF_EDIT_MODE            equ     5
UF_ON_SELECTED_FIELD    equ     6
UF_IS_EDITABLE          equ     7

UF_SELECT_NEXT          equ     0
UF_SELECT_PREV          equ     1

		org	LCD_BASE_ADDR

;*******************************************************************
; LCD_PORT_CONFIGURE
;
; Configures the correct PIC ports to driver the LCD
;
; Registers used:
;	this: W	(temporarily store TRIS value)
;	this: _mr_oldxtris
;	this: _mr_oldytris
;
LCD_PORT_CONFIGURE
	banksel	LCD_CONTROL_TRIS
	movf	LCD_CONTROL_TRIS, W		; Save port configuration
	bcf	LCD_CONTROL_TRIS, LCD_E		; Initialize the LCD_PORT control and data lines to outputs
	bcf	LCD_CONTROL_TRIS, LCD_R_W
	bcf	LCD_CONTROL_TRIS, LCD_RS
	banksel	_mr_oldxtris
	movwf	_mr_oldxtris

	banksel	LCD_DATA_TRIS
	movf	LCD_DATA_TRIS, W		; Save port configuration
	clrf	LCD_DATA_TRIS			; Make LCD_PORT IO lines outputs
	banksel	_mr_oldytris
	movwf	_mr_oldytris

	return

;*******************************************************************
; LCD_PORT_RESTORE
;
; Restores the original port configuration to the PIC
;
; Registers used:
;	this: W	(temporarily store TRIS value)
;	this: _mr_oldxtris
;	this: _mr_oldytris
;
LCD_PORT_RESTORE
	banksel	_mr_oldxtris
	movf	_mr_oldxtris, W
	banksel	LCD_CONTROL_TRIS
	movwf	LCD_CONTROL_TRIS	; Make LCD_PORT IO lines outputs

	banksel	_mr_oldytris
	movf	_mr_oldytris, W
	banksel	LCD_DATA_TRIS
	movwf	LCD_DATA_TRIS		; Make LCD_PORT IO lines outputs

	return

;*******************************************************************
; LCD_INITIALIZE
; Right now, the display could be either in 8-bit mode if we
; just powered up, or it could be in 4-bit mode if we just
; experienced a reset. So to begin, we have to initialize the
; display to a known state: the 8-bit mode. This is done by
; sending the LCD command "Function Set" with the 8-bit mode
; bit set. We need to do this 3 times!

LCD_INITIALIZE
	call	LCD_PORT_CONFIGURE

	movlw	3
	banksel	_mr_lcd_loop
	movwf	_mr_lcd_loop				; Use _mr_lcd_loop as a loop counter
	banksel	LCD_CONTROL_PORT
	bcf	LCD_CONTROL_PORT, LCD_E
	bcf	LCD_CONTROL_PORT, LCD_RS
	bcf	LCD_CONTROL_PORT, LCD_R_W

lcd_init_8bit:
	call	LCD_DELAY

	banksel	LCD_DATA_PORT
	movf	LCD_DATA_PORT, W
	iorlw	(LCD_CMD_FUNC_SET | LCD_8bit_MODE) >> LCD_DATA_SHIFT
	movwf	LCD_DATA_PORT				; Put command on the bus

	nop
	call	LCD_RAISE_E
	call	LCD_DROP_E

	banksel	_mr_lcd_loop
	decfsz	_mr_lcd_loop, F
	goto	lcd_init_8bit

; If this is an OLED display, make sure to turn on DC/DC PSU and select character mode
IFDEF	OLED_DISPLAY
	movlw	LCD_CMD_FUNC_SET | LCD_8bit_MODE | LCD_2_LINES | LCD_SMALL_FONT | LCD_FONT_WESTERN_EUROPEAN2
	call	LCD_WRITE_CMD

	banksel	_mr_lcd_module_state
	bsf	_mr_lcd_module_state, 1
	movlw	LCD_CMD_MODEPWR_CTRL | LCD_MODE_CHAR | LCD_DCDC_ON
	call	LCD_WRITE_CMD
ELSE
	movlw	LCD_CMD_FUNC_SET | LCD_8bit_MODE | LCD_2_LINES | LCD_SMALL_FONT
	call	LCD_WRITE_CMD
ENDIF

	; Turn on the display and turn off the cursor. Set the cursor to the non-blink mode
	banksel	_mr_lcd_module_state
	bsf	_mr_lcd_module_state, 0
	movlw	LCD_CMD_DISPLAY_CTRL | LCD_DISPLAY_ON | LCD_CURSOR_OFF | LCD_BLINK_OFF
	call	LCD_WRITE_CMD

	; Clear the display memory. This command also moves the cursor to the home position
	movlw	LCD_CMD_CLEAR_DISPLAY
	call	LCD_WRITE_CMD

	; Set up the cursor mode
	movlw	LCD_CMD_ENTRY_MODE | LCD_INC_CURSOR_POS | LCD_NO_SCROLL
	call	LCD_WRITE_CMD

	; Set the Display Data RAM address to 0
	movlw	LCD_CMD_SET_DDRAM
	call	LCD_WRITE_CMD

	call	LCD_PORT_RESTORE

	return

;*******************************************************************
;LCD_DELAY
; This routine takes the calculated times that the delay loop needs to
; be executed, based on the LCD_INIT_DELAY EQUate that includes the
; frequency of operation.
;
;
; Registers used:
;	this: W (only on call of LCD_DELAY, not LCD_A_DELAY)
;	this: _mr_lcd_delayloop1
;	this: _mr_lcd_delayloop2
;

LCD_DELAY
		movlw	LCD_INIT_DELAY
LCD_A_DELAY
		banksel	_mr_lcd_delayloop1
		movwf	_mr_lcd_delayloop1
		clrf	_mr_lcd_delayloop2
LCD_DELAY_LOOP
		decfsz	_mr_lcd_delayloop2, F		; Delay time = _mr_lcd_delayloop1 * ((3 * 256) + 3) * Tcy
			goto	LCD_DELAY_LOOP		;            = _mr_lcd_delayloop2 * 154.2 (20Mhz clock)
		decfsz	_mr_lcd_delayloop1, F
			goto	LCD_DELAY_LOOP
		RETURN

;;*******************************************************************
;; LCD_TOGGLE_E
;;
;; This routine toggles the "E" bit (enable) on the LCD module. The contents
;; of W contain the state of the R/W and RS bits along with the data that's
;; to be written (that is if data is to be written). The contents of the LCD port
;; while E is active are returned in W.
;;
;; Code LCD_DROP_E & LCD_RAISE_E repeated here as this will save stack space.
;;
;; Registers used:
;;	W (used to return lcd data)
;;
;LCD_TOGGLE_E
;	banksel	LCD_CONTROL_PORT
;	bcf	LCD_CONTROL_PORT, LCD_E		; Make sure E is low
;LCD_LTE1:
;	btfsc	LCD_CONTROL_PORT, LCD_E		; E is low the first time through the loop
;		goto	LCD_LTE2
;
;	bsf	LCD_CONTROL_PORT, LCD_E		; Make sure E is high
;	goto	LCD_LTE1
;LCD_LTE2:
;	movf	LCD_DATA_PORT, W		; Read the LCD Data bus
;	bcf	LCD_CONTROL_PORT, LCD_E		; Turn off E
;	return

LCD_DROP_E
	banksel	LCD_CONTROL_PORT
	bcf	LCD_CONTROL_PORT, LCD_E		; Make sure E is low
	banksel	_mr_lcd_enable_delay
	movf	_mr_lcd_enable_delay, W		; Provides a delay needed primarily for faster clocks
	movwf	_mr_lcd_delayloop1
LCD_DROP_E_LOOP
	decfsz	_mr_lcd_delayloop1, F
		goto	LCD_DROP_E_LOOP
	return

LCD_RAISE_E
	banksel	LCD_CONTROL_PORT
	bsf	LCD_CONTROL_PORT, LCD_E		; Make sure E is high
	banksel	_mr_lcd_enable_delay
	movf	_mr_lcd_enable_delay, W		; Provides a delay needed primarily for faster clocks
	movwf	_mr_lcd_delayloop1
LCD_RAISE_E_LOOP
	decfsz	_mr_lcd_delayloop1, F
		goto	LCD_RAISE_E_LOOP
	return

;*******************************************************************
; LCD_WRITE_DATA
;
; Sends a character to LCD. Character is in W.
;
; Registers used:
;	this: W (character to write to lcd)
;	this: _mr_lcd_temp (temporarily store character)
;	LCD_BUSY_CHECK: W (flag check, number of times to loop in LCD_A_DELAY, and value read from LCD)
;	LCD_BUSY_CHECK: _mr_lcd_delayloop1
;	LCD_BUSY_CHECK: _mr_lcd_delayloop2
;
LCD_WRITE_DATA
	banksel	_mr_lcd_temp
	movwf	_mr_lcd_temp
	call	LCD_BUSY_CHECK		; Wait for LCD to be ready
	banksel	_mr_lcd_temp
	movf	_mr_lcd_temp, W

	banksel	LCD_CONTROL_PORT
	bsf	LCD_CONTROL_PORT, LCD_RS
	bcf	LCD_CONTROL_PORT, LCD_R_W
	goto	LCD_WRITE

;*******************************************************************
; LCD_WRITE_CMD
;
; Writes a command (as opposed to data) to the LCD. Command is in W
;
; Registers used:
;	this: W (command to write to lcd)
;	this: _mr_lcd_temp (temporarily store character)
;	LCD_BUSY_CHECK: W (flag check, number of times to loop in LCD_A_DELAY, and value read from LCD)
;	LCD_BUSY_CHECK: _mr_lcd_delayloop1
;	LCD_BUSY_CHECK: _mr_lcd_delayloop2
;
LCD_WRITE_CMD
	banksel	_mr_lcd_temp
	movwf	_mr_lcd_temp
	call	LCD_BUSY_CHECK		; Wait for LCD to be ready
	banksel	_mr_lcd_temp
	movf	_mr_lcd_temp, W

	;Both R_W and RS should be low
	banksel	LCD_CONTROL_PORT
	bcf	LCD_CONTROL_PORT, LCD_RS
	bcf	LCD_CONTROL_PORT, LCD_R_W
	goto	LCD_WRITE

;*******************************************************************
; LCD_WRITE
;
; Write the contents of W to the LCD
;
; Registers used:
;
LCD_WRITE
	movwf	LCD_DATA_PORT
	call	LCD_RAISE_E
	call	LCD_DROP_E
	return

;;*******************************************************************
;;LCD_READ_DATA
;;This routine will read 8 bits of data from the LCD.
;;
;LCD_READ_DATA
;	CALL    LCD_BUSY_CHECK
;
;					;For a data read, RS and R/W should be high
;	BSF     LCD_CONTROL_PORT,LCD_RS
;	BSF     LCD_CONTROL_PORT,LCD_R_W
;*******************************************************************
; LCD_READ
;
; Reads data from the LCD, returned in W.
;
; Registers used:
;	this: W (value returned from LCD_TOGGLE_E)
;
LCD_READ
	banksel	LCD_DATA_TRIS
	movlw	LCD_DATA_MASK			; Set the TRIS bits - make all of the data
	movwf	LCD_DATA_TRIS			; lines inputs.

;	call	LCD_TOGGLE_E			; Toggle E
	call	LCD_DROP_E
	call	LCD_RAISE_E
	banksel	LCD_DATA_PORT
	movf	LCD_DATA_PORT, W		; Read the LCD Data bus
	bcf	LCD_CONTROL_PORT, LCD_E		; Turn off E, don't need a delay here

	banksel	LCD_DATA_TRIS			; Return the data lines to outputs
	clrf	LCD_DATA_TRIS

	return

;*******************************************************************
; LCD_BUSY_CHECK
;
; This routine checks the busy flag, returns when not busy
;
; Registers used:
;	this: W (flag check, and number of times to loop in LCD_A_DELAY)
;	LCD_READ: W (value read from LCD)
;	LCD_A_DELAY: _mr_lcd_delayloop1
;	LCD_A_DELAY: _mr_lcd_delayloop2
;
LCD_BUSY_CHECK
	banksel	LCD_CONTROL_PORT

	;For a busy check, RS is low and R/W is high
	bcf	LCD_CONTROL_PORT, LCD_RS
	bsf	LCD_CONTROL_PORT, LCD_R_W

	call	LCD_READ
	andlw	0x80					; Check busy flag, high = busy

	skpnz
		return
	movlw	5
	call	LCD_A_DELAY
	goto	LCD_BUSY_CHECK				; If busy, check again

;*******************************************************************
; LCD_CLEAR_SCREEN
;
; Clears the entire LCD screen
;
; Registers used:
;	this: W (number of characters to clear)
;	LCD_WRITE_CMD: W (command to write to lcd)
;	LCD_WRITE_CMD: _mr_lcd_temp (temporarily store command)
;	LCD_WRITE_CMD: _mr_lcd_delayloop1
;	LCD_WRITE_CMD: _mr_lcd_delayloop2
;
LCD_CLEAR_SCREEN
	; Clear the display memory. This command also moves the cursor to the home position
	movlw	LCD_CMD_CLEAR_DISPLAY
	call	LCD_WRITE_CMD

	return

;*******************************************************************
; LCD_CLEAR_CHARS
;
; Writes a number (W) of ASCII spaces to the LCD
;
; Registers used:
;	this: W (number of characters to clear, also holds ASCII space)
;	this: _mr_lcd_loop (number of characters to clear)
;	LCD_WRITE_DATA: W (character to write to lcd)
;	LCD_WRITE_DATA: _mr_lcd_temp (temporarily store character)
;	LCD_WRITE_DATA: _mr_lcd_delayloop1
;	LCD_WRITE_DATA: _mr_lcd_delayloop2
;
LCD_CLEAR_CHARS
	banksel	_mr_lcd_loop
	movwf	_mr_lcd_loop
	movlw	0x20				; ASCII space
LCD_CLEAR_CHARS_LOOP
	call	LCD_WRITE_DATA
	banksel _mr_lcd_loop
	decfsz	_mr_lcd_loop, F
		goto	LCD_CLEAR_CHARS_LOOP
	return

;*******************************************************************
; LCD_WRITE_EEPROM_2_BUFFER
;
; Copies a zero terminated string from the EEPROM to the LCD.
; W register points to the offset in ROM.
;
LCD_WRITE_EEPROM_2_BUFFER
	banksel	EEADR
	movwf	EEADR				; Write EEPROM offset address
	clrf	EEADRH				; Clear high address for EEPROM access
LCD_WRITE_EEPROM_2_BUFFER_READ
	banksel	EECON1
	bcf	EECON1, EEPGD			; Select EEPROM memory
	bsf	EECON1, RD			; Start read operation
	banksel	EEADR
	incf	EEADR, F
	movf	EEDATA, W			; Read data

	btfsc   STATUS, Z
		goto	LCD_WRITE_EEPROM_2_BUFFER_EXIT
	call	LCD_WRITE_DATA
	goto	LCD_WRITE_EEPROM_2_BUFFER_READ

LCD_WRITE_EEPROM_2_BUFFER_EXIT
        return

;*******************************************************************
; LCD_CTRL_DISPLAY_x
;
; Controls whether the display is on or off (not the PSU)
;
;
LCD_CTRL_DISPLAY_ON
	banksel	_mr_lcd_module_state
	btfsc	_mr_lcd_module_state, 0
		return
	bsf	_mr_lcd_module_state, 0
	call	LCD_PORT_CONFIGURE
	movlw	LCD_CMD_DISPLAY_CTRL | LCD_DISPLAY_ON | LCD_CURSOR_OFF | LCD_BLINK_OFF
	call	LCD_WRITE_CMD
	call	LCD_PORT_RESTORE
	return

LCD_CTRL_DISPLAY_OFF
	banksel	_mr_lcd_module_state
	btfss	_mr_lcd_module_state, 0
		return
	bcf	_mr_lcd_module_state, 0
	call	LCD_PORT_CONFIGURE
	movlw	LCD_CMD_DISPLAY_CTRL | LCD_DISPLAY_OFF | LCD_CURSOR_OFF | LCD_BLINK_OFF
	call	LCD_WRITE_CMD
	call	LCD_PORT_RESTORE
	return

IFDEF	OLED_DISPLAY
;*******************************************************************
; LCD_CTRL_POWER_x
;
; Controls whether the DC/DC convertor is on or off
;
; THIS DOESN'T APPEAR TO DO ANYTHING :( !!!
;
LCD_CTRL_POWER_ON
	banksel	_mr_lcd_module_state
	btfsc	_mr_lcd_module_state, 1
		return
	bsf	_mr_lcd_module_state, 1
	call	LCD_PORT_CONFIGURE
	movlw	LCD_CMD_MODEPWR_CTRL | LCD_MODE_CHAR | LCD_DCDC_ON
	call	LCD_WRITE_CMD
	call	LCD_PORT_RESTORE
	return

LCD_CTRL_POWER_OFF
	banksel	_mr_lcd_module_state
	btfss	_mr_lcd_module_state, 1
		return
	bcf	_mr_lcd_module_state, 1
	call	LCD_PORT_CONFIGURE
	movlw	LCD_CMD_MODEPWR_CTRL | LCD_MODE_CHAR | LCD_DCDC_OFF
	call	LCD_WRITE_CMD
	call	LCD_PORT_RESTORE
	return
ENDIF

;*******************************************************************
; LCD_WRITE_CGDATA
;
; Write data to CGRAM
;
; FSR -	Points to the data to load (must be in the first RAM bank)
;	First byte is the index of the character to update
;
LCD_WRITE_CGDATA
	call	LCD_PORT_CONFIGURE

	banksel	_mr_i2c_buffer
	movf	INDF, W			; Get character index
	incf	FSR, F
	andlw	0x07			; Constrain to < 8 (CGRAM limit)
	banksel	_mr_lcd_temp
	movwf	_mr_lcd_temp
	movlw	0x8			; Setup loop counter
	movwf	_mr_lcd_loop

	; Mutiply character index by 8 to get address
	bcf	STATUS, C		; Make sure CARRY is clear for shift
	rlf	_mr_lcd_temp, F
	rlf	_mr_lcd_temp, F
	rlf	_mr_lcd_temp, W

	iorlw	LCD_CMD_SET_CGRAM	; Add CGRAM command
	call	LCD_WRITE_CMD

LCD_WRITE_CGDATA_LOOP
	banksel	_mr_i2c_buffer
	movf	INDF, W
	call	LCD_WRITE_DATA
	incf	FSR, F
	banksel	_mr_lcd_loop
	decfsz	_mr_lcd_loop, F
		goto	LCD_WRITE_CGDATA_LOOP

	call	LCD_PORT_RESTORE

	return

;*******************************************************************
; LCD_UPDATE_FROM_SCREEN_BUFFER
;
; Write a screen buffer to the lcd
;
LCD_UPDATE_FROM_SCREEN_BUFFER
	call	LCD_PORT_CONFIGURE

	movlw	LCD_CMD_SET_DDRAM | SCR_ROW0 | SCR_COL0
	call	LCD_WRITE_CMD

	banksel	_mr_screen_buffer_line1
	movlw	_mr_screen_buffer_line1
	movwf	FSR
	movlw	0x28					; We're writing 2 lines of data
	movwf   _mr_screen_buffer_loop
LCD_UPDATE_FROM_SCREEN_BUFFER_LINES13
	movf	INDF, W
	call	LCD_WRITE_DATA
	incf	FSR, F
	banksel	_mr_screen_buffer_loop
	decfsz	_mr_screen_buffer_loop, F
		goto	LCD_UPDATE_FROM_SCREEN_BUFFER_LINES13

	movlw	LCD_CMD_SET_DDRAM | SCR_ROW1 | SCR_COL0
	call	LCD_WRITE_CMD

	banksel	_mr_screen_buffer_line2
	movlw	_mr_screen_buffer_line2
	movwf	FSR
	movlw	0x28					; We're writing 2 lines of data
	movwf   _mr_screen_buffer_loop
LCD_UPDATE_FROM_SCREEN_BUFFER_LINES24
	movf	INDF, W
	call	LCD_WRITE_DATA
	incf	FSR, F
	banksel	_mr_screen_buffer_loop
	decfsz	_mr_screen_buffer_loop, F
		goto	LCD_UPDATE_FROM_SCREEN_BUFFER_LINES24

	call	LCD_PORT_RESTORE

	return
