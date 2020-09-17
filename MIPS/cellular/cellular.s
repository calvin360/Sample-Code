########################################################################
# COMP1521 20T2 --- assignment 1: a cellular automaton renderer
#
# Written by Calvin Lau, July 2020.

# Maximum and minimum values for the 3 parameters.

MIN_WORLD_SIZE  =    1
MAX_WORLD_SIZE  =  128
MIN_GENERATIONS = -256
MAX_GENERATIONS =  256
MIN_RULE    =    0
MAX_RULE    =  255

# Characters used to print alive/dead cells.

ALIVE_CHAR  = '#'
DEAD_CHAR   = '.'

# Maximum number of bytes needs to store all generations of cells.

MAX_CELLS_BYTES = (MAX_GENERATIONS + 1) * MAX_WORLD_SIZE

    .data

# `cells' is used to store successive generations.  Each byte will be 1
# if the cell is alive in that generation, and 0 otherwise.

cells:  .space MAX_CELLS_BYTES

# Some strings you'll need to use:

prompt_world_size:  .asciiz "Enter world size: "
error_world_size:   .asciiz "Invalid world size\n"
prompt_rule:        .asciiz "Enter rule: "
error_rule:     .asciiz "Invalid rule\n"
prompt_n_generations:   .asciiz "Enter how many generations: "
error_n_generations:    .asciiz "Invalid number of generations\n"

    .text
    # $s0 = world size
    # $s1 = rule
    # $s2 = n_generations
    # $s3 = reverse
    # $t0 = x
    # $t1 = left
    # $t2 = right
    # $t3 = state
    # $t4 = bit

main:
    sw     $fp, -4($sp)     # push $fp onto stack
    la     $fp, -4($sp)     # set up $fp for this function
    sw     $ra, -4($fp)     # save return address

    # getting world size
    la     $a0, prompt_world_size       # print
    li     $v0, 4
    syscall
    li     $v0, 5       # scan
    syscall
    bgt    $v0, MAX_WORLD_SIZE, end_invalid_world       # check if value is valid
    blt    $v0, MIN_WORLD_SIZE, end_invalid_world
    move   $s0, $v0     # world size

    # getting rule
    la     $a0, prompt_rule
    li     $v0, 4
    syscall
    li     $v0, 5
    syscall
    bgt    $v0, MAX_RULE, end_invalid_rule
    blt    $v0, MIN_RULE, end_invalid_rule
    move   $s1, $v0

    # getting generations
    la     $a0, prompt_n_generations
    li     $v0,4
    syscall
    li     $v0, 5
    syscall
    bgt    $v0, MAX_GENERATIONS, end_invalid_generations
    blt    $v0, MIN_GENERATIONS, end_invalid_generations
    blt    $v0, $0, invert_gen
    move   $s2, $v0
    li     $s3, 0
    li     $a0, '\n'    # print new line
    li     $v0, 11
    syscall
    b      cell0

invert_gen:
    neg    $s2, $v0
    li     $s3, 1   # set reverse bit
    li     $a0, '\n' 
    li     $v0, 11
    syscall
 # setting up array
cell0:
    # $s4 = address
    # $s5 = offset
    # $s6 = index i (row)
    # $s7 = index i (col)
    # $t6 = 2
    # $t7 = counter
    # offset = sizeof element*(row size*i+j)

    li     $t6, 2
    div    $t5, $s0, $t6    # find middle point
    la     $s4, cells       # set address
    li     $s7, 0           # set index col 
    sub    $t7, $s0, $t6

cell1:
    beq    $s7, $t5, middle
    bgt    $s7, $t7, running    # (needs to be 1 smaller because starting from 0)
    add    $s5, $s4, $s7        # add address and index col (mul index and size if size not 1)
    addi   $s7, $s7, 1  
    sb     $0, ($s5)
    j      cell1

 middle:
    li     $t5, 1 
    add    $s5, $s4, $s7    # add address and index col (mul index and size if size not 1)
    addi   $s7, $s7, 1  
    sb     $t5, ($s5)
    j      cell1

# big for loop
running:
    # using $t5 as a counter
    li    $s7, 0        # reseting col index
    addi  $s6, $s6, 1   # move row counter up by 1 after first line
    li    $t5, 1        # int g = 1
# generating all values first
jump_running:
    bgt   $t5, $s2, check_reverse
    jal   run_generation
    addi  $t5, $t5, 1   #incrementing counter after each run
    addi  $s6, $s6, 1
    li    $s7, 0        # reseting col index
    b     jump_running
# branching point to see if printing in reverse
check_reverse:
    li    $s6, 0        # reset row counter after loading values in
    bgt   $s3, $0 reverse_print
    li    $t5, -1       # offsetting the +1 for the first loop
# printing normally 
print_norm: 
    addi  $t5, $t5, 1
    bgt   $t5, $s2, end_main
    jal   print_generation
    addi  $s6, $s6, 1
    b     print_norm
# printing in reverse setup
reverse_print:
    move  $t5, $s2
    addi  $t5, $t5, 1
    li    $t0, 1
# printing in reverse
print_rev:
    sub   $t5, $t5, $t0
    blt   $t5, 0, end_main
    jal   print_generation 
    addi  $s6, $s6, 1
    b     print_rev
# ending program
end_main:
    # cleaning up stack frame
    lw    $ra, -4($fp)       # restore $ra for return
    la    $sp, 4($fp)        # restore $sp (remove stack frame)
    lw    $fp, ($fp)         # restore $fp (remove stack frame)
    li    $v0, 10
    syscall
# generating values here
run_generation:
    # $s7 = x
    # $t1 = left
    # $s2 = centre
    # $t2 = right
    # $t3 = state
    # $t4 = bit
    # $s3 = set
    # $s5 = offset
    # $t5, $t6, $t7 as temp math regs
    
    sw    $fp, -4($sp)    
    la    $fp, -4($sp)       
    sw    $ra, -4($fp)       
    sw    $s2, -8($fp)
    sw    $s4, 12($fp)       
    sw    $s5, -16($fp)
    sw    $s3, -20($fp)
    sw    $t0, -24($fp)
    sw    $t1, -28($fp)
    sw    $t2, -32($fp)
    sw    $t3, -36($fp)
    sw    $t4, -40($fp)
    sw    $t5, -44($fp)
    sw    $t6, -48($fp)
    sw    $t7, -52($fp)
    addi  $sp, $sp, -56
# setting up for loops
gen_running:
    bgt   $s7, $s0, end_gen
    li    $t5, 1
    li    $t1, 0            # reseting values for new loop
    li    $t2, 0
    li    $s2, 0
    sub   $t3, $s7, $t5     # holding x-1 until required
    addi  $t4, $s7, 1       # holding x+1 until requied
    sub   $s3, $s6, $t5     # holding row-1 until required
    mul   $s3, $s3, $s0     # row size *row index-1
    sub   $t6, $s6, $t5 
    mul   $t6, $s0, $t6     # row size*row index
    sub   $s4, $s0, $t5     # getting row size-1
# getting left value for comparison  
left:
    # offset=(row size*row index+column index)
    bge   $0, $s7, centre 
    la    $s5, cells
    add   $t7, $s3, $t3    #offset (row-1)+(x-1)
    add   $s5, $s5, $t7    #offset+inital address
    lb    $t1, ($s5)       #load value at $s5 into $t1
# getting centre value for comparison 
centre:
    la    $s5, cells
    add   $t7, $s3, $s7    #offset (row-1)+x
    add   $s5, $s5, $t7    #offset+inital address
    lb    $s2, ($s5)
# getting right value for comparison 
right: 
    bge   $s7, $s4, states
    la    $s5, cells
    add   $t7, $s3, $t4    #offset (row-1)+(x+1)
    add   $s5, $s5, $t7    #offset+inital address
    lb    $t2, ($s5)
# combining values
states:
    la    $s5, cells
    li    $t4, 1
    sll   $t1, $t1, 2      # left<<2
    sll   $s2, $s2, 1      # centre<<1
    or    $t3, $t1, $s2    # left|centre
    or    $t3, $t3, $t2    # state|right
    sllv  $t4, $t4, $t3    # bit=1<<state
    and   $s3, $t4, $s1    # set=rule&bit
    mul   $t6, $s6, $s0    # set for current row not previous
    add   $t6, $t6, $s7    # offset (row size* row index+col index)
    add   $s5, $s5, $t6
    beqz  $s3, set_dead    # if (set)
    sb    $t5, ($s5)       #store 1 to address (setting alive bit)
    addi  $s7, $s7, 1
    b     gen_running
# setting dead bit
set_dead:
    sb    $0, ($s5)
    addi  $s7, $s7, 1
    b     gen_running

end_gen:
    lw    $t7, -52($fp)
    lw    $t6, -48($fp)
    lw    $t5, -44($fp)
    lw    $t4, -40($fp)
    lw    $t3, -36($fp)
    lw    $t2, -32($fp)
    lw    $t1, -28($fp)
    lw    $t0, -24($fp)
    lw    $s3, -20($fp)
    lw    $s5, -16($fp)
    lw    $s4, -12($fp)       
    lw    $s2, -8($fp)
    lw    $ra, -4($fp)       
    la    $sp, 4($fp)       
    lw    $fp, ($fp)          
    jr    $ra
# printing values here   
print_generation:
    # $t1 = offset
    # $t5 = g
    # $s0 = row size
    # $s4 array address
    # $s5 = element location
    # $s7 = local col index

    sw    $fp, -4($sp)       # push $fp onto stack
    la    $fp, -4($sp)       # set up $fp for this function
    sw    $ra, -4($fp)       # save return address
    sw    $s4, -8($fp)       # save $s0 to use as ... int n;
    sw    $s5, -12($fp)
    sw    $s7, -16($fp)
    sw    $t0, -20($fp)
    sw    $t1, -24($fp)
    sw    $t6, -28($fp)
    addi  $sp, $sp, -32

    move  $a0, $t5  # print current gen (row)
    li    $v0, 1
    syscall
    li    $a0, '\t'
    li    $v0, 11
    syscall
    #reseting indexing variables
    li    $s7, 0    # set index col 
    #using $t6 as a counter
    mul   $t1, $s0, $t5 # (row size*row index)
 printing:
    la    $s4, cells    # set address
    bge   $s7, $s0, print_new_line 
    add   $s5, $t1, $s7 # add address and index col 
    add   $s5, $s5, $s4
    addi  $s7, $s7, 1  
    lb    $a0, ($s5)
    bne   $a0, $0, print_alive
    li    $a0, DEAD_CHAR
    li    $v0, 11
    syscall
    b     printing

print_alive:
    li   $a0, ALIVE_CHAR
    li   $v0, 11
    syscall
    b    printing

print_new_line:
    li   $a0, '\n'
    li   $v0, 11
    syscall

end_print:
    lw   $t6, -28($fp)
    lw   $t1, -24($fp)
    lw   $t0, -20($fp)
    lw   $s7, -16($fp)
    lw   $s5, -12($fp)
    lw   $s4, -8($fp)      
    lw   $ra, -4($fp)     
    la   $sp, 4($fp)    
    lw   $fp, ($fp)         
    jr   $ra

end_invalid_world:
    la   $a0, error_world_size
    li   $v0, 4
    syscall
    li   $v0 10 #kill
    syscall

end_invalid_rule:
    la   $a0, error_rule
    li   $v0, 4
    syscall
    li   $v0 10
    syscall

end_invalid_generations:
    la   $a0, error_n_generations
    li   $v0, 4
    syscall
    li   $v0 10
    syscall
