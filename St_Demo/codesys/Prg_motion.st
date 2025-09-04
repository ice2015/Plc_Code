PROGRAM MOTION_PRG
VAR
        iStatus: INT;
        Power: MC_Power;
        MoveAbsolute: MC_MoveAbsolute;
        p:REAL:=100;
END_VAR

CASE iStatus OF

// initialization of the axis
0:
        Power(Enable:=TRUE, bRegulatorOn:=TRUE, bDriveStart:=TRUE, Axis:=Drive);
        IF Power.Status THEN
                iStatus := iStatus + 1;
        END_IF

// Move the axis to position p by use of the MC_MoveAbsolute function block
1:
        MoveAbsolute(Execute:=TRUE, Position:= p, Velocity:=100, Acceleration:=100, Deceleration:=100, Axis:=Drive);
        IF MoveAbsolute.Done THEN
                MoveAbsolute(Execute:=FALSE, Axis:=Drive);
                iStatus := iStatus + 1;
        END_IF

// Move the axis back to position 0 by use of the MC_MoveAbsolute function block:
2:
        MoveAbsolute(Execute:=TRUE, Position:= 0, Velocity:=100, Acceleration:=100, Deceleration:=100, Axis:=Drive);
        IF MoveAbsolute.Done THEN
                MoveAbsolute(Execute:=FALSE, Axis:=Drive);
                iStatus := 1;
        END_IF