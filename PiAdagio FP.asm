        list    p=16F874,t=ON,c=132,n=80
        title   "Adagio Front Panel redesign"
        radix   dec
;********************************************************************************
	include "p16f874.inc"
	include <coff.inc>
	include	"i2c.inc"
	include "lcd.inc"
;	include "screen.inc"

;	4 MHz ceramic resonator
	__CONFIG _CP_OFF & _PWRTE_ON & _WDT_OFF & _XT_OSC & _LVP_ON
	ERRORLEVEL -302 ;remove message about using proper bank

	#define NODE_ADDR		0x22		; I2C address of this node
	#define RX_BUF_LEN		22		; Length of receive buffer (cmd str + cmd pos + max str len (20))
	#define I2C_CHAR_CLEAR		0x00		; value to load into array after transmit

	#define	START_OF_RAM_1	0x20
	#define	END_OF_RAM_1	0x7f
	#define	START_OF_RAM_2	0xa0
	#define	END_OF_RAM_2	0xff

	cblock  START_OF_RAM_1
; Interrupt handler save registers
		WREGsave,STATUSsave,FSRsave,PCLATHsave
; General registers
		_mr_loop1,_mr_loop2
		_mr_temp1,_mr_temp2
		_mr_oldxtris,_mr_oldytris
; LCD registers
		_mr_lcd_loop1,_mr_lcd_loop2,_mr_lcd_loop3
		_mr_char_buffer,_mr_lcd_temp
		_mr_lcd_screen_pos,_mr_lcd_clear_chars
; Button registers
		_mr_button_bank: 3
; i2c registers
		_mr_i2c_temp,_mr_i2c_cmd_status,_mr_i2c_cmd_size
		_mr_i2c_buffer: RX_BUF_LEN, _mr_i2c_buffer_index
	endc

; processor reset vector
	org		0x000
		clrwdt						; Clear the watchdog timer.
		CLRF   INTCON					; Disable all interrupts
		CLRF   PCLATH
		goto	main

; interrupt vector location
	org		0x004
		goto   ISR

;---------------------------------------------------------------------
; Interrupt Code
;---------------------------------------------------------------------
ISR
	movwf	WREGsave		; Save WREG
	movf	STATUS,W		; Get STATUS register
	banksel	STATUSsave		; Switch banks, if needed.
	movwf	STATUSsave		; Save the STATUS register
	movf	PCLATH,W
	movwf	PCLATHsave		; Save PCLATH
	movf	FSR,W
	movwf	FSRsave			; Save FSR
	banksel	PIR1
	btfsc	PIR1,SSPIF		; Is this a SSP interrupt?
		call    i2c_slave_ssp_handler   ; Yes, service SSP interrupt. By skipping is this going to cause problems on bus collisions
	banksel	FSRsave
	movf	FSRsave,W
	movwf	FSR			; Restore FSR
	movf	PCLATHsave,W
	movwf	PCLATH			; Restore PCLATH
	movf	STATUSsave,W
	movwf	STATUS			; Restore STATUS
	swapf	WREGsave,F
	swapf	WREGsave,W		; Restore WREG
	retfie				; Return from interrupt.

;***********************************************************************
main
	CALL    init_mpu				; MPU Initialisation
	CALL    init_board				; Hardware Initialisation
	CALL    init_mem
	CALL	set_mpu_as_i2c_slave			; Reset SSP as i2c slave and enable interrupts

	CALL	screen_draw_border

main_loop
	CALL	READ_BUTTONS

	CALL	fp_cmd_process

	goto	main_loop

;***********************************************************************
; Process command
fp_cmd_process
	bcf     INTCON,GIE					; Disable interrupts while we are processing

	btfss	_mr_i2c_cmd_status, FP_CMD_STATUS_LOADING
		goto	fp_cmd_process_exit			; Skip if there isn't a command pending
	btfsc	_mr_i2c_cmd_status, FP_CMD_STATUS_PROCESSED
		goto	fp_cmd_process_exit			; Skip if the command has been processed
	btfss	_mr_i2c_cmd_status, FP_CMD_STATUS_LOADED
		goto	fp_cmd_process_exit			; Skip if the command hasn't finished loading

	bsf	_mr_i2c_cmd_status, FP_CMD_STATUS_PROCESSING	; Mark command as being processed

	btfsc	_mr_i2c_buffer, FP_CMD_CLEAR_SCREEN		; Clear screen command
		goto 	fp_cmd_process_clear_screen
	btfsc	_mr_i2c_buffer, FP_CMD_WRITE_SCREEN		; Write screen command
		goto	fp_cmd_process_write_screen

	bsf	_mr_i2c_cmd_status, FP_CMD_STATUS_PROCESSED	; Mark command as processed anyway to clear it

fp_cmd_process_exit
	call	i2c_slave_clear_overflow			; Flush any i2c overflow condition

	bsf     INTCON,GIE					; Re-enable interrupts
	RETURN

;***********************************************************************
; Process command - Clear screen
fp_cmd_process_clear_screen
	call	LCD_PORT_CONFIGURE

	btfss	_mr_i2c_cmd_size, 0x01				; Is this command 2 or more bytes
		goto	fp_cmd_process_clear_whole_screen	; Only 1 command byte, so clear all the screen

	clrw							; First reset screen clear position
	btfsc	(_mr_i2c_buffer + 1), 0x01
		goto	fp_cmd_process_clear_screen_row_gt_2	; Row selection is greater than or equal to 2
	btfsc	(_mr_i2c_buffer + 1), 0x00
		addlw	SCR_ROW1				; Row 1	selected
	goto	fp_cmd_process_clear_screen_next
fp_cmd_process_clear_screen_row_gt_2
	addlw	SCR_ROW2
	btfsc	(_mr_i2c_buffer + 1), 0x00
		addlw	SCR_ROW1				; With SCR_ROW2 produces SCR_ROW3

fp_cmd_process_clear_screen_next
	movwf	_mr_lcd_screen_pos				; Save selected row
	movlw	0x14
	movwf	_mr_lcd_clear_chars				; Set the default number of characters to clear

	btfss	_mr_i2c_cmd_size, 0x00
		goto	fp_cmd_process_clear_screen_portion

	rrf	(_mr_i2c_buffer + 1), F				; Now get column data
	rrf	(_mr_i2c_buffer + 1), W				; Now get column data
	andlw	b'00111111'
	addwf	_mr_lcd_screen_pos, F					; Add the column data to the selected row
	movf	(_mr_i2c_buffer + 2), W				; Get the number of characters to clear
	movwf	_mr_lcd_clear_chars

fp_cmd_process_clear_screen_portion
	movf	_mr_lcd_screen_pos, W
	iorlw	LCD_CMD_SET_DDRAM				; Set the command bits
	call	LCD_WRITE_CMD
	call	LCD_CLEAR_CHARS
	goto	fp_cmd_process_clear_screen_finish

fp_cmd_process_clear_whole_screen
	call	LCD_CLEAR_SCREEN

fp_cmd_process_clear_screen_finish
	call	LCD_PORT_RESTORE
	bsf	_mr_i2c_cmd_status, FP_CMD_STATUS_PROCESSED	; Mark command as processed

	goto	fp_cmd_process

;***********************************************************************
; Process command - Write to screen
fp_cmd_process_write_screen
	call	LCD_PORT_CONFIGURE

	movf	_mr_i2c_cmd_size, w				; Check for invalid command
	xorlw	b'00000001'
	btfsc	STATUS, Z
		goto	fp_cmd_process_write_screen_finish	; Improper command

	movf	_mr_i2c_cmd_size, w				; Check for single character write
	xorlw	b'00000010'
	btfsc	STATUS, Z
		goto	fp_cmd_process_write_screen_write_char

	clrw							; First reset screen position
	btfsc	(_mr_i2c_buffer + 1), 0x01
		goto	fp_cmd_process_write_screen_row_gt_2	; Row selection is greater than or equal to 2
	btfsc	(_mr_i2c_buffer + 1), 0x00
		addlw	SCR_ROW1				; Row 1	selected
	goto	fp_cmd_process_write_screen_next
fp_cmd_process_write_screen_row_gt_2
	addlw	SCR_ROW2
	btfsc	(_mr_i2c_buffer + 1), 0x00
		addlw	SCR_ROW1				; With SCR_ROW2 produces SCR_ROW3

fp_cmd_process_write_screen_next
	movwf	_mr_lcd_screen_pos				; Save selected row
	rrf	(_mr_i2c_buffer + 1), F				; Now get column data
	rrf	(_mr_i2c_buffer + 1), W				; Now get column data
	andlw	b'00111111'
	addwf	_mr_lcd_screen_pos, F				; Add the column data to the selected row
	movf	_mr_lcd_screen_pos, W
	iorlw	LCD_CMD_SET_DDRAM				; Set the command bits
	call	LCD_WRITE_CMD					; Set screen position

	movlw	0x02						; Update command size to represent character data size
	subwf	_mr_i2c_cmd_size, F

	clrf	_mr_i2c_buffer_index				; Reset pointer to use to load data out
fp_cmd_process_write_screen_next_char
	movlw	(_mr_i2c_buffer + 2)				; Set the start of the character data
	addwf	_mr_i2c_buffer_index, W
	movwf	FSR
	movf	INDF, W
	call	LCD_WRITE_DATA					; Write character to screen
	incf	_mr_i2c_buffer_index, F
	decfsz	_mr_i2c_cmd_size, F
		goto	fp_cmd_process_write_screen_next_char
	goto	fp_cmd_process_write_screen_finish

fp_cmd_process_write_screen_write_char
	movf	(_mr_i2c_buffer + 1), W
	call	LCD_WRITE_DATA

fp_cmd_process_write_screen_finish
	call	LCD_PORT_RESTORE
	bsf	_mr_i2c_cmd_status, FP_CMD_STATUS_PROCESSED	; Mark command as processed

	GOTO fp_cmd_process

;***********************************************************************
; Test modes
;***********************************************************************
; Display button values
fp_test_display_buttons
	CALL	LCD_PORT_CONFIGURE
	;CALL	LCD_CLEAR_SCREEN			; This causes redraw problems
	MOVLW   LCD_CMD_SET_DDRAM | SCR_ROW0 | SCR_COL0
	CALL    LCD_WRITE_CMD
	MOVF	_mr_button_bank, W
	CALL	screen_write_byte_as_hex

	MOVLW   LCD_CMD_SET_DDRAM | SCR_ROW1 | SCR_COL0
	CALL    LCD_WRITE_CMD
	MOVF	(_mr_button_bank + 1), W
	CALL	screen_write_byte_as_hex

	MOVLW   LCD_CMD_SET_DDRAM | SCR_ROW2 | SCR_COL0
	CALL    LCD_WRITE_CMD
	MOVF	(_mr_button_bank + 2), W
	CALL	screen_write_byte_as_hex
	CALL	LCD_PORT_RESTORE

	RETURN

;***********************************************************************
; Initialisation routines
;***********************************************************************
; Initialise MPU
init_mpu
	banksel	PCON
	bsf	PCON,NOT_POR
	bsf	PCON,NOT_BOR

	BCF     STATUS, RP1
	BCF     STATUS, RP0
	CLRWDT

	MOVLW   0x07					; (OLD CODE: Startup for Main CPU board?)
	MOVWF   PORTB

	MOVLW   0x20
	MOVLW   0x05					; These are reduntant (don't know why they are in the original code)

	MOVLW   0x00
	MOVWF   PIR1					; Reset registers
	MOVWF   PIR2
	MOVWF   TMR1L
	MOVWF   TMR1H
	MOVWF   TMR2
	MOVWF   T1CON
	MOVWF   CCPR1L
	MOVWF   CCPR1H
	MOVWF   RCSTA
	MOVWF   ADCON0
	MOVWF   CCP1CON
	MOVWF   CCP2CON

	MOVLW   0x05
	MOVWF   T2CON					; Set Timer2 on, with prescalar of 4

	BSF     STATUS, RP0
	MOVLW   0x19
	MOVWF   TRISC					; Configure PORTC (Inputs: 0,3,4 | Outputs: 1,2,5,6,7)
	BCF     STATUS, RP0
	MOVLW   0x09
	MOVWF   _mr_loop1					; Setup loop counter
init_mpu_wait_4_portc4_l1
	BTFSC   PORTC, 0x4				; Test PortC{4},
	GOTO    init_mpu_configure_ports		; If it's set, skip to next section
	MOVLW   0x09
	MOVWF   PORTC					; Set output when it's an input ??????????
	BCF     STATUS, RP0
	MOVLW   0x00
	MOVWF   PORTC					; Set output when it's an input ??????????
	MOVLW   0x19
	MOVWF   _mr_loop2				; Setup loop counter
init_mpu_wait_4_portc4_l2
	DECFSZ  _mr_loop2, 0x1
	GOTO    init_mpu_wait_4_portc4_l2
	MOVLW   0x19					; Set output when it's an input ??????????
	MOVWF   PORTC
	BCF     STATUS, RP0
	MOVLW   0x19
	MOVWF   _mr_loop2				; Setup loop counter
init_mpu_wait_4_portc4_l3
	DECFSZ  _mr_loop2, 0x1
	GOTO    init_mpu_wait_4_portc4_l3
	DECFSZ  _mr_loop1, 0x1
	GOTO    init_mpu_wait_4_portc4_l1

init_mpu_configure_ports
	BSF     STATUS, RP0
	MOVLW   0xef
	MOVWF   TRISA					; Configure PORTA (Inputs: 0,1,2,3,5,6,7 | Outputs: 4)
	BSF     STATUS, RP0
	MOVLW   0xf7
	MOVWF   TRISB					; Configure PORTB (Inputs: 0,1,2,4,5,6,7 | Outputs: 3)
	MOVLW   0x1d
	MOVWF   TRISC					; Configure PORTC (Inputs: 0,2,3,4 | Outputs: 1,5,6,7)
	MOVLW   0x00
	MOVWF   PIE1
	MOVWF   PIE2
	MOVWF   TXSTA
	MOVWF   SPBRG
	MOVWF   TRISE					; Configure PORTE (Inputs: | Outputs: 0,1,2,3,4,5,6,7 )
	MOVLW   0xff
	MOVWF   TRISD					; Configure PORTD (Inputs: 0,1,2,3,4,5,6,7 | Outputs: )
	MOVWF   PR2
	MOVLW   0x01
	MOVWF   OPTION_REG
	MOVLW   0x06
	MOVWF   ADCON1
	BCF     STATUS, RP0
	MOVLW   0x00
	MOVWF   PORTC
	MOVWF   PORTE

	CALL	i2c_master_init

;	CALL    i2c_master_start
;	CALL    i2c_master_stop

	BSF     PORTC, 0x1				; Light 'online' LED

	MOVLW   0x32
	MOVWF   0x66					; Setup loop counter
init_mpu_l1
	CLRWDT
	CALL    waste_time
	DECFSZ  0x66, 0x1
	GOTO    init_mpu_l1

	BCF     PORTC, 0x1				; Extinguish 'online' LED

	return

;***********************************************************************
; Initialise Hardware
init_board
	bcf	STATUS, RP1
	bcf	STATUS, RP0

;	call    0x049c					; Jump to 0xc9c (Read EEPROM)

	movlw   0x64
	movwf   0x4e					; Setup loop counter
init_board_l1
	clrwdt
	call    waste_time
	decfsz  0x4e, 0x1
	goto    init_board_l1

	btfsc   PORTC, 0x0
	goto    init_board_j1

	movlw   0x08
	movwf   0x6b
;	bsf     0x6b, 0x2
;	bcf     0x6b, 0x0
;	call    0x05ca					; Jump to 0xdca (Read EEPROM)

	call	LCD_INITIALIZE

;	call    lcd_write_bckcon_default_bck		; The backlight would be setup with a value from EEPROM, bypassed
;;	call    lcd_write_bckcon_default_con		; Fudge contrast value as well for testing

	goto    init_board_j2

init_board_j1
;	call    0x05ca					; Jump to 0xdca (Read EEPROM)
	movlw   0x08
	movwf   0x6b
init_board_j2
	bcf     T1CON, 0x0
	movlw   0x00
	movwf   TMR1L
	movwf   TMR1H
	bcf     PIR1, 0x0
	return

;***********************************************************************
; Initialises Memory
init_mem
	bcf     STATUS, RP1
	bcf     STATUS, RP0

	clrf	WREGsave
	clrf	STATUSsave
	clrf	FSRsave
	clrf	PCLATHsave

	clrf	_mr_oldxtris
	clrf	_mr_oldytris

	clrf	_mr_char_buffer
	clrf	_mr_lcd_screen_pos
	clrf	_mr_lcd_clear_chars

	movlw	0x03					; Setup command, screen write 'System booting'
	movwf	_mr_i2c_cmd_status
	movlw	0x10
	movwf	_mr_i2c_cmd_size
	movlw	0x02					; Write screen command
	movwf	(_mr_i2c_buffer + 0)
	movlw	0x0d					; Line 1, Column 3
	movwf	(_mr_i2c_buffer + 1)
	movlw	'S'
	movwf	(_mr_i2c_buffer + 2)
	movlw	'y'
	movwf	(_mr_i2c_buffer + 3)
	movlw	's'
	movwf	(_mr_i2c_buffer + 4)
	movlw	't'
	movwf	(_mr_i2c_buffer + 5)
	movlw	'e'
	movwf	(_mr_i2c_buffer + 6)
	movlw	'm'
	movwf	(_mr_i2c_buffer + 7)
	movlw	' '
	movwf	(_mr_i2c_buffer + 8)
	movlw	'B'
	movwf	(_mr_i2c_buffer + 9)
	movlw	'o'
	movwf	(_mr_i2c_buffer + 10)
	movlw	'o'
	movwf	(_mr_i2c_buffer + 11)
	movlw	't'
	movwf	(_mr_i2c_buffer + 12)
	movlw	'i'
	movwf	(_mr_i2c_buffer + 13)
	movlw	'n'
	movwf	(_mr_i2c_buffer + 14)
	movlw	'g'
	movwf	(_mr_i2c_buffer + 15)

	return

;***********************************************************************
; Reset the i2c interface as a slave
set_mpu_as_i2c_slave
	clrf	PIR1			; Clear interrupt flag
	call	i2c_slave_init

	bsf	INTCON,PEIE 		; Enable all peripheral interrupts
	bsf	INTCON,GIE		; Enable global interrupts
	return

;***********************************************************************
; this function looks like it just wastes machine cycles (Old Code)
waste_time
	movlw   0x0c
	movwf   _mr_loop1				; _mr_loop1 = 12
	goto    waste_time_j1
	movlw   0x01
	movwf   _mr_loop1				; _mr_loop1 = 01
	goto    waste_time_j1
waste_time_j1
	movlw   0x00
	movwf   _mr_loop2				; _mr_loop2 = 0
waste_time_l1
	decfsz  _mr_loop2, 0x1
	goto    waste_time_l1
	decfsz  _mr_loop1, 0x1
	goto    waste_time_l1
	return


	include "buttons.asm"
	include "i2c_master.asm"
	include "i2c_slave.asm"
	include "lcd.asm"
	include	"screen.asm"

        END


;# Function
;2000:  3fff  dw      0x3fff
;2001:  3fff  dw      0x3fff
;2002:  3fff  dw      0x3fff
;2003:  3fff  dw      0x3fff
;2007:  3ff5  dw      0x3ff5
;2100:  01    db      0x01
;2101:  00    db      0x00
;2102:  ff    db      0xff
;2103:  00    db      0x00
;2104:  00    db      0x00
;2105:  00    db      0x00
;2106:  ff    db      0xff
;2107:  00    db      0x00
;2108:  0a    db      0x0a
;2109:  00    db      0x00
;210a:  14    db      0x14
;210b:  00    db      0x00
;210c:  0a    db      0x0a
;210d:  00    db      0x00
;210e:  01    db      0x01
;210f:  00    db      0x00
;2110:  ff    db      0xff
;2111:  00    db      0x00
;2112:  ff    db      0xff
;2113:  00    db      0x00
;2114:  ff    db      0xff
;2115:  00    db      0x00
;2116:  e0    db      0xe0
;2117:  00    db      0x00
;2118:  e0    db      0xe0
;2119:  00    db      0x00
;211a:  ff    db      0xff
;211b:  00    db      0x00
;211c:  ff    db      0xff
;211d:  00    db      0x00
;211e:  00    db      0x00
;211f:  00    db      0x00
;2120:  ce    db      0xce
;2121:  00    db      0x00
;2122:  30    db      0x30                                   ; '0'
;2123:  00    db      0x00
;2124:  00    db      0x00
;2125:  00    db      0x00
;2126:  60    db      0x60                                   ; '`'
;2127:  00    db      0x00
;2128:  80    db      0x80
;2129:  00    db      0x00
;212a:  eb    db      0xeb
;212b:  00    db      0x00
;212c:  14    db      0x14
;212d:  00    db      0x00
;212e:  00    db      0x00
;212f:  00    db      0x00
;2130:  62    db      0x62                                   ; 'b'
;2131:  00    db      0x00
;2132:  1b    db      0x1b
;2133:  00    db      0x00
;2134:  00    db      0x00
;2135:  00    db      0x00
;2136:  38    db      0x38                                   ; '8'
;2137:  00    db      0x00
;2138:  01    db      0x01
;2139:  00    db      0x00
;213a:  06    db      0x06
;213b:  00    db      0x00
;213c:  08    db      0x08
;213d:  00    db      0x00
;213e:  0c    db      0x0c
;213f:  00    db      0x00
;2140:  14    db      0x14
;2141:  00    db      0x00
;2142:  1b    db      0x1b
;2143:  00    db      0x00
;2144:  00    db      0x00
;2145:  00    db      0x00
;2146:  80    db      0x80
;2147:  00    db      0x00
;2148:  1b    db      0x1b
;2149:  00    db      0x00
;214a:  01    db      0x01
;214b:  00    db      0x00
;214c:  20    db      0x20                                   ; '*'
;214d:  00    db      0x00
;214e:  20    db      0x20                                   ; '*'
;214f:  00    db      0x00
;2150:  20    db      0x20                                   ; '*'
;2151:  00    db      0x00
;2152:  20    db      0x20                                   ; '*'
;2153:  00    db      0x00
;2154:  20    db      0x20                                   ; '*'
;2155:  00    db      0x00
;2156:  20    db      0x20                                   ; '*'
;2157:  00    db      0x00
;2158:  20    db      0x20                                   ; '*'
;2159:  00    db      0x00
;215a:  20    db      0x20                                   ; '*'
;215b:  00    db      0x00
;215c:  20    db      0x20                                   ; '*'
;215d:  00    db      0x00
;215e:  20    db      0x20                                   ; '*'
;215f:  00    db      0x00
;2160:  20    db      0x20                                   ; '*'
;2161:  00    db      0x00
;2162:  20    db      0x20                                   ; '*'
;2163:  00    db      0x00
;2164:  20    db      0x20                                   ; '*'
;2165:  00    db      0x00
;2166:  20    db      0x20                                   ; '*'
;2167:  00    db      0x00
;2168:  20    db      0x20                                   ; '*'
;2169:  00    db      0x00
;216a:  20    db      0x20                                   ; '*'
;216b:  00    db      0x00
;216c:  20    db      0x20                                   ; '*'
;216d:  00    db      0x00
;216e:  20    db      0x20                                   ; '*'
;216f:  00    db      0x00
;2170:  20    db      0x20                                   ; '*'
;2171:  00    db      0x00
;2172:  20    db      0x20                                   ; '*'
;2173:  00    db      0x00
;2174:  20    db      0x20                                   ; ' '
;2175:  00    db      0x00
;2176:  20    db      0x20                                   ; ' '
;2177:  00    db      0x00
;2178:  20    db      0x20                                   ; ' '
;2179:  00    db      0x00
;217a:  20    db      0x20                                   ; ' '
;217b:  00    db      0x00
;217c:  20    db      0x20                                   ; ' '
;217d:  00    db      0x00
;217e:  20    db      0x20                                   ; ' '
;217f:  00    db      0x00
;2140:  20    db      0x20                                   ; ' '
;2140:  00    db      0x00
;2141:  53    db      0x53                                   ; 'S'
;2141:  00    db      0x00
;2142:  65    db      0x65                                   ; 'e'
;2142:  00    db      0x00
;2143:  72    db      0x72                                   ; 'r'
;2143:  00    db      0x00
;2144:  76    db      0x76                                   ; 'v'
;2144:  00    db      0x00
;2145:  65    db      0x65                                   ; 'e'
;2145:  00    db      0x00
;2146:  72    db      0x72                                   ; 'r'
;2146:  00    db      0x00
;2147:  20    db      0x20                                   ; ' '
;2147:  00    db      0x00
;2148:  20    db      0x20                                   ; ' '
;2148:  00    db      0x00
;2149:  20    db      0x20                                   ; ' '
;2149:  00    db      0x00
;214a:  20    db      0x20                                   ; ' '
;214a:  00    db      0x00
;214b:  20    db      0x20                                   ; ' '
;214b:  00    db      0x00
;214c:  20    db      0x20                                   ; ' '
;214c:  00    db      0x00
;214d:  20    db      0x20                                   ; ' '
;214d:  00    db      0x00
;214e:  1b    db      0x1b
;214e:  00    db      0x00
;214f:  00    db      0x00
;214f:  00    db      0x00
;2150:  c0    db      0xc0
;2150:  00    db      0x00
;2151:  1b    db      0x1b
;2151:  00    db      0x00
;2152:  01    db      0x01
;2152:  00    db      0x00
;2153:  20    db      0x20                                   ; ' '
;2153:  00    db      0x00
;2154:  20    db      0x20                                   ; ' '
;2154:  00    db      0x00
;2155:  20    db      0x20                                   ; ' '
;2155:  00    db      0x00
;2156:  20    db      0x20                                   ; ' '
;2156:  00    db      0x00
;2157:  41    db      0x41                                   ; 'A'
;2157:  00    db      0x00
;2158:  64    db      0x64                                   ; 'd'
;2158:  00    db      0x00
;2159:  61    db      0x61                                   ; 'a'
;2159:  00    db      0x00
;215a:  67    db      0x67                                   ; 'g'
;215a:  00    db      0x00
;215b:  69    db      0x69                                   ; 'i'
;215b:  00    db      0x00
;215c:  6f    db      0x6f                                   ; 'o'
;215c:  00    db      0x00
;215d:  20    db      0x20                                   ; ' '
;215d:  00    db      0x00
;215e:  41    db      0x41                                   ; 'A'
;215e:  00    db      0x00
;215f:  75    db      0x75                                   ; 'u'
;215f:  00    db      0x00
;2160:  64    db      0x64                                   ; 'd'
;2160:  00    db      0x00
;2161:  69    db      0x69                                   ; 'i'
;2161:  00    db      0x00
;2162:  6f    db      0x6f                                   ; 'o'
;2162:  00    db      0x00
;2163:  20    db      0x20                                   ; ' '
;2163:  00    db      0x00
;2164:  20    db      0x20                                   ; ' '
;2164:  00    db      0x00
;2165:  20    db      0x20                                   ; ' '
;2165:  00    db      0x00
;2166:  20    db      0x20                                   ; ' '
;2166:  00    db      0x00
;2167:  20    db      0x20                                   ; ' '
;2167:  00    db      0x00
;2168:  20    db      0x20                                   ; ' '
;2168:  00    db      0x00
;2169:  20    db      0x20                                   ; ' '
;2169:  00    db      0x00
;216a:  20    db      0x20                                   ; ' '
;216a:  00    db      0x00
;216b:  20    db      0x20                                   ; ' '
;216b:  00    db      0x00
;216c:  20    db      0x20                                   ; ' '
;216c:  00    db      0x00
;216d:  20    db      0x20                                   ; ' '
;216d:  00    db      0x00
;216e:  20    db      0x20                                   ; ' '
;216e:  00    db      0x00
;216f:  20    db      0x20                                   ; ' '
;216f:  00    db      0x00
;2170:  20    db      0x20                                   ; ' '
;2170:  00    db      0x00
;2171:  20    db      0x20                                   ; ' '
;2171:  00    db      0x00
;2172:  20    db      0x20                                   ; ' '
;2172:  00    db      0x00
;2173:  20    db      0x20                                   ; ' '
;2173:  00    db      0x00
;2174:  20    db      0x20                                   ; ' '
;2174:  00    db      0x00
;2175:  20    db      0x20                                   ; ' '
;2175:  00    db      0x00
;2176:  20    db      0x20                                   ; ' '
;2176:  00    db      0x00
;2177:  20    db      0x20                                   ; ' '
;2177:  00    db      0x00
;2178:  20    db      0x20                                   ; ' '
;2178:  00    db      0x00
;2179:  20    db      0x20                                   ; ' '
;2179:  00    db      0x00
;217a:  20    db      0x20                                   ; ' '
;217a:  00    db      0x00
;217b:  00    db      0x00
;217b:  00    db      0x00
;217c:  00    db      0x00
;217c:  00    db      0x00
;217d:  00    db      0x00
;217d:  00    db      0x00
;217e:  00    db      0x00
;217e:  00    db      0x00
;217f:  00    db      0x00
;217f:  00    db      0x00
