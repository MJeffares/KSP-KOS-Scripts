// launch.ks v2.0.0
// Mansel Jeffares
// KOS launch script

//TODO:
// limit max pitch/AOA based on pressure
parameter turnSpeed is 30.
parameter turnPitch is 10.
parameter targetHeight is 125000.

set terminal:width to 60.
set terminal:height to 26.
clearscreen.

declare local function lngToDegrees 
{
	PARAMETER lng.
	RETURN MOD(lng + 360, 360).
}

declare local function ORBITABLE 
{
	PARAMETER name.

	LIST TARGETS in vessels.
	FOR vs IN vessels 
	{
		if vs:NAME = name 
		{
			RETURN VESSEL(name).
		}
	}
  
  RETURN BODY(name).
}

declare local function getTargetAngle
{
	PARAMETER target.

	RETURN MOD(lngToDegrees (ORBITABLE(target):LONGITUDE) - lngToDegrees (SHIP:LONGITUDE) + 360, 360).
}

declare local function PrintHud
{
	parameter message.
	parameter delay is 5.
	parameter size is 20.
	parameter colour is WHITE.
	//parameter echo is true.
	parameter echo is false.
	HudText(message, delay, 2, size, colour, echo).
	LogToTerminal(message).
}


global emptyString is "                                                            ".
global terminalLog is list().

function TerminalClearLine
{
	parameter l.
	TerminalFillLine(l, " ").
}

function TerminalFillLine
{
	parameter line.
	parameter character.

	local s is emptyString.
	set s to s:replace(" ", character).
	print(s) at (0, line).
}

function LogToTerminal
{
	parameter s.

	if terminalLog:length = 10
	{
		terminalLog:remove(0).
	}

	terminalLog:add(s).

	DrawTerminalLog().
}

function DrawTerminalLog
{
	local lineStart is 15.
	local counter is 1.

	until counter = terminalLog:length
	{
		TerminalClearLine(lineStart + counter).
		print terminalLog[terminalLog:length - counter] at (0, lineStart + counter).
		set counter to counter + 1.
	}
}

declare local function compareWithAllowance
{
	PARAMETER a.
	PARAMETER b.
	PARAMETER allowance.
	
	RETURN a - allowance < b AND a + allowance > b.
}

function AutoStage
{
	if not(defined prevThrust)
	{
		set prevThrust to ship:AVAILABLETHRUST.
	}

	if ship:AVAILABLETHRUST < (prevThrust - 10)
	{
		wait until stage:ready.
		stage.
		wait 0.3.
		set prevThrust to ship:AVAILABLETHRUST.
	}

}

function LaunchCountdown
{
	parameter count.

	PrintHud("Counting Down: ", count).

	from {local countdown is count.} until countdown = 0 step {set countdown to countdown -1.}
	do
	{
		PrintHud("....." + countdown, 1.0).
		wait 1.
	}
	PrintHud("Liftoff", 5).
}


set thrustPID To PIDLOOP(1, 0, 0.5).
set thrustPID:SETPOINT to 40.
set thrustPID:minoutput to 0.05.

set pitchPID to PIDLOOP(30, 0, 2).
set pitchPID:MINOUTPUT to -3.
set pitchPID:MAXOUTPUT to 5.
set pitchPID:SETPOINT to 0.3.

CLEARSCREEN.

set launchState to 0.
set launchComplete To FALSE.
set mySteer to HEADING(90,90).
set myThrottle To 1.0.
lock STEERING to mySteer.
lock THROTTLE to myThrottle.
lock grav to (SHIP:BODY:MU / ( (SHIP:BODY:RADIUS + altitude) ^ 2)).

TerminalFillLine(14, "=").

until launchComplete
{
	AutoStage().
	set speed to SHIP:VELOCITY:SURFACE:MAG.
	
	if launchState = 0
	{
		LaunchCountdown(5).
		stage.
		set launchState to 1.
		PrintHud("Executing Vertical Ascent").
	}

	if launchState = 1
	{
		if speed > turnSpeed
		{
			set launchState to 2.
		}
	}
	
	if launchState = 2
	{
		set mySteer to HEADING(90, 90 - turnPitch).
	 	PrintHud("Executing Pitch Maneuver").
		WAIT UNTIL VANG(facing:vector,mySteer:vector)<0.5.
	 	PrintHud("Awaiting Velocity Vector Alignment").
		WAIT UNTIL VANG(srfPrograde:vector,facing:vector)<1.
	 	PrintHud("Executing Gravity Turn").
		lock mySteer to srfPrograde.
		set launchState to 3.
	}
	
	if launchState = 3
	{	
		// limit TWR to 2.5
		//set myThrottle to (SHIP:MASS * grav) * 2.5  / SHIP:AVAILABLETHRUST. 
		lock timeToApo to ETA:APOAPSIS.
		//lock mult to ((2 - ((120000 - APOAPSIS) / 120000)) ^ 2).
		lock mult to ((2 - ((SHIP:BODY:ATM:height - alt:radar) / SHIP:BODY:ATM:height)) ^ 2).
		
		//set mult to 1.

		set thrustPID:SETPOINT to (40 * mult).
		
		thrustPID:UPDATE(TIME:SECONDS, timeToApo).
		pitchPID:UPDATE(TIME:SECONDS, -thrustPID:DTERM).
		
		set myThrottle to thrustPID:OUTPUT.

		if thrustPID:ERROR > 2.0
		{
			//set thrustPID:MAXOUTPUT to (SHIP:MASS * grav) * 4.0  / SHIP:AVAILABLETHRUST. 
			set mySteer to srfPrograde + R(0, pitchPID:OUTPUT, 0).
			set thrustPID:kp to 1.
			set thrustPID:ki to 0.0.
			set thrustPID:kd to 0.5.
		}
		else
		{
			//set thrustPID:MAXOUTPUT to (SHIP:MASS * grav) * 2.0  / SHIP:AVAILABLETHRUST. 
			set mySteer to srfPrograde.
			set thrustPID:kp to 0.25.
			set thrustPID:ki to 0.1.
			set thrustPID:kd to 0.1.
		}

		if APOAPSIS > 120000
		{
			set myThrottle to 0.1.
			if APOAPSIS > 125000
			{
				set myThrottle to 0.
				set launchState to 4.
			 	PrintHud("Coasting to apoapsis").
			}
		}

		print("Target Time: " + round(thrustPID:setpoint,4)) at (0,0).
		print("Current Time: " + round(timeToApo,4)) at (30,0).
		print("MAIN PID") at (0,1).
		print("ERROR: " + round(thrustPID:ERROR,4)) at (0,2).
		PRINT("P-TERM: " + round(thrustPID:PTERM,4)) at (0,3).
		PRINT("I-TERM: " + round(thrustPID:ITERM,4)) at (0,4).
		PRINT("D-TERM: " + round(thrustPID:DTERM,4)) at (0,5).
		PRINT("OUTPUT: " + round(thrustPID:OUTPUT,4)) at (0,6).
		print("PITCH PID") at (30,1).
		print("ERROR: " + round(pitchPID:ERROR,4)) at (30,2).
		PRINT("P-TERM: " + round(pitchPID:PTERM,4)) at (30,3).
		PRINT("I-TERM: " + round(pitchPID:ITERM,4)) at (30,4).
		PRINT("D-TERM: " + round(pitchPID:DTERM,4)) at (30,5).
		PRINT("OUTPUT: " + round(pitchPID:OUTPUT,4)) at (30,6).	
	}
	
	if launchState = 4
	{
		set myThrottle To 0.
		lock mySteer to SHIP:PROGRADE.
		WAIT UNTIL VANG(Prograde:vector,facing:vector)<0.1.
		set kuniverse:TimeWarp:WARP to 4. 
		
		if ETA:APOAPSIS < 20
		{
			kuniverse:TimeWarp:CANCELWARP().
			WAIT 10.
			set launchState to 5.
		 PrintHud("Circularizing").
		}		
	}
	
	if launchState = 5
	{
		set myThrottle to 1.
				
		if PERIAPSIS > 120000
		{
			set myThrottle to 0.1.
			if PERIAPSIS > 125000
			{
				//launchState = 5.
				set myThrottle to 0.
			 	PrintHud("Finished").
				set launchComplete to true. 
				//set SHIP:CONTROL:PILOTMAINTHROTTLE to 0. 
				//SHUTDOWN.
			}
		}
	}
	
	if SHIP:LIQUIDFUEL < 0.10
	{
		set SHIP:CONTROL:PILOTMAINTHROTTLE to 0. 
	 	PrintHud("OUTTA FUEL").
		SHUTDOWN.
	}
	
	WAIT 0.07.
}



set SHIP:CONTROL:PILOTMAINTHROTTLE to 0.  
PrintHud("FINISHED").
SHUTDOWN.
