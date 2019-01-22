;-----------------------------------------------------------------------------------------------
; The macro LOADFSR loads FSR1 with the I2C address and the I2C index value to read or write to
; and makes code easier to read.
;------------------------------------- LOADFSR macro -------------------------------------------

LOADFSR macro 	ADDRESS, INDEX 					; ADDRESS = I2C_ARRAY, INDEX = _mr_i2c_buffer_index
		movlw 	ADDRESS 				; load address
		addwf	INDEX, W				; add the index value to determine location in array
		movwf 	FSR					; load FSR1L with pointer info
		endm

;---------------------------------------------------------------------
; Initializes program variables and peripheral registers.
;---------------------------------------------------------------------
i2c_slave_init
	bsf	STATUS, RP0
	bcf	STATUS, RP1

	bsf     TRISC, 0x03
	bsf     TRISC, 0x04
	movlw   NODE_ADDR
	movwf   SSPADD
	clrf    SSPSTAT
	bsf     SSPSTAT, 0x07					; Slew rate control disabled for standard speed mode (100 kHz and 1 MHz)
	bsf     PIE1,SSPIE

	bcf	STATUS, RP0
	bcf	STATUS, RP1

	movlw   0x36						; Setup SSP module for 7-bit
	movwf   SSPCON						; address, slave mode

	return

;-----------------------------------------------------------------------------------------------
; i2c slave Interrupt Service Routine (ISR)
;-----------------------------------------------------------------------------------------------
i2c_slave_ssp_handler
	bcf	STATUS, RP0
	bcf	STATUS, RP1
	btfss 	PIR1, SSPIF 					; Is this a SSP interrupt?
		goto 	i2c_slave_ssp_handler_bus_coll 		; if not, bus collision int occurred (does this occur in slave mode?)
	bsf	STATUS, RP0
	btfsc	SSPSTAT, 2					; is it a master read:
		goto	i2c_slave_ssp_handler_read		; if so go here
	goto	i2c_slave_ssp_handler_write			; if not, go here

i2c_slave_ssp_handler_read
	btfss	SSPSTAT, 5					; was last byte an address or data?
	goto	i2c_slave_ssp_handler_read_address		; if clear, it was an address
	goto	i2c_slave_ssp_handler_read_data			; if set, it was data

i2c_slave_ssp_handler_read_address
	bcf	STATUS, RP0
	bcf	STATUS, RP1

        movfw   SSPBUF						; Get the buffer data (clear BF)
        clrf    _mr_i2c_buffer_index
        clrf	W                           			; clear W
	movlw	0x03						; load array elements value (size of button bank)
	btfsc	STATUS, Z					; is Z clear?
		subwf	_mr_i2c_buffer_index,W			; if Z = 1, subtract index from number of elements
	btfsc	STATUS, C					; did a carry occur after subtraction?
		goto	i2c_slave_ssp_handler_read_data_reset	; if so, Master is trying to read too many bytes, so reset
	LOADFSR	_mr_button_bank, _mr_i2c_buffer_index		; call LOADFSR macro
	movf	INDF, W						; move value into W to load to SSP buffer
	movwf	SSPBUF						; load SSP buffer
	btfsc	SSPCON, WCOL					; did a write collision occur?
	        call    i2c_slave_ssp_handler_write_coll	; if so, go clear bit
        LOADFSR	_mr_button_bank, _mr_i2c_buffer_index		; call LOADFSR macro
        movlw   I2C_CHAR_CLEAR					; load I2C_CHAR_CLEAR into W
        movwf   INDF						; load W into array
	incf	_mr_i2c_buffer_index, F				; increment _mr_i2c_buffer_index 'pointer'
	bsf	SSPCON, CKP					; release clock stretch
	bcf 	PIR1, SSPIF					; clear the SSP interrupt flag
	goto    i2c_slave_ssp_handler_exit 			; Go to i2c_slave_ssp_handler_exit to return from interrupt

i2c_slave_ssp_handler_read_data
	bcf	STATUS, RP0
	bcf	STATUS, RP1

	clrf	W       					; clear W
	movlw	0x03						; load array elements value
	btfsc	STATUS, Z					; is Z clear?
		subwf	_mr_i2c_buffer_index, W			; if Z = 1, subtract index from number of elements
	btfsc	STATUS, C					; did a carry occur after subtraction?
		goto	i2c_slave_ssp_handler_read_data_reset	; if so, Master is trying to read too many bytes, so reset
	LOADFSR	_mr_button_bank, _mr_i2c_buffer_index		; call LOADFSR macro
	movf	INDF, W						; move value into W to load to SSP buffer
	movwf	SSPBUF						; load SSP buffer
	btfsc	SSPCON, WCOL					; did a write collision occur?
	        call    i2c_slave_ssp_handler_write_coll	; if so, go clear bit
        LOADFSR	_mr_button_bank, _mr_i2c_buffer_index		; call LOADFSR macro
        movlw   I2C_CHAR_CLEAR					; load I2C_CHAR_CLEAR into W
        movwf   INDF						; load W into array
	incf	_mr_i2c_buffer_index, F				; increment _mr_i2c_buffer_index 'pointer'
	bsf	SSPCON, CKP					; release clock stretch
	bcf 	PIR1, SSPIF					; clear the SSP interrupt flag
	goto    i2c_slave_ssp_handler_exit 			; Go to i2c_slave_ssp_handler_exit to return from interrupt

i2c_slave_ssp_handler_read_data_reset
	clrf	_mr_i2c_buffer_index
	goto	i2c_slave_ssp_handler_read_data

i2c_slave_ssp_handler_write
	btfss	SSPSTAT, 5					; was last byte an address or data?
		goto	i2c_slave_ssp_handler_write_address	; if clear, it was an address
	goto	i2c_slave_ssp_handler_write_data		; if set, it was data

i2c_slave_ssp_handler_write_address
	bcf	STATUS, RP0
	bcf	STATUS, RP1

	clrf	_mr_i2c_cmd_status
	bsf	_mr_i2c_cmd_status, FP_CMD_STATUS_LOADING	; Set the command status flag, so we don't try to process until it's complete
	clrf	_mr_i2c_cmd_size
	clrf	_mr_i2c_buffer_index				; Clear the buffer _mr_i2c_buffer_index.

	movfw	SSPBUF						; move the contents of the buffer into W
								; dummy read to clear the BF bit
	bsf	SSPCON, CKP					; release clock stretch
	bcf 	PIR1, SSPIF					; clear the SSP interrupt flag
	goto    i2c_slave_ssp_handler_exit 			; Go to i2c_slave_ssp_handler_exit to return from interrupt

i2c_slave_ssp_handler_write_data
	bcf	STATUS, RP0
	bcf	STATUS, RP1

        clrf	W						; clear W
	movf    _mr_i2c_cmd_size, F				; Have we loaded in the payload size yet
	btfss   STATUS, Z
		GOTO i2c_slave_ssp_handler_write_data_save_data
	movf    SSPBUF, W					; Get the byte from the SSP.
	movwf   _mr_i2c_cmd_size				; Set the payload size
	sublw	RX_BUF_LEN					; Check the payload size is not larger than the buffer
	btfsc	STATUS, C
		goto	i2c_slave_ssp_handler_write_data_release
	movlw	RX_BUF_LEN					; If it is,
	movwf	_mr_i2c_cmd_size				; Reset the payload size to the buffer size
	goto	i2c_slave_ssp_handler_write_data_release
i2c_slave_ssp_handler_write_data_save_data
	movf	_mr_i2c_cmd_size, W				; load payload size
	btfsc	STATUS, Z					; is Z clear?
		goto	i2c_slave_ssp_handler_no_mem_overwrite	; if so, Master is trying to write to many bytes
	subwf	_mr_i2c_buffer_index, W				; if Z = 0, subtract index from number of elements
	btfsc	STATUS, C					; did a carry occur after subtraction?
		goto	i2c_slave_ssp_handler_no_mem_overwrite	; if so, Master is trying to write to many bytes
	LOADFSR	_mr_i2c_buffer, _mr_i2c_buffer_index		; call LOADFSR macro
	movfw	SSPBUF						; move the contents of the buffer into W
	movwf 	INDF						; load INDF with data to write
	incf	_mr_i2c_buffer_index, F				; increment _mr_i2c_buffer_index 'pointer'
	movf	_mr_i2c_buffer_index, W				; Get the current buffer _mr_i2c_buffer_index.
	subwf	_mr_i2c_cmd_size, W
        btfsc	STATUS, Z
		bsf	_mr_i2c_cmd_status, FP_CMD_STATUS_LOADED	; Set the status flag, so we ignore any more data
i2c_slave_ssp_handler_write_data_release
	btfsc	SSPCON, WCOL					; did a write collision occur?
		call    i2c_slave_ssp_handler_write_coll	; if so, go clear bit
	bsf	SSPCON, CKP					; release clock stretch
	bcf 	PIR1, SSPIF					; clear the SSP interrupt flag
	goto    i2c_slave_ssp_handler_exit 			; Go to i2c_slave_ssp_handler_exit to return from interrupt

i2c_slave_ssp_handler_no_mem_overwrite
	movfw	SSPBUF						; move SSP buffer to W
                    						; clear buffer so no overwrite occurs
	bsf	SSPCON, CKP					; release clock stretch
	bcf 	PIR1, SSPIF					; clear the SSP interrupt flag
	goto    i2c_slave_ssp_handler_exit 			; Go to i2c_slave_ssp_handler_exit to return from interrupt

i2c_slave_ssp_handler_write_coll
	bcf	SSPCON, WCOL					; clear WCOL bit
	movfw	SSPBUF						; move SSP buffer to W
                    						; dummy read to clear the BF bit
        return

i2c_slave_ssp_handler_bus_coll
	movfw	SSPBUF						; move SSP buffer to W
                    						; dummy read to clear the BF bit
	bcf	PIR2, BCLIF					; clear the SSP interrupt flag
	bsf	SSPCON, CKP					; release clock stretch
	goto    i2c_slave_ssp_handler_exit			; Go to i2c_slave_ssp_handler_exit to return from interrupt

i2c_slave_ssp_handler_exit
	return

i2c_slave_clear_overflow
	bcf	STATUS, RP0
	bcf	STATUS, RP1

	btfss	SSPCON, SSPOV					; Has an overflow occured
		call	i2c_slave_clear_overflow_exit		; if so, clear it

	movfw	SSPBUF						; move SSP buffer to W
                    						; dummy read to clear the BF bit
	bcf	SSPCON, SSPOV					; clear overflow flag

	bcf	PIR1, SSPIF					; clear the SSP interrupt flag

i2c_slave_clear_overflow_exit
	return
