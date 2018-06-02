WAIT UNTIL SHIP:UNPACKED.
COPYPATH("0:/launch.ks","1:/launch.ks").
COPYPATH("0:/lib/terminalUtilities.ks", "1:/terminalUtilities.ks").

// Open KOS terminal window
CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").

WAIT 1.
RUN launch.ks.
