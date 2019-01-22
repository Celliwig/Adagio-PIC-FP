;********************************************************************************
;
; The file contains code to control an LCD module.
;
; T. Scott Dattalo
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

;*******************************************************************
;

LCD_PORT_CONFIGURE
        BSF     STATUS, RP0             	; Select Register page 1
	MOVF	LCD_CONTROL_TRIS, W		; Save port configuration
        BCF	LCD_CONTROL_TRIS, LCD_E		;Initialize the LCD_PORT control and data lines to outputs
        BCF	LCD_CONTROL_TRIS, LCD_R_W
        BCF	LCD_CONTROL_TRIS, LCD_RS
        BCF     STATUS, RP0			; Select Register page 0
	MOVWF	_mr_oldxtris


        BSF     STATUS, RP0             	; Select Register page 1
	MOVF	LCD_DATA_TRIS, W		; Save port configuration
	CLRF	LCD_DATA_TRIS			; Make LCD_PORT IO lines outputs
	BCF     STATUS, RP0			; Select Register page 0
	MOVWF	_mr_oldytris

	RETURN

LCD_PORT_RESTORE
	;Restore the LCD_PORT control and data lines to outputs
	MOVF	_mr_oldxtris, W
        BSF     STATUS, RP0             ; Select Register page 1
        MOVWF   LCD_CONTROL_TRIS        ; Make LCD_PORT IO lines outputs
        BCF     STATUS, RP0             ; Select Register page 0

	MOVF	_mr_oldytris, W
        BSF     STATUS, RP0             ; Select Register page 1
        MOVWF   LCD_DATA_TRIS           ; Make LCD_PORT IO lines outputs
        BCF     STATUS, RP0             ; Select Register page 0

	RETURN

;LCD_INITIALIZE
;  Right now, the display could be either in 8-bit mode if we
; just powered up, or it could be in 4-bit mode if we just
; experienced a reset. So to begin, we have to initialize the
; display to a known state: the 8-bit mode. This is done by
; sending the LCD command "Function Set" with the 8-bit mode
; bit set. We need to do this 3 times!

LCD_INITIALIZE

	CALL LCD_PORT_CONFIGURE

        MOVLW   3
        MOVWF   _mr_lcd_loop1		; Use _mr_lcd_loop1 as a loop counter
        BCF     LCD_CONTROL_PORT, LCD_E
        BCF     LCD_CONTROL_PORT, LCD_RS
        BCF     LCD_CONTROL_PORT, LCD_R_W

lcd_init_8bit:
        CALL    LCD_DELAY

        MOVF    LCD_DATA_PORT,W
        IORLW   (LCD_CMD_FUNC_SET | LCD_8bit_MODE) >> LCD_DATA_SHIFT
        MOVWF   LCD_DATA_PORT           ;Put command on the bus

        GOTO    $+1
        BSF     LCD_CONTROL_PORT, LCD_E ;Enable the LCD, i.e. write the command.
        GOTO    $+1                     ;NOP's are only needed for 20Mhz crystal
        GOTO    $+1
        BCF     LCD_CONTROL_PORT, LCD_E ;Disable the LCD

        DECFSZ  _mr_lcd_loop1, F
        GOTO    lcd_init_8bit

;   ;Now we are in 4-bit mode. This means that all reads and writes of bytes have to be done
;   ;a nibble at a time. But that's all taken care of by the read/write functions.
;   ;Set up the display to have 2 lines and the small (5x7 dot) font.
;
;        MOVLW   LCD_CMD_FUNC_SET | LCD_4bit_MODE | LCD_2_LINES | LCD_SMALL_FONT
;        CALL    LCD_WRITE_CMD

        MOVLW   LCD_CMD_FUNC_SET | LCD_8bit_MODE | LCD_2_LINES | LCD_SMALL_FONT
        CALL    LCD_WRITE_CMD

   ;Turn on the display and turn off the cursor. Set the cursor to the non-blink mode

        MOVLW   LCD_CMD_DISPLAY_CTRL | LCD_DISPLAY_ON | LCD_CURSOR_OFF | LCD_BLINK_OFF
        CALL    LCD_WRITE_CMD

   ;Clear the display memory. This command also moves the cursor to the home position.

        MOVLW   LCD_CMD_CLEAR_DISPLAY
        CALL    LCD_WRITE_CMD

   ;Set up the cursor mode.

        MOVLW   LCD_CMD_ENTRY_MODE | LCD_INC_CURSOR_POS | LCD_NO_SCROLL
        CALL    LCD_WRITE_CMD

   ;Set the Display Data RAM address to 0

        MOVLW   LCD_CMD_SET_DDRAM
        CALL    LCD_WRITE_CMD

        CALL    LCD_CLEAR_SCREEN

	CALL	LCD_PORT_RESTORE

        RETURN

;*******************************************************************
;LCD_DELAY
; This routine takes the calculated times that the delay loop needs to
;be executed, based on the LCD_INIT_DELAY EQUate that includes the
;frequency of operation.
;
; _mr_lcd_loop1 already in use
;
LCD_DELAY	MOVLW   LCD_INIT_DELAY
LCD_A_DELAY	MOVWF   _mr_lcd_loop2		; Use _mr_lcd_loop2 and _mr_lcd_loop3
		CLRF    _mr_lcd_loop3
LCD_LOOP2	DECFSZ  _mr_lcd_loop3, F		; Delay time = _mr_lcd_loop2 * ((3 * 256) + 3) * Tcy
		GOTO	LCD_LOOP2		;            = _mr_lcd_loop2 * 154.2 (20Mhz clock)
		DECFSZ  _mr_lcd_loop2, F
		GOTO    LCD_LOOP2
		RETURN

;*******************************************************************
;LCD_TOGGLE_E
;  This routine toggles the "E" bit (enable) on the LCD module. The contents
;of W contain the state of the R/W and RS bits along with the data that's
;to be written (that is if data is to be written). The contents of the LCD port
;while E is active are returned in W.

LCD_TOGGLE_E
        BCF  LCD_CONTROL_PORT,LCD_E     ;Make sure E is low
LCD_LTE1:
	NOP				;Delays needed primarily for 10Mhz and faster clocks
;	NOP
;	NOP
;	NOP
        BTFSC   LCD_CONTROL_PORT, LCD_E ;E is low the first time through the loop
		goto	LCD_LTE2

        BSF     LCD_CONTROL_PORT, LCD_E ;Make E high and go through the loop again
		GOTO	LCD_LTE1
LCD_LTE2:
        MOVF    LCD_DATA_PORT, W        ;Read the LCD Data bus
        BCF     LCD_CONTROL_PORT, LCD_E ;Turn off E
        RETURN

LCD_DROP_E
        BCF  LCD_CONTROL_PORT,LCD_E     ;Make sure E is low
	NOP				;Delays needed primarily for 10Mhz and faster clocks
;	NOP
;	NOP
;	NOP
        RETURN

LCD_RAISE_E
        BSF  LCD_CONTROL_PORT,LCD_E     ;Make sure E is high
	NOP				;Delays needed primarily for 10Mhz and faster clocks
;	NOP
;	NOP
;	NOP
        RETURN


;*******************************************************************
;LCD_WRITE_DATA - Sends a character to LCD
;
; Memory used:
;    LCD_CHAR,
; Calls
;    LCD_TOGGLE_E
;
LCD_WRITE_DATA
        MOVWF   _mr_char_buffer		; Character to be sent is in W
        CALL    LCD_BUSY_CHECK		; Wait for LCD to be ready

        BSF     LCD_CONTROL_PORT,LCD_RS
        BCF     LCD_CONTROL_PORT,LCD_R_W
        GOTO    LCD_WRITE

;*******************************************************************
;LCD_WRITE_CMD
;
;  This routine splits the command into the upper and lower
;nibbles and sends them to the LCD, upper nibble first.

LCD_WRITE_CMD
        MOVWF   _mr_char_buffer		; Character to be sent is in W

        CALL    LCD_BUSY_CHECK		; Wait for LCD to be ready

   ;Both R_W and RS should be low
        BCF     LCD_CONTROL_PORT,LCD_RS
        BCF     LCD_CONTROL_PORT,LCD_R_W
        GOTO    LCD_WRITE

;*******************************************************************
LCD_WRITE
        CALL    LCD_RAISE_E
        MOVF    _mr_char_buffer, w
        MOVWF   LCD_DATA_PORT
        CALL    LCD_DROP_E
	RETURN

;*******************************************************************
;LCD_READ_DATA
;This routine will read 8 bits of data from the LCD. Since we're using
;4-bit mode, two passes have to be made. On the first pass we read the
;upper nibble, and on the second the lower.
;
LCD_READ_DATA
	CALL    LCD_BUSY_CHECK

					;For a data read, RS and R/W should be high
	BSF     LCD_CONTROL_PORT,LCD_RS
	BSF     LCD_CONTROL_PORT,LCD_R_W
LCD_READ
	BSF     STATUS, RP0		;Select Register page 1
	MOVF    LCD_DATA_TRIS,W		;Get the current setting for the whole register
	IORLW   LCD_DATA_MASK		;Set the TRIS bits- make all of the data
	MOVWF   LCD_DATA_TRIS		;   lines inputs.
	BCF     STATUS, RP0		;Select Register page 0

	CALL    LCD_TOGGLE_E		;Toggle E and read upper nibble
	MOVWF   _mr_lcd_temp		;Save the upper nibble

	BSF     STATUS, RP0		;Select Register page 1

	MOVLW   0
	ANDWF   LCD_DATA_TRIS,F		;   lines outputs.

	BCF     STATUS, RP0		;Select Register page 0
	MOVF    _mr_lcd_temp,W

	RETURN

;*******************************************************************
;LCD_BUSY_CHECK
;This routine checks the busy flag, returns when not busy

LCD_BUSY_CHECK

   ;For a busy check, RS is low and R/W is high
        BCF     LCD_CONTROL_PORT,LCD_RS
        BSF     LCD_CONTROL_PORT,LCD_R_W

        CALL    LCD_READ
        ANDLW   0x80                    ;Check busy flag, high = busy

        SKPNZ
		RETURN
        MOVLW   5
        CALL    LCD_A_DELAY
        GOTO    LCD_BUSY_CHECK          ;If busy, check again

;*******************************************************************
;LCD_CLEAR_SCREEN
LCD_CLEAR_SCREEN
	MOVLW   LCD_CMD_SET_DDRAM | SCR_ROW0 | SCR_COL0
	CALL    LCD_WRITE_CMD
	MOVLW	0x14
	MOVWF	_mr_lcd_clear_chars
	CALL	LCD_CLEAR_CHARS

        MOVLW   LCD_CMD_SET_DDRAM | SCR_ROW1 | SCR_COL0
	CALL    LCD_WRITE_CMD
	MOVLW	0x14
	MOVWF	_mr_lcd_clear_chars
	CALL	LCD_CLEAR_CHARS

        MOVLW   LCD_CMD_SET_DDRAM | SCR_ROW2 | SCR_COL0
	CALL    LCD_WRITE_CMD
	MOVLW	0x14
	MOVWF	_mr_lcd_clear_chars
	CALL	LCD_CLEAR_CHARS

        MOVLW   LCD_CMD_SET_DDRAM | SCR_ROW3 | SCR_COL0
	CALL    LCD_WRITE_CMD
	MOVLW	0x14
	MOVWF	_mr_lcd_clear_chars
	CALL	LCD_CLEAR_CHARS

	RETURN

;*******************************************************************
; LCD_CLEAR_CHARS - Writes a number (_mr_lcd_clear_chars) of ASCII spaces to the LCD
LCD_CLEAR_CHARS
	MOVLW   0x20                    ;ASCII space
	CALL    LCD_WRITE_DATA
	DECFSZ	_mr_lcd_clear_chars, F
		goto  LCD_CLEAR_CHARS
	RETURN
