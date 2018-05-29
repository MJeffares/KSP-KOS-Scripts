
WAIT UNTIL SHIP:UNPACKED.
COPYPATH("0:/launch.ks","1:/launch.ks").

CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").

WAIT 1.
RUN launch.ks.


//SWITCH TO 0.
//COPYPATH(0:/launch.ks,1).
//SWITCH TO 1.
//WAIT 5.
//RUN launch.ks.