//COMP1521 20T2 --- assignment 2: simple MIPS emulator
//Written by Calvin Lau 01/08/2020

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#define MAX_INSTRUCTION_CODES 1000
#define SIX_BIT_MASK 0x3F
#define EIGHT_BIT_MASK 0xFFFF
#define SIGNED_BIT_MASK 0x8000
#define S_MASK 0x3E00000
#define T_MASK 0x1F0000
#define D_MASK 0xF800
#define I_MASK 0xFFFF
#define SYSCALL_BARCODE 0xC
#define ADD_BARCODE 0x20
#define SUB_BARCODE 0x22
#define AND_BARCODE 0x24
#define OR_BARCODE 0x25
#define SLT_BARCODE 0x2A
#define MUL_BARCODE 0x702
#define BEQ_BARCODE 0x100
#define BNE_BARCODE 0x140
#define ADDI_BARCODE 0x200
#define SLTI_BARCODE 0x280
#define ANDI_BARCODE 0x300
#define ORI_BARCODE 0x340
#define LUI_BARCODE 0x3C0
#define MUL_BARCODE_LEAD_BITS 0X700

void decode_instructions(int codes, int reg[], int syscall[], int output[], 
                         int *print_count, int *output_count, 
                         int *program_counter, int* bad_syscall);
void verify_code(int codes, char *argv, int i);

int main(int argc, char *argv[]) {
    int program_counter = 0;
    int reg[32]={0};
    //flags and counters requried for the functions
    int print_count=0;
    int output_count=0;
    int bad_syscall=0;
    //record of all the operations that need to be done
    int syscall[MAX_INSTRUCTION_CODES]={2};
    int output[MAX_INSTRUCTION_CODES]={0};

    //checking have correct amount of cmd line args
    if(argc!=2) {
        printf("incorrect number of argument \n");
        return 0;
    }

    //reading hex code
    FILE *f=fopen(argv[1], "r");
    if(f==NULL) {
        perror("Failed: ");
        return 0;
    }
    //scanning in hex code
    int codes[MAX_INSTRUCTION_CODES]={0};
    int i=0;
    while(i<MAX_INSTRUCTION_CODES&&fscanf(f,"%x",&codes[i])==1){
        //checking for instructions that don't exist with the instruction 
        //set
        verify_code(codes[i], argv[1], i);
        i++;
    }
    //decoding hex
    printf("Program\n");
    while(program_counter<i) {
        decode_instructions(codes[program_counter], reg, syscall, output,
        &print_count, &output_count, &program_counter, &bad_syscall);
        if (program_counter==-1) {
            break;
        }
        program_counter++;
    }
    
    //print output
    i=0;
    printf("Output\n"); 
    while(i<output_count) {
        if(syscall[i]==1){
            printf("%d",output[i]);
            i++;
        }else if(syscall[i]==11){
            printf("%c",output[i]);
            i++;
        }else if(syscall[i]==10){
            break;
        }else {
            printf("Unknown system call: %d\n", syscall[i]);
            break;
        }    
    }
    
    //print non-zero regs
    i=0;
    printf("Registers After Execution\n");
    while(i<32) {
        //don't know how to align the equal signs automatically 
        //so did it manually
        if((reg[i]!=0)&&(i<10)) {
            printf("$%d  = %d\n",i, reg[i]);
        }else if((reg[i]!=0)&&(i>=10)) {
            printf("$%d = %d\n",i, reg[i]);
        }
        i++;
    }
    return 0;
}
//printing instructions and handinling logic done here
void decode_instructions(int codes, int reg[], int syscall[], int output[], 
int *print_count, int *output_count, int *program_counter, int *bad_syscall){
    int d,s,t,i;
    //used as buffer to not print unwanted instructions (reason why using
    //sprintf
    //instead of printf until the final print)
    char str[10000];
    //if signed bit = 1, two complement value and make neg,
    //else use value normally (ternary operator) (i stays 16 bits long)
    i=(codes&SIGNED_BIT_MASK)?-(((codes&I_MASK)^EIGHT_BIT_MASK)+1):(codes&I_MASK);
    //shifting down all numbers to be 6 bits long
    s=(codes&S_MASK)>>21;
    t=(codes&T_MASK)>>16;
    d=(codes&D_MASK)>>11;
    //if first 6 bits = 0, use low byte(i.e.000000x), else use high byte 
    //(i.e.x000000)high byte barcodes are padded with 0s to stop any false 
    //recognition
    uint16_t barcode=(codes>>26)?((codes>>26)<<6):((codes&SIX_BIT_MASK));
    //using all MUL indentifier bits to prevent any potential fake 
    //instructions
    //that might slip through
    if(barcode==MUL_BARCODE_LEAD_BITS) {
        barcode=MUL_BARCODE;
    }
    //finding out which instruction is being decoded
    //using breaks because there is more code that needs to be run before 
    //returning
    switch(barcode) {
        //syscall
        case SYSCALL_BARCODE:
            sprintf(str,"%3d: syscall\n", *program_counter);
            if(*bad_syscall==0){
                syscall[*output_count]=reg[2];
                output[*output_count]=reg[4];
                (*output_count)++;   
            }
            if((reg[2]!=1)&&(reg[2]!=11)) {
                //using bad_syscall flag to also manage exit call
                *bad_syscall=1;   
            }
            break;
        //add
        case ADD_BARCODE:
            sprintf(str,"%3d: add  $%d, $%d, $%d\n",*program_counter, d, s, t);
            reg[d]=reg[s]+reg[t];
            break;
        //sub
        case SUB_BARCODE:
            sprintf(str,"%3d: sub  $%d, $%d, $%d\n",*program_counter, d, s, t);
            reg[d]=reg[s]-reg[t];
            break;
        //and
        case AND_BARCODE:
            sprintf(str,"%3d: and  $%d, $%d, $%d\n",*program_counter, d, s, t);
            reg[d]=reg[s]&reg[t];
            break;
        //or
        case OR_BARCODE:
            sprintf(str,"%3d: or  $%d, $%d, $%d\n",*program_counter, d, s, t);
            reg[d]=reg[s]|reg[t];
            break;
        //slt
        case SLT_BARCODE:
            sprintf(str,"%3d: slt  $%d, $%d, $%d\n",*program_counter, d, s, t);
            if(reg[s]<reg[t]){
                reg[d]=1;
                break;
            }
            reg[d]=0;
            break;
        //mul
        case MUL_BARCODE:
            sprintf(str,"%3d: mul  $%d, $%d, $%d\n", *program_counter, d, s, t);
            reg[d]=reg[s]*reg[t];
            break;
        //beq
        case BEQ_BARCODE: 
            sprintf(str,"%3d: beq  $%d, $%d, %d\n",*program_counter, s, t, i);
            if(reg[s]==reg[t]) {
                if(((*program_counter)+i)<0) {
                    *program_counter=-1;
                    *bad_syscall=1;
                    break;
                }
                //offsetting for +1 after returning
                (*program_counter)+=(i-1);
            }
            break;
        //bne
        case BNE_BARCODE:
            sprintf(str,"%3d: bne  $%d, $%d, %d\n",*program_counter, s, t, i);
            if(reg[s]!=reg[t]) {
                if(((*program_counter)+i)<0) {
                    *program_counter=-1;
                    *bad_syscall=1;
                    break;
                }
                //offsetting for +1 after returning
                (*program_counter)+=(i-1);
            }
            break;
        //addi
        case ADDI_BARCODE:
            sprintf(str,"%3d: addi $%d, $%d, %d\n",*program_counter, t, s, i);
            reg[t]=reg[s]+i;
            break;
        //slti
        case SLTI_BARCODE:
            sprintf(str,"%3d: slti $%d, $%d, %d\n",*program_counter, t, s, i);
            if(reg[s]<i){
                reg[t]=1;
                break;
            }
            reg[t]=0;
            break;
        //andi
        case ANDI_BARCODE:
            sprintf(str,"%3d: andi $%d, $%d, %d\n",*program_counter, t, s, i);
            reg[t]=reg[s]&i;
            break;
        //ori
        case ORI_BARCODE:
            sprintf(str,"%3d: ori  $%d, $%d, %d\n",*program_counter, t, s, i);
            reg[t]=reg[s]|i;
            break;
        //lui
        case LUI_BARCODE:
            sprintf(str,"%3d: lui  $%d, %d\n",*program_counter, t, i);
            reg[t]=i<<16;
            break;
    }
    //pinning $0 to 0
    if(reg[0]!=0) {
        reg[0]=0;
    }
    //pinning $a0 and $v0 when bad syscall
    if(*bad_syscall==1) {
        //$v0
        reg[2]=syscall[(*output_count)-1];
        //$a0
        reg[4]=output[(*output_count)-1];
    }
    //only printing new instructions
    if(*print_count<=*program_counter){
        printf("%s", str);
        (*print_count)++;
        return;
    }
    if(*program_counter==-1){
        printf("%s", str);
        return;
    }
}
//checks if the instruction exists
void verify_code(int codes, char *argv, int i) {
    //same barcode system in decode_instructions
    uint16_t barcode=(codes>>26)?((codes>>26)<<6):((codes&0x3F));
    if(barcode==0x700) {
        barcode=MUL_BARCODE;
    }
    //checking if instruction exists
    //if instruction doesn't exist then print error and exit
    switch(barcode) {
        //syscall
        case SYSCALL_BARCODE:
            return;
        //add
        case ADD_BARCODE:
            return;
        //sub
        case SUB_BARCODE:
            return;
        //and
        case AND_BARCODE:
            return;
        //or
        case OR_BARCODE:
            return;
        //slt
        case SLT_BARCODE:
            return;
        //mul
        case MUL_BARCODE:
            return;
        //beq
        case BEQ_BARCODE: 
            return;
        //bne
        case BNE_BARCODE:
            return;
        //addi
        case ADDI_BARCODE:
            return;
        //slti
        case SLTI_BARCODE:
            return;
        //andi
        case ANDI_BARCODE:
            return;
        //ori
        case ORI_BARCODE:
            return;
        //lui
        case LUI_BARCODE:
            return;
    }
    //if none of the returns are triggered, then invalid instruction has 
    //been inputted
    printf("%s:%d: invalid instruction code: %d\n", argv, (i+1), codes);
    exit(0);
}
