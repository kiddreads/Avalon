//
//  UniversalScript.c
//  ManicJIT-script
//
//  Created by Stossy11 on 20/3/2026.
//


#include <stddef.h>
#include <stdio.h>

__attribute__((noinline,optnone,naked))
void BreakSendJITScript(char* script, size_t len) {
   asm("mov x16, #2 \n"
       "brk #0xf00d \n"
       "ret");
}
