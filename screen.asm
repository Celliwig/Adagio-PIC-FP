;*******************************************************************
;Screen drivers.
;The purpose of this code is to provide utilities for writing info
;to an LCD module.

;;*******************************************************************
;;write_buffer
;;
;;  The purpose of this routine is to display the contents of 'buffer' on
;;the LCD module. _mr_str_buffer0 is the first element of the string. The string
;;is assumed to be zero terminated. If it isn't, then the whole buffer will
;;get displayed. (Note, there's a check to insure that no more than 'buffer'
;;is written.)
;;
;; Memory used
;;    _mr_str_buffer0
;; Calls
;;    LCD_WRITE_DATA
;;
;write_buffer
;        MOVLW   _mr_str_buffer0		;Get a pointer to the first buffer location
;        MOVWF   FSR
;wb1:    MOVF    INDF,W			;Get a byte from the buffer
;        BTFSC   STATUS,Z		;If it is zero, then that's the last byte
;          RETURN
;        CALL    LCD_WRITE_DATA
;        INCF    FSR,F			;Point to the next buffer entry
;        MOVF    FSR,W
;        SUBLW   _mr_str_buffer19	;If we're pointing to the last buffer entry
;        BTFSS   STATUS,Z		;then we need to quit writing.
;          goto  wb1
;        RETURN


;;*******************************************************************
;;write_string
;;
;;  The purpose of this routine is to display a string on the LCD module.
;;On entry, W contains the string number to be displayed. The current cursor
;;location is the destination of the output.
;;  This routine can be located anywhere in the code space and may be
;;larger than 256 bytes.
;;
;; psuedo code:
;;
;; char *string0 = "foo";
;; char *string1 = "bar";
;;
;; char *strings[] = { string0, string1};
;; char num_strings = sizeof(strings)/sizeof(char *);
;;
;; void write_string(char string_num)
;; {
;;   char *str;
;;
;;   str = strings[string_num % num_strings];
;;
;;   for( ; *str; str++)
;;     LCD_WRITE_DATA(*str);
;;
;; }
;;   
;; Memory used
;;    _mr_str_buffer2, _mr_str_buffer3
;; Calls
;;    LCD_WRITE_DATA
;; Inputs
;;    W = String Number
;;
;write_string
;
;	andlw   WS_TABLE_MASK           ;Make sure the string is in range
;        movwf   _mr_str_buffer3                 ;Used as an index into the string table
;	addwf	_mr_str_buffer3,w               ;to get the string offset
;                                        ;
;	addlw	LOW(ws_table)           ;First, get a pointer to the string
;	movwf	_mr_str_buffer3                 ;
;                                        ;
;	movlw   HIGH(ws_table)          ;
;	skpnc                           ;
;	 movlw   HIGH(ws_table)+1       ;
;
;	movwf	PCLATH
;
;	movf	_mr_str_buffer3,w
;	call	ws2			;First call is to get string offset in table
;	movwf	_mr_str_buffer2
;
;	incf	PCLATH,f
;	incfsz	_mr_str_buffer3,w
;	 decf	PCLATH,f
;
;	call	ws2                     ;get the high word (of the offset)
;
;	movwf	PCLATH                  ;
;ws1:                                    ;Now loop through the string
;	movf	_mr_str_buffer2,w
;	call	ws2
;
;	andlw	0xff
;        skpnz                           ;If the returned byte is zero, 
;         return                         ;   we've reached the end
;
;        call    LCD_WRITE_DATA
;
;	incf	PCLATH,f                ;Point to the next character in the string
;	incfsz	_mr_str_buffer2,f
;	 decf	PCLATH,f
;
;        goto    ws1
;
;ws2
;	movwf	PCL


;WS_TABLE_MASK  equ	7   ; This should equal 2^number of strings
;
;; The first part of the table contains pointers to the start of the 
;; strings. Note that each string has a two word pointer for the low
;; and high bytes.
;
;ws_table:
;	retlw	LOW(string0)
;	retlw	HIGH(string0)
;
;	retlw	LOW(string1)
;	retlw	HIGH(string1)
;
;	retlw	LOW(string2)
;	retlw	HIGH(string2)
;
;	retlw	LOW(string3)
;	retlw	HIGH(string3)
;
;
;string0:	dt	"********************", 0
;string1:	dt	"*     Test Mode    *", 0
;string2:	dt	"*                  *", 0
;string3:	dt	"********************", 0

;*******************************************************************
; Clears (fills with spaces) the screen buffer

screen_clear
	banksel	_mr_screen_buffer_line1

	movlw	_mr_screen_buffer_line1		; Load the address of the first character of the screen buffer
	movwf	FSR				; Move this to the FSR

screen_clear_loop
	movlw	0x20				; ASCII space
	movwf	INDF				; move space to address pointed to by FSR
	incf	FSR, F				; increment address pointer
	movlw	(_mr_screen_buffer_line1 + 80)	; load end address of the buffer
	subwf	FSR, W
	btfss	STATUS, Z			; check if they are the same address
	goto	screen_clear_loop		; if they are, keep looping

	return

;*******************************************************************
; Write the screen buffer to the lcd
screen_write_2_lcd
	call	LCD_PORT_CONFIGURE

	movlw	LCD_CMD_SET_DDRAM | SCR_ROW0 | SCR_COL0
	call	LCD_WRITE_CMD

	banksel	_mr_screen_buffer_line1
	movlw	_mr_screen_buffer_line1
	movwf	FSR
	movlw	0x28					; We're writing 2 lines of data
	movwf   _mr_screen_buffer_loop
screen_write_2_lcd_lines13
	movf	INDF, W
	call	LCD_WRITE_DATA
	incf	FSR, F
	banksel	_mr_screen_buffer_loop
	decfsz	_mr_screen_buffer_loop, F
		goto	screen_write_2_lcd_lines13

	movlw	LCD_CMD_SET_DDRAM | SCR_ROW1 | SCR_COL0
	call	LCD_WRITE_CMD

	banksel	_mr_screen_buffer_line2
	movlw	_mr_screen_buffer_line2
	movwf	FSR
	movlw	0x28					; We're writing 2 lines of data
	movwf   _mr_screen_buffer_loop
screen_write_2_lcd_lines24
	movf	INDF, W
	call	LCD_WRITE_DATA
	incf	FSR, F
	banksel	_mr_screen_buffer_loop
	decfsz	_mr_screen_buffer_loop, F
		goto	screen_write_2_lcd_lines24

	call	LCD_PORT_RESTORE

	return


;*******************************************************************
; Draw a decorative border around the screen (lcd buffer)

screen_draw_border
	call	screen_clear

	banksel	_mr_screen_buffer_line1

	movlw	_mr_screen_buffer_line1
	movwf	FSR
	movlw	0x15
	movwf	_mr_screen_buffer_loop
	movlw	0x2A					; Ascii '*'
screen_draw_border_l13
	movwf	INDF
	incf	FSR, F
	decfsz	_mr_screen_buffer_loop, F
		goto	screen_draw_border_l13
	movf	FSR, W
	addlw	0x12
	movwf	FSR
	movlw	0x2A					; Ascii '*'
	movwf	INDF

	movlw	_mr_screen_buffer_line2
	movwf	FSR
	movlw	0x2A					; Ascii '*'
	movwf	INDF
	movf	FSR, W
	addlw	0x13
	movwf	FSR
	movlw	0x15
	movwf	_mr_screen_buffer_loop
	movlw	0x2A					; Ascii '*'
screen_draw_border_l24
	movwf	INDF
	incf	FSR, F
	decfsz	_mr_screen_buffer_loop, F
		goto	screen_draw_border_l24

	return

;*******************************************************************
;write_byte_as_hex
;
; The purpose of this routine is to convert the byte in W to a 2 digit
; ASCII string representing the hexadecimal value of the byte. The FSR
; must be pointing to the correct position in the screen buffer.
;
; Memory used
;    _mr_screen_buffer_loop, _mr_screen_buffer_temp
;
screen_write_byte_as_hex
	banksel	_mr_screen_buffer_loop
	clrf	_mr_screen_buffer_loop		; Used as temporary storage to keep track of loop count
	movwf	_mr_screen_buffer_temp		; Save byte to be written here
wbah1:
	swapf	_mr_screen_buffer_temp,W	; Write the high nibble first.
	andlw	0x0f				; Get the lower nibble of W
	addlw	-0xa				; If it is >= 0xa, then
	btfsc	STATUS, C			;    the carry will get set.
	addlw	'A'-'9' - 1			; The digit is between 0xa and 0xf
	addlw	'9'+ 1				; Convert it to ASCII
	movwf	FSR				; write digit to screen buffer
	btfsc	_mr_screen_buffer_loop,1	; This bit is clear the first time through the loop.
	return
	swapf	_mr_screen_buffer_temp,F	; Get the low nibble
	bsf	_mr_screen_buffer_loop,1	; Set so next time through we will return.
	goto	wbah1

;;*******************************************************************
;;write_word_as_hex
;; The purpose of this routine is to convert the word pointed to by W to a
;; 4 digit ASCII string representing the hexadecimal value of the word.
;; Note, words are stored in RAM with the least significant byte first.
;;
;; Memory used
;;    _mr_str_buffer2
;; Calls
;;    write_byte_as_hex
;;
;write_word_as_hex
;        MOVWF   FSR                     ;W points to the word
;        MOVWF   _mr_str_buffer2                 ;Save a copy of the pointer
;        INCF    FSR, F                  ;Point to the MSB
;        MOVF    INDF,W                  ;Get the MSB
;        CALL    write_byte_as_hex       ;And print it.
;        MOVF    _mr_str_buffer2,W               ;Get pointer to the word.
;        MOVWF   FSR                     ;W now points to the LSB
;        MOVF    INDF,W                  ;Get the LSB
;        goto    write_byte_as_hex       ;And print it.
