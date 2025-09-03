VAR
    (* ... 其他原有变量，包括用于MC_Cam方案的锁存变量 ... *)

    (* 传感器输入 *)
    xSensorA_Input      : BOOL := FALSE; // 螺杆A传感器信号
    xSensorB_Input      : BOOL := FALSE; // 螺杆B传感器信号
    xSensorC_Input      : BOOL := FALSE; // 螺杆C传感器信号
    xSensorD_Input      : BOOL := FALSE; // 螺杆D传感器信号

    (* MC_TouchProbe 功能块 *)
    MC_TouchProbe_A     : MC_TouchProbe;
    MC_TouchProbe_B     : MC_TouchProbe;
    MC_TouchProbe_C     : MC_TouchProbe;
    MC_TouchProbe_D     : MC_TouchProbe;

    (* 修正相关的参数 *)
    ProbePositionA      : LREAL := 0.0;     // 螺杆A传感器理论位置 (度)
    ProbePositionB      : LREAL := 0.0;     // 螺杆B传感器理论位置 (度)
    ProbePositionC      : LREAL := 0.0;     // 螺杆C传感器理论位置 (度)
    ProbePositionD      : LREAL := 0.0;     // 螺杆D传感器理论位置 (度)

    DetectedPositionA   : LREAL := 0.0;     // 螺杆A传感器检测到的实际位置 (度)
    DetectedPositionB   : LREAL := 0.0;     // 螺杆B传感器检测到的实际位置 (度)
    DetectedPositionC   : LREAL := 0.0;     // 螺杆C传感器检测到的实际位置 (度)
    DetectedPositionD   : LREAL := 0.0;     // 螺杆D传感器检测到的实际位置 (度)

    ErrorA              : LREAL := 0.0;     // 螺杆A位置误差 (度)
    ErrorB              : LREAL := 0.0;     // 螺杆B位置误差 (度)
    ErrorC              : LREAL := 0.0;     // 螺杆C位置误差 (度)
    ErrorD              : LREAL := 0.0;     // 螺杆D位置误差 (度)

    xStartProbeA        : BOOL := FALSE;    // 启动A轴检测
    xStartProbeB        : BOOL := FALSE;    // 启动B轴检测
    xStartProbeC        : BOOL := FALSE;    // 启动C轴检测
    xStartProbeD        : BOOL := FALSE;    // 启动D轴检测

    bPreviousSensorA    : BOOL; // 用于检测传感器上升沿
    bPreviousSensorB    : BOOL;
    bPreviousSensorC    : BOOL;
    bPreviousSensorD    : BOOL;

    bProbeCycleActive   : BOOL := FALSE;    // 探针检测周期是否活跃

    // 用于MC_TouchProbe的模式选择 (MC_TOUCHPROBE_IMMEDIATE_STOP 或 MC_TOUCHPROBE_CONTINUOUS)
    // 通常我们选择连续模式，不停车
    ProbeMode           : MC_TouchProbeMode := MC_TOUCHPROBE_CONTINUOUS;
END_VAR
PROGRAM ConveyorMC_Cam
VAR_INPUT
    EnableSystemInput : BOOL;
    ResetButtonInput  : BOOL;
    TriggerAB_Input   : BOOL;
    TriggerBC_Input   : BOOL;
    TriggerCD_Input   : BOOL;
    SensorA_Input     : BOOL; // 外部传感器信号输入
    SensorB_Input     : BOOL;
    SensorC_Input     : BOOL;
    SensorD_Input     : BOOL;
END_INPUT
VAR_OUTPUT
    SystemReady       : BOOL;
    Moving            : BOOL;
    AB_Completed      : BOOL;
    BC_Completed      : BOOL;
    CD_Completed      : BOOL;
    TriggerAB_Latched : BOOL;
    TriggerBC_Latched : BOOL;
    TriggerCD_Latched : BOOL;
    ProbeErrorA       : LREAL; // 输出误差值给HMI
    ProbeErrorB       : LREAL;
    ProbeErrorC       : LREAL;
    ProbeErrorD       : LREAL;
END_OUTPUT

// 将输入连接到内部变量
xEnableSystem := EnableSystemInput;
xResetButton := ResetButtonInput;
xTrigger_AB := TriggerAB_Input;
xTrigger_BC := TriggerBC_Input;
xTrigger_CD := TriggerCD_Input;
xSensorA_Input := SensorA_Input;
xSensorB_Input := SensorB_Input;
xSensorC_Input := SensorC_Input;
xSensorD_Input := SensorD_Input;

// 输出锁存状态和误差
TriggerAB_Latched := xLatchTrigger_AB;
TriggerBC_Latched := xLatchTrigger_BC;
TriggerCD_Latched := xLatchTrigger_CD;
ProbeErrorA := ErrorA;
ProbeErrorB := ErrorB;
ProbeErrorC := ErrorC;
ProbeErrorD := ErrorD;

// --- 轴电源控制 (不变) ---
MC_Power_M_AB(Axis := MasterAxis_AB, Enable := xEnableSystem);
MC_Power_M_BC(Axis := MasterAxis_BC, Enable := xEnableSystem);
MC_Power_M_CD(Axis := MasterAxis_CD, Enable := xEnableSystem);
MC_Power_A(Axis := AxisA, Enable := xEnableSystem);
MC_Power_B(Axis := AxisB, Enable := xEnableSystem);
MC_Power_C(Axis := AxisC, Enable := xEnableSystem);
MC_Power_D(Axis := AxisD, Enable := xEnableSystem);

// --- 凸轮表加载状态机 (不变，此处省略，请将完整代码段放入实际PLC程序) ---
CASE nCamTableLoadState OF
    0: // 创建第一个凸轮表 (AB)
        MC_CamTable_Create_FB(Execute := TRUE, CamTableID := CamTableID_AB);
        IF MC_CamTable_Create_FB.Done THEN MC_CamTable_Create_FB(Execute := FALSE); nCamTableLoadState := 10; END_IF

    10: // 加载AB凸轮表点
        MC_CamTable_AddPoint_FB(Execute := TRUE, CamTableID := CamTableID_AB, MasterPosition := 0.0, SlavePosition := 0.0);
        MC_CamTable_AddPoint_FB(Execute := TRUE, CamTableID := CamTableID_AB, MasterPosition := MasterMoveDistance_Segment * 0.2, SlavePosition := RotationAnglePerSegment * 0.2);
        MC_CamTable_AddPoint_FB(Execute := TRUE, CamTableID := CamTableID_AB, MasterPosition := MasterMoveDistance_Segment * 0.8, SlavePosition := RotationAnglePerSegment * 0.8);
        MC_CamTable_AddPoint_FB(Execute := TRUE, CamTableID := CamTableID_AB, MasterPosition := MasterMoveDistance_Segment, SlavePosition := RotationAnglePerSegment);
        IF MC_CamTable_AddPoint_FB.Done THEN
            MC_CamTable_AddPoint_FB(Execute := FALSE);
            MC_CamTable_End_FB(Execute := TRUE, CamTableID := CamTableID_AB);
            IF MC_CamTable_End_FB.Done THEN MC_CamTable_End_FB(Execute := FALSE); nCamTableLoadState := 20; END_IF
        END_IF

    20: // 创建第二个凸轮表 (BC)
        MC_CamTable_Create_FB(Execute := TRUE, CamTableID := CamTableID_BC);
        IF MC_CamTable_Create_FB.Done THEN MC_CamTable_Create_FB(Execute := FALSE); nCamTableLoadState := 30; END_IF

    30: // 加载BC凸轮表点
        MC_CamTable_AddPoint_FB(Execute := TRUE, CamTableID := CamTableID_BC, MasterPosition := 0.0, SlavePosition := 0.0);
        MC_CamTable_AddPoint_FB(Execute := TRUE, CamTableID := CamTableID_BC, MasterPosition := MasterMoveDistance_Segment * 0.2, SlavePosition := RotationAnglePerSegment * 0.2);
        MC_CamTable_AddPoint_FB(Execute := TRUE, CamTableID := CamTableID_BC, MasterPosition := MasterMoveDistance_Segment * 0.8, SlavePosition := RotationAnglePerSegment * 0.8);
        MC_CamTable_AddPoint_FB(Execute := TRUE, CamTableID := CamTableID_BC, MasterPosition := MasterMoveDistance_Segment, SlavePosition := RotationAnglePerSegment);
        IF MC_CamTable_AddPoint_FB.Done THEN
            MC_CamTable_AddPoint_FB(Execute := FALSE);
            MC_CamTable_End_FB(Execute := TRUE, CamTableID := CamTableID_BC);
            IF MC_CamTable_End_FB.Done THEN MC_CamTable_End_FB(Execute := FALSE); nCamTableLoadState := 40; END_IF
        END_IF

    40: // 创建第三个凸轮表 (CD)
        MC_CamTable_Create_FB(Execute := TRUE, CamTableID := CamTableID_CD);
        IF MC_CamTable_Create_FB.Done THEN MC_CamTable_Create_FB(Execute := FALSE); nCamTableLoadState := 50; END_IF

    50: // 加载CD凸轮表点
        MC_CamTable_AddPoint_FB(Execute := TRUE, CamTableID := CamTableID_CD, MasterPosition := 0.0, SlavePosition := 0.0);
        MC_CamTable_AddPoint_FB(Execute := TRUE, CamTableID := CamTableID_CD, MasterPosition := MasterMoveDistance_Segment * 0.2, SlavePosition := RotationAnglePerSegment * 0.2);
        MC_CamTable_AddPoint_FB(Execute := TRUE, CamTableID := CamTableID_CD, MasterPosition := MasterMoveDistance_Segment * 0.8, SlavePosition := RotationAnglePerSegment * 0.8);
        MC_CamTable_AddPoint_FB(Execute := TRUE, CamTableID := CamTableID_CD, MasterPosition := MasterMoveDistance_Segment, SlavePosition := RotationAnglePerSegment);
        IF MC_CamTable_AddPoint_FB.Done THEN
            MC_CamTable_AddPoint_FB(Execute := FALSE);
            MC_CamTable_End_FB(Execute := TRUE, CamTableID := CamTableID_CD);
            IF MC_CamTable_End_FB.Done THEN MC_CamTable_End_FB(Execute := FALSE); nCamTableLoadState := 60; END_IF
        END_IF

    60: // 所有凸轮表加载完成
        Nop();
END_CASE;

// --- 更新轴活跃状态标志 (不变) ---
bCamInAB_A_Active := MC_CamIn_AB_A.Active OR MC_CamIn_AB_A.InSync;
bCamInAB_B_Active := MC_CamIn_AB_B.Active OR MC_CamIn_AB_B.InSync;
bCamInBC_B_Active := MC_CamIn_BC_B.Active OR MC_CamIn_BC_B.InSync;
bCamInBC_C_Active := MC_CamIn_BC_C.Active OR MC_CamIn_BC_C.InSync;
bCamInCD_C_Active := MC_CamIn_CD_C.Active OR MC_CamIn_CD_C.InSync;
bCamInCD_D_Active := MC_CamIn_CD_D.Active OR MC_CamIn_CD_D.InSync;

// --- 主状态机 ---
CASE nState OF
    0: // 初始化 & 回零
        SystemReady := FALSE;
        Moving := FALSE;
        AB_Completed := FALSE;
        BC_Completed := FALSE;
        CD_Completed := FALSE;
        bAB_Active := FALSE; bBC_Active := FALSE; bCD_Active := FALSE;
        bAB_Done := FALSE; bBC_Done := FALSE; bCD_Done := FALSE;
        xLatchTrigger_AB := FALSE; xLatchTrigger_BC := FALSE; xLatchTrigger_CD := FALSE; // 清除所有锁存
        bProbeCycleActive := FALSE; // 确保探针检测周期不活跃

        // 确保凸轮表已加载完成
        IF nCamTableLoadState < 60 THEN
            RETURN; // 等待凸轮表加载
        END_IF

        // 首次上电或复位时，所有主轴和从轴回零
        IF NOT bInitialHomingDone THEN
            MC_Home_M_AB(Axis := MasterAxis_AB, Execute := TRUE, Position := 0.0, Mode := MC_HOME_SET_POSITION);
            MC_Home_M_BC(Axis := MasterAxis_BC, Execute := TRUE, Position := 0.0, Mode := MC_HOME_SET_POSITION);
            MC_Home_M_CD(Axis := MasterAxis_CD, Execute := TRUE, Position := 0.0, Mode := MC_HOME_SET_POSITION);
            MC_Home_A(Axis := AxisA, Execute := TRUE, Position := 0.0, Mode := MC_HOME_SET_POSITION);
            MC_Home_B(Axis := AxisB, Execute := TRUE, Position := 0.0, Mode := MC_HOME_SET_POSITION);
            MC_Home_C(Axis := AxisC, Execute := TRUE, Position := 0.0, Mode := MC_HOME_SET_POSITION);
            MC_Home_D(Axis := AxisD, Execute := TRUE, Position := 0.0, Mode := MC_HOME_SET_POSITION);

            IF MC_Home_M_AB.Done AND MC_Home_M_BC.Done AND MC_Home_M_CD.Done AND
               MC_Home_A.Done AND MC_Home_B.Done AND MC_Home_C.Done AND MC_Home_D.Done THEN
                MC_Home_M_AB(Execute := FALSE); MC_Home_M_BC(Execute := FALSE); MC_Home_M_CD(Execute := FALSE);
                MC_Home_A(Execute := FALSE); MC_Home_B(Execute := FALSE);
                MC_Home_C(Execute := FALSE); MC_Home_D(Execute := FALSE);

                CurrentAbsPosA := 0.0; CurrentAbsPosB := 0.0;
                CurrentAbsPosC := 0.0; CurrentAbsPosD := 0.0;
                ErrorA := 0.0; ErrorB := 0.0; ErrorC := 0.0; ErrorD := 0.0; // 初始化误差为0
                bInitialHomingDone := TRUE;
                nState := 10;
            END_IF
        ELSE
            nState := 10;
        END_IF

    10: // 准备就绪，等待动作触发 或 自动执行锁存的动作
        SystemReady := TRUE;
        Moving := bAB_Active OR bBC_Active OR bCD_Active;
        AB_Completed := NOT bAB_Active;
        BC_Completed := NOT bBC_Active;
        CD_Completed := NOT bCD_Active;

        // --- 锁存触发请求 (不变) ---
        IF xTrigger_AB AND NOT bPreviousTrigger_AB THEN xLatchTrigger_AB := TRUE; END_IF; bPreviousTrigger_AB := xTrigger_AB;
        IF xTrigger_BC AND NOT bPreviousTrigger_BC THEN xLatchTrigger_BC := TRUE; END_IF; bPreviousTrigger_BC := xTrigger_BC;
        IF xTrigger_CD AND NOT bPreviousTrigger_CD THEN xLatchTrigger_CD := TRUE; END_IF; bPreviousTrigger_CD := xTrigger_CD;

        // --- 运动启动逻辑 (加入探针检测的互锁) ---
        // 只有当所有轴都静止且没有活跃的探针检测时，才允许启动新运动
        IF NOT Moving AND NOT bProbeCycleActive THEN

            // 尝试启动 AB 动作
            IF (xLatchTrigger_AB OR (xTrigger_AB AND NOT bPreviousTrigger_AB)) AND NOT bCamInBC_B_Active THEN
                xLatchTrigger_AB := FALSE; // 清除锁存变量
                // ... (MC_CamOut, MC_CamTableSelect, MC_Home_M_AB, MC_CamIn_AB_A/B, MC_MoveRelative_M_AB 逻辑不变) ...
                MC_CamOut_AB_A(Enable := TRUE, Axis := AxisA); MC_CamOut_AB_B(Enable := TRUE, Axis := AxisB);
                IF MC_CamOut_AB_A.Done AND MC_CamOut_AB_B.Done THEN
                    MC_CamOut_AB_A(Enable := FALSE); MC_CamOut_AB_B(Enable := FALSE);
                    MC_CamTable_Select_FB_A(Enable := TRUE, CamTableID := CamTableID_AB, AxisMaster := MasterAxis_AB, AxisSlave := AxisA);
                    MC_CamTable_Select_FB_B(Enable := TRUE, CamTableID := CamTableID_AB, AxisMaster := MasterAxis_AB, AxisSlave := AxisB);
                    IF MC_CamTable_Select_FB_A.Done AND MC_CamTable_Select_FB_B.Done THEN
                        MC_CamTable_Select_FB_A(Enable := FALSE); MC_CamTable_Select_FB_B(Enable := FALSE);
                        MC_Home_M_AB(Axis := MasterAxis_AB, Execute := TRUE, Position := 0.0, Mode := MC_HOME_SET_POSITION);
                        IF MC_Home_M_AB.Done THEN
                            MC_Home_M_AB(Execute := FALSE);
                            MC_CamIn_AB_A(Enable := TRUE, Master := MasterAxis_AB, Slave := AxisA, MasterStart := 0.0, SlaveStart := CurrentAbsPosA, CamTableID := CamTableID_AB, StartMode := MC_STARTMODE_ABSOLUTE);
                            MC_CamIn_AB_B(Enable := TRUE, Master := MasterAxis_AB, Slave := AxisB, MasterStart := 0.0, SlaveStart := CurrentAbsPosB, CamTableID := CamTableID_AB, StartMode := MC_STARTMODE_ABSOLUTE);
                            MC_MoveRelative_M_AB(Axis := MasterAxis_AB, Execute := TRUE, Distance := MasterMoveDistance_Segment, Velocity := MasterSpeed, Acceleration := Accel, Deceleration := Decel);
                            bAB_Active := TRUE; bAB_Done := FALSE; SystemReady := FALSE;
                        END_IF
                    END_IF
                END_IF
            END_IF

            // 尝试启动 BC 动作
            IF (xLatchTrigger_BC OR (xTrigger_BC AND NOT bPreviousTrigger_BC)) AND NOT bCamInAB_B_Active AND NOT bCamInCD_C_Active THEN
                xLatchTrigger_BC := FALSE;
                // ... (MC_CamOut, MC_CamTableSelect, MC_Home_M_BC, MC_CamIn_BC_B/C, MC_MoveRelative_M_BC 逻辑不变) ...
                MC_CamOut_BC_B(Enable := TRUE, Axis := AxisB); MC_CamOut_BC_C(Enable := TRUE, Axis := AxisC);
                IF MC_CamOut_BC_B.Done AND MC_CamOut_BC_C.Done THEN
                    MC_CamOut_BC_B(Enable := FALSE); MC_CamOut_BC_C(Enable := FALSE);
                    MC_CamTable_Select_FB_B(Enable := TRUE, CamTableID := CamTableID_BC, AxisMaster := MasterAxis_BC, AxisSlave := AxisB);
                    MC_CamTable_Select_FB_C(Enable := TRUE, CamTableID := CamTableID_BC, AxisMaster := MasterAxis_BC, AxisSlave := AxisC);
                    IF MC_CamTable_Select_FB_B.Done AND MC_CamTable_Select_FB_C.Done THEN
                        MC_CamTable_Select_FB_B(Enable := FALSE); MC_CamTable_Select_FB_C(Enable := FALSE);
                        MC_Home_M_BC(Axis := MasterAxis_BC, Execute := TRUE, Position := 0.0, Mode := MC_HOME_SET_POSITION);
                        IF MC_Home_M_BC.Done THEN
                            MC_Home_M_BC(Execute := FALSE);
                            MC_CamIn_BC_B(Enable := TRUE, Master := MasterAxis_BC, Slave := AxisB, MasterStart := 0.0, SlaveStart := CurrentAbsPosB, CamTableID := CamTableID_BC, StartMode := MC_STARTMODE_ABSOLUTE);
                            MC_CamIn_BC_C(Enable := TRUE, Master := MasterAxis_BC, Slave := AxisC, MasterStart := 0.0, SlaveStart := CurrentAbsPosC, CamTableID := CamTableID_BC, StartMode := MC_STARTMODE_ABSOLUTE);
                            MC_MoveRelative_M_BC(Axis := MasterAxis_BC, Execute := TRUE, Distance := MasterMoveDistance_Segment, Velocity := MasterSpeed, Acceleration := Accel, Deceleration := Decel);
                            bBC_Active := TRUE; bBC_Done := FALSE; SystemReady := FALSE;
                        END_IF
                    END_IF
                END_IF
            END_IF

            // 尝试启动 CD 动作
            IF (xLatchTrigger_CD OR (xTrigger_CD AND NOT bPreviousTrigger_CD)) AND NOT bCamInBC_C_Active THEN
                xLatchTrigger_CD := FALSE;
                // ... (MC_CamOut, MC_CamTableSelect, MC_Home_M_CD, MC_CamIn_CD_C/D, MC_MoveRelative_M_CD 逻辑不变) ...
                MC_CamOut_CD_C(Enable := TRUE, Axis := AxisC); MC_CamOut_CD_D(Enable := TRUE, Axis := AxisD);
                IF MC_CamOut_CD_C.Done AND MC_CamOut_CD_D.Done THEN
                    MC_CamOut_CD_C(Enable := FALSE); MC_CamOut_CD_D(Enable := FALSE);
                    MC_CamTable_Select_FB_C(Enable := TRUE, CamTableID := CamTableID_CD, AxisMaster := MasterAxis_CD, AxisSlave := AxisC);
                    MC_CamTable_Select_FB_D(Enable := TRUE, CamTableID := CamTableID_CD, AxisMaster := MasterAxis_CD, AxisSlave := AxisD);
                    IF MC_CamTable_Select_FB_C.Done AND MC_CamTable_Select_FB_D.Done THEN
                        MC_CamTable_Select_FB_C(Enable := FALSE); MC_CamTable_Select_FB_D(Enable := FALSE);
                        MC_Home_M_CD(Axis := MasterAxis_CD, Execute := TRUE, Position := 0.0, Mode := MC_HOME_SET_POSITION);
                        IF MC_Home_M_CD.Done THEN
                            MC_Home_M_CD(Execute := FALSE);
                            MC_CamIn_CD_C(Enable := TRUE, Master := MasterAxis_CD, Slave := AxisC, MasterStart := 0.0, SlaveStart := CurrentAbsPosC, CamTableID := CamTableID_CD, StartMode := MC_STARTMODE_ABSOLUTE);
                            MC_CamIn_CD_D(Enable := TRUE, Master := MasterAxis_CD, Slave := AxisD, MasterStart := 0.0, SlaveStart := CurrentAbsPosD, CamTableID := CamTableID_CD, StartMode := MC_STARTMODE_ABSOLUTE);
                            MC_MoveRelative_M_CD(Axis := MasterAxis_CD, Execute := TRUE, Distance := MasterMoveDistance_Segment, Velocity := MasterSpeed, Acceleration := Accel, Deceleration := Decel);
                            bCD_Active := TRUE; bCD_Done := FALSE; SystemReady := FALSE;
                        END_IF
                    END_IF
                END_IF
            END_IF

        END_IF // End IF NOT Moving AND NOT bProbeCycleActive

        // --- 运动完成检测与位置更新 (不变) ---
        // (省略，与之前的MC_Cam方案相同)
        // 检查 AB 组是否完成运动
        IF bAB_Active AND MC_MoveRelative_M_AB.Done THEN
            MC_MoveRelative_M_AB(Execute := FALSE);
            MC_CamOut_AB_A(Enable := TRUE, Axis := AxisA); MC_CamOut_AB_B(Enable := TRUE, Axis := AxisB);
            IF MC_CamOut_AB_A.Done AND MC_CamOut_AB_B.Done THEN
                MC_CamOut_AB_A(Enable := FALSE); MC_CamOut_AB_B(Enable := FALSE);
                CurrentAbsPosA := CurrentAbsPosA + RotationAnglePerSegment;
                CurrentAbsPosB := CurrentAbsPosB + RotationAnglePerSegment;
                bAB_Active := FALSE; bAB_Done := TRUE;
            END_IF
        END_IF

        // 检查 BC 组是否完成运动
        IF bBC_Active AND MC_MoveRelative_M_BC.Done THEN
            MC_MoveRelative_M_BC(Execute := FALSE);
            MC_CamOut_BC_B(Enable := TRUE, Axis := AxisB); MC_CamOut_BC_C(Enable := TRUE, Axis := AxisC);
            IF MC_CamOut_BC_B.Done AND MC_CamOut_BC_C.Done THEN
                MC_CamOut_BC_B(Enable := FALSE); MC_CamOut_BC_C(Enable := FALSE);
                CurrentAbsPosB := CurrentAbsPosB + RotationAnglePerSegment;
                CurrentAbsPosC := CurrentAbsPosC + RotationAnglePerSegment;
                bBC_Active := FALSE; bBC_Done := TRUE;
            END_IF
        END_IF

        // 检查 CD 组是否完成运动
        IF bCD_Active AND MC_MoveRelative_M_CD.Done THEN
            MC_MoveRelative_M_CD(Execute := FALSE);
            MC_CamOut_CD_C(Enable := TRUE, Axis := AxisC); MC_CamOut_CD_D(Enable := TRUE, Axis := AxisD);
            IF MC_CamOut_CD_C.Done AND MC_CamOut_CD_D.Done THEN
                MC_CamOut_CD_C(Enable := FALSE); MC_CamOut_CD_D(Enable := FALSE);
                CurrentAbsPosC := CurrentAbsPosC + RotationAnglePerSegment;
                CurrentAbsPosD := CurrentAbsPosD + RotationAnglePerSegment;
                bCD_Active := FALSE; bCD_Done := TRUE;
            END_IF
        END_IF

        // --- 触发探针检测周期 ---
        // 当系统静止 (所有轴都已完成运动) 且没有活跃的探针检测时，启动一轮新的探针检测
        // 可以设置为每 N 个循环后触发一次，或者手动触发
        IF NOT Moving AND NOT bProbeCycleActive THEN
            // 假设我们希望在每个完整送料周期后（例如，所有的 AB, BC, CD 动作都已执行过），进行一次探针检测。
            // 也可以设置为定时触发，或在系统空闲超过一定时间后触发。
            // 这里我们简化为，只要系统不忙，就尝试启动探针检测。
            xStartProbeA := TRUE;
            xStartProbeB := TRUE;
            xStartProbeC := TRUE;
            xStartProbeD := TRUE;
            bProbeCycleActive := TRUE; // 标记探针检测周期开始
        END_IF

        // --- MC_TouchProbe 功能块的执行 ---
        // 螺杆A的探针
        MC_TouchProbe_A(
            Axis := AxisA,
            Execute := xStartProbeA,
            Enable := TRUE, // 轴使能后，TouchProbe通常也需要使能
            SensorInput := xSensorA_Input,
            ProbeMode := ProbeMode // MC_TOUCHPROBE_CONTINUOUS 不停止轴，只记录位置
        );

        IF MC_TouchProbe_A.InTriggeredPosition THEN // 传感器触发后，位置被记录
            DetectedPositionA := MC_TouchProbe_A.RecordedPosition;
            // 计算误差: 实际检测到的位置 - 理论位置 (理论位置是相对回零点的绝对位置)
            // 这里假设我们的ProbePositionA是螺杆A经过物理对齐点时，其轴编码器的理论读数
            // 例如，如果对齐点是A轴的0度，那么ProbePositionA就是0
            // 如果对齐点是A轴的某个特征点，其编码器对应角度是180度，那么ProbePositionA就是180
            ErrorA := DetectedPositionA - ProbePositionA;
            // **关键：用检测到的实际位置修正 CurrentAbsPosA**
            // 考虑误差累计，这里的修正需要将当前误差考虑进去
            // 更严谨的做法是：CurrentAbsPosA = CurrentAbsPosA - ErrorA;
            // 但是MC_TouchProbe返回的是触发时的轴位置，所以直接更新CurrentAbsPosA：
            // 假设我们总是将探针点视为 CurrentAbsPos 的一个基准点
            // 例如，如果当前循环结束后，A轴应该在 450 度，但传感器在 450.5 度触发，
            // 那么 ErrorA = 450.5 - 450 = 0.5 度。
            // 我们应该将 CurrentAbsPosA 更新为 DetectedPositionA，这样下次 CamIn 就会从 450.5 度开始计算
            // 确保每次 CamIn 都是基于最新的真实位置。
            CurrentAbsPosA := DetectedPositionA;
            xStartProbeA := FALSE; // 停止当前轴的探针请求
        END_IF;

        // 螺杆B的探针 (类似螺杆A)
        MC_TouchProbe_B(Axis := AxisB, Execute := xStartProbeB, Enable := TRUE, SensorInput := xSensorB_Input, ProbeMode := ProbeMode);
        IF MC_TouchProbe_B.InTriggeredPosition THEN
            DetectedPositionB := MC_TouchProbe_B.RecordedPosition;
            ErrorB := DetectedPositionB - ProbePositionB;
            CurrentAbsPosB := DetectedPositionB;
            xStartProbeB := FALSE;
        END_IF;

        // 螺杆C的探针 (类似螺杆A)
        MC_TouchProbe_C(Axis := AxisC, Execute := xStartProbeC, Enable := TRUE, SensorInput := xSensorC_Input, ProbeMode := ProbeMode);
        IF MC_TouchProbe_C.InTriggeredPosition THEN
            DetectedPositionC := MC_TouchProbe_C.RecordedPosition;
            ErrorC := DetectedPositionC - ProbePositionC;
            CurrentAbsPosC := DetectedPositionC;
            xStartProbeC := FALSE;
        END_IF;

        // 螺杆D的探针 (类似螺杆A)
        MC_TouchProbe_D(Axis := AxisD, Execute := xStartProbeD, Enable := TRUE, SensorInput := xSensorD_Input, ProbeMode := ProbeMode);
        IF MC_TouchProbe_D.InTriggeredPosition THEN
            DetectedPositionD := MC_TouchProbe_D.RecordedPosition;
            ErrorD := DetectedPositionD - ProbePositionD;
            CurrentAbsPosD := DetectedPositionD;
            xStartProbeD := FALSE;
        END_IF;

        // 检测所有探针检测是否完成
        IF bProbeCycleActive AND
           NOT xStartProbeA AND NOT MC_TouchProbe_A.Active AND
           NOT xStartProbeB AND NOT MC_TouchProbe_B.Active AND
           NOT xStartProbeC AND NOT MC_TouchProbe_C.Active AND
           NOT xStartProbeD AND NOT MC_TouchProbe_D.Active THEN
            bProbeCycleActive := FALSE; // 探针检测周期完成
            // 此时可以根据需要对 CurrentAbsPosX 进行进一步的微调，
            // 或者只是让系统回到 SystemReady 状态，等待下一个运动或新的探针周期。
        END_IF;

        // --- 复位逻辑 ---
        IF xResetButton AND NOT bPreviousResetButton THEN
            bInitialHomingDone := FALSE;
            xLatchTrigger_AB := FALSE; xLatchTrigger_BC := FALSE; xLatchTrigger_CD := FALSE; // 复位时清除所有锁存
            bProbeCycleActive := FALSE; // 停止所有探针检测
            xStartProbeA := FALSE; xStartProbeB := FALSE; xStartProbeC := FALSE; xStartProbeD := FALSE;
            nState := 0;
        END_IF
        bPreviousResetButton := xResetButton;

END_CASE