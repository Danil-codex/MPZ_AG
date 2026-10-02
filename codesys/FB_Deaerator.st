FUNCTION_BLOCK FB_Deaerator
VAR_INPUT
    Enable : BOOL;
    Stop : BOOL;
    DrainRequest : BOOL; (* accepted only while stopped *)
    CoolingEnable : BOOL := TRUE;
    LevelPct : REAL; (* engineering units, test range 0..100 % *)
    TemperatureC : REAL; (* test range 0..150 deg C *)
    PressureBar : REAL; (* gauge pressure, test range 0..1 bar *)
    LevelLow : REAL := 55.0;
    LevelHigh : REAL := 65.0;
    StartLevel : REAL := 60.0;
    TemperatureSet : REAL := 104.0;
    TemperatureBand : REAL := 1.0;
    PressureSet : REAL := 0.20;
    PressureBand : REAL := 0.03;
    CoolingOn : REAL := 110.0;
    CoolingOff : REAL := 107.0;
    SecondLevelOn : REAL := 75.0;
    SecondLevelOff : REAL := 70.0;
    DrainStopLevel : REAL := 5.0;
    ValvePulse : TIME := T#1s;
    ValvePause : TIME := T#4s;
END_VAR
VAR_OUTPUT
    State : INT; (* 0 stopped, 10 filling, 20 warming, 30 running, 40 draining *)
    HeatClose : BOOL; (* Q0.0, three-position valve *)
    HeatOpen : BOOL; (* Q0.1 *)
    Feed1 : BOOL; (* Q0.2 *)
    Feed2 : BOOL; (* Q0.3 *)
    Drain : BOOL; (* Q0.6 *)
    StationEnabled : BOOL; (* Q0.7, operational indication only *)
    SecondLevel : BOOL; (* Q1.0, level indication only *)
    Cooling : BOOL; (* Q1.1 *)
    Ready : BOOL; (* software indication, not an alarm permissive *)
END_VAR
VAR
    FeedDemand : BOOL;
    CoolingDemand : BOOL;
    SecondLevelDemand : BOOL;
    HeatDemand : INT; (* -1 close, 0 hold, 1 open *)
    ActiveDirection : INT;
    DesiredDirection : INT;
    PulseActive : BOOL;
    PauseActive : BOOL;
    PulseTimer : TON;
    PauseTimer : TON;
END_VAR

(* Stop takes precedence; Enable is a maintained operating request. *)
IF Stop OR NOT Enable THEN
    IF DrainRequest THEN State := 40; ELSE State := 0; END_IF;
ELSIF State = 0 OR State = 40 THEN
    State := 10;
END_IF;

IF State = 10 AND LevelPct >= StartLevel THEN State := 20; END_IF;
IF State = 20 AND TemperatureC >= TemperatureSet - TemperatureBand
    AND PressureBar >= PressureSet - PressureBand THEN
    State := 30;
END_IF;

StationEnabled := (State = 10) OR (State = 20) OR (State = 30);
Ready := (State = 30) AND (LevelPct >= LevelLow)
    AND (TemperatureC >= TemperatureSet - TemperatureBand)
    AND (PressureBar >= PressureSet - PressureBand);

(* Level hysteresis with a fixed first feed stage. *)
IF NOT StationEnabled THEN
    FeedDemand := FALSE;
ELSIF State = 10 THEN
    FeedDemand := LevelPct < StartLevel;
ELSIF LevelPct <= LevelLow THEN
    FeedDemand := TRUE;
ELSIF LevelPct >= LevelHigh THEN
    FeedDemand := FALSE;
END_IF;
(* Two feed stages: second opens only below the low threshold by 10 %. *)
Feed1 := StationEnabled AND FeedDemand;
Feed2 := Feed1 AND (LevelPct < LevelLow - 10.0);

IF TemperatureC >= CoolingOn THEN CoolingDemand := TRUE;
ELSIF TemperatureC <= CoolingOff THEN CoolingDemand := FALSE;
END_IF;
Cooling := StationEnabled AND CoolingEnable AND CoolingDemand;

IF LevelPct >= SecondLevelOn THEN SecondLevelDemand := TRUE;
ELSIF LevelPct <= SecondLevelOff THEN SecondLevelDemand := FALSE;
END_IF;
SecondLevel := SecondLevelDemand;
Drain := (State = 40) AND (LevelPct > DrainStopLevel);

(* Temperature control with a pressure ceiling; pressure alone cannot demand heat. *)
IF NOT ((State = 20) OR (State = 30)) OR Cooling THEN
    HeatDemand := -1;
ELSIF TemperatureC >= TemperatureSet + TemperatureBand
    OR PressureBar >= PressureSet + PressureBand THEN
    HeatDemand := -1;
ELSIF TemperatureC <= TemperatureSet - TemperatureBand
    AND PressureBar <= PressureSet THEN
    HeatDemand := 1;
ELSE
    HeatDemand := 0;
END_IF;
DesiredDirection := HeatDemand;

(* Fixed jog pulses, separated by a pause. Reversals first remove both outputs. *)
IF PulseActive AND DesiredDirection <> ActiveDirection THEN
    PulseActive := FALSE;
    PauseActive := TRUE;
END_IF;
PulseTimer(IN := PulseActive, PT := ValvePulse);
PauseTimer(IN := PauseActive, PT := ValvePause);
IF PulseTimer.Q THEN
    PulseActive := FALSE;
    PauseActive := TRUE;
END_IF;
IF PauseTimer.Q THEN PauseActive := FALSE; END_IF;
IF NOT PulseActive AND NOT PauseActive AND DesiredDirection <> 0 THEN
    ActiveDirection := DesiredDirection;
    PulseActive := TRUE;
END_IF;
HeatOpen := PulseActive AND (ActiveDirection = 1);
HeatClose := PulseActive AND (ActiveDirection = -1);
END_FUNCTION_BLOCK
