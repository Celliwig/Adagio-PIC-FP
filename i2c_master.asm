;***********************************************************************
; i2c functions
;***********************************************************************

;---------------------------------------------------------------------
; MASTER
;---------------------------------------------------------------------
i2c_master_init
        MOVLW   0x00
        MOVWF   SSPCON2
        MOVWF   SSPSTAT
        MOVLW   0x01
        MOVWF   SSPADD
        MOVLW   0x28
        MOVWF   SSPCON                                  ; Set as i2c master, and enable the ports
	RETURN

; i2c Initiate START condition
i2c_master_start
	bsf     STATUS, RP0
	bsf     SSPCON2, 0x0
i2c_master_start_loop
	btfsc   SSPCON2, 0x0
	goto    i2c_master_start_loop
	bcf     STATUS, RP0
	return

;***********************************************************************
; i2c Initiate Repeated START condition
i2c_master_restart
	bsf     STATUS, RP0
	bsf     SSPCON2, 0x1
i2c_master_restart_loop
	btfsc   SSPCON2, 0x1
	goto    i2c_master_restart_loop
	bcf     STATUS, RP0
	return

;***********************************************************************
; i2c Initiate STOP condition
i2c_master_stop
	bsf     STATUS, RP0
	bsf     SSPCON2, 0x2
i2c_master_stop_loop
	btfsc   SSPCON2, 0x2
	goto    i2c_master_stop_loop
	bcf     STATUS, RP0
	return

;***********************************************************************
; i2c ACK seq
i2c_master_ack_seq
	bsf     STATUS, RP0
	bcf     SSPCON2, 0x5
	bsf     SSPCON2, 0x4
i2c_master_ack_seq_loop
	btfsc   SSPCON2, 0x4
	goto    i2c_master_ack_seq_loop
	bcf     STATUS, RP0
	return

;***********************************************************************
; i2c NACK seq
i2c_master_nack_seq
	bsf     STATUS, RP0
	bsf     SSPCON2, 0x5
	bsf     SSPCON2, 0x4
i2c_master_nack_seq_loop
	btfsc   SSPCON2, 0x4
	goto    i2c_master_nack_seq_loop
	bcf     STATUS, RP0
	return

;***********************************************************************
; i2c write
; 0xc26 - 0xa4 -> Write Access U8 DS1845
; 0xc28 - 0xa5 -> Read Access U8 DS1845
i2c_master_write_unknown1
	movlw   0x04
	goto    i2c_master_write
i2c_master_write_unknown2
	movlw   0x02
	goto    i2c_master_write
i2c_master_write_unknown3
	movlw   0x03
	goto    i2c_master_write
i2c_master_write_BCKCONW
	movlw   0xa4					; Write address for U8 DS1845 (Backlight and contrast control)
	goto    i2c_master_write
i2c_master_write_BCKCONR
	movlw   0xa5					; Read address for U8 DS1845 (Backlight and contrast control)
	goto    i2c_master_write
i2c_master_write
	bcf     STATUS, RP0
	movwf   SSPBUF					; Set data to write
	bsf     STATUS, RP0
	bcf     SSPCON2, ACKSTAT			; Clear ACKSTAT
i2c_master_write_l1
	btfsc   SSPSTAT, 0x02				; Skip on write, else (wait for writing to begin)
	goto    i2c_master_write_l1
	bcf     STATUS, RP0
	movlw   0x32
	movwf   _mr_loop1				; Setup loop counter
	movlw   0x00
	movwf   _mr_loop2				; Setup loop counter
i2c_master_write_l3
	clrwdt
i2c_master_write_l2
	bsf     STATUS, RP0
	btfss   SSPCON2, ACKSTAT
	goto    i2c_master_write_clear_carry
	bcf     STATUS, RP0
	decfsz  _mr_loop2, 0x1
	goto    i2c_master_write_l2
	decfsz  _mr_loop1, 0x1
	goto    i2c_master_write_l3
	bcf     STATUS, 0x0
	return
i2c_master_write_clear_carry
	bcf     STATUS, RP0
	bsf     STATUS, C
	return

;***********************************************************************
; i2c Read: byte saved in Register W
i2c_master_read
	bsf     STATUS, RP0
	bsf     SSPCON2, 0x3
i2c_master_read_loop
	btfsc   SSPCON2, 0x3
	goto    i2c_master_read_loop
	bcf     STATUS, RP0
	movf    SSPBUF, 0x0
	return

;***********************************************************************
; i2c write to U8 DS1845
; Wiper0 -> LCD Backlight -> F9
; Wiper1 -> LCD Contrast -> F8
lcd_write_bckcon_default_bck
	movlw   0xf9
	movwf   0x3a
	movf    0x0, 0x0
	movwf   0x3b
	goto    lcd_write_bckcon
lcd_write_bckcon_default_con
	movlw   0xf8
	movwf   0x3a
	movf    0x7f, 0x0
	movwf   0x3b
	goto    lcd_write_bckcon
lcd_write_bckcon
	movlw   0x03					; Setup a retry of 3
	movwf   0x7d

lcd_write_bckcon_l1
	clrwdt

	call	i2c_master_stop
	call    i2c_master_start
	call    i2c_master_write_BCKCONW

	btfsc   STATUS, C
	goto    lcd_write_bckcon_j1
	decfsz  0x7d, 0x1
	goto    lcd_write_bckcon_l1
	return
lcd_write_bckcon_j1
	movf    0x3a, 0x0
	call    i2c_master_write
	movf    0x3b, 0x0
	call    i2c_master_write
	call    i2c_master_stop
	return

;***********************************************************************
; i2c read from U8 DS1845 (write: {0x3a} read: {0x3b})
; Wiper0 -> LCD Backlight -> F9
; Wiper1 -> LCD Contrast -> F8
lcd_read_bckcon
	movlw   0x03					; Setup a retry of 3
	movwf   0x7d

lcd_read_bckcon_l1
	call    i2c_master_stop
	call    i2c_master_start
	call    i2c_master_write_BCKCONW
	btfsc   STATUS, C
	goto    lcd_read_bckcon_j1
	decfsz  0x7d, 0x1
	goto    lcd_read_bckcon_l1
	return
lcd_read_bckcon_j1
	movf    0x3a, 0x0
	call    i2c_master_write
	call    i2c_master_restart
	call    i2c_master_write_BCKCONR
	call	i2c_master_read
	movwf   0x3b					; Save value in 0x3b
	call    i2c_master_stop
	return
