;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Button Codes
;
; Button code to function translation table. The button
; code (in W) is added to the start of the table to get
; the function value.
;
; This has to be editted for a particular remote.
; This setup is for an Avermedia RC.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	org	0xEFF				; Locate the table at the end of the memory space (so it's at a fixed position)
						; This is a VERY!!! fixed position, so that we don't roll over on the add
ir_receiver_bc_2_cmd_table
	addwf	PCL, F				; Increment the program counter using button code to get the command value

; Comand code 0
	retlw   CMD_POWER			; 'Power'
; Comand code 1
	retlw   CMD_CDHD			; 'Source'
; Comand code 2
	retlw   CMD_NONE
; Comand code 3
	retlw   CMD_ALT5			; 'Teletext'
; Comand code 4
	retlw   CMD_ALT6			; 'EPG'
; Comand code 5
	retlw   CMD_1				; '1'
; Comand code 6
	retlw   CMD_2				; '2'
; Comand code 7
	retlw   CMD_3				; '3'
; Comand code 8
	retlw   CMD_AUDIO			; 'Audio'
; Comand code 9
	retlw   CMD_4				; '4'
; Comand code 10
	retlw   CMD_5				; '5'
; Comand code 11
	retlw   CMD_6				; '6'
; Comand code 12
	retlw   CMD_SELECT			; 'FullScreen'
; Comand code 13
	retlw   CMD_7				; '7'
; Comand code 14
	retlw   CMD_8				; '8'
; Comand code 15
	retlw   CMD_9				; '9'
; Comand code 16
	retlw   CMD_ALT4			; '16 Chan Prev'
; Comand code 17
	retlw   CMD_0				; '0'
; Comand code 18
	retlw   CMD_ALT1			; 'L'
; Comand code 19
	retlw   CMD_ALT2			; 'R'
; Comand code 20
	retlw   CMD_MUTE			; 'Mute'
; Comand code 21
	retlw   CMD_MODE			; 'Menu'
; Comand code 22
	retlw   CMD_NONE
; Comand code 23
	retlw   CMD_ALT3			; 'SnapShot'
; Comand code 24
	retlw   CMD_PLAY			; 'Play'
; Comand code 25
	retlw   CMD_RECORD			; 'Record'
; Comand code 26
	retlw   CMD_PAUSE			; 'Pause'
; Comand code 27
	retlw   CMD_STOP			; 'Stop'
; Comand code 28
	retlw   CMD_NEXT			; '>>'
; Comand code 29
	retlw   CMD_PREVIOUS			; '<<'
; Comand code 30
	retlw   CMD_LEFT			; 'Volume Down'
; Comand code 31
	retlw   CMD_RIGHT			; 'Volume Up'
; Comand code 32
	retlw   CMD_NONE
; Comand code 33
	retlw   CMD_NONE
; Comand code 34
	retlw   CMD_NONE
; Comand code 35
	retlw   CMD_NONE
; Comand code 36
	retlw   CMD_NONE
; Comand code 37
	retlw   CMD_NONE
; Comand code 38
	retlw   CMD_NONE
; Comand code 39
	retlw   CMD_NONE
; Comand code 40
	retlw   CMD_NONE
; Comand code 41
	retlw   CMD_NONE
; Comand code 42
	retlw   CMD_NONE
; Comand code 43
	retlw   CMD_NONE
; Comand code 44
	retlw   CMD_NONE
; Comand code 45
	retlw   CMD_NONE
; Comand code 46
	retlw   CMD_NONE
; Comand code 47
	retlw   CMD_NONE
; Comand code 48
	retlw   CMD_NONE
; Comand code 49
	retlw   CMD_NONE
; Comand code 50
	retlw   CMD_NONE
; Comand code 51
	retlw   CMD_NONE
; Comand code 52
	retlw   CMD_NONE
; Comand code 53
	retlw   CMD_NONE
; Comand code 54
	retlw   CMD_NONE
; Comand code 55
	retlw   CMD_NONE
; Comand code 56
	retlw   CMD_NONE
; Comand code 57
	retlw   CMD_NONE
; Comand code 58
	retlw   CMD_NONE
; Comand code 59
	retlw   CMD_NONE
; Comand code 60
	retlw   CMD_NONE
; Comand code 61
	retlw   CMD_NONE
; Comand code 62
	retlw   CMD_NONE
; Comand code 63
	retlw   CMD_NONE
; Comand code 64
	retlw   CMD_FASTFOWARD			; '>>|'
; Comand code 65
	retlw   CMD_REWIND			; '|<<'
; Comand code 66
	retlw   CMD_DOWN			; 'Channel Down'
; Comand code 67
	retlw   CMD_UP				; 'Channel Up'
; Comand code 68
	retlw   CMD_NONE
; Comand code 69
	retlw   CMD_NONE
; Comand code 70
	retlw   CMD_NONE
; Comand code 71
	retlw   CMD_NONE
; Comand code 72
	retlw   CMD_NONE
; Comand code 73
	retlw   CMD_NONE
; Comand code 74
	retlw   CMD_NONE
; Comand code 75
	retlw   CMD_NONE
; Comand code 76
	retlw   CMD_NONE
; Comand code 77
	retlw   CMD_NONE
; Comand code 78
	retlw   CMD_NONE
; Comand code 79
	retlw   CMD_NONE
; Comand code 80
	retlw   CMD_NONE
; Comand code 81
	retlw   CMD_NONE
; Comand code 82
	retlw   CMD_NONE
; Comand code 83
	retlw   CMD_NONE
; Comand code 84
	retlw   CMD_NONE
; Comand code 85
	retlw   CMD_NONE
; Comand code 86
	retlw   CMD_NONE
; Comand code 87
	retlw   CMD_NONE
; Comand code 88
	retlw   CMD_NONE
; Comand code 89
	retlw   CMD_NONE
; Comand code 90
	retlw   CMD_NONE
; Comand code 91
	retlw   CMD_NONE
; Comand code 92
	retlw   CMD_NONE
; Comand code 93
	retlw   CMD_NONE
; Comand code 94
	retlw   CMD_NONE
; Comand code 95
	retlw   CMD_NONE
; Comand code 96
	retlw   CMD_NONE
; Comand code 97
	retlw   CMD_NONE
; Comand code 98
	retlw   CMD_NONE
; Comand code 99
	retlw   CMD_NONE
; Comand code 100
	retlw   CMD_NONE
; Comand code 101
	retlw   CMD_NONE
; Comand code 102
	retlw   CMD_NONE
; Comand code 103
	retlw   CMD_NONE
; Comand code 104
	retlw   CMD_NONE
; Comand code 105
	retlw   CMD_NONE
; Comand code 106
	retlw   CMD_NONE
; Comand code 107
	retlw   CMD_NONE
; Comand code 108
	retlw   CMD_NONE
; Comand code 109
	retlw   CMD_NONE
; Comand code 110
	retlw   CMD_NONE
; Comand code 111
	retlw   CMD_NONE
; Comand code 112
	retlw   CMD_NONE
; Comand code 113
	retlw   CMD_NONE
; Comand code 114
	retlw   CMD_NONE
; Comand code 115
	retlw   CMD_NONE
; Comand code 116
	retlw   CMD_NONE
; Comand code 117
	retlw   CMD_NONE
; Comand code 118
	retlw   CMD_NONE
; Comand code 119
	retlw   CMD_NONE
; Comand code 120
	retlw   CMD_NONE
; Comand code 121
	retlw   CMD_NONE
; Comand code 122
	retlw   CMD_NONE
; Comand code 123
	retlw   CMD_NONE
; Comand code 124
	retlw   CMD_NONE
; Comand code 125
	retlw   CMD_NONE
; Comand code 126
	retlw   CMD_NONE
; Comand code 127
	retlw   CMD_NONE
; Comand code 128
	retlw   CMD_NONE
; Comand code 129
	retlw   CMD_NONE
; Comand code 130
	retlw   CMD_NONE
; Comand code 131
	retlw   CMD_NONE
; Comand code 132
	retlw   CMD_NONE
; Comand code 133
	retlw   CMD_NONE
; Comand code 134
	retlw   CMD_NONE
; Comand code 135
	retlw   CMD_NONE
; Comand code 136
	retlw   CMD_NONE
; Comand code 137
	retlw   CMD_NONE
; Comand code 138
	retlw   CMD_NONE
; Comand code 139
	retlw   CMD_NONE
; Comand code 140
	retlw   CMD_NONE
; Comand code 141
	retlw   CMD_NONE
; Comand code 142
	retlw   CMD_NONE
; Comand code 143
	retlw   CMD_NONE
; Comand code 144
	retlw   CMD_NONE
; Comand code 145
	retlw   CMD_NONE
; Comand code 146
	retlw   CMD_NONE
; Comand code 147
	retlw   CMD_NONE
; Comand code 148
	retlw   CMD_NONE
; Comand code 149
	retlw   CMD_NONE
; Comand code 150
	retlw   CMD_NONE
; Comand code 151
	retlw   CMD_NONE
; Comand code 152
	retlw   CMD_NONE
; Comand code 153
	retlw   CMD_NONE
; Comand code 154
	retlw   CMD_NONE
; Comand code 155
	retlw   CMD_NONE
; Comand code 156
	retlw   CMD_NONE
; Comand code 157
	retlw   CMD_NONE
; Comand code 158
	retlw   CMD_NONE
; Comand code 159
	retlw   CMD_NONE
; Comand code 160
	retlw   CMD_NONE
; Comand code 161
	retlw   CMD_NONE
; Comand code 162
	retlw   CMD_NONE
; Comand code 163
	retlw   CMD_NONE
; Comand code 164
	retlw   CMD_NONE
; Comand code 165
	retlw   CMD_NONE
; Comand code 166
	retlw   CMD_NONE
; Comand code 167
	retlw   CMD_NONE
; Comand code 168
	retlw   CMD_NONE
; Comand code 169
	retlw   CMD_NONE
; Comand code 170
	retlw   CMD_NONE
; Comand code 171
	retlw   CMD_NONE
; Comand code 172
	retlw   CMD_NONE
; Comand code 173
	retlw   CMD_NONE
; Comand code 174
	retlw   CMD_NONE
; Comand code 175
	retlw   CMD_NONE
; Comand code 176
	retlw   CMD_NONE
; Comand code 177
	retlw   CMD_NONE
; Comand code 178
	retlw   CMD_NONE
; Comand code 179
	retlw   CMD_NONE
; Comand code 180
	retlw   CMD_NONE
; Comand code 181
	retlw   CMD_NONE
; Comand code 182
	retlw   CMD_NONE
; Comand code 183
	retlw   CMD_NONE
; Comand code 184
	retlw   CMD_NONE
; Comand code 185
	retlw   CMD_NONE
; Comand code 186
	retlw   CMD_NONE
; Comand code 187
	retlw   CMD_NONE
; Comand code 188
	retlw   CMD_NONE
; Comand code 189
	retlw   CMD_NONE
; Comand code 190
	retlw   CMD_NONE
; Comand code 191
	retlw   CMD_NONE
; Comand code 192
	retlw   CMD_NONE
; Comand code 193
	retlw   CMD_NONE
; Comand code 194
	retlw   CMD_NONE
; Comand code 195
	retlw   CMD_NONE
; Comand code 196
	retlw   CMD_NONE
; Comand code 197
	retlw   CMD_NONE
; Comand code 198
	retlw   CMD_NONE
; Comand code 199
	retlw   CMD_NONE
; Comand code 200
	retlw   CMD_NONE
; Comand code 201
	retlw   CMD_NONE
; Comand code 202
	retlw   CMD_NONE
; Comand code 203
	retlw   CMD_NONE
; Comand code 204
	retlw   CMD_NONE
; Comand code 205
	retlw   CMD_NONE
; Comand code 206
	retlw   CMD_NONE
; Comand code 207
	retlw   CMD_NONE
; Comand code 208
	retlw   CMD_NONE
; Comand code 209
	retlw   CMD_NONE
; Comand code 210
	retlw   CMD_NONE
; Comand code 211
	retlw   CMD_NONE
; Comand code 212
	retlw   CMD_NONE
; Comand code 213
	retlw   CMD_NONE
; Comand code 214
	retlw   CMD_NONE
; Comand code 215
	retlw   CMD_NONE
; Comand code 216
	retlw   CMD_NONE
; Comand code 217
	retlw   CMD_NONE
; Comand code 218
	retlw   CMD_NONE
; Comand code 219
	retlw   CMD_NONE
; Comand code 220
	retlw   CMD_NONE
; Comand code 221
	retlw   CMD_NONE
; Comand code 222
	retlw   CMD_NONE
; Comand code 223
	retlw   CMD_NONE
; Comand code 224
	retlw   CMD_NONE
; Comand code 225
	retlw   CMD_NONE
; Comand code 226
	retlw   CMD_NONE
; Comand code 227
	retlw   CMD_NONE
; Comand code 228
	retlw   CMD_NONE
; Comand code 229
	retlw   CMD_NONE
; Comand code 230
	retlw   CMD_NONE
; Comand code 231
	retlw   CMD_NONE
; Comand code 232
	retlw   CMD_NONE
; Comand code 233
	retlw   CMD_NONE
; Comand code 234
	retlw   CMD_NONE
; Comand code 235
	retlw   CMD_NONE
; Comand code 236
	retlw   CMD_NONE
; Comand code 237
	retlw   CMD_NONE
; Comand code 238
	retlw   CMD_NONE
; Comand code 239
	retlw   CMD_NONE
; Comand code 240
	retlw   CMD_NONE
; Comand code 241
	retlw   CMD_NONE
; Comand code 242
	retlw   CMD_NONE
; Comand code 243
	retlw   CMD_NONE
; Comand code 244
	retlw   CMD_NONE
; Comand code 245
	retlw   CMD_NONE
; Comand code 246
	retlw   CMD_NONE
; Comand code 247
	retlw   CMD_NONE
; Comand code 248
	retlw   CMD_NONE
; Comand code 249
	retlw   CMD_NONE
; Comand code 250
	retlw   CMD_NONE
; Comand code 251
	retlw   CMD_NONE
; Comand code 252
	retlw   CMD_NONE
; Comand code 253
	retlw   CMD_NONE
; Comand code 254
	retlw   CMD_NONE
; Comand code 255
	retlw   CMD_NONE
