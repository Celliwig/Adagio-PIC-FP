        list    p=16F874,t=ON,c=132,n=80
        title   "Adagio Front Panel redesign"
        radix   dec
;********************************************************************************
	include "p16f874.inc"
	include <coff.inc>
	include "lcd.inc"
	include	"PiAdagio FP.inc"

;	4 MHz ceramic resonator
	__CONFIG _XT_OSC & _WDT_OFF & _PWRTE_ON & _BODEN_OFF & _LVP_ON & _CPD_ON & _WRT_ON & _DEBUG_OFF & _CP_OFF
	ERRORLEVEL -302 ;remove message about using proper bank

	#define	START_OF_RAM_1	0x20
	#define	END_OF_RAM_1	0x7f
	#define	START_OF_RAM_2	0xa0
	#define	END_OF_RAM_2	0xff

	#define LCD_LINE_LENGTH         20              ; Line length of lcd

	cblock  START_OF_RAM_1
; Interrupt handler save registers
		WREGsave					; This has to be implement in both banks
		STATUSsave,FSRsave,PCLATHsave
; General registers
		_mr_loop1,_mr_loop2
		_mr_temp1,_mr_temp2
		_mr_oldxtris,_mr_oldytris

		_mr_display_countl
		_mr_display_counth
	endc

        cblock  START_OF_RAM_2
; Screen registers
		WREGsave_alt					; This has to be implement in both banks
		_mr_screen_buffer_update
		_mr_screen_buffer_loop
		_mr_screen_buffer_temp
		_mr_screen_buffer_line1: LCD_LINE_LENGTH	; Screen buffer
		_mr_screen_buffer_line3: LCD_LINE_LENGTH	; Screen buffer
		_mr_screen_buffer_line2: LCD_LINE_LENGTH	; Screen buffer
		_mr_screen_buffer_line4: LCD_LINE_LENGTH	; Screen buffer
; LCD registers
		_mr_lcd_loop
		_mr_lcd_temp
		_mr_lcd_delayloop1, _mr_lcd_delayloop2
	endc

; processor reset vector
reset	org	0x000
		clrwdt						; Clear the watchdog timer.
		CLRF   INTCON					; Disable all interrupts
		CLRF   PCLATH
		goto	main

ISR	org	0x004
	movwf	WREGsave		; Save WREG (any bank)
	swapf	STATUS, W		; Get STATUS register (without affecting it)
	banksel STATUSsave		; Switch banks, after we have copied the STATUS register
	movwf	STATUSsave		; Save the STATUS register
	movf	PCLATH, W
	movwf	PCLATHsave		; Save PCLATH
	movf	FSR, W
	movwf	FSRsave			; Save FSR

	banksel	PIR1
	btfss	PIR1, TMR2IF
		goto	ISR_exit
	bcf	PIR1, TMR2IF
	banksel	_mr_screen_buffer_update
	movlw	0x1
	movwf	_mr_screen_buffer_update
ISR_exit
	banksel	FSRsave
	movf	FSRsave, W
	movwf	FSR			; Restore FSR
	movf	PCLATHsave, W
	movwf	PCLATH			; Restore PCLATH
	swapf	STATUSsave, W
	movwf	STATUS			; Restore STATUS
	swapf	WREGsave, F
	swapf	WREGsave, W		; Restore WREG
	retfie

;***********************************************************************
main
	CALL    init_mpu				; MPU Initialisation
	call	init_mem
	call	init_board

        CLRWDT
	BCF     STATUS, RP1
	BCF     STATUS, RP0

        BSF     PORTC, 0x1				; Light 'online' LED
        BSF     PORTE, 0x2				; Light 'standby' LED

	call	screen_draw_border

;	movlw	_mr_screen_buffer_line2 + 1
;	movwf	FSR
;	movlw	eeprom_str_title1 - 0x2100
;	call	screen_write_eeprom_2_buffer

;	movlw	_mr_screen_buffer_line3 + 1
;	movwf	FSR
;	movlw	eeprom_str_title2 - 0x2100
;	call	screen_write_eeprom_2_buffer

	banksel	INTCON					; enable interrupts
	bsf	INTCON, GIE
	bsf	INTCON, PEIE

	call	screen_timer_init
	call	screen_timer_enable
main_loop

	banksel	_mr_screen_buffer_update
	movf	_mr_screen_buffer_update, F
	btfsc	STATUS, Z
		goto	main_loop_exit

	movlw	_mr_screen_buffer_line2 + 9
	movwf	FSR
	banksel	_mr_display_counth
	movf	_mr_display_counth, W
	call	screen_write_byte_as_hex

	incf	FSR, F
	banksel	_mr_display_countl
	movf	_mr_display_countl, W
	call	screen_write_byte_as_hex

	call	screen_write_2_lcd
	banksel	_mr_screen_buffer_update
	clrf	_mr_screen_buffer_update

	banksel	_mr_display_countl
	clrf	_mr_display_countl
	clrf	_mr_display_counth

main_loop_exit
	banksel	_mr_display_countl
	incf	_mr_display_countl, F
	btfsc	STATUS, Z
		incf	_mr_display_counth, F

	GOTO	main_loop

;***********************************************************************

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

	BSF     PORTC, 0x1				; Light 'online' LED

	return

;***********************************************************************
; Initialises Memory
init_mem
	banksel	WREGsave
	clrf	WREGsave
	clrf	STATUSsave
	clrf	FSRsave
	clrf	PCLATHsave

	clrf	_mr_oldxtris
	clrf	_mr_oldytris

	clrf	_mr_display_countl
	clrf	_mr_display_counth

	banksel	_mr_screen_buffer_update
	clrf	_mr_screen_buffer_update
	clrf	_mr_screen_buffer_loop
	clrf	_mr_screen_buffer_temp
	clrf	_mr_lcd_loop
	clrf	_mr_lcd_temp
	clrf	_mr_lcd_delayloop1
	clrf	_mr_lcd_delayloop2

	call	screen_clear				; Clear screen buffer

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
	banksel	T1CON
	bcf     T1CON, 0x0
	movlw   0x00
	movwf   TMR1L
	movwf   TMR1H
	bcf     PIR1, 0x0
	return

;***********************************************************************
; this function looks like it just wastes machine cycles (Old Code)
waste_time
	movlw   0x0c
	movwf   _mr_loop1                               ; _mr_loop1 = 12
	goto    waste_time_j1
	movlw   0x01
	movwf   _mr_loop1                               ; _mr_loop1 = 01
	goto    waste_time_j1
waste_time_j1
	movlw   0x00
	movwf   _mr_loop2                               ; _mr_loop2 = 0
waste_time_l1
	decfsz  _mr_loop2, 0x1
	goto    waste_time_l1
	decfsz  _mr_loop1, 0x1
	goto    waste_time_l1
	return

	include "lcd.asm"
	include "screen.asm"

;***********************************************************************
;***********************************************************************
; EEPROM
;***********************************************************************
;***********************************************************************
.eedata	org 0x2100
eeprom_str_title1	de	"  PiAdagio Sound  \0"
eeprom_str_title2	de	"      Server      \0"
eeprom_str_tmode1	de	"Button Test\0"
eeprom_str_tmode2	de	"IR Test\0"
eeprom_str_tmode3	de	"LCD Test\0"
eeprom_str_tmode4	de	"i2c Test\0"
eeprom_str_poweroff	de	"Power Off\0"
eeprom_str_reset	de	"Hard Reset\0"
eeprom_str_shutdown	de	"Shutdown\0"

eeprom_test		TESTFP_LIST	TESTFP_LIST_EEPROM,1

        END
