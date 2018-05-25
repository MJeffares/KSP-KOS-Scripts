// launch.ks v2.0.0
// Mansel Jeffares
// KOS launch script

declare local function printHUD
{
	PARAMETER message.
	HUDTEXT("KOS: " + message, 5, 2, 25, WHITE, true).
}

CLEARSCREEN.

printHUD("LAUNCH").

SET launchState TO 0.
SET launchComplete To FALSE.
SET MYSTEER TO HEADING(90,90).
LOCK STEERING TO MYSTEER.
LOCK THROTTLE TO 1.0.
STAGE.

WHEN SHIP:AVAILABLETHRUST < (prevThrust -10) THEN
{
	LOCK THROTTLE TO 0.3.
	WAIT 0.3.
	STAGE.
	WAIT 1.
	LOCK THROTTLE TO 1.
	SET prevThrust to SHIP:AVAILABLETHRUST.
	PRESERVE.
}

UNTIL launchComplete
{
	SET prevThrust TO SHIP:AVAILABLETHRUST.
	SET speed TO SHIP:VELOCITY:SURFACE:MAG.
	
	IF launchState = 0
	{
		IF speed > 30
		{
			SET launchState TO 1.
		}
	}
	
	IF launchState = 1
	{		
		IF speed > 1275 
		{
			SET MYSTEER TO HEADING(90,5).
		}
		ELSE
		{
			SET MYSTEER TO HEADING(90, 90 - (speed)/15).
		}
		
		IF APOAPSIS > 125000
		{
			LOCK THROTTLE TO 0.
			SET launchState TO 2.
			printHUD("Coasting to apoapsis").
		}
	}
	
	IF launchState = 2
	{
		LOCK MYSTEER TO SHIP:PROGRADE.
		
		IF ETA:APOAPSIS < 20
		{
			SET launchState TO 3.
			printHUD("Circularizing").
		}		
	}
	
	IF launchState = 3
	{
		LOCK THROTTLE TO 1.
		
		IF PERIAPSIS > 125000
		{
			//launchState = 4.
			LOCK THROTTLE TO 0.
			printHUD("Finished").
			SET launchComplete TO true. 
			SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0. 
			SHUTDOWN.
		}
	}
	
	IF SHIP:LIQUIDFUEL < 0.10
	{
		SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0. 
		printHUD("OUTTA FUEL").
		SHUTDOWN.
	}
	
	WAIT 0.1.
}

SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0. 
printHUD("FINISHED").
SHUTDOWN.
