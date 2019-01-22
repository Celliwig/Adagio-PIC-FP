; Define the paramters of the i2c command structure

; i2c write structure
; 1st byte - number of bytes to follow
; 2nd byte - command byte
; n bytes - payload

;---------------------------------------------------------------------
; Command byte
;---------------------------------------------------------------------
FP_CMD_BIT_CLEAR_SCREEN		EQU	0x00
FP_CMD_BIT_WRITE_SCREEN		EQU	0x01
FP_CMD_BIT_LCD_CGRAM_UPDATE	EQU	0x02
FP_CMD_BIT_LED_CONTROL		EQU	0x03

;---------------------------------------------------------------------
; Command status
;---------------------------------------------------------------------
FP_CMD_STATUS_BIT_LOADING	EQU	0x00		; Started reading in a command
FP_CMD_STATUS_BIT_LOADED	EQU	0x01		; Command has been read in
FP_CMD_STATUS_BIT_PROCESSING	EQU	0x02		; Started processing command
FP_CMD_STATUS_BIT_PROCESSED	EQU	0x03		; Command processed

;---------------------------------------------------------------------
; Screen postion byte
; |   7   |   6   |   5   |   4   |   3   |   2   |   1   |   0   |
; -----------------------------------------------------------------
; |   X   |  C4   |  C3   |  C2   |  C1   |  C0   |  R1   |  R0   |
;---------------------------------------------------------------------
;
; R0 - Row select 1
; R1        "
;
; C0 - Character position to start writing from
; C1             "
; C2             "
; C3             "
; C4             "
;

FP_LCD_CLEAR_SCREEN		EQU	0x07
FP_LCD_ROW1			EQU	0x00
FP_LCD_ROW2			EQU	0x01
FP_LCD_ROW3			EQU	0x02
FP_LCD_ROW4			EQU	0x03

;---------------------------------------------------------------------
; Led byte
; |   7   |   6   |   5   |   4   |   3   |   2   |   1   |   0   |
; -----------------------------------------------------------------
; |   X   |   X   |   X   |   X   |   X   |   X   |  L1   |  L0   |
;---------------------------------------------------------------------
;
; L0 - Power LED
; L1 - Online LED
;
FP_CMD_LED_BIT_POWER		EQU	0x00
FP_CMD_LED_BIT_ONLINE		EQU	0x01
