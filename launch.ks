// launch.ks v3.0.0
// Mansel Jeffares
// KOS launch script

// Needed for terminal drawing functions.
runoncepath("1:/terminalUtilities.ks").

InitialiseTerminal().

parameter turnSpeed is 100. //down to 15 for extremly high thrust
parameter turnPitch is 10.  //up to 25 for high thrust
// parameter turnSpeed is 15.
// parameter turnPitch is 25.
parameter targetHeight is 125000.
parameter dynamicPressureLimit is 30.
parameter allowableOrbitError is 0.1. //% //not sure this is working atm



function AutoStage
{
	if not(defined prevThrust)
	{
		set prevThrust to ship:AVAILABLETHRUST.
	}

	if ship:AVAILABLETHRUST < (prevThrust - 10)
	{
        set mysteer to ship:facing.
        wait 0.5.
        LogToTerminal("STAGING").
		wait until stage:ready.
		stage.
		wait 0.3.
	}
    set prevThrust to ship:AVAILABLETHRUST.
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

function GetCurrentPressure
{
	return ship:body:atm:altitudepressure(ship:altitude) * Constant:AtmToKpa.
}

function GetSeaLevelPressure
{
	return ship:body:atm:SeaLevelPressure * Constant:AtmToKpa.
}

function GetDynamicPressure
{
	return ship:q * Constant:AtmToKpa.
}

function PitchOfVector
{
    parameter vect.

    return 90 - vang(ship:up:vector, vect).
}

function YawOfVector
{
    parameter vect.

    local trigX is vdot(ship:north:vector, vect).
    local trigY is vdot(vcrs(ship:up:vector, ship:north:vector), vect).

    local result is arctan2(trigY, trigX).

    if result < 0
    {
        return 360 + result.
    }
    else
    {
        return result.
    }
}

function VisVivaEquation
{
    parameter apoa.
    parameter peri.
    parameter rad.
    parameter datum.
    parameter gravConst.
    parameter bodyMass.

    return sqrt(gravConst * bodyMass * ((2 / rad) - (1 / (((apoa + peri) / 2) + datum)))).
}

function CalculateCircularisationBurn
{
    set speedAtApoapsis to VisVivaEquation(apoapsis, periapsis, (apoapsis + body:radius), body:radius, constant:G, body:mass).
    set speedIfCircular to VisVivaEquation(apoapsis, targetHeight, (targetHeight + body:radius), body:radius, constant:G, body:mass).

    set circularisationDeltaV to speedIfCircular - speedAtApoapsis.

    set myNode to NODE(time:seconds + timeToApo, 0, 0, circularisationDeltaV).
    return myNode.
}

function ExecuteNode
{
    parameter myNode.
    parameter steer.
    parameter throt.
    
    unlock steering.
    unlock throttle.
    set throttle to 0.

    set steering to myNode:burnvector.
    WAIT UNTIL VANG(myNode:burnvector, facing:vector) < 0.1.

    //improve burn estimate using rocket equation
    set crudeBurnEstimate to myNode:deltav:mag/(ship:maxthrust/ship:mass).

    set kuniverse:TimeWarp:WARP to 4. 
    wait until myNode:eta <= (crudeBurnEstimate / 2).
    kuniverse:TimeWarp:CANCELWARP().
    
    set myNodeInitialVector to myNode:burnvector.
    set burnComplete to false.

    until burnComplete
    {
        set max_acc to ship:maxthrust/ship:mass.
        set steering to myNode:burnvector.

        if myNode:deltav:mag < 0.1
        {
            wait until vdot(myNodeInitialVector, myNode:burnvector) < 0.5.
            set throttle to 0.
            set launchComplete to true.
        }

        set throttle to min(myNode:deltav:mag/max_acc, 1).

        if vdot(myNode:burnvector, myNodeInitialVector) < 0
        {
            set throttle to 0.

            // return throttle and steering to what they were before function ran.
            lock throttle to throt.
            lock steering to steer.

            set burnComplete to true.
        }

        wait 0.
    }    
}


CLEARSCREEN.

set launchState to 0.
set launchComplete To FALSE.
set mySteer to HEADING(90,90).
set myThrottle To 1.0.
lock STEERING to mySteer.
lock THROTTLE to myThrottle.
lock grav to (SHIP:BODY:MU / ( (SHIP:BODY:RADIUS + altitude) ^ 2)).

TerminalFillLine(14, "=").

set angleOfAttackLimit to 30 - ((GetDynamicPressure / dynamicPressureLimit) * 25).

set timeToApoPID to PIDLOOP(1, 0, 1).
set timeToApoPID:setpoint to 0.

set pitchPID to PIDLOOP(100, 0, 0.1).
set pitchPID:setpoint to 0.3.
set pitchPID:minoutput to -1.
set pitchPID:maxoutput to angleOfAttackLimit.

//set pressurePID to PIDLOOP(0.1, 0.0, 0.025).  //high thrust
//set pressurePID to PIDLOOP(0.5, 0.0, 0.1).  //standard thrust
set pressurePID to PIDLOOP(0.1, 0.0, 0.025).
set pressurePID:setpoint to dynamicPressureLimit.
set pressurePID:maxoutput to 1.
set pressurePID:minoutput to 0.1.

set nodePID to PIDLOOP(0.002, 0.0, 0.0001).
set nodePID:setpoint to targetHeight.
set nodePID:maxoutput to 1.
set nodePID:minoutput to 0.

lock timeToApo to ETA:APOAPSIS.

until launchComplete
{
	AutoStage().
	set speed to SHIP:VELOCITY:SURFACE:MAG.
	
    // Countdown/pre liftoff state
	if launchState = 0
	{
		LaunchCountdown(5).
		stage.
		set launchState to 1.
		PrintHud("Executing Vertical Ascent").
	}

    // Vertical Ascent State
	else if launchState = 1
	{
		if speed > turnSpeed
		{
			set launchState to 2.
		}
	}
	
    // Intial turn/bump over
	else if launchState = 2
	{
		set mySteer to HEADING(90, 90 - turnPitch).
	 	PrintHud("Executing Pitch Maneuver").
		UNTIL VANG(facing:vector,mySteer:vector) < 0.5
        {
            pressurePID:update(time:seconds, GetDynamicPressure).
	        set myThrottle to 1 * pressurePID:output.
        }
	 	PrintHud("Awaiting Velocity Vector Alignment").
		UNTIL VANG(srfPrograde:vector,facing:vector) < 1
        {
            pressurePID:update(time:seconds, GetDynamicPressure).
	        set myThrottle to 1 * pressurePID:output.
        }
	 	PrintHud("Executing Gravity Turn").
		lock mySteer to srfPrograde.
		set launchState to 3.
	}
	
    // Intial flight
	else if launchState = 3
	{	
        timeToApoPID:update(time:seconds, -timeToApo).
		pitchPID:update(time:seconds, timeToApoPID:dterm).

		pressurePID:update(time:seconds, GetDynamicPressure).
		set myThrottle to 1 * pressurePID:output.

        // if at less than 5% seaLevelPressure
        if GetCurrentPressure < GetSeaLevelPressure / 20
        {
            PrintHud("Less than 5% atmosphere switching to orbital guidance").
            set navmode to "orbit".
            set angleOfAttackLimit to 90 - PitchOfVector(Prograde:vector).
            set pitchPID:maxoutput to angleOfAttackLimit.
            set mysteer to heading(90, PitchOfVector(Prograde:vector) + pitchPID:output).
        }
        else
        {
            set angleOfAttackLimit to 30 - ((GetDynamicPressure / dynamicPressureLimit) * 25).
            set pitchPID:maxoutput to angleOfAttackLimit.
            set mysteer to heading(90, PitchOfVector(srfPrograde:vector) + pitchPID:output).
        }

		// within 5% of our target height
		if targetHeight - apoapsis < (targetHeight / 20)
		{
            PrintHud("Fine tuning apoapsis").
            // set myThrottle to 0.
            // set mySteer to SHIP:PROGRADE.
		    // WAIT UNTIL VANG(Prograde:vector,facing:vector) < 0.1.
            set launchState to 4.
		}

        LogPidToTerminal("MAIN PID", timeToApoPID, 1, 0).
        LogPidToTerminal("PRESSURE PID", pressurePID, 1, 20).
        LogPidToTerminal("PITCH PID", pitchPID, 1, 40).

        LOG TIME:SECONDS + "," +  round(GetCurrentPressure, 4) + "," + round(ship:q * Constant:AtmToKpa, 4) TO "0:/myfile.csv".
	}
	
    // Fine tuning apoapsis
	else if launchState = 4
	{
        if (abs(((apoapsis / targetheight)* 100) - 100)) < allowableOrbitError and altitude > 70000
        {
            PrintHud("Executing Circularisation Burn").
            set myThrottle to 0.
            set circularisationBurn to CalculateCircularisationBurn.
            add circularisationBurn.

            set launchState to 5.
        }
        else
        {
            nodePID:update(time:seconds, apoapsis).
            set myThrottle to nodePID:output.
        }	
	}
	
    // Circularisation burn
	else if launchState = 5
	{
        ExecuteNode(circularisationBurn, mysteer, myThrottle).
        PrintHud("Circularisation Burn Finished").
        set launchComplete to true.	
	}
	
	if SHIP:LIQUIDFUEL < 0.10
	{
		set SHIP:CONTROL:PILOTMAINTHROTTLE to 0. 
	 	PrintHud("OUTTA FUEL").
		SHUTDOWN.
	}

    //wait until the next tick before we run
    wait 0.
	
}

PrintHud("Launch Script Finished").
unlock throttle.
unlock steering.
set SHIP:CONTROL:PILOTMAINTHROTTLE to 0.  
SHUTDOWN.
