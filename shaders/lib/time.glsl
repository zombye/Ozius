#define PERSISTENT_TIME // If enabled, time-based effects are persistent across sessions. It is recommended that you disable this if the doDaylightCycle gamerule is set to false, as that will stop the timers required for persistent time.

// globalTime: Time in seconds.
// globalTick: Time in ticks.

#ifdef PERSISTENT_TIME
uniform float sunAngle;
uniform int moonPhase;

const float globalTime = (sunAngle + moonPhase) * 12e2;
const float globalTick = (sunAngle + moonPhase) * 24e3;
#else
uniform float frameTimeCounter;

const float globalTime = frameTimeCounter;
const float globalTick = frameTimeCounter * 20.0;
#endif
