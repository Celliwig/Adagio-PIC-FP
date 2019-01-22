;***********************************************************************
; Convert button buffer to command value
;***********************************************************************
buttons_2_command
	banksel	_mr_button_bank
	movf	_mr_cmd_cur, W					; Load current command, as this module follows the
								; IR receiver, which will clear this register otherwise

	movf	_mr_button_bank, F				; Test if this bank has depressed switches
	btfsc	STATUS, Z
		goto	buttons_2_command_1			; If not, skip tests
	btfsc	_mr_button_bank, BUTTON_BIT_RB1_PREV
	movlw	CMD_PREVIOUS
	btfsc	_mr_button_bank, BUTTON_BIT_RB1_DSP4
	movlw	CMD_DSPSEL4
	btfsc	_mr_button_bank, BUTTON_BIT_RB1_DSP3
	movlw	CMD_DSPSEL3
	btfsc	_mr_button_bank, BUTTON_BIT_RB1_MODE
	movlw	CMD_MODE
	btfsc	_mr_button_bank, BUTTON_BIT_RB1_NEXT
	movlw	CMD_NEXT
	btfsc	_mr_button_bank, BUTTON_BIT_RB1_STOP
	movlw	CMD_STOP
	btfsc	_mr_button_bank, BUTTON_BIT_RB1_DSP1
	movlw	CMD_DSPSEL1
	btfsc	_mr_button_bank, BUTTON_BIT_RB1_EJCT
	movlw	CMD_EJECT

buttons_2_command_1
	movf	(_mr_button_bank + 1), F			; Test if this bank has depressed switches
	btfsc	STATUS, Z
		goto	buttons_2_command_2			; If not, skip tests
	btfsc	(_mr_button_bank + 1), BUTTON_BIT_RB2_RGHT
	movlw	CMD_RIGHT
	btfsc	(_mr_button_bank + 1), BUTTON_BIT_RB2_UP
	movlw	CMD_UP

buttons_2_command_2
	movf	(_mr_button_bank + 2), F			; Test if this bank has depressed switches
	btfsc	STATUS, Z
		goto	buttons_2_command_exit			; If not, skip tests
	btfsc	(_mr_button_bank + 2), BUTTON_BIT_RC2_PWR
	movlw	CMD_POWER
	btfsc	(_mr_button_bank + 2), BUTTON_BIT_RC2_PLAY
	movlw	CMD_PLAY
	btfsc	(_mr_button_bank + 2), BUTTON_BIT_RC2_LEFT
	movlw	CMD_LEFT
	btfsc	(_mr_button_bank + 2), BUTTON_BIT_RC2_CDHD
	movlw	CMD_CDHD
	btfsc	(_mr_button_bank + 2), BUTTON_BIT_RC2_DSP2
	movlw	CMD_DSPSEL2
	btfsc	(_mr_button_bank + 2), BUTTON_BIT_RC2_DOWN
	movlw	CMD_DOWN
	btfsc	(_mr_button_bank + 2), BUTTON_BIT_RC2_SLCT
	movlw	CMD_SELECT
	btfsc	(_mr_button_bank + 2), BUTTON_BIT_RC2_PAUS
	movlw	CMD_PAUSE

; Check for test mode
	btfss	(_mr_button_bank + 2), BUTTON_BIT_RC2_PWR
		goto	buttons_2_command_exit
	btfss	(_mr_button_bank + 2), BUTTON_BIT_RC2_PLAY
		goto	buttons_2_command_exit
	movlw	CMD_TESTMODE

buttons_2_command_exit
	movwf	_mr_cmd_cur
	return
