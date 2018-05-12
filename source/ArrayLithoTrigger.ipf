#pragma rtGlobals=1		// Use modern global access method.

// Version History:

// Current version : 1.0

// Version 1.0
//	Calibrates the tip position.
// 	displays the x and y position of the tip using a background function

Menu "Macros"
	"Lithography Position Triggerer", LithoTriggerDriver()
End

Function LithoTriggerDriver()
	
	// If the panel is already created, just bring it to the front.
	DoWindow/F LithoTriggerPanel
	if (V_Flag != 0)
		return 0
	endif
	
	String dfSave = GetDataFolder(1)
	// Create a data folder in Packages to store globals.
	NewDataFolder/O/S root:packages:SmartLitho
	NewDataFolder/O/S root:packages:SmartLitho:ArrayTrigger
	
	//Variables declaration
	Variable Xoffset = NumVarOrDefault(":gXoffset",0)
	Variable/G gXoffset= Xoffset
	Variable Yoffset = NumVarOrDefault(":gYoffset",0)
	Variable/G gYoffset= Yoffset
	Variable Xpos = NumVarOrDefault(":gXpos",0)
	Variable/G gXpos= Xpos
	Variable Ypos = NumVarOrDefault(":gYpos",0)
	Variable/G gYpos= Ypos
	Variable poscalibrated = NumVarOrDefault(":gposcalibrated",0)
	Variable/G gposcalibrated= poscalibrated
	
	
	// Calibrate tip position here.
	if(gPosCalibrated == 0)
		CalibratePosn()
	Endif
			
	// Starting background process here:
	Variable/G GrunMeter = 1
	//SetBackground bgThermalMeter()
	//GrunMeter = 1;CtrlBackground period=5,start
	//The delay I've given the background function has
	// a value of 5. or a delay of (5/60 = 1/12 sec) or 12 hz.
	ARBackground("bgPosMonitor",1,"")
	
	//Reset the datafolder to the root / previous folder
	SetDataFolder dfSave

	// Create the control panel.
	Execute "LithoTriggerPanel()"
End


Window LithoTriggerPanel(): Panel
	
	PauseUpdate; Silent 1		// building window...
	NewPanel /K=1 /W=(485,145, 745,255) as "Litho Trigger Panel"
	SetDrawLayer UserBack
	
	SetDrawEnv fsize=18
	DrawText 16,37, "Tip Position (um)"
	
	ValDisplay vd_Xpos,pos={16,50},size={100,20},title="X:"
	ValDisplay vd_Xpos,limits={0,10,0},fsize=14
	ValDisplay vd_Xpos, value=root:Packages:SmartLitho:ArrayTrigger:GXpos
	
	ValDisplay vd_Ypos,pos={133,50},size={100,20},title="Y:"
	ValDisplay vd_Ypos,limits={0,10,0},fsize=14
	ValDisplay vd_Ypos, value=root:Packages:SmartLitho:ArrayTrigger:GYpos

	SetDrawEnv fsize=16
	DrawText 38,104, "Suhas Somnath, UIUC 2011"
End

Function bgPosMonitor()
		
	String dfSave = GetDataFolder(1)
		
	SetDataFolder root:packages:SmartLitho:ArrayTrigger
	NVAR gXoffset, gYoffset, gXpos, gYpos, gRunMeter

	gXpos = (gXoffset + td_RV("Input.X")*GV("XLVDTSens"))* 1E+6
	gYpos = (gYoffset + td_RV("Input.Y")*GV("YLVDTSens")) * 1E+6
	
	SetDataFolder dfSave	
		
	// A return value of 1 stops the background task. a value of 0 keeps it running
	return !gRunMeter					
	
End


Function CalibratePosn()

	// Pick point (automatically goes to default (10um, 10um)
	DoForceFunc("ClearForce_2")
	DoForceFunc("DrawForce_2")
	DoForceFunc("GoForce_2")
	
	// Wait for 1 second for tip to reach that position
	Variable t0 = ticks
	do
	while((ticks - t0)/60 < 1)
	
	Wave scanmastervariables = root:Packages:MFP3D:Main:Variables:MasterVariablesWave

	// Grab what the sensors think the position is. offset this later
	String dfSave = GetDataFolder(1)
	SetDataFolder root:Packages:SmartLitho:ArrayTrigger
	NVAR gXoffset, gYoffset, gposcalibrated, gXpos, gYpos
	Variable scansize = scanmastervariables[0];
	gXoffset = scansize/2 - td_RV("Input.X")*GV("XLVDTSens")
	gYoffset =  scansize/2 - td_RV("Input.Y")*GV("YLVDTSens")
	gXpos = scansize/2 * 1E+6
	gYpos = scansize/2 * 1E+6
	gposcalibrated = 1;
	setDataFolder dfSave
	
	DoForceFunc("ClearForce_2")
End