;***********************************************************************
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
;***********************************************************************

;***********************************************************************
; PortD bit associated with each switch
;***********************************************************************
BUTTON_BIT_RC2_PWR	EQU	0
BUTTON_BIT_RC2_PLAY	EQU	1
BUTTON_BIT_RC2_LEFT	EQU	2
BUTTON_BIT_RC2_CDHD	EQU	3
BUTTON_BIT_RC2_DSP2	EQU	4
BUTTON_BIT_RC2_DOWN	EQU	5
BUTTON_BIT_RC2_SLCT	EQU	6
BUTTON_BIT_RC2_PAUS	EQU	7

BUTTON_BIT_RB1_PREV	EQU	0
BUTTON_BIT_RB1_DSP4	EQU	1
BUTTON_BIT_RB1_DSP3	EQU	2
BUTTON_BIT_RB1_MODE	EQU	3
BUTTON_BIT_RB1_NEXT	EQU	4
BUTTON_BIT_RB1_STOP	EQU	5
BUTTON_BIT_RB1_DSP1	EQU	6
BUTTON_BIT_RB1_EJCT	EQU	7

BUTTON_BIT_RB2_UP	EQU	0
BUTTON_BIT_RB2_RGHT	EQU	1

;***********************************************************************
; Read switch arrays into button buffers
;***********************************************************************
read_buttons
	banksel	TRISD
	movf	TRISD, W
	movwf	_mr_oldxtris			; Save the TRISD state
	movlw	0xFF
	movwf	TRISD				; Set PortD to all inputs

	call	read_buttons_RB1		; Read bank 1
	banksel	_mr_button_bank
	movwf	_mr_button_bank

	call	read_buttons_RB2		; Read bank 2
	banksel	_mr_button_bank
	movwf	(_mr_button_bank + 1)

	call	read_buttons_RC2		; Read bank 3
	banksel	_mr_button_bank
	movwf	(_mr_button_bank + 2)

	banksel	TRISD
	movf	_mr_oldxtris,W			; Restore TRISD state
	movwf	TRISD

	return

;***********************************************************************
; Read the switch array selected by RB1
;***********************************************************************
read_buttons_RB1
	banksel	TRISB
	bcf	TRISB, 0x1			; Set as Output

	banksel	PORTB
	bcf	PORTB, 0x1
	comf	PORTD, W
	bsf	PORTB, 0x1

	banksel	TRISB
	bsf	TRISB, 0x1			; Reset to input

	return

;***********************************************************************
; Read the switch array selected by RB2
;***********************************************************************
read_buttons_RB2
	banksel	TRISB
	bcf	TRISB, 0x2			; Set as Output

	banksel	PORTB
	bcf	PORTB, 0x2
	comf	PORTD, W
	bsf	PORTB, 0x2

	banksel	TRISB
	bsf	TRISB, 0x2			; Reset to input

	return

;***********************************************************************
; Read the switch array selected by RC2
;***********************************************************************
read_buttons_RC2
	banksel	TRISC
	bcf	TRISC, 0x2			; Set as Output

	banksel	PORTC
	bcf	PORTC, 0x2
	comf	PORTD, W
	bsf	PORTC, 0x2

	banksel	TRISC
	bsf	TRISC, 0x2			; Reset to input

	return

