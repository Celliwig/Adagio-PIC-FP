;*******************************************************************
; PIC EEPROM
;
; Routines to access the in built EEPROM
;
;*******************************************************************
;
; pic_eeprom_read
;
; Read a byte from the EEPROM, then increments the address. The
; address to read is preconfigured.
;	W (on return) - Data read
;
pic_eeprom_read
	banksel	EECON1
	bcf	EECON1, EEPGD		; Select EEPROM memory
	bsf	EECON1, RD		; Start read operation
	banksel	EEADR
	incf	EEADR, F
	movf	EEDATA, W		; Read data

	return

;*******************************************************************
;
; pic_eeprom_write_finish_wait
;
; Loop until a write operation in progress finishes
;
pic_eeprom_write_finish_wait
	banksel	EECON1
	btfsc	EECON1, WR				; Wait for write
		goto	$-1				; To finish

	return

;*******************************************************************
;
; pic_eeprom_write
;
; Write a byte to the EEPROM, then increments the address. The
; address to write, and data is preconfigured.
;
pic_eeprom_write
	banksel	EECON1
	bcf	EECON1, EEPGD				; Point to EEPROM memory
	bcf	INTCON, GIE				; Disable interrupts
	bsf	EECON1, WREN				; Enable writes

	movlw	0x55					; Special sequence, needed for write
	movwf	EECON2					; Write 55h to EECON2
	movlw	0xAA
	movwf	EECON2					; Write AAh to EECON2
	bsf	EECON1, WR				; Start write operation

	bcf	EECON1, WREN				; Disable writes
	bsf	INTCON, GIE				; Enable interrupts

	banksel	EEADR
	incf	EEADR, F

	return
