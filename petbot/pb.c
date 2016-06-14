#include <unistd.h>

void pbdelay(int d) {
        usleep(1000*d); //on a20 we dont have wiring delay so lets sleep for microseconds
}
