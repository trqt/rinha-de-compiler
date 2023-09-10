#include <stdio.h>
#include <limits.h>
#include <stdlib.h>

// Int is 32 bits, so true and false should be 64 bits
#define false INT_MAX
#define true INT_MAX-1

#define print(X) _Generic((X), \
                          char*: printstr, \
                          int: printint, \
                          default: printerr)(X)

void 
printint(int x){
    if(x == false) puts("false");
    else if(x == true) puts("true");
    else printf("%d", x);
}

void 
printstr(char* x){
    fputs(x, stdout);
}

void 
printerr(int x){
    exit(1);
}


int
main(void){
    

