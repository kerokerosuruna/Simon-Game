.data
count:     .word 0
seed:      .word 1
play:      .string "\nDo you want to continue?\nClick up on the d-pad to continue.\nClick anything else to end the game.\n"
restart:   .string "\nGame over!\nDo you want to play again?\nClick up on the d-pad to play again.\nClick anything else to end the game.\n"

.globl main
.text

main:    
    # load the information
    mv s11, sp  # keep the top of the stack pointer for later
    jal genseed # generate the initial seed
    start:
        # load the count variable, and increment it by 1. Then store it for later
        la t6, count
        lw t5, count
        
        # increase count by 1 and store it so every round has 1 more light
        addi t5, t5, 1
        sw t5, 0(t6)
        
        # each time this runs we generate 1 random number and add it to the stack
        li a0, 4
        jal rand
        addi sp, sp, -1
        sb a0, 0(sp)

    mv t5, s11 #beginning of stack pointer, or in this case the sequence
    lights:
        addi t5, t5, -1 # next index (subtract once to get to first)
        lb t0, 0(t5) # load the value at the index
        andi a1, t0, 1 # sees if it is odd or even by looking at last bit
        andi a2, t0, 2 # sees if it is greater than 1 by looking at second last bit
        srli a2, a2, 1 # shifts everything over one spot to the right to get 0 or 1
        
        # store the positions for later use
        addi sp, sp, -1
        sb a2, 0(sp)
        addi sp, sp, -1
        sb a1, 0(sp)
        
        # set to blue
        li a0, 0x0000FF
        jal setLED
        
        # wait
        li a0, 500
        jal delay
        
        # get the led position again
        lb a1, 0(sp)
        addi sp, sp, 1
        lb a2, 0(sp)
        addi sp, sp, 1
        
        # set LED to black
        li a0, 0x000000
        jal setLED
        
        beq t5, sp, continue #check to see if we haave reached the stack pointer, which is the last led
        # wait
        li a0, 750
        jal delay
        j lights # there are more leds, loop over
        
    continue: # this runs only once after we finish displaying the sequence
        # do one last small delay for the fans
        li a0 750
        # flash to indicate that it is time to start inputting
        jal delay
        li a1, 0
        li a2, 0
        li a0 0x0000FF
        jal setLED
        li a2, 1
        jal setLED
        li a1, 1
        jal setLED
        li a2, 0
        jal setLED
        li a0 1000
        jal delay
        
        li a1, 0
        li a2, 0
        li a0 0x000000
        jal setLED
        li a2, 1
        jal setLED
        li a1, 1
        jal setLED
        li a2, 0
        jal setLED
        
        li a0 10
        jal delay
        mv t5, s11

    input:
        jal pollDpad  # get input
        addi t5, t5, -1 # move to next index
        lb t0, 0(t5)  # load the current place in the sequence
        
        # light up led to show correct
        andi a1, a0, 1 #check if odd
        andi a2, a0, 2 # check row
        srli a2, a2, 1 # shifts everything over one spot to the right to get 0 or 1
        
        # store a1 and a2 so we dont lost the values in delays
        # this is set up for both this branch and the wrong branch
        addi sp, sp, -1
        sb a2, 0(sp)
        addi sp, sp, -1
        sb a1, 0(sp)
        
        bne a0, t0, wrong  # check if it matches input
        
        li a0, 0xCCFF00
        jal setLED
        
        li a0, 150
        jal delay
        
        lb a1, 0(sp)
        addi sp, sp, 1
        lb a2, 0(sp)
        addi sp, sp, 1   
        li a0, 0x000000
        jal setLED
        
        li a0, 10
        jal delay
        
        beq t5, sp, correct # check to see if we have gone far enough
        j input
    
    wrong:
        # set the led they clicked to red, ask to play again     
        li a0, 0xFF0000
        jal setLED
        
        li a0, 500
        jal delay
        
        lb a1, 0(sp)
        addi sp, sp, 1
        lb a2, 0(sp)
        addi sp, sp, 1
        
        li a0, 0x000000
        jal setLED
        
        mv sp, s11
        la t6, count
        li t5, 0
        sw t5, 0(t6)
        
        li a7, 4
        la a0, restart
        ecall
        jal pollDpad
        beqz a0, start
        
    correct:
        # hard coding this command, we are setting every light
        li a1, 0
        li a2, 0
        li a0 0xccff00
        jal setLED
        li a2, 1
        jal setLED
        li a1, 1
        jal setLED
        li a2, 0
        jal setLED
        li a0 500
        jal delay
        
        li a1, 0
        li a2, 0
        li a0 0x000000
        jal setLED
        li a2, 1
        jal setLED
        li a1, 1
        jal setLED
        li a2, 0
        jal setLED
        #lw a0, count
        #addi a0, a0, 1
        #la a1, count
        #sw a1, 0(a0)
        j playagain
    
    playagain:
        li a7, 4
        la a0, play
        ecall
        jal pollDpad
        beqz a0, start

exit:
    mv sp, s11
    li a7, 10
    ecall
    
    
# --- HELPER FUNCTIONS ---
     
# Takes in the number of milliseconds to wait (in a0) before returning
delay:
    mv t0, a0
    li a7, 30
    ecall
    mv t1, a0
delayLoop:
    ecall
    sub t2, a0, t1
    bgez t2, delayIfEnd
    addi t2, t2, -1
delayIfEnd:
    bltu t2, t0, delayLoop
    jr ra

# Takes in a number in a0, and returns a (sort of) random number from 0 to
# this number (exclusive)
rand:
    # XOR shifting pseudo random number generation
    mv t1, a0
    lw a0, seed
    slli t0, a0, 13
    xor a0, a0, t0
    srli t0, a0, 17
    xor a0, a0, t0
    slli t0, a0, 5
    xor a0, a0, t0
    
    la t0, seed
    sw a0, 0(t0) # the value we got will be the next seed
    
    remu a0, a0, t1 #modulo
    jr ra

genseed:
    mv t0, a0
    li a7, 30
    ecall
    la t0 seed
    beqz a0, fix
    sw a0 0(t0)
    jr ra
    fix: # we need a non zero seed. Both arent gonna be non zero unless its the epoch
        sw a1 0(t0)
        jr ra
    
# Takes in an RGB color in a0, an x-coordinate in a1, and a y-coordinate
# in a2. Then it sets the led at (x, y) to the given color.
setLED:
    li t1, LED_MATRIX_0_WIDTH
    mul t0, a2, t1
    add t0, t0, a1
    li t1, 4
    mul t0, t0, t1
    li t1, LED_MATRIX_0_BASE
    add t0, t1, t0
    sw a0, (0)t0
    jr ra
    
# Polls the d-pad input until a button is pressed, then returns a number
# representing the button that was pressed in a0.
# The possible return values are:
# 0: UP
# 1: DOWN
# 2: LEFT
# 3: RIGHT
pollDpad:
    mv a0, zero
    li t1, 4
pollLoop:
    bge a0, t1, pollLoopEnd
    li t2, D_PAD_0_BASE
    slli t3, a0, 2
    add t2, t2, t3
    lw t3, (0)t2
    bnez t3, pollRelease
    addi a0, a0, 1
    j pollLoop
pollLoopEnd:
    j pollDpad
pollRelease:
    lw t3, (0)t2
    bnez t3, pollRelease
pollExit:
    jr ra
