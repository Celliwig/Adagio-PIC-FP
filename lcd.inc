#define         OLED_DISPLAY            ; Enable extra configuration for OLED displays
#define		LCD_BASE_ADDR	0xA00


;*******************************************************************
;
; LCD
;   The information for the LCD software comes from several places: Microchip's AN587,
; Optrex Data Book, Christopher J. Burian's LCD Technical FAQ, and Peer Ouwehand's "How to
; Control HD44780-based Character-LCD".
;
; Microchip can be reached at
;   http://www.ultranet.com/biz/mchip/
; Burian's FAQ is located at
;   http://www.paranoia.com/~filipg/HTML/LINK/F_LCD_tech.html
; Ouwehand's document is located at
;   http://www.iaehv.nl/users/pouweha/lcd.htm
;
;*******************************************************************
;Dev_Tcyc		EQU	400			; Tcyc = 400 ns, Instruction Cycle time (10 MHz)
;Dev_Tcyc		EQU	1000			; Tcyc = 1000 ns, Instruction Cycle time (4 MHz)
Dev_Tcyc		EQU	250			; Tcyc = 250 ns, Instruction Cycle time (16 MHz)
Inner_delay		EQU	(256*3 + 3)*Dev_Tcyc	; The amount of time spent in inner delay loop
LCD_INIT_DELAY		EQU	15000000/Inner_delay	; 15ms

LCD_CONTROL_PORT	EQU	PORTC			; LCD control lines interface to PORTC
LCD_CONTROL_TRIS	EQU	TRISC
LCD_DATA_PORT		EQU	PORTD			; PORTD<7:0> == LCD_DB<7:0>
LCD_DATA_TRIS		EQU	TRISD

LCD_E			EQU	7			; PORTC<7>   == LCD Enable control line
LCD_Eb			EQU	(1<<LCD_E)
LCD_R_W			EQU	6			; PORTC<6>   == LCD Read/Write control line
LCD_RS			EQU	5			; PORTC<5>   == LCD Register Select control line

LCD_CONTROL_MASK	EQU	(1<<LCD_E) | (1<<LCD_R_W) | (1<<LCD_RS)

;Define the data mask. If the 4-bit LCD data bus is accessible via the high nibble
;of the DATA_PORT then the DATA_MASK should be 0xf0. Otherwise, it should be 0x0f.
;Note, the software will NOT work if the LCD data bus is not nibble-aligned.

; 8 bit
LCD_DATA_MASK		EQU	0xff

LCD_DATA_SHIFT		EQU	0			; Used to shift the LCD constants.

;LCD Command Clear Display = 00000001
LCD_CMD_CLEAR_DISPLAY	EQU	0x01

;LCD Command Display Control = 00001dcb
;  d = 1 turn display on or 0 to turn display off
;  c = 1 turn cursor on or 0 to turn cursor off
;  b = 1 blinking cursor or 0 non-blinking cursor

LCD_CMD_DISPLAY_CTRL	EQU	0x08			; LCD Command "Display Control"
LCD_DISPLAY_OFF		EQU	0x00			; d=0
LCD_DISPLAY_ON		EQU	0x04			; d=1
LCD_CURSOR_OFF		EQU	0x00			; c=0
LCD_CURSOR_ON		EQU	0x02			; c=1
LCD_BLINK_OFF		EQU	0x00			; b=0
LCD_BLINK_ON		EQU	0x01			; b=1


IFDEF	OLED_DISPLAY
;LCD Command Function Set =  0001sr00	- cursor & display shift
;LCD Command Function Set =  0001mp11	- mode (character/graphics) & DC/DC PSU
;  s/r = shift cursor/display to the left or right
;  m = 1 is graphics mode, 0 is character mode
;  p = 1 internal power is on, 0 the power is off
LCD_CMD_SHIFT_CTRL	EQU	0x10
LCD_CMD_MODEPWR_CTRL	EQU	0x13
LCD_MODE_GRAPHICS	EQU	0x08
LCD_MODE_CHAR		EQU	0x00
LCD_DCDC_ON		EQU	0x04
LCD_DCDC_OFF		EQU	0x00
ENDIF

;LCD Command Function Set =  001dnfxx
;  d = 1 for 8-bit interface or 0 for 4-bit interface
;  n = for 2 line displays, n=1 allows both lines to be displayed while n=0 only allows the first.
;  f = font size. f=1 is for 5x11 dots while f=0 is for 5x8 dots.

LCD_CMD_FUNC_SET	EQU	0x20			; LCD Command "Function Set"
LCD_4bit_MODE		EQU	0x00			; d=0
LCD_8bit_MODE		EQU	0x10			; d=1
LCD_1_LINE		EQU	0x00			; n=0
LCD_2_LINES		EQU	0x08			; n=1
LCD_SMALL_FONT		EQU	0x00			; f=0
LCD_LARGE_FONT		EQU	0x04			; f=1
IFDEF	OLED_DISPLAY
LCD_FONT_ENGLISH_JAPANESE	EQU	0x0
LCD_FONT_WESTERN_EUROPEAN1	EQU	0x1
LCD_FONT_ENGLISH_RUSSIAN	EQU	0x2
LCD_FONT_WESTERN_EUROPEAN2	EQU	0x3
ENDIF

;LCD Command "Entry Mode" = 000001is
;  i = 1 to increment or 0 to decrement the DDRAM address after each DDRAM access.
;  s = 1 to scroll the display in the direction specified by the i-bit when the
;        cursor reaches the edge of the display window.

LCD_CMD_ENTRY_MODE	EQU	0x04			; LCD Command "Entry Mode"
LCD_DEC_CURSOR_POS	EQU	0x00			; i=0
LCD_INC_CURSOR_POS	EQU	0x02			; i=1
LCD_NO_SCROLL		EQU	0x00			; s=0
LCD_SCROLL		EQU	0x01			; s=1

;LCD Command "Set Display Data RAM Address" = 10000000

LCD_CMD_SET_DDRAM	EQU	0x80
LCD_CMD_SET_CGRAM	EQU	0x40

;LCD Module DDRAM Address is formed by adding the row and column EQU
SCR_ROW0		EQU	0x00			; Row 0 starts at LCD DDRAM Address 0
SCR_ROW1		EQU	0x40			; Row 1     "            "          64
SCR_ROW2		EQU	0x14			; Row 2     "            "          20
SCR_ROW3		EQU	0x54			; Row 3     "            "          84

SCR_COL0		EQU	0x00

