;**************************
;Screen drivers.
;The purpose of this code is to provide utilities for writing info
;to an LCD module.


;;*******************************************************************
;;scale_hex2dec
;;  The purpose of this routine is to scale a hexadecimal byte to a
;;decimal byte. In other words, if 'h' is a hexadecimal byte then
;;the scaled decimal equivalent 'd' is:
;;    d = h * 100/256.
;;Note that this can be simplified:
;;    d = h * 25 / 64 = h * 0x19 / 0x40
;;Multiplication and division can be expressed in terms of shift lefts
;;and shift rights:
;;    d = [ (h<<4) + (h<<3) + h ] >> 6
;;The program divides the shifting as follows so that carries are automatically
;;taken care of:
;;    d =   (h + (h + (h>>3)) >> 1) >> 2
;;
;;Inputs:   W - should contain 'h', the hexadecimal value to be scaled
;;Outputs:  W - The scaled hexadecimal value is returned in W
;;Memory:   _mr_temp1
;;Calls:    none
;
;scale_hex2dec
;  ifdef __scale_hex2dec__
;
;        MOVWF   _mr_temp1            ;Hex value is in W.
;        CLRC                    ;Clear the Carry bit so it doesn't affect RRF
;        RRF     _mr_temp1,F
;        CLRC
;        RRF     _mr_temp1,F
;        CLRC
;        RRF     _mr_temp1,F          ;_mr_temp1 = h>>3
;        ADDWF   _mr_temp1,F          ;_mr_temp1 = h + (h>>3)
;        RRF     _mr_temp1,F          ;_mr_temp1 = (h + (h>>3)) >> 1
;        ADDWF   _mr_temp1,F          ;_mr_temp1 = h + ((h + (h>>3)) >> 1)
;        RRF     _mr_temp1,F
;        CLRC
;        RRF     _mr_temp1,W          ;d = W = (h + (h + (h>>3)) >> 1) >> 2
;
;   endif
;        RETURN


;;*******************************************************************
;;write_word_as_hex
;; The purpose of this routine is to convert the word pointed to by W to a
;;4 digit ASCII string representing the hexadecimal value of the word.
;;Note, words are stored in RAM with the least significant byte first.
;;
;; Memory used
;;    _mr_str_buffer2
;; Calls
;;    write_byte_as_hex
;;
;write_word_as_hex
;  ifdef __write_word_as_hex__
;    ifndef __write_byte_as_hex__
;#define __write_byte_as_hex__ 1
;    endif
;
;        MOVWF   FSR                     ;W points to the word
;        MOVWF   _mr_str_buffer2                 ;Save a copy of the pointer
;        INCF    FSR, F                  ;Point to the MSB
;        MOVF    INDF,W                  ;Get the MSB
;        CALL    write_byte_as_hex       ;And print it.
;        MOVF    _mr_str_buffer2,W               ;Get pointer to the word.
;        MOVWF   FSR                     ;W now points to the LSB
;        MOVF    INDF,W                  ;Get the LSB
;        goto    write_byte_as_hex       ;And print it.
;   else
;        RETURN
;   endif

;*******************************************************************
;write_byte_as_hex
;
; The purpose of this routine is to convert the byte in W to a 2 digit
;ASCII string representing the hexadecimal value of the byte. For example,
;0xf9 is converted to 0x45 0x39. The ASCII digits are then written to the
;LCD module.
;
; Memory used
;    _mr_str_buffer0, string_number
; Calls
;    LCD_WRITE_DATA
;
screen_write_byte_as_hex
;  ifdef  __write_byte_as_hex__

	CLRF    _mr_loop1			; Used as temporary storage to keep track of loop count
	MOVWF   _mr_temp2			; Save byte to be written here
wbah1:
	SWAPF   _mr_temp2,W			; Write the high nibble first.
	ANDLW   0x0f				; Get the lower nibble of W
	ADDLW   -0xa				; If it is >= 0xa, then
	BTFSC   STATUS, C			;    the carry will get set.
	ADDLW   'A'-'9' - 1			; The digit is between 0xa and 0xf
	ADDLW   '9'+ 1				; Convert it to ASCII
	CALL    LCD_WRITE_DATA
	BTFSC   _mr_loop1,1			; This bit is clear the first time through the loop.
	RETURN
	SWAPF   _mr_temp2,F			; Get the low nibble
	BSF     _mr_loop1,1			; Set so next time through we will return.
	goto    wbah1
;   else
;        RETURN
;   endif

;;*******************************************************************
;;write_byte_as_dec
;;
;;  The purpose of this routine is to convert a byte to a 3 digit ASCII string
;;representing the decimal value of the byte. For example, 0xff = 255 is converted
;;to 0x32 0x35 0x35.
;;
;; Memory used
;;    _mr_str_buffer0 - _mr_str_buffer5
;; Calls
;;    BCD_2_ASCII, BCD_adjust
;;
;write_byte_as_dec
;         BCF     STATUS,C        ;Clear the carry so the first shift is not corrupted
;         CLRF    _mr_str_buffer0
;         CLRF    _mr_str_buffer1
;         CLRF    _mr_str_buffer2
;         CLRF    _mr_str_buffer3
;         MOVWF   _mr_str_buffer4         ;Save copy of input
;         MOVLW   6               ;
;         MOVWF   _mr_str_buffer5         ;Number of times we'll loop.
;         RLF     _mr_str_buffer4,F       ;The first two shifts do not need BCD adjusting
;         RLF     _mr_str_buffer1,F
;         RLF     _mr_str_buffer4,F
;         RLF     _mr_str_buffer1,F
;
;wbad1    RLF     _mr_str_buffer4,F
;         RLF     _mr_str_buffer1,F
;         RLF     _mr_str_buffer0,F
;
;         DECFSZ  _mr_str_buffer5,F
;           goto  wbad2
;
;         MOVLW   _mr_str_buffer1+1
;         MOVWF   FSR
;         MOVF    _mr_str_buffer1,W
;         CALL    BCD_2_ASCII
;
;         MOVLW   '0'
;         ADDWF   _mr_str_buffer0,F
;
;         GOTO    write_buffer
;
;wbad2    MOVLW   _mr_str_buffer1
;         CALL    BCD_adjust
;         GOTO    wbad1

;;*******************************************************************
;;BCD_2_ASCII
;;
;;   The purpose of this routine is to convert the BCD byte in W into two ASCII bytes. The
;; ASCII data is written to the indirect address contained in FSR.
;;
;; Memory used
;;    _mr_temp1
;; Calls
;;    none
;; Inputs
;;    W = BCD data
;;  FSR = points to where ASCII data is to be written
;;
;BCD_2_ASCII
;         MOVWF   _mr_temp1
;         ANDLW   0x0f
;         ADDLW   '0'
;         MOVWF   INDF
;         DECF    FSR,F
;
;         SWAPF   _mr_temp1,W
;         ANDLW   0x0f
;         ADDLW   '0'
;         MOVWF   INDF
;         RETURN

;;*******************************************************************
;;write_word_as_dec
;;
;; Memory used
;;    _mr_str_buffer0 - _mr_str_buffer5
;; Calls
;;    BCD_2_ASCII, BCD_adjust
;; Inputs
;;    FSR = pointer to the word to be written
;;
;write_word_as_dec
;         CLRF    _mr_str_buffer0
;         CLRF    _mr_str_buffer1
;         CLRF    _mr_str_buffer2
;         MOVWF   FSR            ;Save copy of input
;         MOVF    INDF,W         ;Get the Least significant Byte
;         MOVWF   _mr_str_buffer3
;         INCF    FSR,F
;         MOVF    INDF,W         ;Get the MSB
;         MOVWF   _mr_str_buffer4
;
;         MOVLW   14             ;
;         MOVWF   _mr_str_buffer5        ;Number of times we'll loop.
;         BCF     STATUS,C       ;Clear the carry so the first shift is not corrupted
;         RLF     _mr_str_buffer3,F      ;The first two shifts do not need BCD adjusting
;         RLF     _mr_str_buffer4,F
;         RLF     _mr_str_buffer2,F
;
;         RLF     _mr_str_buffer3,F
;         RLF     _mr_str_buffer4,F
;         RLF     _mr_str_buffer2,F
;
;wwad1    RLF     _mr_str_buffer3,F
;         RLF     _mr_str_buffer4,F
;         RLF     _mr_str_buffer2,F
;         RLF     _mr_str_buffer1,F
;         RLF     _mr_str_buffer0,F
;
;         DECFSZ  _mr_str_buffer5,F
;           goto  wwad2
;
;         MOVLW   _mr_str_buffer3+1
;         MOVWF   FSR
;         MOVF    _mr_str_buffer2,W
;         CALL    BCD_2_ASCII
;
;         MOVLW   _mr_str_buffer1+1
;         MOVWF   FSR
;         MOVF    _mr_str_buffer1,W
;         CALL    BCD_2_ASCII
;
;         MOVLW   '0'
;         ADDWF   _mr_str_buffer0,F
;
;         GOTO    write_buffer
;
;wwad2    MOVLW   _mr_str_buffer2
;         CALL    BCD_adjust
;
;         MOVLW   _mr_str_buffer1
;         CALL    BCD_adjust
;         GOTO    wwad1

;;*******************************************************************
;;BCD_adjust
;;
;;  This routine will 'adjust' the byte that W points to to BCD. The
;;algorithm is based on converting hexadecimal into decimal. Normally, to
;;convert a hex digit (i.e. a nibble) to binary coded decimal, you add
;;6 to it if it is greater than or equal 0xa. So, 0x0 through 0x9 convert
;;to 0 through 9 while 0xa through 0xf convert to 0x10 through 0x15.
;;Now, this routine adds 3 instead of 6. Also, instead of checking
;;to see if the digit is >= 0xa, this routine checks for > 0x7. However,
;;the caller will perform a left shift after calling this routine. Thus,
;;the 3 is multiplyed by two to get 6.
;BCD_adjust
;         MOVWF   FSR
;         MOVLW   0x03
;         ADDWF   INDF,F
;         BTFSS   INDF,3
;         SUBWF   INDF,F
;
;         MOVLW   0x30
;         ADDWF   INDF,F
;         BTFSS   INDF,7
;         SUBWF   INDF,F
;
;         RETURN


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

screen_draw_border
	CALL	LCD_PORT_CONFIGURE
	CALL	LCD_CLEAR_SCREEN

	MOVLW	LCD_CMD_SET_DDRAM | SCR_ROW0 | SCR_COL0
	CALL	LCD_WRITE_CMD
	MOVLW	0x14
	MOVWF	_mr_loop1
	MOVLW	0x2A					; Ascii '*'
screen_draw_border_l1
	CALL	LCD_WRITE_DATA
	DECFSZ	_mr_loop1, F
		GOTO	screen_draw_border_l1

	MOVLW	LCD_CMD_SET_DDRAM | SCR_ROW3 | SCR_COL0
	CALL	LCD_WRITE_CMD
	MOVLW	0x14
	MOVWF	_mr_loop1
	MOVLW	0x2A					; Ascii '*'
screen_draw_border_l2
	CALL	LCD_WRITE_DATA
	DECFSZ	_mr_loop1, F
		GOTO	screen_draw_border_l2

        CALL    LCD_PORT_RESTORE

        RETURN

