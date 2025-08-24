#ifndef TIMER_H
#define TIMER_H

#include <sys/time.h>

float timedifference_msec(struct timeval t0, struct timeval t1);

#endif
