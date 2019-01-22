#define	PWRCTRL_NUM_CONTROLS	0x3				; Number of power controls

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Modes selection bits
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

#define MODE_BIT_POWEROFF	0
#define MODE_BIT_POWERON	1
#define MODE_BIT_TESTFP		2
#define MODE_BIT_POWERCTRL	3

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Mode values
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

#define	MODE_POWEROFF		(1<<MODE_BIT_POWEROFF)
#define	MODE_POWERON		(1<<MODE_BIT_POWERON)
#define	MODE_TESTFP		(1<<MODE_BIT_TESTFP)
#define	MODE_POWERCTRL		(1<<MODE_BIT_POWERCTRL)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Test mode values
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#define	TESTFP_NUM_TESTS	0x4				; Number of tests available

; List (and order) of tests
#define	TESTFP_TESTS_BUTTONS	0x0
#define	TESTFP_TESTS_LCD	0x1
#define	TESTFP_TESTS_IR		0x2
#define	TESTFP_TESTS_I2C	0x3

#define	TEST_STR_0		"Button Test\0"
#define	TEST_CODE_0		mode_testfp_test_buttons

#define	TEST_STR_1		"LCD Test\0"
#define	TEST_CODE_1		mode_testfp_test_lcd

#define	TEST_STR_2		"IR Test\0"
#define	TEST_CODE_2		mode_testfp_test_ir

#define	TEST_STR_3		"i2c Test\0"
#define	TEST_CODE_3		mode_testfp_test_i2c

#define	TESTFP_OBJ_CHECK	0x1
#define	TESTFP_OBJ_CODE		0x2
#define	TESTFP_OBJ_EEPROM	0x3

TESTFP_TEST_LIST	macro	Object, Index
	if (Object == TESTFP_OBJ_CHECK)
		sublw	#v(Index)
	endif
	if (Object == TESTFP_OBJ_CODE)
		call	TEST_CODE_#v(Index)
	endif
	if (Object == TESTFP_OBJ_EEPROM)
		de	TEST_STR_#v(Index)
	endif
	endm
