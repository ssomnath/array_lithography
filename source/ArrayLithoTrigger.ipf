#pragma rtGlobals=1		// Use modern global access method.

// Version History:

// Current version : 1.1
//	Goes through only the first line of master X,Y Litho waves and flashes an LED if near a line. 	

// Upcoming changes:
// Lithography.ipf -> master writing bit / variable (instead of BNC outputs)
// New GUI for calibration only -> Manually set the X, Y offset.

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
	Variable tolerance = NumVarOrDefault(":gtolerance",1E-7)
	Variable/G gtolerance= tolerance
	
	if(!exists("gActive"))
		Make/O/N=5 gActive
	endif	
	
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
	NewPanel /K=1 /W=(485,145, 745,435) as "Litho Trigger Panel"
	SetDrawLayer UserBack
	
	SetDrawEnv fsize=18
	DrawText 16,37, "Tip Position (um)"
	
	ValDisplay vd_Xpos,pos={16,50},size={100,20},title="X:"
	ValDisplay vd_Xpos,limits={0,10,0},fsize=14
	ValDisplay vd_Xpos, value=root:Packages:SmartLitho:ArrayTrigger:GXpos
	
	ValDisplay vd_Ypos,pos={133,50},size={100,20},title="Y:"
	ValDisplay vd_Ypos,limits={0,10,0},fsize=14
	ValDisplay vd_Ypos, value=root:Packages:SmartLitho:ArrayTrigger:GYpos
	
	Button but_ManCalib,pos={17,86},size={218,25},title="Manual Tip Position Calibration"//, proc=addExternalPattern
	
	SetVariable sv_tolerance,pos={47,127},size={150,20},title="Tolerance"
	SetVariable sv_tolerance,fsize=14, limits={1E-8,1E-5,0}
	SetVariable sv_tolerance, value=root:Packages:SmartLitho:ArrayTrigger:GTolerance
	
	SetDrawEnv fsize=18
	DrawText 16,185, "Active Cantilevers"
	
	SetDrawEnv fsize=16
	DrawText 21,211, "1"
	SetDrawEnv fsize=16
	DrawText 61,211, "2"
	SetDrawEnv fsize=16
	DrawText 101,211, "3"
	SetDrawEnv fsize=16
	DrawText 141,211, "4"
	SetDrawEnv fsize=16
	DrawText 181,211, "5"
	
	ValDisplay vd_activeLED1, title="", value=Root:Packages:SmartLitho:ArrayTrigger:gActive[0]
	ValDisplay vd_activeLED1, mode=2, limits={0,1,0}, highColor= (0,65280,0), zeroColor= (0,12032,0)
	ValDisplay vd_activeLED1, lowColor= (0,12032,0), pos={18,220},size={16,16}, barmisc={0,0}, fsize=14

	SetDrawEnv fsize=16
	DrawText 44,281, "Suhas Somnath, UIUC 2011"
End

Function bgPosMonitor()
		
	String dfSave = GetDataFolder(1)
		
	SetDataFolder root:packages:SmartLitho:ArrayTrigger
	NVAR gXoffset, gYoffset, gXpos, gYpos, gRunMeter, gTolerance
	Wave gActive

	gXpos = (gXoffset + td_RV("Input.X")*GV("XLVDTSens"))* 1E+6
	gYpos = (gYoffset + td_RV("Input.Y")*GV("YLVDTSens")) * 1E+6
	
	SetDataFolder root:packages:MFP3D:Litho
	Wave XLitho, YLitho
	
	// Assume only one line for now
	Variable i=0;
	for(i=0;i<1; i=i+1) // change to 5 later
		Variable hit = pointLineDist(XLitho[0],YLitho[0],XLitho[1],YLitho[1],gXpos*1e-6,gYpos*1e-6, gTolerance)
		if(hit==1)
			gActive[i] = 1
		else
			gActive[i] = 0
		endif
	endfor
	
	
	SetDataFolder dfSave	
		
	// A return value of 1 stops the background task. a value of 0 keeps it running
	return !gRunMeter					
	
End

Function pointLineDist(xa,ya,xb,yb,xc,yc, tolerance)
	Variable xa,ya,xb,yb,xc,yc, tolerance
	Variable dist = inf;
	// r = (ac.ab)/(ab.ab)
	Variable r = ((xc - xa)*(xb - xa) + (yc-ya)*(yb-ya))/((xb-xa)^2 + (yb-ya)^2);
	//print "r = " + num2str(r)
	if(r > 0 && r < 1)
		//print "case 1"
		// Finding the point p where cp is perpendicular to AB:
		Variable xp = xa + r*(xb-xa);
    		Variable yp = ya + r*(yb-ya);
    		//print "\tPoint P=("+num2str(xp)+","+num2str(yp)+")"
    		dist = ((xp-xc)^2 + (yp-yc)^2)^0.5
    	elseif(r >=1)
		//print "case 2"
		dist = ((xb-xc)^2 + (yb-yc)^2)^0.5
	else //if(r <= 0)
		//print "case 3 ( r<0)"
		dist = ((xa-xc)^2 + (ya-yc)^2)^0.5
	endif
	//print "Distance = " + num2str(dist);
	if(dist > tolerance)
		return 0
	else
		return 1
	endif
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