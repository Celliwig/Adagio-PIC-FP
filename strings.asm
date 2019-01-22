;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Strings
;
; This is a set of strings, packed into 14 bit program
; memory.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

		org	STR_PANEL_BASE_ADDR

str_panel_border_full		da	"********************\0"
str_panel_border_edges		da	"*                  *\0"
str_panel_title1		da	"PiAdagio Sound\0"
str_panel_title2		da	"Server\0"


		org	STR_TESTS_BASE_ADDR

str_tests_tmode0		TESTFP_TEST_LIST	TESTFP_OBJ_FLASH,0
str_tests_tmode1		TESTFP_TEST_LIST	TESTFP_OBJ_FLASH,1
str_tests_tmode2		TESTFP_TEST_LIST	TESTFP_OBJ_FLASH,2
str_tests_tmode3		TESTFP_TEST_LIST	TESTFP_OBJ_FLASH,3
str_tests_tmode4		TESTFP_TEST_LIST	TESTFP_OBJ_FLASH,4
str_tests_tmode5		TESTFP_TEST_LIST	TESTFP_OBJ_FLASH,5

str_tests_bank			da	"Bnk\0"				; Bank
str_tests_cmd			da	"Cmd:\0"			; Command
str_tests_err_cnt		da	"Err Cnt:\0"			; Error Count
str_tests_fp_cmd		da	"FP Cmd:\0"			; Front Panel Command
str_tests_not_avail		da	"Not Available\0"
str_tests_rcvd_addr		da	"Rcvd Addr:\0"			; Recieved Address
str_tests_rcvd_cmd		da	"Rcvd Cmd:\0"			; Recieved Command
str_tests_backlight		da	"Backlight\0"
str_tests_contrast		da	"Contrast\0"

str_tests_lcd_line1		da	"ABCDEFGHIJKLMNOPQRST\0"	; LCD test data - line 1
str_tests_lcd_line2		da	"UVWXYZabcdefghijklmn\0"	; LCD test data - line 2
str_tests_lcd_line3		da	"opqrstuvwxyz01234567\0"	; LCD test data - line 3
str_tests_lcd_line4		da	"89[]{}()<>.,:?!+-*/=\0"	; LCD test data - line 4
