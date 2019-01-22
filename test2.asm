        list    p=16F874,t=ON,c=132,n=80
        title   "Adagio Front Panel redesign"
        radix   dec
;********************************************************************************
	include "p16f874.inc"
	include <coff.inc>

;	4 MHz ceramic resonator
	__CONFIG _XT_OSC & _WDT_OFF & _PWRTE_ON & _BODEN_OFF & _LVP_ON & _CPD_ON & _WRT_ON & _DEBUG_OFF & _CP_OFF
	ERRORLEVEL -302 ;remove message about using proper bank

	#define	START_OF_RAM_1	0x20
	#define	END_OF_RAM_1	0x7f
	#define	START_OF_RAM_2	0xa0
	#define	END_OF_RAM_2	0xff

	cblock  START_OF_RAM_1
; General registers
                _mr_loop1, _mr_loop2, _main_loop
	endc

; processor reset vector
	org		0x000
		clrwdt						; Clear the watchdog timer.
		CLRF   INTCON					; Disable all interrupts
		CLRF   PCLATH
		goto	main

;***********************************************************************
main
	CALL    init_mpu				; MPU Initialisation

        CLRWDT
	BCF     STATUS, RP1
	BCF     STATUS, RP0

main_loop
        BSF     PORTC, 0x1				; Light 'online' LED

        MOVLW   0xff
        MOVWF   _main_loop				; Setup loop counter
main_loop_on
        CALL    waste_time
        DECFSZ  _main_loop, 0x1
        GOTO    main_loop_on

        BCF     PORTC, 0x1                              ; Extinguish 'online' LED

        MOVLW   0xff
        MOVWF   _main_loop				; Setup loop counter
main_loop_off
        CALL    waste_time
        DECFSZ  _main_loop, 0x1
        GOTO    main_loop_off

	GOTO	main_loop

;***********************************************************************

;***********************************************************************
; Initialisation routines
;***********************************************************************
; Initialise MPU
init_mpu
	banksel	PCON
	bsf	PCON,NOT_POR
	bsf	PCON,NOT_BOR

	BCF     STATUS, RP1
	BCF     STATUS, RP0
	CLRWDT

	MOVLW   0x07					; (OLD CODE: Startup for Main CPU board?)
	MOVWF   PORTB

	MOVLW   0x20
	MOVLW   0x05					; These are reduntant (don't know why they are in the original code)

	MOVLW   0x00
	MOVWF   PIR1					; Reset registers
	MOVWF   PIR2
	MOVWF   TMR1L
	MOVWF   TMR1H
	MOVWF   TMR2
	MOVWF   T1CON
	MOVWF   CCPR1L
	MOVWF   CCPR1H
	MOVWF   RCSTA
	MOVWF   ADCON0
	MOVWF   CCP1CON
	MOVWF   CCP2CON

	MOVLW   0x05
	MOVWF   T2CON					; Set Timer2 on, with prescalar of 4

	BSF     STATUS, RP0
	MOVLW   0x19
	MOVWF   TRISC					; Configure PORTC (Inputs: 0,3,4 | Outputs: 1,2,5,6,7)
	BCF     STATUS, RP0

init_mpu_configure_ports
	BSF     STATUS, RP0
	MOVLW   0xef
	MOVWF   TRISA					; Configure PORTA (Inputs: 0,1,2,3,5,6,7 | Outputs: 4)
	BSF     STATUS, RP0
	MOVLW   0xf7
	MOVWF   TRISB					; Configure PORTB (Inputs: 0,1,2,4,5,6,7 | Outputs: 3)
	MOVLW   0x1d
	MOVWF   TRISC					; Configure PORTC (Inputs: 0,2,3,4 | Outputs: 1,5,6,7)
	MOVLW   0x00
	MOVWF   PIE1
	MOVWF   PIE2
	MOVWF   TXSTA
	MOVWF   SPBRG
	MOVWF   TRISE					; Configure PORTE (Inputs: | Outputs: 0,1,2,3,4,5,6,7 )
	MOVLW   0xff
	MOVWF   TRISD					; Configure PORTD (Inputs: 0,1,2,3,4,5,6,7 | Outputs: )
	MOVWF   PR2
	MOVLW   0x01
	MOVWF   OPTION_REG
	MOVLW   0x06
	MOVWF   ADCON1
	BCF     STATUS, RP0
	MOVLW   0x00
	MOVWF   PORTC
	MOVWF   PORTE

	BSF     PORTC, 0x1				; Light 'online' LED

	return

;***********************************************************************
; this function looks like it just wastes machine cycles (Old Code)
waste_time
	movlw   0x0c
	movwf   _mr_loop1                               ; _mr_loop1 = 12
	goto    waste_time_j1
	movlw   0x01
	movwf   _mr_loop1                               ; _mr_loop1 = 01
	goto    waste_time_j1
waste_time_j1
	movlw   0x00
	movwf   _mr_loop2                               ; _mr_loop2 = 0
waste_time_l1
	decfsz  _mr_loop2, 0x1
	goto    waste_time_l1
	decfsz  _mr_loop1, 0x1
	goto    waste_time_l1
	return

        END

;# Function
;2000:  3fff  dw      0x3fff
;2001:  3fff  dw      0x3fff
;2002:  3fff  dw      0x3fff
;2003:  3fff  dw      0x3fff
;2007:  3ff5  dw      0x3ff5
;2100:  01    db      0x01
;2101:  00    db      0x00
;2102:  ff    db      0xff
;2103:  00    db      0x00
;2104:  00    db      0x00
;2105:  00    db      0x00
;2106:  ff    db      0xff
;2107:  00    db      0x00
;2108:  0a    db      0x0a
;2109:  00    db      0x00
;210a:  14    db      0x14
;210b:  00    db      0x00
;210c:  0a    db      0x0a
;210d:  00    db      0x00
;210e:  01    db      0x01
;210f:  00    db      0x00
;2110:  ff    db      0xff
;2111:  00    db      0x00
;2112:  ff    db      0xff
;2113:  00    db      0x00
;2114:  ff    db      0xff
;2115:  00    db      0x00
;2116:  e0    db      0xe0
;2117:  00    db      0x00
;2118:  e0    db      0xe0
;2119:  00    db      0x00
;211a:  ff    db      0xff
;211b:  00    db      0x00
;211c:  ff    db      0xff
;211d:  00    db      0x00
;211e:  00    db      0x00
;211f:  00    db      0x00
;2120:  ce    db      0xce
;2121:  00    db      0x00
;2122:  30    db      0x30                                   ; '0'
;2123:  00    db      0x00
;2124:  00    db      0x00
;2125:  00    db      0x00
;2126:  60    db      0x60                                   ; '`'
;2127:  00    db      0x00
;2128:  80    db      0x80
;2129:  00    db      0x00
;212a:  eb    db      0xeb
;212b:  00    db      0x00
;212c:  14    db      0x14
;212d:  00    db      0x00
;212e:  00    db      0x00
;212f:  00    db      0x00
;2130:  62    db      0x62                                   ; 'b'
;2131:  00    db      0x00
;2132:  1b    db      0x1b
;2133:  00    db      0x00
;2134:  00    db      0x00
;2135:  00    db      0x00
;2136:  38    db      0x38                                   ; '8'
;2137:  00    db      0x00
;2138:  01    db      0x01
;2139:  00    db      0x00
;213a:  06    db      0x06
;213b:  00    db      0x00
;213c:  08    db      0x08
;213d:  00    db      0x00
;213e:  0c    db      0x0c
;213f:  00    db      0x00
;2140:  14    db      0x14
;2141:  00    db      0x00
;2142:  1b    db      0x1b
;2143:  00    db      0x00
;2144:  00    db      0x00
;2145:  00    db      0x00
;2146:  80    db      0x80
;2147:  00    db      0x00
;2148:  1b    db      0x1b
;2149:  00    db      0x00
;214a:  01    db      0x01
;214b:  00    db      0x00
;214c:  20    db      0x20                                   ; '*'
;214d:  00    db      0x00
;214e:  20    db      0x20                                   ; '*'
;214f:  00    db      0x00
;2150:  20    db      0x20                                   ; '*'
;2151:  00    db      0x00
;2152:  20    db      0x20                                   ; '*'
;2153:  00    db      0x00
;2154:  20    db      0x20                                   ; '*'
;2155:  00    db      0x00
;2156:  20    db      0x20                                   ; '*'
;2157:  00    db      0x00
;2158:  20    db      0x20                                   ; '*'
;2159:  00    db      0x00
;215a:  20    db      0x20                                   ; '*'
;215b:  00    db      0x00
;215c:  20    db      0x20                                   ; '*'
;215d:  00    db      0x00
;215e:  20    db      0x20                                   ; '*'
;215f:  00    db      0x00
;2160:  20    db      0x20                                   ; '*'
;2161:  00    db      0x00
;2162:  20    db      0x20                                   ; '*'
;2163:  00    db      0x00
;2164:  20    db      0x20                                   ; '*'
;2165:  00    db      0x00
;2166:  20    db      0x20                                   ; '*'
;2167:  00    db      0x00
;2168:  20    db      0x20                                   ; '*'
;2169:  00    db      0x00
;216a:  20    db      0x20                                   ; '*'
;216b:  00    db      0x00
;216c:  20    db      0x20                                   ; '*'
;216d:  00    db      0x00
;216e:  20    db      0x20                                   ; '*'
;216f:  00    db      0x00
;2170:  20    db      0x20                                   ; '*'
;2171:  00    db      0x00
;2172:  20    db      0x20                                   ; '*'
;2173:  00    db      0x00
;2174:  20    db      0x20                                   ; ' '
;2175:  00    db      0x00
;2176:  20    db      0x20                                   ; ' '
;2177:  00    db      0x00
;2178:  20    db      0x20                                   ; ' '
;2179:  00    db      0x00
;217a:  20    db      0x20                                   ; ' '
;217b:  00    db      0x00
;217c:  20    db      0x20                                   ; ' '
;217d:  00    db      0x00
;217e:  20    db      0x20                                   ; ' '
;217f:  00    db      0x00
;2140:  20    db      0x20                                   ; ' '
;2140:  00    db      0x00
;2141:  53    db      0x53                                   ; 'S'
;2141:  00    db      0x00
;2142:  65    db      0x65                                   ; 'e'
;2142:  00    db      0x00
;2143:  72    db      0x72                                   ; 'r'
;2143:  00    db      0x00
;2144:  76    db      0x76                                   ; 'v'
;2144:  00    db      0x00
;2145:  65    db      0x65                                   ; 'e'
;2145:  00    db      0x00
;2146:  72    db      0x72                                   ; 'r'
;2146:  00    db      0x00
;2147:  20    db      0x20                                   ; ' '
;2147:  00    db      0x00
;2148:  20    db      0x20                                   ; ' '
;2148:  00    db      0x00
;2149:  20    db      0x20                                   ; ' '
;2149:  00    db      0x00
;214a:  20    db      0x20                                   ; ' '
;214a:  00    db      0x00
;214b:  20    db      0x20                                   ; ' '
;214b:  00    db      0x00
;214c:  20    db      0x20                                   ; ' '
;214c:  00    db      0x00
;214d:  20    db      0x20                                   ; ' '
;214d:  00    db      0x00
;214e:  1b    db      0x1b
;214e:  00    db      0x00
;214f:  00    db      0x00
;214f:  00    db      0x00
;2150:  c0    db      0xc0
;2150:  00    db      0x00
;2151:  1b    db      0x1b
;2151:  00    db      0x00
;2152:  01    db      0x01
;2152:  00    db      0x00
;2153:  20    db      0x20                                   ; ' '
;2153:  00    db      0x00
;2154:  20    db      0x20                                   ; ' '
;2154:  00    db      0x00
;2155:  20    db      0x20                                   ; ' '
;2155:  00    db      0x00
;2156:  20    db      0x20                                   ; ' '
;2156:  00    db      0x00
;2157:  41    db      0x41                                   ; 'A'
;2157:  00    db      0x00
;2158:  64    db      0x64                                   ; 'd'
;2158:  00    db      0x00
;2159:  61    db      0x61                                   ; 'a'
;2159:  00    db      0x00
;215a:  67    db      0x67                                   ; 'g'
;215a:  00    db      0x00
;215b:  69    db      0x69                                   ; 'i'
;215b:  00    db      0x00
;215c:  6f    db      0x6f                                   ; 'o'
;215c:  00    db      0x00
;215d:  20    db      0x20                                   ; ' '
;215d:  00    db      0x00
;215e:  41    db      0x41                                   ; 'A'
;215e:  00    db      0x00
;215f:  75    db      0x75                                   ; 'u'
;215f:  00    db      0x00
;2160:  64    db      0x64                                   ; 'd'
;2160:  00    db      0x00
;2161:  69    db      0x69                                   ; 'i'
;2161:  00    db      0x00
;2162:  6f    db      0x6f                                   ; 'o'
;2162:  00    db      0x00
;2163:  20    db      0x20                                   ; ' '
;2163:  00    db      0x00
;2164:  20    db      0x20                                   ; ' '
;2164:  00    db      0x00
;2165:  20    db      0x20                                   ; ' '
;2165:  00    db      0x00
;2166:  20    db      0x20                                   ; ' '
;2166:  00    db      0x00
;2167:  20    db      0x20                                   ; ' '
;2167:  00    db      0x00
;2168:  20    db      0x20                                   ; ' '
;2168:  00    db      0x00
;2169:  20    db      0x20                                   ; ' '
;2169:  00    db      0x00
;216a:  20    db      0x20                                   ; ' '
;216a:  00    db      0x00
;216b:  20    db      0x20                                   ; ' '
;216b:  00    db      0x00
;216c:  20    db      0x20                                   ; ' '
;216c:  00    db      0x00
;216d:  20    db      0x20                                   ; ' '
;216d:  00    db      0x00
;216e:  20    db      0x20                                   ; ' '
;216e:  00    db      0x00
;216f:  20    db      0x20                                   ; ' '
;216f:  00    db      0x00
;2170:  20    db      0x20                                   ; ' '
;2170:  00    db      0x00
;2171:  20    db      0x20                                   ; ' '
;2171:  00    db      0x00
;2172:  20    db      0x20                                   ; ' '
;2172:  00    db      0x00
;2173:  20    db      0x20                                   ; ' '
;2173:  00    db      0x00
;2174:  20    db      0x20                                   ; ' '
;2174:  00    db      0x00
;2175:  20    db      0x20                                   ; ' '
;2175:  00    db      0x00
;2176:  20    db      0x20                                   ; ' '
;2176:  00    db      0x00
;2177:  20    db      0x20                                   ; ' '
;2177:  00    db      0x00
;2178:  20    db      0x20                                   ; ' '
;2178:  00    db      0x00
;2179:  20    db      0x20                                   ; ' '
;2179:  00    db      0x00
;217a:  20    db      0x20                                   ; ' '
;217a:  00    db      0x00
;217b:  00    db      0x00
;217b:  00    db      0x00
;217c:  00    db      0x00
;217c:  00    db      0x00
;217d:  00    db      0x00
;217d:  00    db      0x00
;217e:  00    db      0x00
;217e:  00    db      0x00
;217f:  00    db      0x00
;217f:  00    db      0x00
