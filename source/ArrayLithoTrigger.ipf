#pragma rtGlobals=1		// Use modern global access method.

// Version History:

// Version 1.3
// 	Completed main UI with 5 LEDs
//	Added separate manual tip position calibration UI
//	Implemented the single second lookup algorithm
// 	Setting up the crosspoint panel setup for OutA, OutB
// 	Start of litho resets the secondChance and CurrentIndex waves.

// Upcoming changes:
// 	Writing the binary information to the Channels in the bg function

// Version 1.2
//	Lithography.ipf -> master writing bit / variable (instead of BNC outputs)
// 	Goes through all lines in master X,Y Litho waves (searches current and next line only)

// Version 1.1
//	Goes through only the first line of master X,Y Litho waves and flashes an LED if near a line. 	

// Version 1.0
//	Calibrates the tip position.
// 	displays the x and y position of the tip using a background function

Menu "Macros"
	"Lithography Position Triggerer", LithoTriggerDriver()
	"Tip Position Calibration", TipPosCalibDriver()
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
	Variable doingLitho = NumVarOrDefault(":gdoingLitho",0)
	Variable/G gdoingLitho= doingLitho
	
	if(!exists("gActive"))
		Make/O/N=5 gActive
	endif
	
	// Index (in wave) of line currently under  scrutiny
	// MUST be reset on each lithography start
	if(!exists("gCurrentIndex"))
		Make/O/N=5 gCurrentIndex
	endif	
	
	// Only one second second lookup (change in current index)
	// may be allowed. This should be reset after the line the cantilever
	// was looking for was found.
	//Must be reset at start of litho
	if(!exists("gSecondLookup"))
		Make/O/N=5 gSecondLookup
	endif
	
	// Calibrate tip position here.
	if(gPosCalibrated == 0)
		CalibratePosn()
	Endif
			
	// Should be starting and stopping the meter within Lithography.ipf
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

// This is the interface function with Lithography.ipf
Function performingLitho(mode)
	Variable mode
	
	String dfSave = GetDataFolder(1)
	SetDataFolder root:packages:SmartLitho:ArrayTrigger
	NVAR gDoingLitho
	gDoingLitho = mode
	SetDataFolder dfSave
End

// This is the interface function with Lithography.ipf
Function resetLithoSetup()
	String dfSave = GetDataFolder(1)
	SetDataFolder root:packages:SmartLitho:ArrayTrigger
	Wave gSecondLookup, gCurrentIndex
	Redimension /N=(0) gSecondLookup, gCurrentIndex
	Redimension /N=(5) gSecondLookup, gCurrentIndex
	SetDataFolder dfSave
	
	// Rewire XPT for OutA, OutB
	WireXpt("BNCOut0Popup","OutA")
	WireXpt("BNCOut1Popup","OutB")
	
	//print "Reset crosspoint and necessary waves"
End

Function WireXpt(whichpopup,channel)
	String whichpopup, channel
	
	execute("XPTPopupFunc(\"" + whichpopup + "\",WhichListItem(\""+ channel +"\",Root:Packages:MFP3D:XPT:XPTInputList,\";\",0,0)+1,\""+ channel +"\")")

End


Window LithoTriggerPanel(): Panel
	
	PauseUpdate; Silent 1		// building window...
	NewPanel /K=1 /W=(485,145, 730,435) as "Litho Trigger Panel"
	SetDrawLayer UserBack
	
	SetDrawEnv fsize=18
	DrawText 16,37, "Tip Position (um)"
	
	ValDisplay vd_Xpos,pos={16,50},size={90,20},title="X:"
	ValDisplay vd_Xpos,limits={0,10,0},fsize=14
	ValDisplay vd_Xpos, value=root:Packages:SmartLitho:ArrayTrigger:GXpos
	
	ValDisplay vd_Ypos,pos={130,50},size={90,20},title="Y:"
	ValDisplay vd_Ypos,limits={0,10,0},fsize=14
	ValDisplay vd_Ypos, value=root:Packages:SmartLitho:ArrayTrigger:GYpos
	
	Button but_ManCalib,pos={17,86},size={207,25},title="Manual Tip Position Calibration", proc=TipPosCalibDriver
	
	SetVariable sv_tolerance,pos={47,127},size={150,20},title="Tolerance"
	SetVariable sv_tolerance,fsize=14, limits={1E-8,1E-5,0}
	SetVariable sv_tolerance, value=root:Packages:SmartLitho:ArrayTrigger:GTolerance
	
	SetDrawEnv fsize=18
	DrawText 16,185, "Active Cantilevers"
	
	SetDrawEnv fsize=16
	DrawText 21,211, "1"
	SetDrawEnv fsize=16
	DrawText 66,211, "2"
	SetDrawEnv fsize=16
	DrawText 111,211, "3"
	SetDrawEnv fsize=16
	DrawText 156,211, "4"
	SetDrawEnv fsize=16
	DrawText 201,211, "5"
	
	ValDisplay vd_activeLED1, title="", value=Root:Packages:SmartLitho:ArrayTrigger:gActive[0]
	ValDisplay vd_activeLED1, mode=2, limits={0,1,0}, highColor= (0,65280,0), zeroColor= (0,12032,0)
	ValDisplay vd_activeLED1, lowColor= (0,12032,0), pos={18,220},size={16,16}, barmisc={0,0}, fsize=14
	
	ValDisplay vd_activeLED2, title="", value=Root:Packages:SmartLitho:ArrayTrigger:gActive[1]
	ValDisplay vd_activeLED2, mode=2, limits={0,1,0}, highColor= (0,65280,0), zeroColor= (0,12032,0)
	ValDisplay vd_activeLED2, lowColor= (0,12032,0), pos={62,220},size={16,16}, barmisc={0,0}, fsize=14
	
	ValDisplay vd_activeLED3, title="", value=Root:Packages:SmartLitho:ArrayTrigger:gActive[2]
	ValDisplay vd_activeLED3, mode=2, limits={0,1,0}, highColor= (0,65280,0), zeroColor= (0,12032,0)
	ValDisplay vd_activeLED3, lowColor= (0,12032,0), pos={109,220},size={16,16}, barmisc={0,0}, fsize=14
	
	ValDisplay vd_activeLED4, title="", value=Root:Packages:SmartLitho:ArrayTrigger:gActive[3]
	ValDisplay vd_activeLED4, mode=2, limits={0,1,0}, highColor= (0,65280,0), zeroColor= (0,12032,0)
	ValDisplay vd_activeLED4, lowColor= (0,12032,0), pos={153,220},size={16,16}, barmisc={0,0}, fsize=14
	
	ValDisplay vd_activeLED5, title="", value=Root:Packages:SmartLitho:ArrayTrigger:gActive[4]
	ValDisplay vd_activeLED5, mode=2, limits={0,1,0}, highColor= (0,65280,0), zeroColor= (0,12032,0)
	ValDisplay vd_activeLED5, lowColor= (0,12032,0), pos={199,220},size={16,16}, barmisc={0,0}, fsize=14

	SetDrawEnv fsize=16, textrgb= (0,0,65280),fstyle= 1
	DrawText 12,275, "Suhas Somnath, UIUC 2011"
End

Function bgPosMonitor()
		
	String dfSave = GetDataFolder(1)
		
	SetDataFolder root:packages:SmartLitho:ArrayTrigger
	NVAR gXoffset, gYoffset, gXpos, gYpos, gRunMeter, gTolerance, gDoingLitho
	Wave gActive, gCurrentIndex, gSecondLookup

	gXpos = (gXoffset + td_RV("Input.X")*GV("XLVDTSens"))* 1E+6
	gYpos = (gYoffset + td_RV("Input.Y")*GV("YLVDTSens")) * 1E+6
	
	SetDataFolder root:packages:MFP3D:Litho
	Wave XLitho, YLitho
	
	Variable i=0;
	
	
	// Add in the main gDoingLitho check here
	if(!gDoingLitho)
		for(i=0;i<5; i=i+1) 
			gActive[i] = 0
		endfor
		return !gRunMeter	
	endif
	
	
	for(i=0;i<1; i=i+1) // change to 5 later
		Variable lineindex = gCurrentIndex[i]
		Variable hit = pointLineDist(XLitho[lineindex],YLitho[lineindex],XLitho[lineindex+1],YLitho[lineindex+1],gXpos*1e-6,gYpos*1e-6, gTolerance)
		if(hit==1)
			gActive[i] = 1
			gSecondLookup[i]=0
			// no changes to gCurrentIndex
		else
			if(gSecondLookup[i] == 1)
				gActive[i] = 0
				return !gRunMeter	
			endif
			//print "is not on line"
			// Look in next line
			if(numtype(XLitho[lineindex+2]) != 0)// End of this segment
				gCurrentIndex[i] = gCurrentIndex[i] + 3
			else // Next line starting from same end point as prev
				gCurrentIndex[i] = gCurrentIndex[i] + 2
			endif
			lineindex = gCurrentIndex[i]
			hit = pointLineDist(XLitho[lineindex],YLitho[lineindex],XLitho[lineindex+1],YLitho[lineindex+1],gXpos*1e-6,gYpos*1e-6, gTolerance)
			if(hit==1)
				gActive[i] = 1
				gSecondLookup[i]=0
			else
				gActive[i] = 0
				gSecondLookup[i] = 1
			endif
		endif
	endfor
	
	
	SetDataFolder dfSave	
		
	// A return value of 1 stops the background task. a value of 0 keeps it running
	return !gRunMeter					
	
End

Function pointLineDist(xa,ya,xb,yb,xc,yc, tolerance)
	Variable xa,ya,xb,yb,xc,yc, tolerance
	
	if(numtype(xa) != 0 || numtype(ya) != 0 || numtype(xb) != 0 || numtype(yb) != 0 || numtype(xc) != 0 || numtype(yc) != 0)
		return 0
	endif
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


Function TipPosCalibDriver()
	
	// If the panel is already created, just bring it to the front.
	DoWindow/F TipPosCalibPanel
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
	
	// Should be starting and stopping the meter within Lithography.ipf
	Variable/G GrunMeter = 1
	//SetBackground bgThermalMeter()
	//GrunMeter = 1;CtrlBackground period=5,start
	//The delay I've given the background function has
	// a value of 5. or a delay of (5/60 = 1/12 sec) or 12 hz.
	ARBackground("bgPosMonitor",1,"")

	// Create the control panel.
	Execute "TipPosCalibPanel()"
End

Window TipPosCalibPanel(): Panel
	
	PauseUpdate; Silent 1		// building window...
	NewPanel /K=1 /W=(185,145, 430,335) as "Tip Pos Calib Panel"
	SetDrawLayer UserBack
	
	SetDrawEnv fsize=18
	DrawText 16,37, "Tip Position (um)"
	
	ValDisplay vd_Xpos,pos={16,50},size={90,20},title="X:"
	ValDisplay vd_Xpos,limits={0,10,0},fsize=14
	ValDisplay vd_Xpos, value=root:Packages:SmartLitho:ArrayTrigger:GXpos
	
	ValDisplay vd_Ypos,pos={130,50},size={90,20},title="Y:"
	ValDisplay vd_Ypos,limits={0,10,0},fsize=14
	ValDisplay vd_Ypos, value=root:Packages:SmartLitho:ArrayTrigger:GYpos
	
	SetDrawEnv fsize=18
	DrawText 16,105, "Offset (m)"
		
	SetVariable sv_Xoffset,pos={16,113},size={95,20},title="X"
	SetVariable sv_Xoffset,fsize=14, limits={1E-8,1E-5,0}
	SetVariable sv_Xoffset, value=root:Packages:SmartLitho:ArrayTrigger:gXoffset
	
	SetVariable sv_Yoffset,pos={130,113},size={95,20},title="Y"
	SetVariable sv_Yoffset,fsize=14, limits={1E-8,1E-5,0}
	SetVariable sv_Yoffset, value=root:Packages:SmartLitho:ArrayTrigger:gYoffset	

	SetDrawEnv fsize=16, textrgb= (0,0,65280),fstyle= 1
	DrawText 12,171, "Suhas Somnath, UIUC 2011"
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