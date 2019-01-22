; Read the front panel buttons
; Select RC2:
;	Pause (SW16): RD7
;	Select (SW15): RD6
;	Down (SW14): RD5
;	Display 2 (SW13): RD4
;	CD/HD (SW12): RD3
;	Left (SW11): RD2
;	Play (SW10): RD1
;	Power (SW9): RD0
;
; Select RB1:
;	Eject (SW8): RD7
;	Display 1 (SW7): RD6
;	Stop (SW6): RD5
;	Next (SW5): RD4
;	Mode (SW4): RD3
;	Display 3 (SW3): RD2
;	Display 4 (SW2): RD1
;	Previous (SW1): RD0
;
; Select RB2:
;	Right (SW18): RD1
;	Up (SW17): RD0

; PortD pulled high, so the bank select line goes low

READ_BUTTONS
	bsf	STATUS, RP0
	movf	TRISD, W
	movwf	_mr_oldxtris			; Save the TRISD state
	MOVLW	0xFF
	movwf	TRISD				; Set PortD to all inputs
	bcf	STATUS, RP0

	call	READ_BUTTONS_RB1		; Read bank 1
	movwf	_mr_button_bank

	call	READ_BUTTONS_RB2		; Read bank 2
	movwf	(_mr_button_bank + 1)

	call	READ_BUTTONS_RC2		; Read bank 3
	movwf	(_mr_button_bank + 2)

	bsf	STATUS, RP0
	movf	_mr_oldxtris,W			; Restore TRISD state
	movwf	TRISD
	bcf	STATUS, RP0

	return

READ_BUTTONS_RB1
	bsf	STATUS, RP0
	bcf     TRISB, 0x1			; Set as Output
	bcf	STATUS, RP0

	bcf     PORTB, 0x1
	comf    PORTD, W
	bsf     PORTB, 0x1

	bsf	STATUS, RP0
	bsf     TRISB, 0x1			; Reset to input
	bcf	STATUS, RP0

	return

READ_BUTTONS_RB2
	bsf	STATUS, RP0
	bcf     TRISB, 0x2			; Set as Output
	bcf	STATUS, RP0

	bcf     PORTB, 0x2
	comf    PORTD, W
	bsf     PORTB, 0x2

	bsf	STATUS, RP0
	bsf     TRISB, 0x2			; Reset to input
	bcf	STATUS, RP0

	return

READ_BUTTONS_RC2
	bsf	STATUS, RP0
	bcf     TRISC, 0x2			; Set as Output
	bcf	STATUS, RP0

	bcf     PORTC, 0x2
	comf    PORTD, W
	bsf     PORTC, 0x2

	bsf	STATUS, RP0
	bsf     TRISC, 0x2			; Reset to input
	bcf	STATUS, RP0

	return

