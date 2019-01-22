;***********************************************************************
; i2c master functions
;***********************************************************************

i2c_master_init
	banksel	SSPCON2
	clrf	SSPCON2						; GCEN<7> General Call address, disabled
								; ACKSTAT<6> Acknowledge received, cleared
								; ACKDT<5> Acknowledge Data, cleared
								; ACKEN<4> Initiate Acknowledge sequence, idle
								; RCEN<3> Receive Enable bit, idle
								; PEN<2> STOP Condition Enable bit, idle
								; RSEN<1> Repeated START Condition Enable bit, idle
								; SEN<0> START Condition Enable bit, idle

	clrf	SSPSTAT						; SMP<7> Slew rate control enabled for high speed mode
								; CKE<6> Data transmitted on rising edge of SCK
								; D/A<5> Data/Address bit, cleared
								; P<4> STOP bit, cleared
								; S<3> START bit, cleared
								; R/W<2> Transmit in progress bit, cleared
								; UA<1> Update Address bit, cleared
								; BF<0> Buffer Full Status bit, cleared

	movlw	0x01
	movwf	SSPADD						; 500kHz clock

	bcf	PIE1,SSPIE					; Disable i2c interrupts

	banksel	SSPCON
	movlw	0x28
	movwf	SSPCON						; WCOL<7> Write Collision Detect bit, cleared
								; SSPOV<6> SSP Overflow bit, cleared
								; SSPEN<5> I2c mode enabled
								; CKP<4> Unused
								; SSPM<3-0> I 2 C Master mode, clock = F OSC / (4 * (SSPADD+1))

	call	i2c_master_start
	call	i2c_master_stop

	return

; i2c Initiate START condition
;***********************************************************************
i2c_master_start
	banksel	SSPCON2
	bsf	SSPCON2, SEN					; Set START condition bit
i2c_master_start_loop
	btfsc	SSPCON2, SEN					; Loop until it's cleared
		goto	i2c_master_start_loop
	return

; i2c Initiate Repeated START condition
;***********************************************************************
i2c_master_restart
	banksel	SSPCON2
	bsf	SSPCON2, RSEN
i2c_master_restart_loop
	btfsc	SSPCON2, RSEN					; Loop until it's cleared
		goto	i2c_master_restart_loop
	return

; i2c Initiate STOP condition
;***********************************************************************
i2c_master_stop
	banksel	SSPCON2
	bsf	SSPCON2, PEN
i2c_master_stop_loop
	btfsc	SSPCON2, PEN					; Loop until it's cleared
		goto	i2c_master_stop_loop
	return

; i2c ACK/NACK seq
;***********************************************************************
i2c_master_ack_seq
	banksel	SSPCON2
	bcf	SSPCON2, ACKDT
	goto	i2c_master_ack_nack_seq
i2c_master_nack_seq
	banksel	SSPCON2
	bsf	SSPCON2, ACKDT
i2c_master_ack_nack_seq
	bsf	SSPCON2, ACKEN
i2c_master_ack_seq_loop
	btfsc	SSPCON2, ACKEN					; Loop until it's cleared
		goto	i2c_master_ack_seq_loop
	return

; i2c Read: byte received saved in W
;***********************************************************************
i2c_master_read
	banksel	SSPCON2
	bsf	SSPCON2, RCEN
i2c_master_read_loop
	btfsc	SSPCON2, RCEN					; Loop until it's cleared
		goto	i2c_master_read_loop
	banksel	SSPBUF
	movf	SSPBUF, W
	return

; i2c write
; 0xa4 -> Write Access U8 DS1845
; 0xa5 -> Read Access U8 DS1845
;***********************************************************************
i2c_master_write_ds1845_write
	movlw	(DS1845_ADDR<<1)				; Write address for U8 DS1845 (Backlight and contrast control)
	goto	i2c_master_write
i2c_master_write_ds1845_read
	movlw	(DS1845_ADDR<<1) + 1 				; Read address for U8 DS1845 (Backlight and contrast control)
	goto	i2c_master_write
i2c_master_write
	banksel	SSPBUF
	movwf	SSPBUF						; Set data to write
	banksel	SSPCON2
	bcf	SSPCON2, ACKSTAT				; Clear ACKSTAT
i2c_master_write_l1
	btfsc	SSPSTAT, R_W					; Check for write completion
		goto	i2c_master_write_l1
	banksel	_mr_loop1
	movlw	0x32
	movwf	_mr_loop1					; Setup loop counter
	movlw	0x00
	movwf	_mr_loop2					; Setup loop counter
i2c_master_write_l3
	clrwdt
i2c_master_write_l2
	banksel	SSPCON2
	btfss	SSPCON2, ACKSTAT
		goto	i2c_master_write_ack_received
	banksel	_mr_loop2
	decfsz	_mr_loop2, 0x1
		goto	i2c_master_write_l2
	decfsz	_mr_loop1, 0x1
		goto	i2c_master_write_l3
	bcf	STATUS, C					; Timed out waiting for ACK
	return
i2c_master_write_ack_received
	bsf	STATUS, C
	return

; i2c read from U8 DS1845
;	_mr_i2c_buffer_index - Address to read
;	_mr_i2c_buffer[0] - Returned data
; Wiper0 -> LCD Backlight -> F9
; Wiper1 -> LCD Contrast -> F8
;***********************************************************************
i2c_master_ds1845_read_backlight
	banksel	_mr_i2c_buffer_index
	movlw	BACKLIGHT_ADDR
	movwf	_mr_i2c_buffer_index
	goto	i2c_master_ds1845_read
i2c_master_ds1845_read_contrast
	banksel	_mr_i2c_buffer_index
	movlw	CONTRAST_ADDR
	movwf	_mr_i2c_buffer_index
	goto	i2c_master_ds1845_read

i2c_master_ds1845_read
	banksel	_mr_i2c_temp
	movlw	0x03						; Setup a retry of 3
	movwf	_mr_i2c_temp

i2c_master_ds1845_read_loop
	call	i2c_master_stop
	call	i2c_master_start
	call	i2c_master_write_ds1845_write			; 'Fake' write to set address
	btfsc	STATUS, C					; Did we receive an ACK
		goto	i2c_master_ds1845_read_data
	banksel	_mr_i2c_temp
	decfsz	_mr_i2c_temp, F
		goto	i2c_master_ds1845_read_loop
	return							; Failed
i2c_master_ds1845_read_data
	banksel	_mr_i2c_buffer_index
	movf	_mr_i2c_buffer_index, W
	call	i2c_master_write				; Write address

	call	i2c_master_restart				; Restart
	call	i2c_master_write_ds1845_read			; As a read
	call	i2c_master_read					; Read data
	banksel	_mr_i2c_buffer
	movwf	_mr_i2c_buffer
	call	i2c_master_stop
	return

; i2c write to U8 DS1845
;	_mr_i2c_buffer_index - Address to write
;	_mr_i2c_buffer[0] - Data to write
; Wiper0 -> LCD Backlight -> F9
; Wiper1 -> LCD Contrast -> F8
;***********************************************************************
i2c_master_ds1845_write_backlight
	banksel	_mr_i2c_buffer
	movwf	_mr_i2c_buffer
	movlw	BACKLIGHT_ADDR
	movwf	_mr_i2c_buffer_index
	goto	i2c_master_ds1845_write
i2c_master_ds1845_write_contrast
	banksel	_mr_i2c_buffer
	movwf	_mr_i2c_buffer
	movlw	CONTRAST_ADDR
	movwf	_mr_i2c_buffer_index
	goto	i2c_master_ds1845_write

i2c_master_ds1845_write
	banksel	_mr_i2c_temp
	movlw	0x03						; Setup a retry of 3
	movwf	_mr_i2c_temp
i2c_master_ds1845_write_loop
	clrwdt

	call	i2c_master_stop
	call	i2c_master_start
	call	i2c_master_write_ds1845_write
	btfsc	STATUS, C					; Did we receive an ACK
		goto	i2c_master_ds1845_write_data
	decfsz	_mr_i2c_temp, F
		goto	i2c_master_ds1845_write_loop
	return							; Failed
i2c_master_ds1845_write_data
	banksel	_mr_i2c_buffer_index
	movf	_mr_i2c_buffer_index, W
	call	i2c_master_write
	banksel	_mr_i2c_buffer
	movf	_mr_i2c_buffer, W
	call	i2c_master_write
	call	i2c_master_stop
	return
