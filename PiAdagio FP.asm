	list	p=16F874,t=ON,c=132,n=80
	title	"Adagio Front Panel redesign"
	radix	dec
;********************************************************************************

	include "p16f874.inc"
	include <coff.inc>
	include	"i2c.inc"
	include "i2c_master.inc"
	include	"ir_receiver.inc"
	include "lcd.inc"
	include "commands.inc"
	include "strings.inc"
	include "PiAdagio FP.inc"

;	4 MHz ceramic resonator
	__CONFIG _CP_OFF & _PWRTE_ON & _WDT_OFF & _XT_OSC & _LVP_ON
	ERRORLEVEL -302 ;remove message about using proper bank

	#define NODE_ADDR		0x22		; I2C address of this node (address 17, it's stored in it's shifted state!)
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
		_mr_i2c_temp,_mr_i2c_cmd_status,_mr_i2c_cmd_size
		_mr_i2c_buffer: RX_BUF_LEN, _mr_i2c_buffer_index
	endc

	cblock	START_OF_RAM_2
; Interrupt handler save registers
		WREGsave_alt						; This has to be implement in both banks
; General registers
		_mr_oldxtris,_mr_oldytris				; Old TRIS values
; Screen buffer registers
		_mr_screen_buffer_update				; <0> Update screen, <1> Disable screen update
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
	bsf	_mr_screen_buffer_update, 0x0	; And mark the LCD for update
	goto	ISR_exit

ISR_Tmr1_int
	banksel	PIR2
	btfss   PIR2, CCP2IF
		goto    ISR_i2c_int
	btfss	_mr_ir_receiver_state, IR_RECEIVER_MODE_BIT_WAIT
		call	set_power_led_toggle	; Indicate IR reception

	movlw	(IR_RECVR_BASE_ADDR>>8)		; Select high address
	movwf	PCLATH				; For the next 'call'
	call	ir_receiver_interrupt_handler
	clrf	PCLATH				; Clear high address for 'goto'
	goto	ISR_exit

ISR_i2c_int
	banksel	PIR1
	btfsc	PIR1,SSPIF			; Is this a SSP interrupt?
		call	i2c_slave_ssp_handler	; Yes, service SSP interrupt. By skipping is this going to cause problems on bus collisions

ISR_Ext_int
	btfss	INTCON, INTF
		goto	ISR_exit
	call	mode_poweroff_set
	bcf	INTCON, INTF

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

	call	screen_timer_enable			; Enable refresh timer
	call	ctrl_rpi_shutdown_int_enable		; Enable power off on shutdown of RPi
	movlw	(IR_RECVR_BASE_ADDR>>8)			; Select high address
	movwf	PCLATH					; For the next 'call'
	call	ir_receiver_timer_enable		; Enable IR receiver timer
	clrf	PCLATH

main_loop
	clrwdt						; Clear watchdog timer

main_loop_update_lcd
	banksel	_mr_screen_buffer_update
	btfss	_mr_screen_buffer_update, 0x0		; Is there a screen update pending
		goto	main_loop_read_inputs
	btfsc	_mr_screen_buffer_update, 0x1		; Is the screen update disabled
		goto	main_loop_read_inputs
	call	screen_write_2_lcd			; Write screen buffer to LCD
	banksel	_mr_screen_buffer_update
	bcf	_mr_screen_buffer_update, 0x0		; Clear screen update flag

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
	call	set_power_led_off

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
	call	set_power_led_on

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
		call	mode_powercontrol_set
	goto	main_loop_mode_cont

;***********************************************************************
;***********************************************************************
; Main: Test Mode
;***********************************************************************
;***********************************************************************
main_loop_mode_testfp
	btfss	_mr_mode_cur, MODE_BIT_TESTFP
		goto	main_loop_mode_powercontrol
; Front panel test mode section
;***********************************************************************
	banksel	_mr_mode_cur
	movf	_mr_mode_cur, W
	subwf	_mr_mode_prev, W
	btfss	STATUS, Z				; Is this the first time through testfp section
		call	mode_testfp_init		; then init
	btfsc	_mr_test_select, 7
		goto	main_loop_mode_testfp_run

	banksel	_mr_test_select
	bcf	_mr_test_select, 0x4			; Clear sub test bits
	bcf	_mr_test_select, 0x5
	bcf	_mr_test_select, 0x6

	call	mode_testfp_display_tests
	goto	main_loop_mode_testfp_process_cmd
main_loop_mode_testfp_run
main_loop_mode_testfp_run_buttons
	banksel	_mr_test_select
	movf	_mr_test_select, W
	andlw	TESTFP_TEST_MASK			; Strip extraneous bits
	TESTFP_TEST_LIST	TESTFP_OBJ_CHECK, TESTFP_TESTS_BUTTONS
	btfss	STATUS, Z
		goto	main_loop_mode_testfp_run_lcd
	TESTFP_TEST_LIST	TESTFP_OBJ_CODE, TESTFP_TESTS_BUTTONS
	goto	main_loop_mode_testfp_process_cmd
main_loop_mode_testfp_run_lcd
	banksel	_mr_test_select
	movf	_mr_test_select, W
	andlw	TESTFP_TEST_MASK			; Strip extraneous bits
	TESTFP_TEST_LIST	TESTFP_OBJ_CHECK, TESTFP_TESTS_LCD
	btfss	STATUS, Z
		goto	main_loop_mode_testfp_run_ir
	TESTFP_TEST_LIST	TESTFP_OBJ_CODE, TESTFP_TESTS_LCD
	goto	main_loop_mode_testfp_process_cmd
main_loop_mode_testfp_run_ir
	banksel	_mr_test_select
	movf	_mr_test_select, W
	andlw	TESTFP_TEST_MASK			; Strip extraneous bits
	TESTFP_TEST_LIST	TESTFP_OBJ_CHECK, TESTFP_TESTS_IR
	btfss	STATUS, Z
		goto	main_loop_mode_testfp_run_pwr_cntrls
	TESTFP_TEST_LIST	TESTFP_OBJ_CODE, TESTFP_TESTS_IR
	goto	main_loop_mode_testfp_process_cmd
main_loop_mode_testfp_run_pwr_cntrls
	banksel	_mr_test_select
	movf	_mr_test_select, W
	andlw	TESTFP_TEST_MASK			; Strip extraneous bits
	TESTFP_TEST_LIST	TESTFP_OBJ_CHECK, TESTFP_TESTS_PWR_CNTRLS
	btfss	STATUS, Z
		goto	main_loop_mode_testfp_run_i2c_master
	TESTFP_TEST_LIST	TESTFP_OBJ_CODE, TESTFP_TESTS_PWR_CNTRLS
	goto	main_loop_mode_testfp_process_cmd
main_loop_mode_testfp_run_i2c_master
	banksel	_mr_test_select
	movf	_mr_test_select, W
	andlw	TESTFP_TEST_MASK			; Strip extraneous bits
	TESTFP_TEST_LIST	TESTFP_OBJ_CHECK, TESTFP_TESTS_I2C_M
	btfss	STATUS, Z
		goto	main_loop_mode_testfp_run_i2c_slave
	TESTFP_TEST_LIST	TESTFP_OBJ_CODE, TESTFP_TESTS_I2C_M
	goto	main_loop_mode_testfp_process_cmd
main_loop_mode_testfp_run_i2c_slave
	banksel	_mr_test_select
	movf	_mr_test_select, W
	andlw	TESTFP_TEST_MASK			; Strip extraneous bits
	TESTFP_TEST_LIST	TESTFP_OBJ_CHECK, TESTFP_TESTS_I2C_S
	btfss	STATUS, Z
		goto	main_loop_mode_testfp_run_exit
	TESTFP_TEST_LIST	TESTFP_OBJ_CODE, TESTFP_TESTS_I2C_S
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
		call	mode_testfp_dec_selected_test
	goto	main_loop_mode_cont
main_loop_mode_testfp_process_cmd_down
	movf	_mr_cmd_cur, W
	sublw	CMD_DOWN
	btfss	STATUS, Z
		goto	main_loop_mode_testfp_process_cmd_left
	btfss	_mr_test_select, 7
		call	mode_testfp_inc_selected_test
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

;***********************************************************************
;***********************************************************************
; Main: Power Control
;***********************************************************************
;***********************************************************************
main_loop_mode_powercontrol
	btfss	_mr_mode_cur, MODE_BIT_POWERCTRL
		goto	main_loop_mode_cont
; Power control section
;***********************************************************************
	banksel	_mr_mode_cur
	movf	_mr_mode_cur, W
	subwf	_mr_mode_prev, W
	btfss	STATUS, Z				; Is this the first time through power control section
		call	mode_powercontrol_init		; then init
	call	fp_cmd_process				; Keep processing commands
	call	mode_powercontrol_update_display	; Update display
	banksel	_mr_cmd_cur
	movf	_mr_cmd_cur, W
	subwf	_mr_cmd_prev, F
	btfsc	STATUS, Z				; Check for a change of command state
		goto	main_loop_mode_cont
main_loop_mode_powercontrol_process_cmd_pwr
	sublw	CMD_POWER
	btfsc	STATUS, Z				; Check for a power command
		call	mode_powercontrol_back_2_poweron
main_loop_mode_powercontrol_process_cmd_select
	movf	_mr_cmd_cur, W
	sublw	CMD_SELECT
	btfsc	STATUS, Z				; Check for a select command
		call	mode_powercontrol_control_exec
main_loop_mode_powercontrol_process_cmd_up
	movf	_mr_cmd_cur, W
	sublw	CMD_UP
	btfsc	STATUS, Z
		call	mode_powercontrol_dec_selected_pwrctrl
main_loop_mode_powercontrol_process_cmd_down
	movf	_mr_cmd_cur, W
	sublw	CMD_DOWN
	btfsc	STATUS, Z
		call	mode_powercontrol_inc_selected_pwrctrl
main_loop_mode_powercontrol_exit
	goto	main_loop_mode_cont

main_loop_mode_cont
	banksel	_mr_cmd_cur
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
	call	i2c_master_init
	call	lcd_backlight_contrast_settings_save_then_clear
	call	screen_clear				; Clear screen buffer
	call	set_online_led_off
	call	set_psu_off

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
	call	lcd_backlight_contrast_settings_restore
	call	set_online_led_off
	call	set_mpu_as_i2c_slave				; Reset SSP as i2c slave and enable interrupts
	call	set_psu_on

	call	screen_draw_border				; Draw a border in the screen buffer

	movlw	_mr_screen_buffer_line2 + 3			; Write 'PiAdagio Sound' in the screen buffer (line 2)
	movwf	FSR
	movlw	str_panel_title1 - STR_PANEL_BASE_ADDR
	call	screen_write_flash_2_buffer_panel_str

	movlw	_mr_screen_buffer_line3 + 7			; Write 'Server' in the screen buffer (line 3)
	movwf	FSR
	movlw	str_panel_title2 - STR_PANEL_BASE_ADDR
	call	screen_write_flash_2_buffer_panel_str

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
	call	lcd_backlight_contrast_settings_restore
	call	screen_clear					; Clear screen buffer
	call	set_online_led_on
	call	set_power_led_on

	banksel	_mr_mode_prev
	movlw	MODE_TESTFP
	movwf	_mr_mode_prev
	clrf	_mr_test_select					; Reset the selected FP test
	return

;***********************************************************************
; mode_testfp_inc_selected_test
;
; Increments the selected test
;
mode_testfp_inc_selected_test
	incf	_mr_test_select, F
	movf	_mr_test_select, W
	sublw	TESTFP_NUM_TESTS - 1		; Subtract W from (TESTFP_NUM_TESTS - 1)
	btfsc	STATUS, C			; Check if the results is negative
		goto	mode_testfp_inc_selected_test_exit
	movlw	TESTFP_NUM_TESTS - 1
	movwf	_mr_test_select
mode_testfp_inc_selected_test_exit
	return

;***********************************************************************
; mode_testfp_dec_selected_test
;
; Decrements the selected test
;
mode_testfp_dec_selected_test
	movf	_mr_test_select, W
	btfsc	STATUS, Z
		goto	mode_testfp_dec_selected_test_exit
	decf	_mr_test_select, F
mode_testfp_dec_selected_test_exit
	return

;***********************************************************************
; mode_testfp_inc_selected_subtest
;
; Increments the selected subtest
;
mode_testfp_inc_selected_subtest
	clrw					; Build number (easier than using rrf)
	btfsc	_mr_test_select, 0x4
		addlw	0x1
	btfsc	_mr_test_select, 0x5
		addlw	0x2

	bcf	_mr_test_select, 0x4		; Clear existing
	bcf	_mr_test_select, 0x5

	addlw	0x1				; Increment existing value
	movwf	_mr_temp
	btfsc	_mr_temp, 0x2			; Rolled over to 4, so decrement again
		decf	_mr_temp, F
	btfsc	_mr_temp, 0x0			; Set the appropriate bits
		bsf	_mr_test_select, 0x4
	btfsc	_mr_temp, 0x1
		bsf	_mr_test_select, 0x5
	return

;***********************************************************************
; mode_testfp_dec_selected_subtest
;
; Decrements the selected subtest
;
mode_testfp_dec_selected_subtest
	clrw					; Build number (easier than using rrf)
	btfsc	_mr_test_select, 0x4
		addlw	0x1
	btfsc	_mr_test_select, 0x5
		addlw	0x2

	bcf	_mr_test_select, 0x4		; Clear existing
	bcf	_mr_test_select, 0x5

	movwf	_mr_temp
	decf	_mr_temp, F
	btfsc	_mr_temp, 0x7			; Rolled over from 0, so just exit
		goto	mode_testfp_dec_selected_subtest_exit
	btfsc	_mr_temp, 0x0			; Set the appropriate bits
		bsf	_mr_test_select, 0x4
	btfsc	_mr_temp, 0x1
		bsf	_mr_test_select, 0x5
mode_testfp_dec_selected_subtest_exit
	return

;***********************************************************************
; mode_testfp_inc_selected_ds1845_value
;
; Increments the selected EEPROM value in the DS1845
;
mode_testfp_inc_selected_ds1845_value
	banksel	_mr_test_select
	movlw	BACKLIGHT_ADDR					; Get the current value
	btfsc	_mr_test_select, 0x4
		movlw	CONTRAST_ADDR
	movwf	_mr_i2c_buffer_index
	call	i2c_master_ds1845_read
	banksel	_mr_i2c_buffer
	incfsz	_mr_i2c_buffer, F				; Increment value
		goto	mode_testfp_inc_selected_ds1845_value_update
	goto	mode_testfp_inc_selected_ds1845_value_exit	; But don't write it back if we roll over
mode_testfp_inc_selected_ds1845_value_update
	call	i2c_master_ds1845_write				; Save value

mode_testfp_inc_selected_ds1845_value_exit
	return

;***********************************************************************
; mode_testfp_dec_selected_ds1845_value
;
; Decrements the selected EEPROM value in the DS1845
;
mode_testfp_dec_selected_ds1845_value
	banksel	_mr_test_select
	movlw	BACKLIGHT_ADDR					; Get the current value
	btfsc	_mr_test_select, 0x4
		movlw	CONTRAST_ADDR
	movwf	_mr_i2c_buffer_index
	call	i2c_master_ds1845_read
	banksel	_mr_i2c_buffer
	movf	_mr_i2c_buffer, F				; Touch value, set STATUS flags
	btfsc	STATUS, Z
		goto	mode_testfp_dec_selected_ds1845_value_exit
	decf	_mr_i2c_buffer, F				; Decrement value
	call	i2c_master_ds1845_write				; Save value

mode_testfp_dec_selected_ds1845_value_exit
	return

;***********************************************************************
; mode_testfp_toggle_subtest_select
;
; Toggles whether the subtest is selected
;
mode_testfp_toggle_subtest_select
	banksel	_mr_test_select
	btfss	_mr_test_select, 0x6
		goto	mode_testfp_toggle_subtest_select_high
mode_testfp_toggle_subtest_select_low
	bcf	_mr_test_select, 0x6
	goto	mode_testfp_toggle_subtest_select_exit
mode_testfp_toggle_subtest_select_high
	bsf	_mr_test_select, 0x6
mode_testfp_toggle_subtest_select_exit
	return

;***********************************************************************
; mode_testfp_display_tests
;
; Displays a list of tests, with the selected test highlighted
;
mode_testfp_display_tests
	call	screen_clear

	banksel	_mr_test_select
	btfsc	_mr_test_select, 0x2
		goto	mode_testfp_display_tests_screen2_line1

mode_testfp_display_tests_screen1_line1
	movlw	_mr_screen_buffer_line1 + 1			; Select line 1, 2nd character
	movwf	FSR
	banksel	_mr_test_select
	movf	_mr_test_select, W				; Is this the test selected
	sublw	0x0						; Usually this would be > 0
	btfss	STATUS, Z
		goto	mode_testfp_display_tests_screen1_line1_txt	; If not selected, skip to text
	movlw	'>'						; Otherwise, add an '>' to show selection
	call	screen_write_char
	decf	FSR, F
mode_testfp_display_tests_screen1_line1_txt
	movlw	0x2						; Add 2 to the FSR, to columinate the text strings
	addwf	FSR, F
	movlw	str_tests_tmode0 - STR_TESTS_BASE_ADDR		; Subtract STR_TESTS_BASE_ADDR to get the offset
	call	screen_write_flash_2_buffer_tests_str			; Write string

mode_testfp_display_tests_screen1_line2
	movlw	_mr_screen_buffer_line2 + 1			; Select line 2, 2nd character
	movwf	FSR
	banksel	_mr_test_select
	movf	_mr_test_select, W				; Is this the test selected
	sublw	0x1						; Usually this would be > 0
	btfss	STATUS, Z
		goto	mode_testfp_display_tests_screen1_line2_txt	; If not selected, skip to text
	movlw	'>'						; Otherwise, add an '>' to show selection
	call	screen_write_char
	decf	FSR, F
mode_testfp_display_tests_screen1_line2_txt
	movlw	0x2						; Add 2 to the FSR, to columinate the text strings
	addwf	FSR, F
	movlw	str_tests_tmode1 - STR_TESTS_BASE_ADDR
	call	screen_write_flash_2_buffer_tests_str

mode_testfp_display_tests_screen1_line3
	movlw	_mr_screen_buffer_line3 + 1			; Select line 3, 2nd character
	movwf	FSR
	banksel	_mr_test_select
	movf	_mr_test_select, W				; Is this the test selected
	sublw	0x2						; Usually this would be > 0
	btfss	STATUS, Z
		goto	mode_testfp_display_tests_screen1_line3_txt	; If not selected, skip to text
	movlw	'>'						; Otherwise, add an '>' to show selection
	call	screen_write_char
	decf	FSR, F
mode_testfp_display_tests_screen1_line3_txt
	movlw	0x2						; Add 2 to the FSR, to columinate the text strings
	addwf	FSR, F
	movlw	str_tests_tmode2 - STR_TESTS_BASE_ADDR
	call	screen_write_flash_2_buffer_tests_str

mode_testfp_display_tests_screen1_line4
	movlw	_mr_screen_buffer_line4 + 1			; Select line 4, 2nd character
	movwf	FSR
	banksel	_mr_test_select
	movf	_mr_test_select, W				; Is this the test selected
	sublw	0x3						; Usually this would be > 0
	btfss	STATUS, Z
		goto	mode_testfp_display_tests_screen1_line4_txt	; If not selected, skip to text
	movlw	'>'						; Otherwise, add an '>' to show selection
	call	screen_write_char
	decf	FSR, F
mode_testfp_display_tests_screen1_line4_txt
	movlw	0x2						; Add 2 to the FSR, to columinate the text strings
	addwf	FSR, F
	movlw	str_tests_tmode3 - STR_TESTS_BASE_ADDR
	call	screen_write_flash_2_buffer_tests_str

	goto	mode_testfp_display_tests_exit

mode_testfp_display_tests_screen2_line1
	movlw	_mr_screen_buffer_line1 + 1			; Select line 1, 2nd character
	movwf	FSR
	banksel	_mr_test_select
	movf	_mr_test_select, W				; Is this the test selected
	sublw	0x4						; Usually this would be > 0
	btfss	STATUS, Z
		goto	mode_testfp_display_tests_screen2_line1_txt	; If not selected, skip to text
	movlw	'>'						; Otherwise, add an '>' to show selection
	call	screen_write_char
	decf	FSR, F
mode_testfp_display_tests_screen2_line1_txt
	movlw	0x2						; Add 2 to the FSR, to columinate the text strings
	addwf	FSR, F
	movlw	str_tests_tmode4 - STR_TESTS_BASE_ADDR		; Subtract STR_TESTS_BASE_ADDR to get the offset
	call	screen_write_flash_2_buffer_tests_str			; Write string

mode_testfp_display_tests_screen2_line2
	movlw	_mr_screen_buffer_line2 + 1			; Select line 2, 2nd character
	movwf	FSR
	banksel	_mr_test_select
	movf	_mr_test_select, W				; Is this the test selected
	sublw	0x5						; Usually this would be > 0
	btfss	STATUS, Z
		goto	mode_testfp_display_tests_screen2_line2_txt	; If not selected, skip to text
	movlw	'>'						; Otherwise, add an '>' to show selection
	call	screen_write_char
	decf	FSR, F
mode_testfp_display_tests_screen2_line2_txt
	movlw	0x2						; Add 2 to the FSR, to columinate the text strings
	addwf	FSR, F
	movlw	str_tests_tmode5 - STR_TESTS_BASE_ADDR
	call	screen_write_flash_2_buffer_tests_str

;mode_testfp_display_tests_screen2_line3
;	movlw	_mr_screen_buffer_line3 + 1			; Select line 3, 2nd character
;	movwf	FSR
;	banksel	_mr_test_select
;	movf	_mr_test_select, W				; Is this the test selected
;	sublw	0x6						; Usually this would be > 0
;	btfss	STATUS, Z
;		goto	mode_testfp_display_tests_screen2_line3_txt	; If not selected, skip to text
;	movlw	'>'						; Otherwise, add an '>' to show selection
;	call	screen_write_char
;	decf	FSR, F
;mode_testfp_display_tests_screen2_line3_txt
;	movlw	0x2						; Add 2 to the FSR, to columinate the text strings
;	addwf	FSR, F
;	movlw	str_tests_tmode6 - STR_TESTS_BASE_ADDR
;	call	screen_write_flash_2_buffer_tests_str

;mode_testfp_display_tests_screen2_line4
;	movlw	_mr_screen_buffer_line4 + 1			; Select line 4, 2nd character
;	movwf	FSR
;	banksel	_mr_test_select
;	movf	_mr_test_select, W				; Is this the test selected
;	sublw	0x7						; Usually this would be > 0
;	btfss	STATUS, Z
;		goto	mode_testfp_display_tests_screen2_line4_txt	; If not selected, skip to text
;	movlw	'>'						; Otherwise, add an '>' to show selection
;	call	screen_write_char
;	decf	FSR, F
;mode_testfp_display_tests_screen2_line4_txt
;	movlw	0x2						; Add 2 to the FSR, to columinate the text strings
;	addwf	FSR, F
;	movlw	str_tests_tmode7 - STR_TESTS_BASE_ADDR
;	call	screen_write_flash_2_buffer_tests_str

	goto	mode_testfp_display_tests_exit

mode_testfp_display_tests_exit
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

	movlw	str_tests_bank - STR_TESTS_BASE_ADDR
	call	screen_write_flash_2_buffer_tests_str
	movlw	'1'
	call	screen_write_char
	movlw	':'
	call	screen_write_char
	banksel	_mr_button_bank
	movf	_mr_button_bank, W
	call	screen_write_byte_as_hex

	movlw	_mr_screen_buffer_line1 + 10
	movwf	FSR
	movlw	str_tests_bank - STR_TESTS_BASE_ADDR
	call	screen_write_flash_2_buffer_tests_str
	movlw	'2'
	call	screen_write_char
	movlw	':'
	call	screen_write_char
	banksel	_mr_button_bank
	movf	(_mr_button_bank + 1), W
	call	screen_write_byte_as_hex

	movlw	_mr_screen_buffer_line2
	movwf	FSR
	movlw	str_tests_bank - STR_TESTS_BASE_ADDR
	call	screen_write_flash_2_buffer_tests_str
	movlw	'3'
	call	screen_write_char
	movlw	':'
	call	screen_write_char
	banksel	_mr_button_bank
	movf	(_mr_button_bank + 2), W
	call	screen_write_byte_as_hex

	movlw	_mr_screen_buffer_line4
	movwf	FSR
	movlw	str_tests_fp_cmd - STR_TESTS_BASE_ADDR
	call	screen_write_flash_2_buffer_tests_str
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
	movlw	str_tests_lcd_line1 - STR_TESTS_BASE_ADDR
	call	screen_write_flash_2_buffer_tests_str

mode_testfp_test_lcd_line2
	movlw	_mr_screen_buffer_line2
	movwf	FSR					; Configure FSR to point to line 2
	movlw	str_tests_lcd_line2 - STR_TESTS_BASE_ADDR
	call	screen_write_flash_2_buffer_tests_str

mode_testfp_test_lcd_line3
	movlw	_mr_screen_buffer_line3
	movwf	FSR					; Configure FSR to point to line 3
	movlw	str_tests_lcd_line3 - STR_TESTS_BASE_ADDR
	call	screen_write_flash_2_buffer_tests_str

mode_testfp_test_lcd_line4
	movlw	_mr_screen_buffer_line4
	movwf	FSR					; Configure FSR to point to line 4
	movlw	str_tests_lcd_line4 - STR_TESTS_BASE_ADDR
	call	screen_write_flash_2_buffer_tests_str

	return

;***********************************************************************
; mode_testfp_test_ir
;
; Tests the IR detector/decoder.
;
mode_testfp_test_ir
	banksel	_mr_test_select
	btfsc	_mr_test_select, 0x6				; Have we paused the display
		goto	mode_testfp_test_ir_process_cmd 	; If so, just process commands

	call	screen_clear

	movlw	_mr_screen_buffer_line1
	movwf	FSR

	movlw	str_tests_rcvd_addr - STR_TESTS_BASE_ADDR
	call	screen_write_flash_2_buffer_tests_str
	banksel	_mr_ir_receiver_address_msb
	movf	_mr_ir_receiver_address_msb, W
	call    screen_write_byte_as_hex
	banksel	_mr_ir_receiver_address_lsb
	movf	_mr_ir_receiver_address_lsb, W
	call    screen_write_byte_as_hex
	movlw	'('
	call	screen_write_char
	banksel	_mr_ir_receiver_address_msb_actual
	movf	_mr_ir_receiver_address_msb_actual, W
	call    screen_write_byte_as_hex
	banksel	_mr_ir_receiver_address_lsb_actual
	movf	_mr_ir_receiver_address_lsb_actual, W
	call    screen_write_byte_as_hex
	movlw	')'
	call	screen_write_char

	movlw	_mr_screen_buffer_line2
	movwf	FSR
	movlw	str_tests_rcvd_cmd - STR_TESTS_BASE_ADDR
	call	screen_write_flash_2_buffer_tests_str
	banksel	_mr_ir_receiver_command
	movf	_mr_ir_receiver_command, W
	call    screen_write_byte_as_hex
	incf	FSR, F
	movlw	'('
	call	screen_write_char
	banksel	_mr_ir_receiver_command_inverted
	movf	_mr_ir_receiver_command_inverted, W
	call	screen_write_byte_as_hex
	movlw	')'
	call	screen_write_char

	movlw	_mr_screen_buffer_line3
	movwf	FSR
	movlw	str_tests_err_cnt - STR_TESTS_BASE_ADDR
	call	screen_write_flash_2_buffer_tests_str
	banksel	_mr_ir_receiver_error_count
	movf	_mr_ir_receiver_error_count, W
	call    screen_write_byte_as_hex
	movlw	'('
	call	screen_write_char
	banksel	_mr_ir_receiver_state_on_err
	movf	_mr_ir_receiver_state_on_err, W
	call	screen_write_byte_as_hex
	movlw	':'
	call	screen_write_char
	banksel	_mr_ir_receiver_count_true_on_err
	movf	_mr_ir_receiver_count_true_on_err, W
	call	screen_write_byte_as_hex
	movlw	'/'
	call	screen_write_char
	banksel	_mr_ir_receiver_count_false_on_err
	movf	_mr_ir_receiver_count_false_on_err, W
	call	screen_write_byte_as_hex
	movlw	')'
	call	screen_write_char

	movlw	_mr_screen_buffer_line4
	movwf	FSR
	movlw	str_tests_cmd - STR_TESTS_BASE_ADDR
	call	screen_write_flash_2_buffer_tests_str
	banksel	_mr_ir_receiver_command_actual
	movf	_mr_ir_receiver_command_actual, W
	call    screen_write_byte_as_hex

	movlw	_mr_screen_buffer_line4 + 10
	movwf	FSR
	movlw	str_tests_fp_cmd - STR_TESTS_BASE_ADDR
	call	screen_write_flash_2_buffer_tests_str
	banksel	_mr_cmd_cur
	movf	_mr_cmd_cur, W
	call    screen_write_byte_as_hex

mode_testfp_test_ir_process_cmd
	banksel	_mr_cmd_cur
	movf	_mr_cmd_cur, W
	subwf	_mr_cmd_prev, W
	btfsc	STATUS, Z					; Check for a change of command state
		goto	mode_testfp_test_ir_exit
	movf	_mr_cmd_cur, W
	sublw	CMD_PAUSE
	btfsc	STATUS, Z
		call	mode_testfp_toggle_subtest_select
	movf	_mr_cmd_cur, W
	sublw	CMD_NONE
	btfss	STATUS, Z
		goto	mode_testfp_test_ir_exit
	movf	_mr_cmd_prev, W
	sublw	CMD_EJECT					; If the eject button was previously depressed
	btfss	STATUS, Z
		goto	mode_testfp_test_ir_exit
	movf	_mr_ir_receiver_address_lsb, W			; Update the IR receiver address, with previously received value
;////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	andlw	0xfe						; Fix the address for Avermedia remote
;////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	movwf	_mr_ir_receiver_address_lsb_actual
	movf	_mr_ir_receiver_address_msb, W			; Update the IR receiver address, with previously received value
;////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	andlw	0xfe						; Fix the address for Avermedia remote
;////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	movwf	_mr_ir_receiver_address_msb_actual
	movlw	(IR_RECVR_BASE_ADDR>>8)				; Select high address
	movwf	PCLATH						; For the next 'call'
	call	ir_receiver_save_receiver_addr			; Save address back to the EEPROM
	clrf	PCLATH

mode_testfp_test_ir_exit
	return

;***********************************************************************
; mode_testfp_test_pwr_cntrls
;
mode_testfp_test_pwr_cntrls
	call	screen_clear

	movlw	_mr_screen_buffer_line2 + 4
	movwf	FSR

	movlw	str_tests_not_avail - STR_TESTS_BASE_ADDR
	call	screen_write_flash_2_buffer_tests_str

	return

;***********************************************************************
; mode_testfp_test_i2c_master
;
mode_testfp_test_i2c_master
	call	i2c_master_init
	call	screen_clear

	movlw	_mr_screen_buffer_line1 + 2
	movwf	FSR
	movlw	'>'
	banksel	_mr_test_select
	btfsc	_mr_test_select, 0x6
		goto	mode_testfp_test_i2c_master_backlight
	btfss	_mr_test_select, 0x4
		call	screen_write_char
mode_testfp_test_i2c_master_backlight
	movlw	_mr_screen_buffer_line1 + 4
	movwf	FSR
	movlw	str_tests_backlight - STR_TESTS_BASE_ADDR
	call	screen_write_flash_2_buffer_tests_str

	movlw	_mr_screen_buffer_line1 + 16
	movwf	FSR
	movlw	'>'
	banksel	_mr_test_select
	btfss	_mr_test_select, 0x6
		goto	mode_testfp_test_i2c_master_backlight_value
	btfss	_mr_test_select, 0x4
		call	screen_write_char
mode_testfp_test_i2c_master_backlight_value
	movlw	_mr_screen_buffer_line1 + 17
	movwf	FSR
	call	i2c_master_ds1845_read_backlight
	banksel	_mr_i2c_buffer
	movf	_mr_i2c_buffer, W
	call	screen_write_byte_as_hex

	movlw	_mr_screen_buffer_line3 + 2
	movwf	FSR
	movlw	'>'
	banksel	_mr_test_select
	btfsc	_mr_test_select, 0x6
		goto	mode_testfp_test_i2c_master_contrast
	btfsc	_mr_test_select, 0x4
		call	screen_write_char
mode_testfp_test_i2c_master_contrast
	movlw	_mr_screen_buffer_line3 + 4
	movwf	FSR
	movlw	str_tests_contrast - STR_TESTS_BASE_ADDR
	call	screen_write_flash_2_buffer_tests_str

	movlw	_mr_screen_buffer_line3 + 16
	movwf	FSR
	movlw	'>'
	banksel	_mr_test_select
	btfss	_mr_test_select, 0x6
		goto	mode_testfp_test_i2c_master_contrast_value
	btfsc	_mr_test_select, 0x4
		call	screen_write_char
mode_testfp_test_i2c_master_contrast_value
	movlw	_mr_screen_buffer_line3 + 17
	movwf	FSR
	call	i2c_master_ds1845_read_contrast
	banksel	_mr_i2c_buffer
	movf	_mr_i2c_buffer, W
	call	screen_write_byte_as_hex

mode_testfp_test_i2c_master_process_cmd
	banksel	_mr_cmd_cur
	movf	_mr_cmd_cur, W
	subwf	_mr_cmd_prev, F
	btfsc	STATUS, Z				; Check for a change of command state
		goto	mode_testfp_test_i2c_master_exit
	btfsc	_mr_test_select, 0x6			; Test if the value is selected
		goto	mode_testfp_test_i2c_master_process_cmd_value
	sublw	CMD_UP
	btfsc	STATUS, Z				; Check for a up command
		call	mode_testfp_dec_selected_subtest
	movf	_mr_cmd_cur, W
	sublw	CMD_DOWN
	btfsc	STATUS, Z				; Check for a down command
		call	mode_testfp_inc_selected_subtest
	movf	_mr_cmd_cur, W
	goto	mode_testfp_test_i2c_master_process_cmd_select
mode_testfp_test_i2c_master_process_cmd_value
	sublw	CMD_UP
	btfsc	STATUS, Z				; Check for a up command
		call	mode_testfp_inc_selected_ds1845_value
	movf	_mr_cmd_cur, W
	sublw	CMD_DOWN
	btfsc	STATUS, Z				; Check for a down command
		call	mode_testfp_dec_selected_ds1845_value
	movf	_mr_cmd_cur, W
mode_testfp_test_i2c_master_process_cmd_select
	sublw	CMD_SELECT
	btfsc	STATUS, Z				; Check for a select command
		call	mode_testfp_toggle_subtest_select

mode_testfp_test_i2c_master_check
	banksel	_mr_test_select
	btfss	_mr_test_select, 0x5			; Check if we've gone too far
		goto	mode_testfp_test_i2c_master_exit
	bcf	_mr_test_select, 0x5			; Reset value
	bsf	_mr_test_select, 0x4

mode_testfp_test_i2c_master_exit
	return

;***********************************************************************
; mode_testfp_test_i2c_slave
;
mode_testfp_test_i2c_slave
	call	screen_clear

	movlw	_mr_screen_buffer_line2 + 4
	movwf	FSR

	movlw	str_tests_not_avail - STR_TESTS_BASE_ADDR
	call	screen_write_flash_2_buffer_tests_str

	return

;***********************************************************************
; Mode: Power Control
;***********************************************************************
mode_powercontrol_set
	banksel	_mr_mode_cur
	movlw	MODE_POWERCTRL
	movwf	_mr_mode_cur
	return

mode_powercontrol_init
	banksel	_mr_pwrctrl_select
	movlw	0x01
	movwf	_mr_pwrctrl_select

	banksel	_mr_screen_buffer_update
	bsf	_mr_screen_buffer_update, 0x1			; Disable screen updates from buffer

	call	LCD_PORT_CONFIGURE

	call	LCD_CLEAR_SCREEN				; Clear screen

	call	LCD_PORT_RESTORE

	banksel	_mr_mode_prev
	movlw	MODE_POWERCTRL
	movwf	_mr_mode_prev
	return

;***********************************************************************
; mode_powercontrol_update_display
;
; Updates the display to indicate the selected power control.
;
mode_powercontrol_update_display
	banksel	_mr_screen_buffer_update
	btfss	_mr_screen_buffer_update, 0x0			; Check if the lcd should be updated
		goto	mode_powercontrol_update_display_exit
	bcf	_mr_screen_buffer_update, 0x0

	call	LCD_PORT_CONFIGURE

; Shutdown
	movlw	(LCD_CMD_SET_DDRAM | SCR_ROW0 | SCR_COL0) + 3
	call	LCD_WRITE_CMD
	banksel	_mr_pwrctrl_select
	movlw	' '
	btfsc	_mr_pwrctrl_select, 0x0
		movlw	'>'
	call	LCD_WRITE_DATA
	movlw	' '
	call	LCD_WRITE_DATA
	movlw	eeprom_str_shutdown - 0x2100
	call	LCD_WRITE_EEPROM_2_BUFFER

; Reset
	movlw	(LCD_CMD_SET_DDRAM | SCR_ROW1 | SCR_COL0) + 3
	call	LCD_WRITE_CMD
	banksel	_mr_pwrctrl_select
	movlw	' '
	btfsc	_mr_pwrctrl_select, 0x1
		movlw	'>'
	call	LCD_WRITE_DATA
	movlw	' '
	call	LCD_WRITE_DATA
	movlw	eeprom_str_reset - 0x2100
	call	LCD_WRITE_EEPROM_2_BUFFER

; Power Off
	movlw	(LCD_CMD_SET_DDRAM | SCR_ROW2 | SCR_COL0) + 3
	call	LCD_WRITE_CMD
	banksel	_mr_pwrctrl_select
	movlw	' '
	btfsc	_mr_pwrctrl_select, 0x2
		movlw	'>'
	call	LCD_WRITE_DATA
	movlw	' '
	call	LCD_WRITE_DATA
	movlw	eeprom_str_poweroff - 0x2100
	call	LCD_WRITE_EEPROM_2_BUFFER

	call	LCD_PORT_RESTORE

mode_powercontrol_update_display_exit
	return

;***********************************************************************
; mode_powercontrol_inc_selected_pwrctrl
;
; Increments the selected power control
;
mode_powercontrol_inc_selected_pwrctrl
	bcf	STATUS, C
	rlf	_mr_pwrctrl_select, F
	btfss	_mr_pwrctrl_select, PWRCTRL_NUM_CONTROLS
		goto	mode_powercontrol_inc_selected_pwrctrl_exit
	movlw	(1<<(PWRCTRL_NUM_CONTROLS - 1))
	movwf	_mr_pwrctrl_select
mode_powercontrol_inc_selected_pwrctrl_exit
	return

;***********************************************************************
; mode_powercontrol_dec_selected_pwrctrl
;
; Decrements the selected power control
;
mode_powercontrol_dec_selected_pwrctrl
	bcf	STATUS, C
	rrf	_mr_pwrctrl_select, F
	btfss	STATUS, C
		goto	mode_powercontrol_dec_selected_pwrctrl_exit
	movlw	0x1
	movwf	_mr_pwrctrl_select
mode_powercontrol_dec_selected_pwrctrl_exit
	return

;***********************************************************************
; mode_powercontrol_back_2_poweron
;
; Restores mode to Power-On
;
mode_powercontrol_back_2_poweron
	banksel	_mr_mode_cur
	movlw	MODE_POWERON
	movwf	_mr_mode_cur					; Reset current mode, back to Power On
	movwf	_mr_mode_prev					; Updated to avoid the init routine

	banksel	_mr_screen_buffer_update
	bcf	_mr_screen_buffer_update, 0x1			; Enable screen updates

	return

;***********************************************************************
; mode_powercontrol_control_exec
;
; Runs the power control
;
mode_powercontrol_control_exec
	banksel	_mr_pwrctrl_select

mode_powercontrol_control_exec_shutdown
	btfss	_mr_pwrctrl_select, 0x0
		goto	mode_powercontrol_control_exec_reset
	call	ctrl_rpi_shutdown
	call	mode_powercontrol_back_2_poweron
	goto	mode_powercontrol_control_exec_exit

mode_powercontrol_control_exec_reset
	btfss	_mr_pwrctrl_select, 0x1
		goto	mode_powercontrol_control_exec_poweroff
	call	ctrl_rpi_reset
	call	mode_powercontrol_back_2_poweron
	goto	mode_powercontrol_control_exec_exit

mode_powercontrol_control_exec_poweroff
	btfss	_mr_pwrctrl_select, 0x2
		goto	mode_powercontrol_control_exec_exit
	call	mode_poweroff_set
	banksel	_mr_screen_buffer_update
	bcf	_mr_screen_buffer_update, 0x1			; Enable screen updates
	goto	mode_powercontrol_control_exec_exit

mode_powercontrol_control_exec_exit
	return

;***********************************************************************
; General routines
;***********************************************************************

;***********************************************************************
; Reset the i2c interface as a slave
set_mpu_as_i2c_slave
	clrf	PIR1						; Clear interrupt flag
	call	i2c_slave_init

	bsf	INTCON,PEIE 					; Enable all peripheral interrupts
	bsf	INTCON,GIE					; Enable global interrupts
	return

;***********************************************************************
; Set PSU state
set_psu_off
	banksel	PORTC
	bcf	PORTC, 0x00
	return

set_psu_on
	banksel	PORTC
	bsf	PORTC, 0x00
	return

;***********************************************************************
; Raspberry Pi controls
; Reset toggles the function of the control pin between input and output
; so as to allow the built in RC Power-On Reset system to function. So,
; to reset the pin is made an output (set low), then the pin is changed
; back to an input to provide a high impedance. This then allows the RC
; circuit to charge normally.
ctrl_rpi_reset
	banksel	PORTA
	bcf	PORTA, 0x05
	banksel	TRISA
	bcf	TRISA, 0x05
	nop							; NOPs should provide sufficient delay
	nop
	bsf	TRISA, 0x05
	return

; This routine signals to the RPi to shutdown by pulsing a particular
; GPIO. See dtoverlay: gpio-shutdown
;***********************************************************************
ctrl_rpi_shutdown
	banksel	PORTB
	bsf	PORTB, 0x07
	nop							; NOPs should provide sufficient delay
	nop
	bcf	PORTB, 0x07
	return

; Enables the external interrupt pin. This allows the RPi to signal a
; shutdown/halt. See dtoverlay: gpio-poweroff
;***********************************************************************
ctrl_rpi_shutdown_int_enable
	banksel	OPTION_REG
	bsf	OPTION_REG, INTEDG
	bsf	INTCON, INTE
	return

;***********************************************************************
; Set Power LED state
set_power_led_off
	banksel	PORTE
	bcf	PORTE, 0x2				; Extinguish 'power' LED
	return

set_power_led_on
	banksel	PORTE
	bsf	PORTE, 0x2				; Light 'power' LED
	return

set_power_led_toggle					; Used for indicating IR reception
	banksel	PORTE
	btfss	PORTE, 0x2
		goto	set_power_led_toggle_on
	bcf	PORTE, 0x2
	goto	set_power_led_toggle_exit
set_power_led_toggle_on
	bsf	PORTE, 0x2				; Light 'power' LED
set_power_led_toggle_exit
	return

;***********************************************************************
; Set Online LED state
set_online_led_off
	banksel	PORTC
	bcf	PORTC, 0x1				; Extinguish 'online' LED
	return

set_online_led_on
	banksel	PORTC
	bsf	PORTC, 0x1				; Light 'online' LED
	return

;***********************************************************************
; Saves the current backlight/contrast values to EEPROM, then clears
lcd_backlight_contrast_settings_save_then_clear
	banksel	_mr_i2c_buffer_index
	movlw	CONTRAST_ADDR			; Load the address of the contrast control
	movwf	_mr_i2c_buffer_index		; as it's first

	banksel	EEADR
	movlw	eeprom_lcd_contrast - 0x2100	; Load the address of the contrast value
	movwf	EEADR				; as it's first
	clrf	EEADRH

lcd_backlight_contrast_settings_save_then_clear_loop
	call	i2c_master_ds1845_read		; Read current value

	call	pic_eeprom_read			; Read stored value

	banksel	_mr_i2c_buffer
	subwf	_mr_i2c_buffer, W		; Test stored value against current value
	btfsc	STATUS, Z
		goto	lcd_backlight_contrast_settings_save_then_clear_next

	movf	_mr_i2c_buffer, W
	banksel	EEDATA
	movwf	EEDATA
	decf	EEADR, F			; This was previously incremented, need the old value

	call	pic_eeprom_write_finish_wait

	call    pic_eeprom_write

lcd_backlight_contrast_settings_save_then_clear_next
	banksel	_mr_i2c_buffer_index
	incf	_mr_i2c_buffer_index, F		; Increment the control address

	movf	_mr_i2c_buffer_index, W
	sublw	BACKLIGHT_ADDR			; Subtract the address of the backlight value
	btfsc	STATUS, Z			; Loop if we still have the backlight to do
		goto	lcd_backlight_contrast_settings_save_then_clear_loop

	movlw	BACKLIGHT_ADDR
	movwf	_mr_i2c_buffer_index
	clrf	_mr_i2c_buffer
	call	i2c_master_ds1845_write		; Turn off LCD backlight

	return

;***********************************************************************
; Restores the current backlight/contrast values from EEPROM
lcd_backlight_contrast_settings_restore
	banksel	_mr_i2c_buffer_index
	movlw	CONTRAST_ADDR			; Load the address of the contrast control
	movwf	_mr_i2c_buffer_index		; as it's first

	banksel	EEADR
	movlw	eeprom_lcd_contrast - 0x2100	; Load the address of the contrast value
	movwf	EEADR				; as it's first
	clrf	EEADRH

lcd_backlight_contrast_settings_restore_loop
	call	pic_eeprom_read

	banksel	_mr_i2c_buffer
	movwf	_mr_i2c_buffer			; Save the data for writing
	call	i2c_master_ds1845_write		; Write the data to the control
	banksel	_mr_i2c_buffer_index
	incf	_mr_i2c_buffer_index, F		; Increment the control address

	movf	_mr_i2c_buffer_index, W
	sublw	BACKLIGHT_ADDR			; Subtract the address of the backlight value
	btfsc	STATUS, Z			; Loop if we still have the backlight to do
		goto	lcd_backlight_contrast_settings_restore_loop

	return

;***********************************************************************
; Draws a border to the screen buffer
screen_draw_border
	movlw	_mr_screen_buffer_line1
	movwf	FSR

	movlw	str_panel_border_full - STR_PANEL_BASE_ADDR
	call	screen_write_flash_2_buffer_panel_str

	movlw	str_panel_border_edges - STR_PANEL_BASE_ADDR
	call	screen_write_flash_2_buffer_panel_str

	movlw	str_panel_border_edges - STR_PANEL_BASE_ADDR
	call	screen_write_flash_2_buffer_panel_str

	movlw	str_panel_border_full - STR_PANEL_BASE_ADDR
	call	screen_write_flash_2_buffer_panel_str

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
	movlw	0xCF
	movwf	TRISA					; Configure PORTA (Inputs: 0,1,2,3,6,7 | Outputs: 4,5)

;	movlw	0xF7
;	movwf	TRISB					; Configure PORTB (Inputs: 0,1,2,4,5,6,7 | Outputs: 3)
	movlw	0x77
	movwf	TRISB					; Configure PORTB (Inputs: 0,1,2,4,5,6 | Outputs: 3,7)

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
	movlw	(IR_RECVR_BASE_ADDR>>8)			; Select high address
	movwf	PCLATH					; For the next 'call'
	call	ir_receiver_timer_init			; Setup timer to sample IR receiver input
	clrf	PCLATH

	call	set_online_led_on			; Turn on 'online' LED (This shows MPU initialised)

	movlw	0x32
	movwf	_mr_temp				; Setup loop counter
init_mpu_led_loop
	clrwdt
	call	waste_time
	decfsz	_mr_temp, F
		goto	init_mpu_led_loop

	call	set_online_led_off			; Turn off 'online' LED

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
	clrf	_mr_pwrctrl_select				; Power control, selected shutdown method

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
	movlw	eeprom_ir_addr_lsb - 0x2100			; Get the IR receiver address
	movwf	EEADR
	clrf	EEADRH
	call	pic_eeprom_read
	banksel	_mr_ir_receiver_address_lsb_actual
	movwf	_mr_ir_receiver_address_lsb_actual
	call	pic_eeprom_read
	banksel	_mr_ir_receiver_address_msb_actual
	movwf	_mr_ir_receiver_address_msb_actual

	return

;***********************************************************************
; Initialise Hardware
init_board
	clrwdt

	call	LCD_INITIALIZE

	call	i2c_master_init

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
	include	"pic_eeprom.asm"
	include	"screen.asm"
	include "commands.asm"

	include	"ir_receiver.asm"			; This has a fixed location so needs to be loaded last
	include	"strings.asm"				; This has a fixed location, so needs to be loaded last
	include	"jmp_tables.asm"			; This has a table at a fixed location, so needs to be loaded last

;***********************************************************************
;***********************************************************************
; EEPROM
;***********************************************************************
;***********************************************************************
.eedata	org	0x2100
;eeprom_lcd_contrast	de	0x00
eeprom_lcd_contrast	de	0x5d
eeprom_lcd_backlight	de	0x3f
eeprom_ir_addr_lsb	de	0x24
eeprom_ir_addr_msb	de	0x42
eeprom_str_poweroff	de	"Power Off\0"
eeprom_str_reset	de	"Hard Reset\0"
eeprom_str_shutdown	de	"Shutdown\0"

        END
