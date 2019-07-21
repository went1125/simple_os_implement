#include<unistd.h>

int main(){
    write(1, "hello, world.\n", 4);
    return 0;
}
