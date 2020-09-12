.include "m2560def.inc"

.equ PORTLDIR = 0xF0
.equ INITCOLMASK = 0xEF
.equ INITROWMASK = 0x01
.equ ROWMASK = 0x0F
.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4
.equ HOB_LABEL = 0b00100000		;high order bit for symbols
.equ HOB_NUM = 0b00110000		;high order bit for numbers
.equ HOB_CHAR = 0b01000000		;high order bit for characters

.def travellingCounter = r12	; stores the current station the monorail is up to (Resused for initialising)
.def passengers = r13			; flag to stop the monorail at the next station (COULD BE DATA)
.def travelling = r14			; flag to say that monorail is moving
.def temp = r16
.def keypad_flag = r17
.def mask = r18					; for keypad
.def temp2 = r19
.def row = r20
.def col = r21
.def stepFlag = r22				; flag to see what step the config is at (COULD BE DATA)
.def stationCount = r23			; stores the number of stations overall
.def travelTime = r24			; stores the time to travel between two stations
.def stationTime = r25			; stores the time to stop at each station (repurposing for keypad)

.dseg
.org 0x00
names: .byte 100
.org 0x110
travelTimes: .byte 10
.org 0x130
datatemp: .byte 10
.org 0x150
datatemp2: .byte 10

.cseg
	rjmp RESET

.macro travel
	;need timer here
	push r16
	ldi r16, 153
	sts OCR3BL, r16						; OC3B low register
	clr temp
	sts OCR3BH, temp						; 0C3B high register 
	delay_1s
	delay_1s
	clr r16
	sts OCR3BL, r16						; OC3B low register
	clr r16
	sts OCR3BH, r16						; 0C3B high register 
	pop r16
.endmacro

.macro clear
ldi YL, low(@0)						; load the memory address to Y pointer
ldi YH, high(@0)
clr temp							; set temp to 0
st Y+, temp							; clear the two bytes at @0 in SRAM
st Y, temp
.endmacro 

.macro do_lcd_command
ldi r16, @0
rcall lcd_command
rcall lcd_wait
.endmacro

.macro do_lcd_data_r
mov r16, @0
rcall lcd_data
rcall lcd_wait
.endmacro

.macro do_lcd_data
ldi r16, @0
rcall lcd_data
rcall lcd_wait
.endmacro

.macro lcd_set
sbi PORTA, @0
.endmacro

.macro lcd_clr
cbi PORTA, @0
.endmacro

.macro delay_1s
	rcall sleep_100ms
    rcall sleep_100ms
    rcall sleep_100ms
    rcall sleep_100ms
    rcall sleep_100ms
    rcall sleep_100ms
    rcall sleep_100ms
    rcall sleep_100ms
    rcall sleep_100ms
    rcall sleep_100ms
.endmacro

.macro delay_300ms
	rcall sleep_100ms
    rcall sleep_100ms
    rcall sleep_100ms
.endmacro

.macro delay_3hz
	rcall sleep_100ms
    rcall sleep_100ms
    rcall sleep_100ms
    rcall sleep_20ms
    rcall sleep_5ms
    rcall sleep_5ms
    rcall sleep_1ms
    rcall sleep_1ms
    rcall sleep_1ms
.endmacro

RESET:
    ldi xl, low(datatemp)
	ldi yl, low(datatemp2)

    ;clearing registers
    clr temp
	clr temp2
	clr row
	clr col
	clr mask
	clr travellingCounter
    clr stationCount
    clr travelTime
    clr stationTime
	clr stepFlag
    st X, temp
	st Y, temp


	; Stack Setup
	ldi temp, low(RAMEND)
    out SPL, temp
    ldi temp, high(RAMEND)
    out SPH, temp
    ;keypad ports
    ldi temp, PORTLDIR 					; columns are outputs, rows are inputs
    STS DDRL, temp     					; cannot use out
    ;LCD ports
    ser temp
    out DDRF, temp						;set F&A as output
    out DDRA, temp
    clr temp
    out PORTF, temp
    out PORTA, temp


    ; LED Setup
    ser temp 
    out DDRC, temp 
    clr temp 
    out DDRD, temp 
    out PORTD, temp

	; PWM Setup
	ser temp
    out DDRE, temp; set PORTE as output
  	clr temp ; this value and the operation mode determines the PWM duty cycle
    sts OCR3BL, temp;OC3B low register
    sts OCR3BH, temp;0C3B high register
    ldi temp, (1<<CS30) ; CS30 = 1: no prescaling
    sts TCCR3B, temp; set the prescaling value
    ldi temp, (1<<WGM30)|(1<<COM3B1)
    ; WGM30=1: phase correct PWM, 8 bits
    ;COM3B1=1: make OC3B override the normal port functionality of the I/O pin PE2
    sts TCCR3A, temp
    
    ; LCD Setup
    do_lcd_command 0b00111000 ; 2x5x7
    rcall sleep_5ms
    do_lcd_command 0b00111000 ; 2x5x7
    rcall sleep_1ms
    do_lcd_command 0b00111000 ; 2x5x7
    do_lcd_command 0b00111000 ; 2x5x7
    do_lcd_command 0b00001000 ; display off?
    do_lcd_command 0b00000001 ; clear display
    do_lcd_command 0b00000110 ; increment, no display shift
    do_lcd_command 0b00001110 ; Cursor on, bar, no blink

	do_lcd_data'M'
	do_lcd_data'O'
	do_lcd_data'N'
	do_lcd_data'O'
	delay_300ms
	delay_300ms
	do_lcd_command 0b00000001
	
	rcall step1
	rjmp keypad_loop


step1:
	do_lcd_command 0b00000001
    do_lcd_data 'S'
    do_lcd_data 'T'
    do_lcd_data 'A'
    do_lcd_data 'T'
    do_lcd_data ' '
    do_lcd_data 'N'
    do_lcd_data 'U'
    do_lcd_data 'M'
    do_lcd_data ':'
	ldi stepFlag, 1
    ret
    ;end step1
	
step2:
	push r25
	ldi r25, 48
	cp stationCount, travellingCounter
	breq prestep3
	inc travellingCounter
	add r25, travellingCounter
	do_lcd_command 0b00000001
	do_lcd_data 'S'
    do_lcd_data 'T'
    do_lcd_data 'A'
    do_lcd_data 'T'
	do_lcd_data_r r25
	do_lcd_data ':'
	ldi stepFlag, 2
	pop r25
	ret
	;end step2

prestep3:
	clr travellingCounter
	do_lcd_command 0b00000001
	do_lcd_data 'S'
    do_lcd_data 'T'
    do_lcd_data 'A'
    do_lcd_data 'Y'
	rjmp keypad_loop

keypad_loop:
  	rcall sleep_100ms
    rcall sleep_100ms
	rcall sleep_100ms
	rcall sleep_20ms

    end_clear:

    scan_start:
    ldi mask, INITCOLMASK ; initial column mask
    clr col ; initial column

    colloop:
    STS PORTL, mask ; set column to mask value
    ; (sets column 0 off)
    ldi temp, 0xFF ; implement a delay so the
    ; hardware can stabilize

    delay:
    dec temp
    brne delay
    LDS temp, PINL ; read PORTL. Cannot use in 
    andi temp, ROWMASK ; read only the row bits
    cpi temp, 0xF ; check if any rows are grounded
    breq nextcol ; if not go to the next column
    ldi mask, INITROWMASK ; initialise row check
    clr row ; initial row

    rowloop:      
    mov temp2, temp
    and temp2, mask ; check masked bit
    brne skipconv ; if the result is non-zero,
    ; we need to look again
    rcall convert ; if bit is clear, convert the bitcode
    jmp keypad_loop ; and start again

    skipconv:
    inc row ; else move to the next row
    lsl mask ; shift the mask to the next bit
    jmp rowloop          

    nextcol:     
    cpi col, 3 ; check if we are on the last column
    breq keypad_loop ; if so, no buttons were pushed,
    ; so start again.

    sec ; else shift the column mask:
    ; We must set the carry bit
    rol mask ; and then rotate left by a bit,
    ; shifting the carry into
    ; bit zero. We need this to make
    ; sure all the rows have
    ; pull-up resistors
    inc col ; increment column value
    jmp colloop ; and check the next column
    ; convert function converts the row and column given to a
    ; binary number and also outputs the value to PORTC.
    ; Inputs come from registers row and col and output is in
    ; temp.

convert:
	rcall sleep_1ms
	cpi col, 3 ;if col 3 then it hsa to be a letter
    breq letter
    cpi row, 3 ;if row 3 then either space, 0 or enter
    breq specialjmp 

	mov temp, row ; otherwise we have a number (1-9)
	lsl temp ; temp = row * 2
	add temp, row ; temp = row * 3
	add temp, col ; add the column address to get the offset from 1
	ldi col, 49   ; using as temp reg
	add temp, col ; add 1. Value of switch is row*3 + col + 1.
	do_lcd_data_r temp
	mov r25, temp
	clr temp
	rjmp keypad_loop

specialjmp:
	rjmp special

letter:
	cpi row, 0
	breq loop1f
	cpi row, 1
	breq loop2f
	cpi row, 2
	breq loop3f
	cpi row, 3
	breq loop4f

loop1f:
	ldi r25, 1
	rjmp loop1

loop2f:
	ldi r25, 2
	rjmp loop1

loop3f:
	ldi r25, 3
	rjmp loop1

loop4f:
	ldi r25, 4
	rjmp loop1

loop1:
	;x is counter
	rcall sleep_1ms
	ld r26, x ;load the saved counter from x
	cpi r26, 8 ;check if first cycle
	brge reloop ; reset values if first loop
	cpi r25, 4 ; check if last set of letters needed
	brne normal_check
	rjmp special_check
normal_check:
	cpi r26, 6
	breq reloop
	rjmp loop1_con
special_check:
	cpi r26, 8
	breq reloop
loop1_con:
	inc r26
	out PORTC, r26
	st x, r26
	rjmp keypad_loop

reloop:
	clr temp
	st x, temp ; r28 counter
	ret
	
skip_step:
	rjmp keypad_loop


special:
	cpi col, 0 ;check for star key
	brne check1
	rjmp star
check1:
	cpi col, 1 ;check for zero key
	brne check2
	rjmp zero
check2:
	cpi col, 2 ;check for hash key
	brne skip_step
	rjmp hash
	
	;code for star key
star:
	rcall sleep_1ms
	cpi stepFlag, 1			;if in step 1 then use as temporary enter key
	brne space
	subi r25, 48			;need to find new register to use
	mov stationCount, r25
	out PORTC, stationCount
	rcall step2
	rjmp keypad_loop 
space:
	push temp
	ldi temp, 31
	do_lcd_data_r temp
	clr temp
	pop temp
	rjmp keypad_loop
	
	;code for zero key
zero:
	rcall sleep_1ms
	push temp
	ldi temp, 48
	do_lcd_data_r temp
	clr temp
	pop temp
	rjmp keypad_loop
	
	;code for hash key
hash:
	rcall sleep_1ms		
	cpi r25, 1		;check if A is pressed
	brne loop2_hash
	ldi temp, 64
	rjmp do_hash
loop2_hash:			;check if B is pressed
	cpi r25, 2
	brne loop3_hash
	ldi temp, 70
	rjmp do_hash
loop3_hash:			;check if C is pressed
	cpi r25, 3
	brne loop4_hash
	ldi temp, 76
	rjmp do_hash
loop4_hash:			;check if D is pressed
	cpi r25, 4
	brne skip_step
	ldi temp, 82
do_hash:
	add temp, r26
    do_lcd_data_r temp
	clr r26
	clr temp
	out PORTC, r26
	rjmp keypad_loop
    
		;LCD commands/junk
lcd_command:
    out PORTF, r16
    nop
    lcd_set LCD_E
    nop
    nop
    nop
    lcd_clr LCD_E
    nop
    nop
    nop
    ret

lcd_data: 
    out PORTF, r16
    lcd_set LCD_RS
    nop
    nop
    nop
    lcd_set LCD_E
    nop
    nop
    nop
    lcd_clr LCD_E
    nop
    nop
    nop
    lcd_clr LCD_RS
    ret

lcd_wait:
    push r16
    clr r16
    out DDRF, r16
    out PORTF, r16
    lcd_set LCD_RW

lcd_wait_loop:
    nop
    lcd_set LCD_E
    nop
    nop
    nop
    in r16, PINF
    lcd_clr LCD_E
    sbrc r16, 7
    rjmp lcd_wait_loop
    lcd_clr LCD_RW
    ser r16
    out DDRF, r16
    pop r16
    ret
    
    .equ F_CPU = 16000000
    .equ DELAY_1MS = F_CPU / 4 / 1000 - 4
    ; 4 cycles per iteration - setup/call-return overhead

    sleep_1ms:
    push r24
    push r25
    ldi r25, high(DELAY_1MS)
    ldi r24, low(DELAY_1MS)
    delayloop_1ms:
    sbiw r25:r24, 1
    brne delayloop_1ms
    pop r25
    pop r24
    ret

    sleep_5ms:
    rcall sleep_1ms
    rcall sleep_1ms
    rcall sleep_1ms
    rcall sleep_1ms
    rcall sleep_1ms
    ret

    sleep_20ms:
    rcall sleep_5ms
    rcall sleep_5ms
    rcall sleep_5ms
    rcall sleep_5ms
    ret

    sleep_100ms:
    rcall sleep_20ms
    rcall sleep_20ms
    rcall sleep_20ms
    rcall sleep_20ms
    rcall sleep_20ms
    ret