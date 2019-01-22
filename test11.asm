        list    p=16F874,t=ON,c=132,n=80
        title   "Adagio Front Panel redesign"
        radix   dec
;********************************************************************************
	include "p16f874.inc"
	include <coff.inc>
	include "lcd.inc"
	include "commands.inc"
	include	"strings.inc"

	__CONFIG _CP_OFF & _PWRTE_ON & _WDT_OFF & _HS_OSC & _LVP_ON	; 16MHz ceramic resonator
	ERRORLEVEL -302 ;remove message about using proper bank

	#define NODE_ADDR		0x22				; I2C address of this node (address 17, it's stored in it's shifted state!)
	#define RX_BUF_LEN		42				; Length of receive buffer (cmd str + cmd pos + 2 lines)
	#define	LCD_LINE_LENGTH		20				; Line length of lcd

	#define	START_OF_RAM_1	0x20
	#define	END_OF_RAM_1	0x7f
	#define	START_OF_RAM_2	0xa0
	#define	END_OF_RAM_2	0xff

	cblock	START_OF_RAM_1
; Interrupt handler save registers
		WREGsave						; This has to be implement in both banks
		STATUSsave,FSRsave,PCLATHsave
; General registers
		_mr_mode_cur,_mr_mode_prev
		_mr_cmd_cur,_mr_cmd_prev
		_mr_cmd_buttons,_mr_cmd_ir
		_mr_test_select						; [7] run test, [6] subtest select, [5-4] subtest number, [3-0] test number
		_mr_pwrctrl_select
		_mr_loop1,_mr_loop2
		_mr_temp
; Button registers
		_mr_button_bank: 3
; IR receiver registers
		_mr_ir_receiver_count_false,_mr_ir_receiver_count_true
		_mr_ir_receiver_count_false_on_err,_mr_ir_receiver_count_true_on_err
		_mr_ir_receiver_state,_mr_ir_receiver_state_on_err,_mr_ir_receiver_error_count
		_mr_ir_receiver_bit_index,_mr_ir_receiver_ft_divide
		_mr_ir_receiver_address_lsb,_mr_ir_receiver_address_msb
		_mr_ir_receiver_command,_mr_ir_receiver_command_inverted
		_mr_ir_receiver_command_actual,_mr_ir_receiver_command_repeat
		_mr_ir_receiver_address_lsb_actual,_mr_ir_receiver_address_msb_actual
; i2c registers
		_mr_i2c_state,_mr_i2c_temp
		_mr_i2c_cmd_status,_mr_i2c_cmd_size
		_mr_i2c_buffer: RX_BUF_LEN, _mr_i2c_buffer_index
		_mr_i2c_rx_count,_mr_i2c_tx_count,_mr_i2c_err_count

		_mr_display_countl
		_mr_display_counth
		_mr_display_countu
	endc

	cblock	START_OF_RAM_2
; Interrupt handler save registers
		WREGsave_alt						; This has to be implement in both banks
; General registers
		_mr_oldxtris,_mr_oldytris				; Old TRIS values
; Screen buffer registers
		_mr_screen_buffer_update				; <0-2> Screen update counter, <7> Disable screen update
		_mr_screen_buffer_loop
		_mr_screen_buffer_temp
		_mr_screen_buffer_line1: LCD_LINE_LENGTH		; Screen buffer
		_mr_screen_buffer_line3: LCD_LINE_LENGTH		; Screen buffer
		_mr_screen_buffer_line2: LCD_LINE_LENGTH		; Screen buffer
		_mr_screen_buffer_line4: LCD_LINE_LENGTH		; Screen buffer
; LCD registers
		_mr_lcd_enable_delay					; This controls the delay time needed for the enable line to register
		_mr_lcd_loop
		_mr_lcd_temp
		_mr_lcd_delayloop1, _mr_lcd_delayloop2
	endc

; processor reset vector
reset   org     0x000
	clrwdt                                          ; Clear the watchdog timer.
	CLRF   INTCON                                   ; Disable all interrupts
	CLRF   PCLATH
	goto    main

ISR     org     0x004
	movwf   WREGsave                ; Save WREG (any bank)
	swapf   STATUS, W               ; Get STATUS register (without affecting it)
	banksel STATUSsave              ; Switch banks, after we have copied the STATUS register
	movwf   STATUSsave              ; Save the STATUS register
	movf    PCLATH, W
	movwf   PCLATHsave              ; Save PCLATH
	movf    FSR, W
	movwf   FSRsave                 ; Save FSR

	banksel PIR1
	btfss   PIR1, TMR2IF
		goto    ISR_exit
	bcf     PIR1, TMR2IF
	banksel _mr_screen_buffer_update
	movlw   0x1
	movwf   _mr_screen_buffer_update
ISR_exit
	banksel FSRsave
	movf    FSRsave, W
	movwf   FSR                     ; Restore FSR
	movf    PCLATHsave, W
	movwf   PCLATH                  ; Restore PCLATH
	swapf   STATUSsave, W
	movwf   STATUS                  ; Restore STATUS
	swapf   WREGsave, F
	swapf   WREGsave, W             ; Restore WREG
	retfie


;***********************************************************************
main
	CALL    init_mpu				; MPU Initialisation
	call	init_board
	call	init_mem

        CLRWDT
	BCF     STATUS, RP1
	BCF     STATUS, RP0

        BSF     PORTC, 0x1				; Light 'online' LED
        BSF     PORTE, 0x2				; Light 'standby' LED

	banksel INTCON                                  ; enable interrupts
	bsf     INTCON, GIE
	bsf     INTCON, PEIE
	call	screen_timer_enable

	; test data
	call	generate_icons

main_loop

;;************************************************************
;; Read buttons
;	call	read_buttons
;	call	buttons_2_command
;
;main_loop_update_command_from_buttons
;	movf	_mr_cmd_buttons, W
;	btfsc	STATUS, Z
;		goto	main_loop_update_command_clear
;	movwf	_mr_cmd_cur
;	goto	main_loop_update_command_done
;main_loop_update_command_clear
;	clrf	_mr_cmd_cur
;main_loop_update_command_done
;
;	movf	_mr_cmd_cur, W
;	subwf	_mr_cmd_prev, F
;	btfsc	STATUS, Z
;		goto	main_loop_repeat
;
;;	sublw	CMD_UP
;;	btfss	STATUS, Z
;;		goto	main_loop_repeat
;;
;;	incf	_nop_store, F
;
;main_loop_repeat
;	movf	_mr_cmd_cur, W
;	movwf	_mr_cmd_prev
;
;	GOTO	main_loop


	banksel	_mr_screen_buffer_update
	movf	_mr_screen_buffer_update, F
	btfsc	STATUS, Z
		goto	main_loop_exit

	movlw	_mr_screen_buffer_line2
	movwf	FSR

	movlw	'H'
	call	screen_write_char
	movlw	'e'
	call	screen_write_char
	movlw	'l'
	call	screen_write_char
	movlw	'l'
	call	screen_write_char
	movlw	'o'
	call	screen_write_char
	movlw	'W'
	call	screen_write_char
	movlw	'o'
	call	screen_write_char
	movlw	'r'
	call	screen_write_char
	movlw	'l'
	call	screen_write_char
	movlw	'd'
	call	screen_write_char

	movlw	_mr_screen_buffer_line3
	movwf	FSR

	movlw	0x0
	call	screen_write_char
	movlw	0x1
	call	screen_write_char
	movlw	0x2
	call	screen_write_char
	movlw	0x3
	call	screen_write_char
	movlw	0x4
	call	screen_write_char
	movlw	0x5
	call	screen_write_char
	movlw	0x6
	call	screen_write_char
	movlw	0x7
	call	screen_write_char

;	banksel	_mr_display_countu
;	movf	_mr_display_countu, W
;	call	screen_write_byte_as_hex
;
;	incf	FSR, F
;	banksel	_mr_display_counth
;	movf	_mr_display_counth, W
;	call	screen_write_byte_as_hex
;
;	incf	FSR, F
;	banksel	_mr_display_countl
;	movf	_mr_display_countl, W
;	call	screen_write_byte_as_hex

        movlw   (LCD_BASE_ADDR>>8)                      ; Select high address
        movwf   PCLATH                                  ; For the next 'call'
        call    LCD_UPDATE_FROM_SCREEN_BUFFER           ; Write screen buffer to LCD
        clrf    PCLATH

	banksel	_mr_screen_buffer_update
	clrf	_mr_screen_buffer_update

	banksel	_mr_display_countl
	clrf	_mr_display_countl
	clrf	_mr_display_counth
	clrf	_mr_display_countu

main_loop_exit
	banksel	_mr_display_countl
	incf	_mr_display_countl, F
	btfss	STATUS, Z
		goto	main_loop
	incf	_mr_display_counth, F
	btfss	STATUS, Z
		goto	main_loop
	incf	_mr_display_countu, F

	GOTO	main_loop

;***********************************************************************
generate_icons
; Speaker
	banksel	_mr_i2c_buffer
	movlw	_mr_i2c_buffer
	movwf	FSR

	movlw	0x00
	movwf	INDF
	incf	FSR, F

	movlw	0x01
	movwf	INDF
	incf	FSR, F

	movlw	0x03
	movwf	INDF
	incf	FSR, F

	movlw	0x1d
	movwf	INDF
	incf	FSR, F

	movlw	0x19
	movwf	INDF
	incf	FSR, F

	movlw	0x19
	movwf	INDF
	incf	FSR, F

	movlw	0x1d
	movwf	INDF
	incf	FSR, F

	movlw	0x03
	movwf	INDF
	incf	FSR, F

	movlw	0x01
	movwf	INDF
	incf	FSR, F

	movlw	_mr_i2c_buffer
	movwf	FSR
	movlw   (LCD_BASE_ADDR>>8)			; Select high address
	movwf   PCLATH					; For the next 'call'
	call    LCD_WRITE_CGDATA			; Write data to CGRAM
	clrf    PCLATH

; Hour Glass 1
	banksel	_mr_i2c_buffer
	movlw	_mr_i2c_buffer
	movwf	FSR

	movlw	0x01
	movwf	INDF
	incf	FSR, F

	movlw	0x1F
	movwf	INDF
	incf	FSR, F

	movlw	0x11
	movwf	INDF
	incf	FSR, F

	movlw	0x0A
	movwf	INDF
	incf	FSR, F

	movlw	0x04
	movwf	INDF
	incf	FSR, F

	movlw	0x0A
	movwf	INDF
	incf	FSR, F

	movlw	0x11
	movwf	INDF
	incf	FSR, F

	movlw	0x1F
	movwf	INDF
	incf	FSR, F

	movlw	0x00
	movwf	INDF
	incf	FSR, F

	movlw	_mr_i2c_buffer
	movwf	FSR
	movlw   (LCD_BASE_ADDR>>8)			; Select high address
	movwf   PCLATH					; For the next 'call'
	call    LCD_WRITE_CGDATA			; Write data to CGRAM
	clrf    PCLATH

; Hour Glass 2
	banksel	_mr_i2c_buffer
	movlw	_mr_i2c_buffer
	movwf	FSR

	movlw	0x02
	movwf	INDF
	incf	FSR, F

	movlw	0x1F
	movwf	INDF
	incf	FSR, F

	movlw	0x1F
	movwf	INDF
	incf	FSR, F

	movlw	0x0e
	movwf	INDF
	incf	FSR, F

	movlw	0x04
	movwf	INDF
	incf	FSR, F

	movlw	0x0a
	movwf	INDF
	incf	FSR, F

	movlw	0x11
	movwf	INDF
	incf	FSR, F

	movlw	0x1f
	movwf	INDF
	incf	FSR, F

	movlw	0x00
	movwf	INDF
	incf	FSR, F

	movlw	_mr_i2c_buffer
	movwf	FSR
	movlw   (LCD_BASE_ADDR>>8)			; Select high address
	movwf   PCLATH					; For the next 'call'
	call    LCD_WRITE_CGDATA			; Write data to CGRAM
	clrf    PCLATH

; Hour Glass 3
	banksel	_mr_i2c_buffer
	movlw	_mr_i2c_buffer
	movwf	FSR

	movlw	0x03
	movwf	INDF
	incf	FSR, F

	movlw	0x1F
	movwf	INDF
	incf	FSR, F

	movlw	0x1F
	movwf	INDF
	incf	FSR, F

	movlw	0x0e
	movwf	INDF
	incf	FSR, F

	movlw	0x04
	movwf	INDF
	incf	FSR, F

	movlw	0x0a
	movwf	INDF
	incf	FSR, F

	movlw	0x1f
	movwf	INDF
	incf	FSR, F

	movlw	0x1f
	movwf	INDF
	incf	FSR, F

	movlw	0x00
	movwf	INDF
	incf	FSR, F

	movlw	_mr_i2c_buffer
	movwf	FSR
	movlw   (LCD_BASE_ADDR>>8)			; Select high address
	movwf   PCLATH					; For the next 'call'
	call    LCD_WRITE_CGDATA			; Write data to CGRAM
	clrf    PCLATH

; Hour Glass 4
	banksel	_mr_i2c_buffer
	movlw	_mr_i2c_buffer
	movwf	FSR

	movlw	0x04
	movwf	INDF
	incf	FSR, F

	movlw	0x1f
	movwf	INDF
	incf	FSR, F

	movlw	0x11
	movwf	INDF
	incf	FSR, F

	movlw	0x0e
	movwf	INDF
	incf	FSR, F

	movlw	0x04
	movwf	INDF
	incf	FSR, F

	movlw	0x0a
	movwf	INDF
	incf	FSR, F

	movlw	0x1f
	movwf	INDF
	incf	FSR, F

	movlw	0x1f
	movwf	INDF
	incf	FSR, F

	movlw	0x00
	movwf	INDF
	incf	FSR, F

	movlw	_mr_i2c_buffer
	movwf	FSR
	movlw   (LCD_BASE_ADDR>>8)			; Select high address
	movwf   PCLATH					; For the next 'call'
	call    LCD_WRITE_CGDATA			; Write data to CGRAM
	clrf    PCLATH

; Hour Glass 5
	banksel	_mr_i2c_buffer
	movlw	_mr_i2c_buffer
	movwf	FSR

	movlw	0x05
	movwf	INDF
	incf	FSR, F

	movlw	0x1f
	movwf	INDF
	incf	FSR, F

	movlw	0x11
	movwf	INDF
	incf	FSR, F

	movlw	0x0e
	movwf	INDF
	incf	FSR, F

	movlw	0x04
	movwf	INDF
	incf	FSR, F

	movlw	0x0e
	movwf	INDF
	incf	FSR, F

	movlw	0x1f
	movwf	INDF
	incf	FSR, F

	movlw	0x1f
	movwf	INDF
	incf	FSR, F

	movlw	0x00
	movwf	INDF
	incf	FSR, F

	movlw	_mr_i2c_buffer
	movwf	FSR
	movlw   (LCD_BASE_ADDR>>8)			; Select high address
	movwf   PCLATH					; For the next 'call'
	call    LCD_WRITE_CGDATA			; Write data to CGRAM
	clrf    PCLATH

; Hour Glass 6
	banksel	_mr_i2c_buffer
	movlw	_mr_i2c_buffer
	movwf	FSR

	movlw	0x06
	movwf	INDF
	incf	FSR, F

	movlw	0x1f
	movwf	INDF
	incf	FSR, F

	movlw	0x11
	movwf	INDF
	incf	FSR, F

	movlw	0x0a
	movwf	INDF
	incf	FSR, F

	movlw	0x04
	movwf	INDF
	incf	FSR, F

	movlw	0x0e
	movwf	INDF
	incf	FSR, F

	movlw	0x1f
	movwf	INDF
	incf	FSR, F

	movlw	0x1f
	movwf	INDF
	incf	FSR, F

	movlw	0x00
	movwf	INDF
	incf	FSR, F

	movlw	_mr_i2c_buffer
	movwf	FSR
	movlw   (LCD_BASE_ADDR>>8)			; Select high address
	movwf   PCLATH					; For the next 'call'
	call    LCD_WRITE_CGDATA			; Write data to CGRAM
	clrf    PCLATH

; Pause
	banksel	_mr_i2c_buffer
	movlw	_mr_i2c_buffer
	movwf	FSR

	movlw	0x07
	movwf	INDF
	incf	FSR, F

	movlw	0x00
	movwf	INDF
	incf	FSR, F

	movlw	0x1b
	movwf	INDF
	incf	FSR, F

	movlw	0x1b
	movwf	INDF
	incf	FSR, F

	movlw	0x1b
	movwf	INDF
	incf	FSR, F

	movlw	0x1b
	movwf	INDF
	incf	FSR, F

	movlw	0x1b
	movwf	INDF
	incf	FSR, F

	movlw	0x1b
	movwf	INDF
	incf	FSR, F

	movlw	0x00
	movwf	INDF
	incf	FSR, F

	movlw	_mr_i2c_buffer
	movwf	FSR
	movlw   (LCD_BASE_ADDR>>8)			; Select high address
	movwf   PCLATH					; For the next 'call'
	call    LCD_WRITE_CGDATA			; Write data to CGRAM
	clrf    PCLATH

	return

;***********************************************************************
; Initialisation routines
;***********************************************************************
; Initialise MPU
init_mpu
	banksel	PCON
	bsf	PCON,NOT_POR				; Clear Power-On reset flag
	bsf	PCON,NOT_BOR				; Clear Brown-Out reset flag

	clrwdt

; Bank 0
	banksel	PIR1
	clrf   PIR1					; Reset registers
	clrf   PIR2
	clrf   TMR1L
	clrf   TMR1H
	clrf   T1CON
	clrf   CCPR1L
	clrf   CCPR1H
	clrf   ADCON0
	clrf   CCP1CON
	clrf   CCP2CON
	clrf   TMR2
	clrf   RCSTA

; Bank 1
	banksel	TRISA
;	movlw	0xEF
;	movwf	TRISA					; Configure PORTA (Inputs: 0,1,2,3,5,6,7 | Outputs: 4)
	movlw	0xEF
	movwf	TRISA					; Configure PORTA (Inputs: 0,1,2,3,5,6,7 | Outputs: 4)

;	movlw	0xF7
;	movwf	TRISB					; Configure PORTB (Inputs: 0,1,2,4,5,6,7 | Outputs: 3)
	movlw	0xF7
	movwf	TRISB					; Configure PORTB (Inputs: 0,1,2,4,5,6,7 | Outputs: 3)

;	movlw	0x1D
;	movwf	TRISC					; Configure PORTC (Inputs: 0,2,3,4 | Outputs: 1,5,6,7)
	movlw	0x1C
	movwf	TRISC					; Configure PORTC (Inputs: 2,3,4 | Outputs: 0,1,5,6,7)

	movlw	0xFF
	movwf	PR2					; Set Timer2 period register
	movwf	TRISD					; Configure PORTD (Inputs: 0,1,2,3,4,5,6,7 | Outputs: )

	clrf	PIE1					; Clear peripheral interrupts
	clrf	PIE2					; Clear peripheral interrupts
	clrf	SPBRG					; Clear baud rate generator register
	clrf	TRISE					; Configure PORTE (Inputs: | Outputs: 0,1,2,3,4,5,6,7 )
	clrf	TXSTA

	movlw	0x95
	movwf	OPTION_REG				; PORTB pull up resistors disabled, prescaler assigned to WDT, WDT rate: 1 : 128

	movlw	0x06					; From the original code (????)
	movwf	ADCON1

	banksel	PORTA
	clrf	PORTA					; Clear outputs
	clrf	PORTB
	clrf	PORTC
	clrf	PORTE

; Setup Timers
	call	screen_timer_init			; Setup timer to refresh LCD
;	movlw	(IR_RECVR_BASE_ADDR>>8)			; Select high address
;	movwf	PCLATH					; For the next 'call'
;	call	ir_receiver_timer_init			; Setup timer to sample IR receiver input
;	clrf	PCLATH

;	call	set_online_led_on			; Turn on 'online' LED (This shows MPU initialised)

;	movlw	0x32
;	movwf	_mr_temp				; Setup loop counter
;init_mpu_led_loop
;	clrwdt
;	call	waste_time_256_x_48
;	decfsz	_mr_temp, F
;		goto	init_mpu_led_loop
;
;	call	set_online_led_off			; Turn off 'online' LED

	return

;***********************************************************************
; Initialises Memory
init_mem
	banksel	WREGsave
	clrf	WREGsave					; Clear the ISR save registers
	clrf	STATUSsave
	clrf	FSRsave
	clrf	PCLATHsave

	clrf	_mr_mode_prev
	clrw
;	movlw	MODE_POWEROFF					; Set the current mode
	movwf	_mr_mode_cur

	clrf	_mr_test_select					; Test mode, selected test
	clrf	_mr_pwrctrl_select				; Power control, selected shutdown method

	clrf	_mr_i2c_cmd_status

	clrf	_mr_display_countl
	clrf	_mr_display_counth
	clrf	_mr_display_countu

	banksel	_mr_screen_buffer_update
	clrf	_mr_screen_buffer_update			; Clear screen buffer related registers
	clrf	_mr_screen_buffer_loop
	clrf	_mr_screen_buffer_temp
	clrf	_mr_lcd_loop					; Clear LCD related registers
	clrf	_mr_lcd_temp
	clrf	_mr_lcd_delayloop1
	clrf	_mr_lcd_delayloop2

	movlw	0x6
	movwf	_mr_lcd_enable_delay				; Time delayed needed for the LCD enable line to register

	clrf	_mr_oldxtris					; Clear the TRIS save registers
	clrf	_mr_oldytris

	call	screen_clear					; Clear screen buffer

;	banksel	EEADR
;	movlw	eeprom_ir_addr_lsb - 0x2100			; Get the IR receiver address
;	movwf	EEADR
;	clrf	EEADRH
;	call	pic_eeprom_read
;	banksel	_mr_ir_receiver_address_lsb_actual
;	movwf	_mr_ir_receiver_address_lsb_actual
;	call	pic_eeprom_read
;	banksel	_mr_ir_receiver_address_msb_actual
;	movwf	_mr_ir_receiver_address_msb_actual

	return

;***********************************************************************
; Initialise Hardware
init_board
	clrwdt

	movlw	(LCD_BASE_ADDR>>8)		; Select high address
	movwf	PCLATH				; For the next 'call'
	call	LCD_INITIALIZE
	clrf	PCLATH

;	call	i2c_master_init

	return

;***********************************************************************
; this function looks like it just wastes machine cycles (Old Code)
waste_time
;	movlw   0x0c
;	movwf   _mr_loop1                               ; _mr_loop1 = 12
;	goto    waste_time_j1
;	movlw   0x01
;	movwf   _mr_loop1                               ; _mr_loop1 = 01
;	goto    waste_time_j1
waste_time_j1
	movlw   0x00
	movwf   _mr_loop2                               ; _mr_loop2 = 0
waste_time_l1
	decfsz  _mr_loop2, 0x1
	goto    waste_time_l1
	decfsz  _mr_loop1, 0x1
	goto    waste_time_l1
	return

	include "buttons.asm"
	include	"screen.asm"
	include "commands.asm"

	include "lcd.asm"
        include "strings.asm"                           ; This has a fixed location, so needs to be loaded last

        END
