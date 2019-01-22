	list	p=16F874,t=ON,c=132,n=80
	title	"Adagio Front Panel redesign"
	radix	dec
;********************************************************************************

	include "p16f874.inc"
	include <coff.inc>
	include	"i2c.inc"
	include	"ir_receiver.inc"
	include "lcd.inc"
	include "commands.inc"
	include "PiAdagio FP.inc"

;	4 MHz ceramic resonator
	__CONFIG _CP_OFF & _PWRTE_ON & _WDT_OFF & _XT_OSC & _LVP_ON
	ERRORLEVEL -302 ;remove message about using proper bank

	#define NODE_ADDR		0x22		; I2C address of this node
	#define RX_BUF_LEN		22		; Length of receive buffer (cmd str + cmd pos + max str len (20))
	#define I2C_CHAR_CLEAR		0x00		; value to load into array after transmit
	#define	LCD_LINE_LENGTH		20		; Line length of lcd

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
		_mr_test_select						; [7] run test, [6-0] test number
		_mr_loop1,_mr_loop2
		_mr_temp
; Button registers
		_mr_button_bank: 3
; IR receiver registers
		_mr_ir_receiver_count_false,_mr_ir_receiver_count_true
		_mr_ir_receiver_state,_mr_ir_receiver_error_count
		_mr_ir_receiver_bit_index,_mr_ir_receiver_ft_divide
		_mr_ir_receiver_address,_mr_ir_receiver_address_inverted
		_mr_ir_receiver_command,_mr_ir_receiver_command_inverted
		_mr_ir_receiver_command_actual,_mr_ir_receiver_command_repeat
		_mr_ir_receiver_address_actual
; i2c registers
		_mr_i2c_temp,_mr_i2c_cmd_status,_mr_i2c_cmd_size
		_mr_i2c_buffer: RX_BUF_LEN, _mr_i2c_buffer_index
	endc

	cblock	START_OF_RAM_2
; Interrupt handler save registers
		WREGsave_alt						; This has to be implement in both banks
; General registers
		_mr_oldxtris,_mr_oldytris				; Old TRIS values
; Screen buffer registers
		_mr_screen_buffer_update
		_mr_screen_buffer_loop
		_mr_screen_buffer_temp
		_mr_screen_buffer_line1: LCD_LINE_LENGTH		; Screen buffer
		_mr_screen_buffer_line3: LCD_LINE_LENGTH		; Screen buffer
		_mr_screen_buffer_line2: LCD_LINE_LENGTH		; Screen buffer
		_mr_screen_buffer_line4: LCD_LINE_LENGTH		; Screen buffer
; LCD registers
		_mr_lcd_loop
		_mr_lcd_temp
		_mr_lcd_delayloop1, _mr_lcd_delayloop2
	endc

; processor reset vector
ResetVector	org	0x000
		clrwdt						; Clear the watchdog timer.
		clrf	INTCON					; Disable all interrupts
		clrf	PCLATH
		goto	main

; interrupt vector location
ISRVector	org	0x004
;---------------------------------------------------------------------
; Interrupt Code
;---------------------------------------------------------------------
ISR
	movwf	WREGsave			; Save WREG (any bank)
	swapf	STATUS, W			; Get STATUS register (without affecting it)
	banksel	STATUSsave			; Switch banks, after we have copied the STATUS register
	movwf	STATUSsave			; Save the STATUS register
	movf	PCLATH, W
	movwf	PCLATHsave			; Save PCLATH
	movf	FSR, W
	movwf	FSRsave				; Save FSR

	clrf	PCLATH				; Clear PCLATH register

ISR_Tmr2_int
	banksel	PIR1
	btfss	PIR1, TMR2IF			; Is this a Timer2 interrupt
		goto	ISR_Tmr1_int		; If not go to next check
	bcf	PIR1, TMR2IF			; Otherwise, clear the interrupt flag
	banksel	_mr_screen_buffer_update
	movlw	0x1
	movwf	_mr_screen_buffer_update	; And mark the LCD for update
	goto	ISR_exit

ISR_Tmr1_int
	banksel	PIR2
	btfss   PIR2, CCP2IF
		goto    ISR_i2c_int
	call    ir_receiver_interrupt_handler
	goto	ISR_exit

ISR_i2c_int
	banksel	PIR1
	btfsc	PIR1,SSPIF			; Is this a SSP interrupt?
		call	i2c_slave_ssp_handler	; Yes, service SSP interrupt. By skipping is this going to cause problems on bus collisions

ISR_exit
	banksel	FSRsave
	movf	FSRsave, W
	movwf	FSR				; Restore FSR
	movf	PCLATHsave, W
	movwf	PCLATH				; Restore PCLATH
	swapf	STATUSsave, W
	movwf	STATUS				; Restore STATUS
	swapf	WREGsave, F
	swapf	WREGsave, W			; Restore WREG
	retfie					; Return from interrupt

;***********************************************************************
main
	call	init_mpu				; MPU Initialisation
	call	init_mem				; Initialise registers
	call	init_board				; Hardware Initialisation

	banksel	INTCON					; enable interrupts
	bsf	INTCON, GIE
	bsf	INTCON, PEIE

	call	screen_timer_init			; Setup timer to refresh LCD
	call	screen_timer_enable			; Enable refresh timer
	call	ir_receiver_timer_init
	call	ir_receiver_timer_enable

main_loop
	clrwdt						; Clear watchdog timer

main_loop_update_lcd
	banksel	_mr_screen_buffer_update
	movf	_mr_screen_buffer_update, F
	btfsc	STATUS, Z				; Check if there is a pending LCD update
		goto	main_loop_read_inputs
	call	screen_write_2_lcd			; Write screen buffer to LCD
	banksel	_mr_screen_buffer_update
	clrf	_mr_screen_buffer_update		; Clear LCD update flag

main_loop_read_inputs
	movlw	0x0f					; Select high address (includes the required offset for the add in the routine)
	movwf	PCLATH					; For the next 'call'
	banksel	_mr_ir_receiver_command_actual
	movf	_mr_ir_receiver_command_actual, W	; Get IR command data
	call	ir_receiver_bc_2_cmd_table		; Translate IR to function code
	movwf	_mr_cmd_cur
	clrf	PCLATH					; Clear the PCLATH

	call	read_buttons				; Check buttons
	call	buttons_2_command			; Translate button presses to function code

;***********************************************************************
;***********************************************************************
; Main: Power Off
;***********************************************************************
;***********************************************************************
main_loop_mode_poweroff
	btfss	_mr_mode_cur, MODE_BIT_POWEROFF
		goto	main_loop_mode_poweron
; Power off section
;***********************************************************************
	banksel	_mr_mode_cur
	movf	_mr_mode_cur, W
	subwf	_mr_mode_prev, W
	btfss	STATUS, Z				; Is this the first time through poweroff section
		call	mode_poweroff_init		; then init
	banksel	_mr_cmd_cur
	movf	_mr_cmd_cur, W
	subwf	_mr_cmd_prev, F
	btfsc	STATUS, Z				; Check for a change of command state
		goto	main_loop_mode_cont
	sublw	CMD_POWER
	btfsc	STATUS, Z				; Check for a power command
		call	mode_poweron_set
	movf	_mr_cmd_cur, W
	sublw	CMD_TESTMODE
	btfsc	STATUS, Z				; Check for a test mode command
		call	mode_testfp_set
	goto	main_loop_mode_cont

;***********************************************************************
;***********************************************************************
; Main: Power On
;***********************************************************************
;***********************************************************************
main_loop_mode_poweron
	btfss	_mr_mode_cur, MODE_BIT_POWERON
		goto	main_loop_mode_testfp
; Power on section
;***********************************************************************
	banksel	_mr_mode_cur
	movf	_mr_mode_cur, W
	subwf	_mr_mode_prev, W
	btfss	STATUS, Z				; Is this the first time through poweron section
		call	mode_poweron_init		; then init
	call	fp_cmd_process				; Process any pending command
	banksel	_mr_cmd_cur
	movf	_mr_cmd_cur, W
	subwf	_mr_cmd_prev, F
	btfsc	STATUS, Z				; Check for a change of command state
		goto	main_loop_mode_cont
	sublw	CMD_POWER
	btfsc	STATUS, Z				; Check for a power command
		call	mode_poweroff_set
	goto	main_loop_mode_cont

;***********************************************************************
;***********************************************************************
; Main: Test Mode
;***********************************************************************
;***********************************************************************
main_loop_mode_testfp
	btfss	_mr_mode_cur, MODE_BIT_TESTFP
		goto	main_loop_mode_cont
; Front panel test mode section
;***********************************************************************
	banksel	_mr_mode_cur
	movf	_mr_mode_cur, W
	subwf	_mr_mode_prev, W
	btfss	STATUS, Z				; Is this the first time through testfp section
		call	mode_testfp_init		; then init
	btfsc	_mr_test_select, 7
		goto	main_loop_mode_testfp_run
	call	mode_testfp_display_tests
	goto	main_loop_mode_testfp_process_cmd
main_loop_mode_testfp_run
main_loop_mode_testfp_run_buttons
	banksel	_mr_test_select
	movf	_mr_test_select, W
	andlw	0x7f					; Strip 'run' flag
	TESTFP_TEST_LIST	TESTFP_OBJ_CHECK, TESTFP_TESTS_BUTTONS
	btfss	STATUS, Z
		goto	main_loop_mode_testfp_run_lcd
	TESTFP_TEST_LIST	TESTFP_OBJ_CODE, TESTFP_TESTS_BUTTONS
	goto	main_loop_mode_testfp_process_cmd
main_loop_mode_testfp_run_lcd
	banksel	_mr_test_select
	movf	_mr_test_select, W
	andlw	0x7f					; Strip 'run' flag
	TESTFP_TEST_LIST	TESTFP_OBJ_CHECK, TESTFP_TESTS_LCD
	btfss	STATUS, Z
		goto	main_loop_mode_testfp_run_ir
	TESTFP_TEST_LIST	TESTFP_OBJ_CODE, TESTFP_TESTS_LCD
	goto	main_loop_mode_testfp_process_cmd
main_loop_mode_testfp_run_ir
	banksel	_mr_test_select
	movf	_mr_test_select, W
	andlw	0x7f					; Strip 'run' flag
	TESTFP_TEST_LIST	TESTFP_OBJ_CHECK, TESTFP_TESTS_IR
	btfss	STATUS, Z
		goto	main_loop_mode_testfp_run_i2c
	TESTFP_TEST_LIST	TESTFP_OBJ_CODE, TESTFP_TESTS_IR
	goto	main_loop_mode_testfp_process_cmd
main_loop_mode_testfp_run_i2c
	banksel	_mr_test_select
	movf	_mr_test_select, W
	andlw	0x7f					; Strip 'run' flag
	TESTFP_TEST_LIST	TESTFP_OBJ_CHECK, TESTFP_TESTS_I2C
	btfss	STATUS, Z
		goto	main_loop_mode_testfp_run_exit
	TESTFP_TEST_LIST	TESTFP_OBJ_CODE, TESTFP_TESTS_I2C
	goto	main_loop_mode_testfp_process_cmd
main_loop_mode_testfp_run_exit
main_loop_mode_testfp_process_cmd
	banksel	_mr_cmd_cur
	movf	_mr_cmd_cur, W
	subwf	_mr_cmd_prev, F
	btfsc	STATUS, Z				; Check for a change of command state
		goto	main_loop_mode_cont
main_loop_mode_testfp_process_cmd_testmode
	sublw	CMD_TESTMODE
	btfss	STATUS, Z				; Check for a test mode command
		goto	main_loop_mode_testfp_process_cmd_up
	call	mode_poweroff_set
	goto	main_loop_mode_cont
main_loop_mode_testfp_process_cmd_up
	movf	_mr_cmd_cur, W
	sublw	CMD_UP
	btfss	STATUS, Z
		goto	main_loop_mode_testfp_process_cmd_down
	btfss	_mr_test_select, 7
		call	mode_testfp_dec_select_test
	goto	main_loop_mode_cont
main_loop_mode_testfp_process_cmd_down
	movf	_mr_cmd_cur, W
	sublw	CMD_DOWN
	btfss	STATUS, Z
		goto	main_loop_mode_testfp_process_cmd_left
	btfss	_mr_test_select, 7
		call	mode_testfp_inc_select_test
	goto	main_loop_mode_cont
main_loop_mode_testfp_process_cmd_left
	movf	_mr_cmd_cur, W
	sublw	CMD_LEFT
	btfss	STATUS, Z
		goto	main_loop_mode_testfp_process_cmd_right
	btfsc	_mr_test_select, 7
		bcf	_mr_test_select, 7
	goto	main_loop_mode_cont
main_loop_mode_testfp_process_cmd_right
	movf	_mr_cmd_cur, W
	sublw	CMD_RIGHT
	btfss	STATUS, Z
		goto	main_loop_mode_testfp_process_cmd_select
	bsf	_mr_test_select, 7
	goto	main_loop_mode_cont
main_loop_mode_testfp_process_cmd_select
	movf	_mr_cmd_cur, W
	sublw	CMD_SELECT
	btfss	STATUS, Z
		goto	main_loop_mode_testfp_process_cmd_pfinish
	bsf	_mr_test_select, 7
	goto	main_loop_mode_cont
main_loop_mode_testfp_process_cmd_pfinish
	goto	main_loop_mode_cont

main_loop_mode_cont
	movf	_mr_cmd_cur, W
	movwf	_mr_cmd_prev
	goto	main_loop

;***********************************************************************
; Mode: Power Off
;***********************************************************************
mode_poweroff_set
	banksel	_mr_mode_cur
	movlw	MODE_POWEROFF
	movwf	_mr_mode_cur
	return

mode_poweroff_init
	call	screen_clear				; Clear screen buffer
	call	set_online_led_off
	call	set_power_led_off

	banksel	_mr_mode_prev
	movlw	MODE_POWEROFF
	movwf	_mr_mode_prev
	return

;***********************************************************************
; Mode: Power On
;***********************************************************************
mode_poweron_set
	banksel	_mr_mode_cur
	movlw	MODE_POWERON
	movwf	_mr_mode_cur
	return

mode_poweron_init
	call	set_power_led_on
	call	set_mpu_as_i2c_slave				; Reset SSP as i2c slave and enable interrupts

	call	screen_draw_border				; Draw a border in the screen buffer

	movlw	_mr_screen_buffer_line2 + 3			; Write 'PiAdagio Sound' in the screen buffer (line 2)
	movwf	FSR
	movlw	eeprom_str_title1 - 0x2100
	call	screen_write_eeprom_2_buffer

	movlw	_mr_screen_buffer_line3 + 7			; Write 'Server' in the screen buffer (line 3)
	movwf	FSR
	movlw	eeprom_str_title2 - 0x2100
	call	screen_write_eeprom_2_buffer

	banksel	_mr_mode_prev
	movlw	MODE_POWERON
	movwf	_mr_mode_prev
	return

; Process command
fp_cmd_process
;	bcf	INTCON,GIE					; Disable interrupts while we are processing
;
;	btfss	_mr_i2c_cmd_status, FP_CMD_STATUS_LOADING
;		goto	fp_cmd_process_exit			; Skip if there isn't a command pending
;	btfsc	_mr_i2c_cmd_status, FP_CMD_STATUS_PROCESSED
;		goto	fp_cmd_process_exit			; Skip if the command has been processed
;	btfss	_mr_i2c_cmd_status, FP_CMD_STATUS_LOADED
;		goto	fp_cmd_process_exit			; Skip if the command hasn't finished loading
;
;	bsf	_mr_i2c_cmd_status, FP_CMD_STATUS_PROCESSING	; Mark command as being processed
;
;	btfsc	_mr_i2c_buffer, FP_CMD_CLEAR_SCREEN		; Clear screen command
;		goto 	fp_cmd_process_clear_screen
;	btfsc	_mr_i2c_buffer, FP_CMD_WRITE_SCREEN		; Write screen command
;		goto	fp_cmd_process_write_screen
;
;	bsf	_mr_i2c_cmd_status, FP_CMD_STATUS_PROCESSED	; Mark command as processed anyway to clear it
;
;fp_cmd_process_exit
;	call	i2c_slave_clear_overflow			; Flush any i2c overflow condition
;
;	bsf	INTCON,GIE					; Re-enable interrupts
	return

;***********************************************************************
; Process command - Clear screen
;fp_cmd_process_clear_screen
;	call	LCD_PORT_CONFIGURE
;
;	btfss	_mr_i2c_cmd_size, 0x01				; Is this command 2 or more bytes
;		goto	fp_cmd_process_clear_whole_screen	; Only 1 command byte, so clear all the screen
;
;	clrw							; First reset screen clear position
;	btfsc	(_mr_i2c_buffer + 1), 0x01
;		goto	fp_cmd_process_clear_screen_row_gt_2	; Row selection is greater than or equal to 2
;	btfsc	(_mr_i2c_buffer + 1), 0x00
;		addlw	SCR_ROW1				; Row 1	selected
;	goto	fp_cmd_process_clear_screen_next
;fp_cmd_process_clear_screen_row_gt_2
;	addlw	SCR_ROW2
;	btfsc	(_mr_i2c_buffer + 1), 0x00
;		addlw	SCR_ROW1				; With SCR_ROW2 produces SCR_ROW3
;
;fp_cmd_process_clear_screen_next
;	movwf	_mr_lcd_screen_pos				; Save selected row
;	movlw	0x14
;	movwf	_mr_lcd_clear_chars				; Set the default number of characters to clear
;
;	btfss	_mr_i2c_cmd_size, 0x00
;		goto	fp_cmd_process_clear_screen_portion
;
;	rrf	(_mr_i2c_buffer + 1), F				; Now get column data
;	rrf	(_mr_i2c_buffer + 1), W				; Now get column data
;	andlw	b'00111111'
;	addwf	_mr_lcd_screen_pos, F					; Add the column data to the selected row
;	movf	(_mr_i2c_buffer + 2), W				; Get the number of characters to clear
;	movwf	_mr_lcd_clear_chars
;
;fp_cmd_process_clear_screen_portion
;	movf	_mr_lcd_screen_pos, W
;	iorlw	LCD_CMD_SET_DDRAM				; Set the command bits
;	call	LCD_WRITE_CMD
;	call	LCD_CLEAR_CHARS
;	goto	fp_cmd_process_clear_screen_finish
;
;fp_cmd_process_clear_whole_screen
;	call	LCD_CLEAR_SCREEN
;
;fp_cmd_process_clear_screen_finish
;	call	LCD_PORT_RESTORE
;	bsf	_mr_i2c_cmd_status, FP_CMD_STATUS_PROCESSED	; Mark command as processed
;
;	goto	fp_cmd_process
;
;***********************************************************************
; Process command - Write to screen
;fp_cmd_process_write_screen
;	call	LCD_PORT_CONFIGURE
;
;	movf	_mr_i2c_cmd_size, w				; Check for invalid command
;	xorlw	b'00000001'
;	btfsc	STATUS, Z
;		goto	fp_cmd_process_write_screen_finish	; Improper command
;
;	movf	_mr_i2c_cmd_size, w				; Check for single character write
;	xorlw	b'00000010'
;	btfsc	STATUS, Z
;		goto	fp_cmd_process_write_screen_write_char
;
;	clrw							; First reset screen position
;	btfsc	(_mr_i2c_buffer + 1), 0x01
;		goto	fp_cmd_process_write_screen_row_gt_2	; Row selection is greater than or equal to 2
;	btfsc	(_mr_i2c_buffer + 1), 0x00
;		addlw	SCR_ROW1				; Row 1	selected
;	goto	fp_cmd_process_write_screen_next
;fp_cmd_process_write_screen_row_gt_2
;	addlw	SCR_ROW2
;	btfsc	(_mr_i2c_buffer + 1), 0x00
;		addlw	SCR_ROW1				; With SCR_ROW2 produces SCR_ROW3
;
;fp_cmd_process_write_screen_next
;	movwf	_mr_lcd_screen_pos				; Save selected row
;	rrf	(_mr_i2c_buffer + 1), F				; Now get column data
;	rrf	(_mr_i2c_buffer + 1), W				; Now get column data
;	andlw	b'00111111'
;	addwf	_mr_lcd_screen_pos, F				; Add the column data to the selected row
;	movf	_mr_lcd_screen_pos, W
;	iorlw	LCD_CMD_SET_DDRAM				; Set the command bits
;	call	LCD_WRITE_CMD					; Set screen position
;
;	movlw	0x02						; Update command size to represent character data size
;	subwf	_mr_i2c_cmd_size, F
;
;	clrf	_mr_i2c_buffer_index				; Reset pointer to use to load data out
;fp_cmd_process_write_screen_next_char
;	movlw	(_mr_i2c_buffer + 2)				; Set the start of the character data
;	addwf	_mr_i2c_buffer_index, W
;	movwf	FSR
;	movf	INDF, W
;	call	LCD_WRITE_DATA					; Write character to screen
;	incf	_mr_i2c_buffer_index, F
;	decfsz	_mr_i2c_cmd_size, F
;		goto	fp_cmd_process_write_screen_next_char
;	goto	fp_cmd_process_write_screen_finish
;
;fp_cmd_process_write_screen_write_char
;	movf	(_mr_i2c_buffer + 1), W
;	call	LCD_WRITE_DATA
;
;fp_cmd_process_write_screen_finish
;	call	LCD_PORT_RESTORE
;	bsf	_mr_i2c_cmd_status, FP_CMD_STATUS_PROCESSED	; Mark command as processed
;
;	GOTO fp_cmd_process

;***********************************************************************
; Mode: Test Mode
;***********************************************************************
; mode_testfp_set
;
; Select test mode
;
mode_testfp_set
	banksel	_mr_mode_cur
	movlw	MODE_TESTFP
	movwf	_mr_mode_cur
	return

;***********************************************************************
; mode_testfp_init
;
; Initialise test mode
;
mode_testfp_init
	call	screen_clear					; Clear screen buffer
	call	set_online_led_on
	call	set_power_led_on

	banksel	_mr_mode_prev
	movlw	MODE_TESTFP
	movwf	_mr_mode_prev
	clrf	_mr_test_select					; Reset the selected FP test
	return

;***********************************************************************
; mode_testfp_inc_select_test
;
; Increments the selected test
;
mode_testfp_inc_select_test
	incf	_mr_test_select, F
	movf	_mr_test_select, W
	sublw	TESTFP_NUM_TESTS - 1		; Subtract W from (TESTFP_NUM_TESTS - 1)
	btfsc	STATUS, C			; Check if the results is negative
		goto	mode_testfp_inc_select_test_exit
	movlw	TESTFP_NUM_TESTS - 1
	movwf	_mr_test_select
mode_testfp_inc_select_test_exit
	return

;***********************************************************************
; mode_testfp_dec_select_test
;
; Decrements the selected test
;
mode_testfp_dec_select_test
	movf	_mr_test_select, W
	btfsc	STATUS, Z
		goto	mode_testfp_dec_select_test_exit
	decf	_mr_test_select, F
mode_testfp_dec_select_test_exit
	return

;***********************************************************************
; mode_testfp_display_tests
;
; Displays a list of tests, with the selected test highlighted
;
mode_testfp_display_tests
	call	screen_clear

mode_testfp_display_tests_line1
	movlw	_mr_screen_buffer_line1 + 1			; Select line 1, 2nd character
	movwf	FSR
	banksel	_mr_test_select
	movf	_mr_test_select, W				; Is this the test selected
	sublw	0x0						; Usually this would be > 0
	btfss	STATUS, Z
		goto	mode_testfp_display_tests_line1_txt	; If not selected, skip to text
	movlw	'>'						; Otherwise, add an '>' to show selection
	call	screen_write_char
	decf	FSR, F
mode_testfp_display_tests_line1_txt
	movlw	0x2						; Add 2 to the FSR, to columinate the text strings
	addwf	FSR, F
	movlw	eeprom_str_tmode0 - 0x2100			; Subtract 0x2100, as that is only used for generating the iHEX file
	call	screen_write_eeprom_2_buffer			; Write string

mode_testfp_display_tests_line2
	movlw	_mr_screen_buffer_line2 + 1			; Select line 2, 2nd character
	movwf	FSR
	banksel	_mr_test_select
	movf	_mr_test_select, W				; Is this the test selected
	sublw	0x1						; Usually this would be > 0
	btfss	STATUS, Z
		goto	mode_testfp_display_tests_line2_txt	; If not selected, skip to text
	movlw	'>'						; Otherwise, add an '>' to show selection
	call	screen_write_char
	decf	FSR, F
mode_testfp_display_tests_line2_txt
	movlw	0x2						; Add 2 to the FSR, to columinate the text strings
	addwf	FSR, F
	movlw	eeprom_str_tmode1 - 0x2100
	call	screen_write_eeprom_2_buffer

mode_testfp_display_tests_line3
	movlw	_mr_screen_buffer_line3 + 1			; Select line 3, 2nd character
	movwf	FSR
	banksel	_mr_test_select
	movf	_mr_test_select, W				; Is this the test selected
	sublw	0x2						; Usually this would be > 0
	btfss	STATUS, Z
		goto	mode_testfp_display_tests_line3_txt	; If not selected, skip to text
	movlw	'>'						; Otherwise, add an '>' to show selection
	call	screen_write_char
	decf	FSR, F
mode_testfp_display_tests_line3_txt
	movlw	0x2						; Add 2 to the FSR, to columinate the text strings
	addwf	FSR, F
	movlw	eeprom_str_tmode2 - 0x2100
	call	screen_write_eeprom_2_buffer

mode_testfp_display_tests_line4
	movlw	_mr_screen_buffer_line4 + 1			; Select line 4, 2nd character
	movwf	FSR
	banksel	_mr_test_select
	movf	_mr_test_select, W				; Is this the test selected
	sublw	0x3						; Usually this would be > 0
	btfss	STATUS, Z
		goto	mode_testfp_display_tests_line4_txt	; If not selected, skip to text
	movlw	'>'						; Otherwise, add an '>' to show selection
	call	screen_write_char
	decf	FSR, F
mode_testfp_display_tests_line4_txt
	movlw	0x2						; Add 2 to the FSR, to columinate the text strings
	addwf	FSR, F
	movlw	eeprom_str_tmode3 - 0x2100
	call	screen_write_eeprom_2_buffer

	return

;***********************************************************************
; mode_testfp_test_buttons
;
; Displays ths status of the panel buttons, and the interpreted command.
;
mode_testfp_test_buttons
	call	screen_clear

	movlw	_mr_screen_buffer_line1
	movwf	FSR
	movlw	'B'
	call	screen_write_char
	movlw	'a'
	call	screen_write_char
	movlw	'n'
	call	screen_write_char
	movlw	'k'
	call	screen_write_char
	movlw	'1'
	call	screen_write_char
	incf	FSR, F
	banksel	_mr_button_bank
	movf	_mr_button_bank, W
	call	screen_write_byte_as_hex

	movlw	_mr_screen_buffer_line1 + 10
	movwf	FSR
	movlw	'B'
	call	screen_write_char
	movlw	'a'
	call	screen_write_char
	movlw	'n'
	call	screen_write_char
	movlw	'k'
	call	screen_write_char
	movlw	'2'
	call	screen_write_char
	incf	FSR, F
	banksel	_mr_button_bank
	movf	(_mr_button_bank + 1), W
	call	screen_write_byte_as_hex

	movlw	_mr_screen_buffer_line2
	movwf	FSR
	movlw	'B'
	call	screen_write_char
	movlw	'a'
	call	screen_write_char
	movlw	'n'
	call	screen_write_char
	movlw	'k'
	call	screen_write_char
	movlw	'3'
	call	screen_write_char
	incf	FSR, F
	banksel	_mr_button_bank
	movf	(_mr_button_bank + 2), W
	call	screen_write_byte_as_hex

	movlw	_mr_screen_buffer_line4
	movwf	FSR
	movlw	'C'
	call	screen_write_char
	movlw	'o'
	call	screen_write_char
	movlw	'm'
	call	screen_write_char
	movlw	'm'
	call	screen_write_char
	movlw	'a'
	call	screen_write_char
	movlw	'n'
	call	screen_write_char
	movlw	'd'
	call	screen_write_char
	incf	FSR, F
	banksel	_mr_cmd_cur
	movf	_mr_cmd_cur, W
	call	screen_write_byte_as_hex

	return

;***********************************************************************
; mode_testfp_test_lcd
;
; Writes a full display of characters to the LCD.
;
mode_testfp_test_lcd
	call	screen_clear

mode_testfp_test_lcd_line1
	movlw	_mr_screen_buffer_line1
	movwf	FSR					; Configure FSR to point to line 1

	banksel	_mr_temp
	clrf	_mr_temp				; Clear temporary storage
mode_testfp_test_lcd_line1_loop
	movf	_mr_temp, W				; Load current value
	addlw	'A'					; Add to 'A' to get current letter
	call	screen_write_char			; Write to screen buffer
	banksel	_mr_temp
	incf	_mr_temp, F				; Increment current value
	movf	_mr_temp, W
	sublw	0x14					; Have we reached the EOL
	btfss	STATUS, Z
		goto	mode_testfp_test_lcd_line1_loop

mode_testfp_test_lcd_line2
	movlw	_mr_screen_buffer_line2
	movwf	FSR					; Configure FSR to point to line 2

	banksel	_mr_temp
	clrf	_mr_temp				; Clear temporary storage
mode_testfp_test_lcd_line2_loop1
	movf	_mr_temp, W				; Load current value
	addlw	'U'					; Add to 'U' to get current letter
	call	screen_write_char			; Write to screen buffer
	banksel	_mr_temp
	incf	_mr_temp, F				; Increment current value
	movf	_mr_temp, W
	sublw	0x06					; Have we reached the EOL
	btfss	STATUS, Z
		goto	mode_testfp_test_lcd_line2_loop1
	clrf	_mr_temp				; Clear temporary storage
mode_testfp_test_lcd_line2_loop2
	movf	_mr_temp, W				; Load current value
	addlw	'a'					; Add to 'a' to get current letter
	call	screen_write_char			; Write to screen buffer
	banksel	_mr_temp
	incf	_mr_temp, F				; Increment current value
	movf	_mr_temp, W
	sublw	0x0e					; Have we reached the EOL
	btfss	STATUS, Z
		goto	mode_testfp_test_lcd_line2_loop2

mode_testfp_test_lcd_line3
	movlw	_mr_screen_buffer_line3
	movwf	FSR					; Configure FSR to point to line 3

	banksel	_mr_temp
	clrf	_mr_temp				; Clear temporary storage
mode_testfp_test_lcd_line3_loop1
	movf	_mr_temp, W				; Load current value
	addlw	'o'					; Add to 'o' to get current letter
	call	screen_write_char			; Write to screen buffer
	banksel	_mr_temp
	incf	_mr_temp, F				; Increment current value
	movf	_mr_temp, W
	sublw	0x0c					; Have we reached the EOL
	btfss	STATUS, Z
		goto	mode_testfp_test_lcd_line3_loop1
	clrf	_mr_temp				; Clear temporary storage
mode_testfp_test_lcd_line3_loop2
	movf	_mr_temp, W				; Load current value
	addlw	'0'					; Add to 'A' to get current letter
	call	screen_write_char			; Write to screen buffer
	banksel	_mr_temp
	incf	_mr_temp, F				; Increment current value
	movf	_mr_temp, W
	sublw	0x08					; Have we reached the EOL
	btfss	STATUS, Z
		goto	mode_testfp_test_lcd_line3_loop2

mode_testfp_test_lcd_line4
	movlw	_mr_screen_buffer_line4
	movwf	FSR					; Configure FSR to point to line 4

	banksel	_mr_temp
	clrf	_mr_temp				; Clear temporary storage
mode_testfp_test_lcd_line4_loop1
	movf	_mr_temp, W				; Load current value
	addlw	'8'					; Add to 'o' to get current letter
	call	screen_write_char			; Write to screen buffer
	banksel	_mr_temp
	incf	_mr_temp, F				; Increment current value
	movf	_mr_temp, W
	sublw	0x02					; Have we reached the EOL
	btfss	STATUS, Z
		goto	mode_testfp_test_lcd_line4_loop1
	clrf	_mr_temp				; Clear temporary storage
mode_testfp_test_lcd_line4_loop2
	movf	_mr_temp, W				; Load current value
	addlw	'!'					; Add to 'A' to get current letter
	call	screen_write_char			; Write to screen buffer
	banksel	_mr_temp
	incf	_mr_temp, F				; Increment current value
	movf	_mr_temp, W
	sublw	0x0f					; Have we reached the EOL
	btfss	STATUS, Z
		goto	mode_testfp_test_lcd_line4_loop2
	movlw	'<'
	call	screen_write_char			; Write to screen buffer
	movlw	'='
	call	screen_write_char			; Write to screen buffer
	movlw	'>'
	call	screen_write_char			; Write to screen buffer

	return

;***********************************************************************
; mode_testfp_test_ir
;
; Tests the IR detector/decoder.
;
mode_testfp_test_ir
	call	screen_clear

	movlw	_mr_screen_buffer_line1
	movwf	FSR
	movlw	'R'
	call	screen_write_char
	movlw	'd'
	call	screen_write_char
	movlw	'_'
	call	screen_write_char
	movlw	'A'
	call	screen_write_char
	movlw	'd'
	call	screen_write_char
	movlw	'd'
	call	screen_write_char
	movlw	'r'
	call	screen_write_char
	movlw	':'
	call	screen_write_char
	banksel	_mr_ir_receiver_address
	movf	_mr_ir_receiver_address, W
	call    screen_write_byte_as_hex

	movlw	_mr_screen_buffer_line1 + 11
	movwf	FSR
	movlw	'R'
	call	screen_write_char
	movlw	'd'
	call	screen_write_char
	movlw	'_'
	call	screen_write_char
	movlw	'C'
	call	screen_write_char
	movlw	'm'
	call	screen_write_char
	movlw	'd'
	call	screen_write_char
	movlw	':'
	call	screen_write_char
	banksel	_mr_ir_receiver_command
	movf	_mr_ir_receiver_command, W
	call    screen_write_byte_as_hex

	movlw	_mr_screen_buffer_line2
	movwf	FSR
	movlw	'R'
	call	screen_write_char
	movlw	'c'
	call	screen_write_char
	movlw	'v'
	call	screen_write_char
	movlw	'r'
	call	screen_write_char
	movlw	' '
	call	screen_write_char
	movlw	'A'
	call	screen_write_char
	movlw	'd'
	call	screen_write_char
	movlw	'd'
	call	screen_write_char
	movlw	'r'
	call	screen_write_char
	movlw	':'
	call	screen_write_char
	banksel	_mr_ir_receiver_address_actual
	movf	_mr_ir_receiver_address_actual, W
	call    screen_write_byte_as_hex

	movlw	_mr_screen_buffer_line3
	movwf	FSR
	movlw	'E'
	call	screen_write_char
	movlw	'r'
	call	screen_write_char
	movlw	'r'
	call	screen_write_char
	movlw	'o'
	call	screen_write_char
	movlw	'r'
	call	screen_write_char
	movlw	' '
	call	screen_write_char
	movlw	'C'
	call	screen_write_char
	movlw	'o'
	call	screen_write_char
	movlw	'u'
	call	screen_write_char
	movlw	'n'
	call	screen_write_char
	movlw	't'
	call	screen_write_char
	movlw	':'
	call	screen_write_char
	banksel	_mr_ir_receiver_error_count
	movf	_mr_ir_receiver_error_count, W
	call    screen_write_byte_as_hex

	movlw	_mr_screen_buffer_line4
	movwf	FSR
	movlw	'C'
	call	screen_write_char
	movlw	'm'
	call	screen_write_char
	movlw	'd'
	call	screen_write_char
	movlw	':'
	call	screen_write_char
	banksel	_mr_ir_receiver_command_actual
	movf	_mr_ir_receiver_command_actual, W
	call    screen_write_byte_as_hex

	banksel	_mr_cmd_cur
	movf	_mr_cmd_cur, F
	btfss	STATUS, Z
		goto	mode_testfp_test_ir_exit
	movf	_mr_cmd_prev, W
	sublw	CMD_EJECT					; If the eject button was previously depressed
	btfss	STATUS, Z
		goto	mode_testfp_test_ir_exit
	movf	_mr_ir_receiver_address, W			; Update the IR receiver address, with previously received value
	movwf	_mr_ir_receiver_address_actual
	call	ir_receiver_save_receiver_addr			; Save address back to the EEPROM

mode_testfp_test_ir_exit
	return

;***********************************************************************
; mode_testfp_test_i2c
;
mode_testfp_test_i2c
	call	screen_clear

	movlw	_mr_screen_buffer_line2 + 3
	movwf	FSR
	movlw	'N'
	call	screen_write_char
	movlw	'o'
	call	screen_write_char
	movlw	't'
	call	screen_write_char
	movlw	' '
	call	screen_write_char
	movlw	'A'
	call	screen_write_char
	movlw	'v'
	call	screen_write_char
	movlw	'a'
	call	screen_write_char
	movlw	'i'
	call	screen_write_char
	movlw	'l'
	call	screen_write_char
	movlw	'a'
	call	screen_write_char
	movlw	'b'
	call	screen_write_char
	movlw	'l'
	call	screen_write_char
	movlw	'e'
	call	screen_write_char

	return

;***********************************************************************
; General routines
;***********************************************************************

;***********************************************************************
; Reset the i2c interface as a slave
set_mpu_as_i2c_slave
	clrf	PIR1			; Clear interrupt flag
	call	i2c_slave_init

	bsf	INTCON,PEIE 		; Enable all peripheral interrupts
	bsf	INTCON,GIE		; Enable global interrupts
	return

;***********************************************************************
; Set Power LED state (W)
set_power_led_off
	banksel	PORTE
	bcf	PORTE, 0x2				; Extinguish 'power' LED
	return

set_power_led_on
	banksel	PORTE
	bsf	PORTE, 0x2				; Light 'power' LED
	return

;***********************************************************************
; Set Online LED state (W)
set_online_led_off
	banksel	PORTC
	bcf	PORTC, 0x1				; Extinguish 'online' LED
	return

set_online_led_on
	banksel	PORTC
	bsf	PORTC, 0x1				; Light 'online' LED
	return

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

	call	set_online_led_on

	MOVLW   0x32
	MOVWF   0x66					; Setup loop counter
init_mpu_l1
	CLRWDT
	CALL    waste_time
	DECFSZ  0x66, 0x1
	GOTO    init_mpu_l1

	call	set_online_led_off

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
	movlw	MODE_POWEROFF					; Set the current mode
	movwf	_mr_mode_cur

	clrf	_mr_test_select					; Test mode, selected test

	banksel	_mr_screen_buffer_update
	clrf	_mr_screen_buffer_update			; Clear screen buffer related registers
	clrf	_mr_screen_buffer_loop
	clrf	_mr_screen_buffer_temp
	clrf	_mr_lcd_loop					; Clear LCD related registers
	clrf	_mr_lcd_temp
	clrf	_mr_lcd_delayloop1
	clrf	_mr_lcd_delayloop2

	clrf	_mr_oldxtris					; Clear the TRIS save registers
	clrf	_mr_oldytris

	call	screen_clear					; Clear screen buffer

	banksel	EEADR
	movlw	eeprom_ir_addr - 0x2100				; Get the IR receiver address
	movwf	EEADR
	banksel	EECON1
	bcf	EECON1, EEPGD					; Select EEPROM memory
	bsf	EECON1, RD					; Start read operation
	banksel	EEDATA
	movf	EEDATA, W
	banksel	_mr_ir_receiver_address_actual
	movwf	_mr_ir_receiver_address_actual

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
	include "commands.asm"
	include	"ir_receiver.asm"			; This has a table at a fixed location, so needs to be loaded last

;***********************************************************************
;***********************************************************************
; EEPROM
;***********************************************************************
;***********************************************************************
.eedata	org	0x2100
eeprom_ir_addr		de	0x42
eeprom_str_title1	de	"PiAdagio Sound\0"
eeprom_str_title2	de	"Server\0"
eeprom_str_poweroff	de	"Power Off\0"
eeprom_str_reset	de	"Hard Reset\0"
eeprom_str_shutdown	de	"Shutdown\0"

eeprom_str_tmode0	TESTFP_TEST_LIST	TESTFP_OBJ_EEPROM,0
eeprom_str_tmode1	TESTFP_TEST_LIST	TESTFP_OBJ_EEPROM,1
eeprom_str_tmode2	TESTFP_TEST_LIST	TESTFP_OBJ_EEPROM,2
eeprom_str_tmode3	TESTFP_TEST_LIST	TESTFP_OBJ_EEPROM,3

        END
