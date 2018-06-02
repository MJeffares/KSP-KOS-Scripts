local emptyString is "                                                            ".
local terminalLog is list().

global function InitialiseTerminal
{
    set terminal:width to 60.
    set terminal:height to 26.
    clearscreen.
}

global function PrintHud
{
	parameter message.
	parameter delay is 5.
	parameter size is 20.
	parameter colour is WHITE.
	parameter echo is true.
	HudText(message, delay, 2, size, colour, false).
    if echo
    {
        LogToTerminal(message).
    }
}

global function TerminalClearLine
{
	parameter l.
	TerminalFillLine(l, " ").
}

global function TerminalFillLine
{
	parameter line.
	parameter character.

	local s is emptyString.
	set s to s:replace(" ", character).
	print(s) at (0, line).
}

global function LogToTerminal
{
	parameter s.

	if terminalLog:length = 10
	{
		terminalLog:remove(0).
	}

	terminalLog:add(s).

	DrawTerminalLog().
}

global function DrawTerminalLog
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

global function LogPidToTerminal
{
    parameter pidName.
    parameter pidObject.
    parameter line.
    parameter column.

    print(pidName) at (column, line).
    print("ERROR: " + round(pidObject:error, 4)) at (column, line + 1).
	PRINT("P-TERM: " + round(pidObject:pterm, 4)) at (column, line + 2).
	PRINT("I-TERM: " + round(pidObject:iterm, 4)) at (column, line + 3).
	PRINT("D-TERM: " + round(pidObject:dterm, 4)) at (column, line + 4).
	PRINT("OUTPUT: " + round(pidObject:output, 4)) at (column, line + 5).
}