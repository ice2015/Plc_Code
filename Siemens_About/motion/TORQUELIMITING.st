// 示例：在程序中添加 R_TRIG 实例
VAR
    R_Trig_MFwd   : R_TRIG;
    R_Trig_MRet   : R_TRIG;
    R_Trig_JgFwd  : R_TRIG;
    R_Trig_JgBwd  : R_TRIG;
    // 外部连接的物理/HMI按钮输入
    Ext_Forward_Btn : BOOL;
    Ext_Return_Btn  : BOOL;
    Ext_Jog_Fwd_Btn : BOOL;
    Ext_Jog_Bwd_Btn : BOOL;
END_VAR

// 在主程序逻辑中，功能块调用区域之前
R_Trig_MFwd(CLK := Ext_Forward_Btn, Q => Manual_Forward_Trigger);
R_Trig_MRet(CLK := Ext_Return_Btn, Q => Manual_Return_Trigger);
R_Trig_JgFwd(CLK := Ext_Jog_Fwd_Btn, Q => Jog_Forward_Input);
R_Trig_JgBwd(CLK := Ext_Jog_Bwd_Btn, Q => Jog_Backward_Input);

VAR
    // 轴引用：连接到实际物理轴
    AxisRef             : AXIS_REF;

    // 位置信息
    StartPosition       : LREAL;             // 回零后的起始位置
    CurrentPosition     : LREAL;             // 轴的当前实际位置

    // MC_POWER 功能块相关
    FB_Power            : MC_POWER;
    MC_Power_Enable     : BOOL := TRUE;      // 轴使能信号 (通常连接到安全回路，初始设为TRUE方便测试)

    // MC_HOME 功能块相关
    FB_Home             : MC_HOME;
    MC_Home_Command     : MC_HOME_MODE := MC_HOME_MODE.DEFAULT; // 回零模式

    // MC_RESET 功能块相关
    FB_Reset            : MC_RESET;

    // MC_STOP 功能块相关
    FB_Stop             : MC_STOP;
    Global_Stop_Input   : BOOL := FALSE;     // 全局停止信号 (如急停按钮，初始设为FALSE)

    // MC_MOVEVELOCITY (速度运动) 相关
    MC_MoveVel_Execute  : BOOL := FALSE;     // 速度运动执行信号
    MC_MoveVel_Velocity : LREAL := 100.0;    // 正向运动速度 (单位/秒)

    // MC_TORQUELIMITING (力矩限制) 相关
    MC_TORQUELIMITING_FB : MC_TORQUELIMITING; // 力矩限制功能块实例
    MC_TorqueLim_Execute: BOOL := FALSE;     // 力矩限制激活信号 (由外部逻辑控制)
    MC_TorqueLim_Limit  : LREAL := 0.5;      // 力矩限制值 (0.0 到 1.0, 表示额定力矩的百分比)
    MC_TorqueLim_Active : BOOL := FALSE;     // 力矩限制是否激活的反馈

    // MC_MOVEABSOLUTE (绝对定位) 相关
    MC_MoveAbs_Execute  : BOOL := FALSE;     // 绝对定位执行信号
    MC_MoveAbs_Position : LREAL := 0.0;      // 目标位置 (这里将设为 StartPosition)

    // MC_JOG (点动) 功能相关
    FB_Jog              : MC_JOG;
    Jog_Forward_Input   : BOOL := FALSE;     // JOG 正向点动输入 (连接到HMI/按钮)
    Jog_Backward_Input  : BOOL := FALSE;     // JOG 反向点动输入 (连接到HMI/按钮)
    Jog_Velocity        : LREAL := 50.0;     // JOG 点动速度

    // 手动触发输入 (通常连接到HMI/按钮，并进行上升沿检测)
    Manual_Forward_Trigger : BOOL := FALSE;  // 手动触发正向运动
    Manual_Return_Trigger  : BOOL := FALSE;  // 手动触发返回起始位置

    // 挡块检测相关
    Block_Hit_Detected  : BOOL := FALSE;     // 检测到挡块的标志

    // 程序状态变量 (状态机)
    ProgramState        : INT := 0;          // 当前程序状态

    // 临时变量 (JOG 控制用)
    Axis_In_Auto_Motion : BOOL := FALSE;     // 轴是否处于自动化运动中
END_VAR
// ##################################################################################
// ########################## 功能块的持续调用区域 ################################
// ##################################################################################

// 1. 轴使能 (MC_POWER)：在每个扫描周期都调用，确保轴处于使能状态。
FB_Power(
    AXIS := AxisRef,
    ENABLE := MC_Power_Enable,
    STATUS => FB_Power.STATUS,
    ERROR => FB_Power.ERROR,
    ERRORID => FB_Power.ERRORID
);

// 2. 轴回零 (MC_HOME)：在每个扫描周期都调用，但只有在 ProgramState = 10 时才执行。
FB_Home(
    AXIS := AxisRef,
    EXECUTE := (ProgramState = 10), // 仅在回零状态下执行
    MODE := MC_Home_Command,
    DONE => FB_Home.DONE,
    ERROR => FB_Home.ERROR,
    ERRORID => FB_Home.ERRORID
);

// 3. 轴复位 (MC_RESET)：在每个扫描周期都调用，用于清除轴的故障。
FB_Reset(
    AXIS := AxisRef,
    EXECUTE := (FB_Power.ERROR AND NOT FB_Reset.DONE), // 当轴有错误且复位未完成时执行
    DONE => FB_Reset.DONE,
    ERROR => FB_Reset.ERROR,
    ERRORID => FB_Reset.ERRORID
);

// 4. 全局停止 (MC_STOP)：在每个扫描周期都调用，优先级最高，由 Global_Stop_Input 触发。
FB_Stop(
    AXIS := AxisRef,
    EXECUTE := Global_Stop_Input, // 由外部全局停止信号触发
    DONE => FB_Stop.DONE,
    ERROR => FB_Stop.ERROR,
    ERRORID => FB_Stop.ERRORID
);

// 5. 力矩限制 (MC_TORQUELIMITING)：在每个扫描周期都调用。
//    其 ENABLE 信号由 ProgramState 和 Global_Stop_Input 共同决定。
MC_TorqueLim_Execute := (ProgramState = 30 OR ProgramState = 40 OR ProgramState = 45) // 在这些状态下激活力矩限制
                      AND NOT Global_Stop_Input; // 全局停止时禁用力矩限制

MC_TORQUELIMITING_FB(
    AXIS := AxisRef,
    ENABLE := MC_TorqueLim_Execute, // 由上面计算出的变量控制
    LIMIT := MC_TorqueLim_Limit,
    ACTIVE => MC_TorqueLim_Active
);

// 6. 获取当前位置：在每个扫描周期更新轴的当前位置。
CurrentPosition := AxisRef.ActualPosition;

// 7. 挡块接触检测：在每个扫描周期判断是否推到挡块。
//    **注意：此逻辑需根据实际驱动器反馈和应用场景进行精确编写。**
//    示例：实际力矩达到力矩限制的90% 并且轴速度非常慢。
Block_Hit_Detected := (AxisRef.ActualTorque >= (MC_TorqueLim_Limit * 0.9)) AND (ABS(AxisRef.ActualVelocity) < 0.1);

// ##################################################################################
// ############################### JOG (点动) 功能 ################################
// ##################################################################################

// 判断轴是否处于自动化运动状态 (即 JOG 不可用状态)
Axis_In_Auto_Motion := (ProgramState >= 30 AND ProgramState <= 60); // 自动化运动状态范围

// JOG 功能的执行条件：
// 1. 轴已使能 (POWER ON)
// 2. 轴没有故障
// 3. 轴不处于自动化运动状态 (防止JOG和自动化程序冲突)
// 4. 全局停止信号未激活
IF (FB_Power.STATUS = MC_POWER_STATE.ENABLED) AND NOT FB_Power.ERROR
AND NOT Axis_In_Auto_Motion AND NOT Global_Stop_Input THEN

    // 如果满足条件，则调用 MC_JOG 功能块
    FB_Jog(
        AXIS := AxisRef,
        JOG_FORWARD := Jog_Forward_Input,    // 正向点动按钮输入
        JOG_BACKWARD := Jog_Backward_Input,  // 反向点动按钮输入
        VELOCITY := Jog_Velocity,            // 点动速度
        ACCELERATION := 1000.0,              // 点动加速度
        DECELERATION := 1000.0,              // 点动减速度
        DONE => FB_Jog.DONE,
        ERROR => FB_Jog.ERROR,
        ERRORID => FB_Jog.ERRORID
    );

ELSE
    // 如果不满足 JOG 条件，确保 JOG 功能块被禁用 (停止点动)
    FB_Jog(
        AXIS := AxisRef,
        JOG_FORWARD := FALSE,
        JOG_BACKWARD := FALSE
        // 其他输入不重要，只要 EXECUTE 逻辑为 FALSE 即可
    );
END_IF;

// ##################################################################################
// ############################# 程序状态机 (CASE 语句) ###########################
// ##################################################################################

// 在进入任何状态之前，首先检查全局停止输入。这是最高优先级的安全机制。
// 如果全局停止信号激活，强制跳转到停止处理状态 (ProgramState 90)。
IF Global_Stop_Input THEN
    ProgramState := 90;

    // 同时，立即取消所有自动化运动指令的 EXECUTE 信号，确保轴停止。
    MC_MoveVel_Execute := FALSE;
    MC_MoveAbs_Execute := FALSE;
    // MC_TorqueLim_Execute 已由外部逻辑处理，在全局停止时会自动变为 FALSE。
END_IF;


CASE ProgramState OF
    0: // 状态0: 初始化与等待轴就绪
        // 等待轴使能且没有故障
        IF (FB_Power.STATUS = MC_POWER_STATE.ENABLED) AND NOT FB_Power.ERROR THEN
            ProgramState := 5; // 轴已就绪，准备回零
        END_IF;

    5: // 状态5: 准备回零
        // 设置回零模式，并准备进入回零执行状态
        MC_Home_Command := MC_HOME_MODE.DEFAULT; // 使用默认回零模式
        ProgramState := 10; // 跳转到回零执行状态

    10: // 状态10: 执行回零，等待回零完成
        // MC_HOME 功能块已在外部调用，这里只检查其完成状态。
        IF FB_Home.DONE AND NOT FB_Home.ERROR THEN
            StartPosition := CurrentPosition; // 记录回零后的当前位置作为起始点
            ProgramState := 20; // 回零完成，进入等待正向运动触发状态
        END_IF;

    20: // 状态20: 等待手动触发正向运动
        // 轴已回零并等待操作员指令。
        IF Manual_Forward_Trigger THEN
            Manual_Forward_Trigger := FALSE; // 消耗触发信号，防止重复启动
            ProgramState := 30; // 跳转到启动力矩限制和速度运动状态
        END_IF;

    30: // 状态30: 启动力矩限制并启动正向速度运动
        // MC_TORQUELIMITING_FB 已在 CASE 外部被 MC_TorqueLim_Execute (该状态下为TRUE) 激活。
        // 等待力矩限制功能块报告其已激活 (ACTIVE) 状态，然后启动速度运动。
        IF MC_TorqueLim_Active THEN
            MC_MoveVel_Execute := TRUE; // 启动正向速度运动
            ProgramState := 40; // 进入正向运动进行中状态
        END_IF;

    40: // 状态40: 正向速度运动进行中 (推向挡块)
        MC_MOVEVELOCITY(
            AXIS := AxisRef,
            EXECUTE := MC_MoveVel_Execute,
            VELOCITY := MC_MoveVel_Velocity
        );

        // 如果检测到挡块接触，则进入力矩保持状态。
        IF Block_Hit_Detected THEN
            ProgramState := 45; // 跳转到力矩保持状态
        END_IF;

    45: // 状态45: 力矩保持状态 (持续推向挡块，力矩受限)
        // 轴将持续以设定的速度（被挡块阻碍）推向挡块，力矩会保持在 MC_TorqueLim_Limit。
        // 轴会一直停留在当前状态，直到操作员手动触发返回。
        IF Manual_Return_Trigger THEN
            Manual_Return_Trigger := FALSE; // 消耗触发信号

            MC_MoveVel_Execute := FALSE; // 停止正向速度命令
            // MC_TorqueLim_Execute 将因程序状态离开 45 而自动变为 FALSE (由外部逻辑控制)
            MC_Stop_Execute := TRUE; // 触发轴停止
            ProgramState := 50; // 跳转到停止轴状态
        END_IF;

    50: // 状态50: 停止轴
        // FB_Stop 功能块已在 CASE 外部调用，这里只等待其完成信号。
        IF FB_Stop.DONE THEN
            MC_Stop_Execute := FALSE; // 复位内部停止指令 (如果需要)
            ProgramState := 55; // 轴已停止，准备返回起始位置
        ENDIF;

    55: // 状态55: 准备返回起始位置
        // 轴已停止，直接启动绝对定位返回运动。
        MC_MoveAbs_Execute := TRUE; // 启动绝对定位指令
        MC_MoveAbs_Position := StartPosition; // 目标位置是回零后的起始位置
        ProgramState := 60; // 进入执行返回绝对位置状态

    60: // 状态60: 执行返回绝对位置
        MC_MOVEABSOLUTE(
            AXIS := AxisRef,
            EXECUTE := MC_MoveAbs_Execute,
            POSITION := MC_MoveAbs_Position,
            DONE => MC_MoveAbs_Done
        );
        IF MC_MoveAbs_Done THEN
            MC_MoveAbs_Execute := FALSE; // 复位绝对定位指令
            ProgramState := 20; // 返回到等待正向运动触发的状态，完成一个循环
        END_IF;

    90: // 状态90: 全局停止处理状态
        // 轴因全局停止信号 (Global_Stop_Input) 而停止。
        // 在此状态下，等待全局停止信号解除，并且轴确实停止了。
        IF NOT Global_Stop_Input AND FB_Stop.DONE THEN
            ProgramState := 0; // 全局停止信号解除且轴已停止，返回初始状态等待重新启动
        END_IF;

END_CASE;