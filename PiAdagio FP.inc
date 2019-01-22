;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Modes selection bits
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

#define MODE_BIT_POWEROFF	0
#define MODE_BIT_POWERON	1
#define MODE_BIT_TESTFP		2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Mode values
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

#define	MODE_POWEROFF		(1<<MODE_BIT_POWEROFF)
#define	MODE_POWERON		(1<<MODE_BIT_POWERON)
#define	MODE_TESTFP		(1<<MODE_BIT_TESTFP)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Test mode values
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#define	TESTFP_NUM_TESTS	0x4				; Number of tests available

#define	TEST_STR_0		"Button Test\0"
#define	TEST_CODE_0		monkey_nuts

#define	TEST_STR_1		"LCD Test\0"
#define	TEST_CODE_1		monkey_nuts

#define	TESTFP_LIST_CODE	0x1
#define	TESTFP_LIST_EEPROM	0x2
#define	TESTFP_LIST_INDEX	0x3

TESTFP_LIST	macro	Object, Index
	if (Object == TESTFP_LIST_CODE)
		de	TEST_STR_#v(Index)
	endif
	if (Object == TESTFP_LIST_EEPROM)
		de	TEST_STR_#v(Index)
	endif
	if (Object == TESTFP_LIST_INDEX)
		de	TEST_STR_#v(Index)
	endif
	endm
