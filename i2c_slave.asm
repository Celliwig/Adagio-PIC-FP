;---------------------------------------------------------------------
; Initializes program variables and peripheral registers.
;---------------------------------------------------------------------
i2c_slave_init
	banksel	TRISC
	bsf     TRISC, 0x03						; Set the ports as inputs
	bsf     TRISC, 0x04

	movlw   NODE_ADDR						; Set slave address
	movwf   SSPADD

	clrf    SSPSTAT
	bsf     SSPSTAT, 0x07						; Slew rate control disabled for standard speed mode (100 kHz and 1 MHz)

	bsf     PIE1,SSPIE						; Enable SSP interrupt

	banksel	PIR1
	bcf	PIR1, SSPIF						; Clear SSP interrupt

	clrf	SSPCON							; Disable SSP to force reinitialisation
	movlw   0x36							; Setup SSP module for 7-bit address, slave mode
	movwf   SSPCON

	clrf	_mr_i2c_state						; Reset state
	clrf	_mr_i2c_rx_count					; Reset counters
	clrf	_mr_i2c_tx_count
	clrf	_mr_i2c_err_count

	return

;-----------------------------------------------------------------------------------------------
; i2c slave toggles the CKP bit (used for testing)
;-----------------------------------------------------------------------------------------------
i2c_slave_toggle_clock_stretch
	banksel	SSPCON
	btfsc	SSPCON, CKP
		goto	i2c_slave_toggle_clock_stretch_low
	bsf	SSPCON, CKP
	goto	i2c_slave_toggle_clock_stretch_exit
i2c_slave_toggle_clock_stretch_low
	bcf	SSPCON, CKP
i2c_slave_toggle_clock_stretch_exit
	return

;-----------------------------------------------------------------------------------------------
; i2c slave Interrupt Service Routine (ISR)
;-----------------------------------------------------------------------------------------------
i2c_slave_ssp_handler
	banksel	PIR1
	bcf 	PIR1, SSPIF						; clear the SSP interrupt flag

	banksel	SSPSTAT
	btfsc	SSPSTAT, 5						; was last byte an address or data?
		goto	i2c_slave_ssp_handler_active

	clrw
	btfsc	SSPSTAT, 2						; Is this a read
		iorlw	(1<<I2C_SLAVE_STATE_BIT_READ_NOT_WRITE)		; Set the flag
	banksel	_mr_i2c_state
	movwf	_mr_i2c_state

i2c_slave_ssp_handler_active
	banksel	_mr_i2c_state
	btfsc	_mr_i2c_state, I2C_SLAVE_STATE_BIT_READ_NOT_WRITE
		goto	i2c_slave_ssp_handler_master_read
	goto	i2c_slave_ssp_handler_master_write

;-----------------------------------------------------------------------------------------------
; i2c slave (Master read)
;-----------------------------------------------------------------------------------------------
i2c_slave_ssp_handler_master_read
	banksel	SSPSTAT
	btfss	SSPSTAT, 2						; Check for an NACK (end of comms)
		goto	i2c_slave_ssp_handler_master_read_exit

	banksel	_mr_i2c_state
	bsf	_mr_i2c_state, I2C_SLAVE_STATE_BIT_DATA_NOT_ADDRESS
	incf	_mr_i2c_tx_count, F

	movf	_mr_cmd_cur, W						; move command value into W to

	movwf	SSPBUF							; load SSP buffer
	btfsc	SSPCON, WCOL						; did a write collision occur?
	        call    i2c_slave_ssp_handler_master_write_coll		; if so, go clear bit

i2c_slave_ssp_handler_master_read_exit
	banksel	SSPCON
	bsf	SSPCON, CKP						; release clock stretch

	btfsc	SSPCON, CKP						; Test the clock stretch bit (should already be set)
		return

	bcf	SSPCON, SSPEN						; The hardware has locked up
	bsf	SSPCON, SSPEN						; So reset it
	bsf	SSPCON, CKP
	clrf	_mr_i2c_state						; Reset state
	incf	_mr_i2c_err_count, F
	return

;-----------------------------------------------------------------------------------------------
; i2c slave (Master write)
;-----------------------------------------------------------------------------------------------
i2c_slave_ssp_handler_master_write
	btfss	_mr_i2c_state, I2C_SLAVE_STATE_BIT_DATA_NOT_ADDRESS	; was last byte an address or data?
		goto	i2c_slave_ssp_handler_master_write_address	; if clear, it was an address
	goto	i2c_slave_ssp_handler_master_write_data			; if set, it was data

i2c_slave_ssp_handler_master_write_address
	movf	SSPBUF, W						; dummy read to clear the BF bit
	bsf	_mr_i2c_state, I2C_SLAVE_STATE_BIT_DATA_NOT_ADDRESS

	clrf	_mr_i2c_cmd_status
	bsf	_mr_i2c_cmd_status, FP_CMD_STATUS_BIT_LOADING		; Set the command status flag, so we don't try to process until it's complete
	clrf	_mr_i2c_cmd_size
	movlw	_mr_i2c_buffer
	movwf	_mr_i2c_buffer_index					; Reset buffer pointer
	return

i2c_slave_ssp_handler_master_write_data
	incf	_mr_i2c_rx_count, F

	btfsc	_mr_i2c_state, I2C_SLAVE_STATE_BIT_SAVED_CMD_SIZE	; Check if the command size is set
		goto	i2c_slave_ssp_handler_master_write_data_save

	bsf	_mr_i2c_state, I2C_SLAVE_STATE_BIT_SAVED_CMD_SIZE	; Set flag
	movf	SSPBUF, W						; Get the byte from the SSP.
	btfsc	STATUS, Z						; Make sure cmd size is not zero
		movlw	0x1						; Otherwise this will cause a buffer overflow
	movwf	_mr_i2c_cmd_size					; Save the command size
	sublw	RX_BUF_LEN						; Check the command size
	btfsc	STATUS, C
		return
	movlw	RX_BUF_LEN
	movwf	_mr_i2c_cmd_size					; Reset the payload size to the buffer size
	return

i2c_slave_ssp_handler_master_write_data_save
	movf	_mr_i2c_buffer_index, W					; Get the i2c buffer index
	movwf	FSR							; Update FSR with it
	movf	SSPBUF, W						; Move the contents of the buffer into W
	movwf 	INDF							; Write it to INDF

	decf	_mr_i2c_cmd_size, W					; Calculate buffer end (from cmd size)
	addlw	_mr_i2c_buffer
	subwf	_mr_i2c_buffer_index, W
	btfsc	STATUS, Z
		bsf	_mr_i2c_cmd_status, FP_CMD_STATUS_BIT_LOADED	; Set the status flag, so we can process data
	btfss	STATUS, Z
		incf	_mr_i2c_buffer_index, F				; Increment i2c buffer index
	return

;---------------------------------------------------------------------
; Clear a write collision
;---------------------------------------------------------------------
i2c_slave_ssp_handler_master_write_coll
	bcf	SSPCON, WCOL						; clear WCOL bit
	movf	SSPBUF, W						; move SSP buffer to W
									; dummy read to clear the BF bit
	return

;---------------------------------------------------------------------
; Clear an overflow condition
;---------------------------------------------------------------------
i2c_slave_clear_overflow
	banksel	SSPCON
	btfss	SSPCON, SSPOV						; Has an overflow occured
		call	i2c_slave_clear_overflow_exit			; if so, clear it

	movf	SSPBUF, W						; move SSP buffer to W
									; dummy read to clear the BF bit
	bcf	SSPCON, SSPOV						; clear overflow flag

	bcf	PIR1, SSPIF						; clear the SSP interrupt flag

i2c_slave_clear_overflow_exit
	return
