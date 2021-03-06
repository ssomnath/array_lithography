#pragma rtGlobals=1		// Use modern global access method.

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////   INSTRUCTIONS FOR CODE USAGE   ///////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Just click on UIUC >> Array Litho Trigger 
// The code should automatically calibrate the tip position recognition
// Use Smart Litho - make 5 layers one for each cantilever. 
// Make a 6th layer that encompasses ALL of the previous layers
// Hide layers 1-5, and only have layer 6 shown. 
// Connect BNCOut 0 as trigger channel 1 (cantilevers 1-3)
// Connect BNC Out 1 as trigger channel 2 (cantilevers (4-5)
// Each time you move the scan window - press the "Automatic" calibration button
// Lock the crosspoint before performing lithgraphy via "Lock" button
// Perform lithography
// Press "Reset" button under Crosspoint to enable scanning / other operations again.


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////   VERSION HISTORY   //////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Upcoming Changes:
// Fix the end of master line triggering
// Fix the sorted pattern triggering

// Version 1.9:
//	Added slope match condition to unsorted triggering to prevent false positive triggering 
//		(if driver crosses sub pattern).

// Version 1.8:
//	Option to choose triggering using sorted or unsorted patterns.
//	Depressed 'Litho' or 'Imaging' button when that mode is in use.
//	Normal setpoint reset to -5 V on Litho Crosspoint lock

// Version 1.7:
//	Array triggering with unsorted lines within each layer.
//	UI Improvements
//	Crosspoint now -> Imaging, Litho, Unlock
//	Crosspoint now sets positive setpoint for imaging 

// Version 1.6:
//       Lithography.ipf now uses Output.C and BNCOut2 instead of Output.B/Ou0 for single cantilever triggering.
//       Cleaned up UI
//       Added Calibration - manual/auto 
//       Added  Crosspoint lock/unlock buttons
//       Auto Caibration button takes over previous - refresh button (restarting bgfun) & now recalibrates position
//       Auto Caibration button now accounts for scan position change.
//       Auto calibration button now refreshes at global rate

// Version 1.5:
// 	Writing the binary information to the Channels in the bg function
//	Make crosspoint panel changes persist.
//	Refresh button to restart bg process
//	Make the bgfunction execute faster. (remove burst)?
//	Get rid of annoying Wave referencing error

// Version 1.4:
//	From this version on, this code has to be tied with the SmartLitho code for the different layers.
//	It can be made to compile without the SmartLitho but cannot run without it because of wave references
//	Goes through the five layers in the SmartLitho folder and searches through them now.
//	Corrected the 'not-yet-found-my-line' algorithm

// Version 1.3
// 	Completed main UI with 5 LEDs
//	Added separate manual tip position calibration UI
//	Implemented the single second lookup algorithm
// 	Setting up the crosspoint panel setup for OutA, OutB
// 	Start of litho resets the secondChance and CurrentIndex waves.

// Version 1.2
//	Lithography.ipf -> master writing bit / variable (instead of BNC outputs)
// 	Goes through all lines in master X,Y Litho waves (searches current and next line only)

// Version 1.1
//	Goes through only the first line of master X,Y Litho waves and flashes an LED if near a line. 	

// Version 1.0
//	Calibrates the tip position.
// 	displays the x and y position of the tip using a background function


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////   BEGIN CODE   /////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Menu "UIUC"
	SubMenu "Lithography"
		"Array Litho Trigger", LithoTriggerDriver()
	End
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
	Variable tolerance = NumVarOrDefault(":gtolerance",1E-7)// This is safe. The tip does drift quite a bit otherwise
	Variable/G gtolerance= tolerance
	Variable doingLitho = NumVarOrDefault(":gdoingLitho",0)
	Variable/G gdoingLitho= doingLitho
	Variable bgFunRate = NumVarOrDefault(":gbgFunRate",10)
	Variable/G gbgFunRate= bgFunRate // Higher this number - faster the background function runs
	Variable sortOrder = NumVarOrDefault(":gsortOrder",1)
	Variable/G gsortOrder= sortOrder
	Variable/G gDriverIndex= 0
	Variable/G gDriverSlope= NaN
	
	Variable/G gDummy = 0;
	
	if(!exists("gActive"))
		Make/O/N=5 gActive
	endif
	
	// Index (in wave) of line currently under  scrutiny
	// MUST be reset on each lithography start
	if(!exists("gCurrentIndex2"))
		Make/O/N=5 gCurrentIndex2
	endif	
	
	// Similar to gCurrent Index but instead it keeps track 
	// of the last line with a hit.
	// Must be reset to -1 for all cantilevers on Litho start
	if(!exists("gPrevIndex") || !exists("gPrevIndex2"))
		Make/O/N=5 gPrevIndex, gPrevIndex2
	else
		Wave gPrevIndex, gPrevIndex2
	endif
	Variable i=0
	for(i=0; i<5;i+=1)
		gPrevIndex[i] = -1;
		gPrevIndex2[i] = -1;
	endfor
	
	// Calibrate tip position here.
	if(gPosCalibrated == 0)
		CalibratePosn()
	Endif
			
	Variable/G GrunMeter = 1

	ARBackground("bgPosMonitor",gbgFunRate,"")
	calcDriverSlope(-1)
	
	//Reset the datafolder to the root / previous folder
	SetDataFolder dfSave

	// Create the control panel.
	Execute "LithoTriggerPanel()"
End

Window LithoTriggerPanel(): Panel
	
	PauseUpdate; Silent 1		// building window...
	NewPanel /K=1 /W=(485,145, 728,585) as "Array Trigger Panel"
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
	DrawText 16,111, "Calibrate Position"
		
	Button but_Refresh,pos={33,122},size={78,25},title="Automatic", proc=AutoTipPosCalib
	
	Button but_ManCalib,pos={135,122},size={78,25},title="Manual", proc=TipPosCalibDriver
	
	SetDrawEnv fsize=18
	DrawText 16,185, "Pattern Order"
	
	CheckBox radio_Sort1, pos={35,203},size={135,18},title="Unsorted",live= 1
	CheckBox radio_Sort1, value=1, proc=SetSortOrder,mode=1
	
	CheckBox radio_Sort2, pos={146,203},size={135,18},title="Sorted",live= 1
	CheckBox radio_Sort2, value=0, proc=SetSortOrder,mode=1
	
	SetDrawEnv fsize=18
	DrawText 16,256, "Crosspoint"
		
	Button but_XPTLitholock,pos={23,269},size={50,32},title="Litho", proc=LockLithoXPT
	
	Button but_XPTReadlock,pos={84,269},size={71,32},title="Imaging", proc=LockReadXPT
	
	Button but_XPTreset,pos={165,269},size={59,32},title="Reset", proc=ResetXPT
	
	SetDrawEnv fsize=18
	DrawText 16,337, "Active Cantilevers"
	
	SetDrawEnv fsize=16
	DrawText 21,367, "1"
	SetDrawEnv fsize=16
	DrawText 66,367, "2"
	SetDrawEnv fsize=16
	DrawText 111,367, "3"
	SetDrawEnv fsize=16
	DrawText 156,367, "4"
	SetDrawEnv fsize=16
	DrawText 203,367, "5"
	
	ValDisplay vd_activeLED1, title="", value=Root:Packages:SmartLitho:ArrayTrigger:gActive[0]
	ValDisplay vd_activeLED1, mode=2, limits={0,1,0}, highColor= (0,65280,0), zeroColor= (0,12032,0)
	ValDisplay vd_activeLED1, lowColor= (0,12032,0), pos={18,376},size={16,16}, barmisc={0,0}, fsize=14
	
	ValDisplay vd_activeLED2, title="", value=Root:Packages:SmartLitho:ArrayTrigger:gActive[1]
	ValDisplay vd_activeLED2, mode=2, limits={0,1,0}, highColor= (0,65280,0), zeroColor= (0,12032,0)
	ValDisplay vd_activeLED2, lowColor= (0,12032,0), pos={62,376},size={16,16}, barmisc={0,0}, fsize=14
	
	ValDisplay vd_activeLED3, title="", value=Root:Packages:SmartLitho:ArrayTrigger:gActive[2]
	ValDisplay vd_activeLED3, mode=2, limits={0,1,0}, highColor= (0,65280,0), zeroColor= (0,12032,0)
	ValDisplay vd_activeLED3, lowColor= (0,12032,0), pos={109,376},size={16,16}, barmisc={0,0}, fsize=14
	
	ValDisplay vd_activeLED4, title="", value=Root:Packages:SmartLitho:ArrayTrigger:gActive[3]
	ValDisplay vd_activeLED4, mode=2, limits={0,1,0}, highColor= (0,65280,0), zeroColor= (0,12032,0)
	ValDisplay vd_activeLED4, lowColor= (0,12032,0), pos={153,376},size={16,16}, barmisc={0,0}, fsize=14
	
	ValDisplay vd_activeLED5, title="", value=Root:Packages:SmartLitho:ArrayTrigger:gActive[4]
	ValDisplay vd_activeLED5, mode=2, limits={0,1,0}, highColor= (0,65280,0), zeroColor= (0,12032,0)
	ValDisplay vd_activeLED5, lowColor= (0,12032,0), pos={199,376},size={16,16}, barmisc={0,0}, fsize=14

	SetDrawEnv fsize=16, textrgb= (0,0,65280),fstyle= 1
	DrawText 12,431, "Suhas Somnath, UIUC 2011"
End

Function SetSortOrder(name,value)
	String name
	Variable value
	
	String dfSave = GetDataFolder(1)
	SetDataFolder Root:Packages:SmartLitho:ArrayTrigger
	NVAR gSortOrder
	
	strswitch (name)
		case "radio_Sort1":
			gSortOrder= 1
			break
		case "radio_Sort2":
			gSortOrder= 2
			break
	endswitch
	CheckBox radio_Sort1,value= gSortOrder==1
	CheckBox radio_Sort2,value= gSortOrder==2
	
	SetDataFolder dfSave
End

Function AutoTipPosCalib(ctrlname) : ButtonControl
	String ctrlname
	
	// Restart background function monitoring tip position (in case of compilation error)
	String dfSave = GetDataFolder(1)
	SetDataFolder root:packages:SmartLitho:ArrayTrigger
	NVAR GrunMeter, gBgFunRate
	GRunMeter = 1
	ARBackground("bgPosMonitor",gbgFunRate,"")
	calcDriverSlope(-1)
	SetDataFolder dfSave
	
	// Also calibrate position while we're at it
	CalibratePosn()
		
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
	Wave gPrevIndex, gCurrentIndex2, gPrevIndex2
	Redimension /N=(0) gCurrentIndex2
	Redimension /N=(5) gCurrentIndex2
	Variable i=0
	for(i=0; i<5;i+=1)
		gPrevIndex[i] = -1;
		gPrevIndex2[i] = -1;
	endfor
	SetDataFolder dfSave
	
	// Wiring the XPT doesn't seem to work here. 
	// Rewire XPT for OutA, OutB
	WireXPT2("BNCOut0Popup","OutA")
	WireXPT2("BNCOut1Popup","OutB")
	XPTButtonFunc("WriteXPT")
	
	//print "Reset crosspoint and necessary waves"
End

Function LockLithoXPT(ctrlname) : ButtonControl
	String ctrlname
	
	XPTPopupFunc("LoadXPTPopup",7,"Litho")
	WireXPT2("BNCOut0Popup","OutA")
	WireXPT2("BNCOut1Popup","OutB")
	XPTButtonFunc("WriteXPT")
	ARCheckFunc("DontChangeXPTCheck",1)

	Button but_XPTLitholock, disable=2
	Button but_XPTReadlock, disable=0
	Button but_XPTreset, disable=0
	
	// This probably affects litho as well - just to be safe
	MainSetVarFunc("IntegralGainSetVar_0",10,"10","MasterVariablesWave[%IntegralGain][%Value]")
	MainSetpointSetVarFunc("SetPointSetVar_0",-5,"-5.000 V","MasterVariablesWave[%DeflectionSetpointVolts][%Value]");
	
	AutoTipPosCalib("") // in case I forget
	
End

Function LockReadXPT(ctrlname) : ButtonControl
	String ctrlname
	
	XPTPopupFunc("LoadXPTPopup",4,"DCScan")
	WireXPT2("BNCOut0Popup","OutC")// Line trigger
	WireXPT2("InAPopup","BNCIn0")
	WireXPT2("InBPopup","BNCIn1")
	XPTButtonFunc("WriteXPT")
	ARCheckFunc("DontChangeXPTCheck",1)
	
	Button but_XPTLitholock, disable=0
	Button but_XPTReadlock, disable=2
	Button but_XPTreset, disable=0
	
	MainSetVarFunc("SetpointSetVar_0",0.1,"0.1","MasterVariablesWave[%DeflectionSetpointVolts][%Value]")
	MainSetVarFunc("IntegralGainSetVar_0",0.5,"0.5","MasterVariablesWave[%IntegralGain][%Value]")
	
End

Function ResetXPT(ctrlname) : ButtonControl
	String ctrlname

	WireXPT2("BNCOut0Popup","Ground")
	WireXPT2("BNCOut1Popup","Ground")
	XPTButtonFunc("WriteXPT")
	ARCheckFunc("DontChangeXPTCheck",0)
	
	Button but_XPTLitholock, disable=0
	Button but_XPTReadlock, disable=0
	Button but_XPTreset, disable=0
	
End

Function WireXPT2(whichpopup,channel)
	String whichpopup, channel
	
	execute("XPTPopupFunc(\"" + whichpopup + "\",WhichListItem(\""+ channel +"\",Root:Packages:MFP3D:XPT:XPTInputList,\";\",0,0)+1,\""+ channel +"\")")

End

Function calcDriverSlope(mode)
	Variable mode; 
	// 0 -> call from LithoRamp only -> update index and slope
	// else -> reset call -> reset index to 0 and calculate slope of first driver line

	String dfSave = GetDataFolder(1)
	SetDataFolder root:packages:SmartLitho:ArrayTrigger
	
	NVAR gDriverIndex, gDriverSlope
	
	if(mode == 0)
		gDriverIndex = gDriverIndex + 3;
	else
		gDriverIndex = 0;
	endif
	
	SetDataFolder root:packages:MFP3D:Litho
	
	Wave XLitho, YLitho
	
	if(DimSize(XLitho,0) <= gDriverIndex)
		print "Error: Out of index in XLitho Wave for driver slope calculation"
	else
		gDriverSlope =(YLitho[gDriverIndex+1] - YLitho[gDriverIndex])/(XLitho[gDriverIndex+1] - XLitho[gDriverIndex])
		if(abs(gDriverSlope) == 0)
			gDriverSlope = 0;
		elseif(abs(gDriverSlope) == inf)
			gDriverSlope = inf;
		endif

	endif
	
	//print "Driver Index = " + num2str(gDriverIndex) + ", slope = " + num2str(gDriverSlope)
		
	SetDataFolder dfSave
	
End

// This is where the code determines if the tip position corresponds to litho or normal for each cantilever
Function bgPosMonitor()
		
	String dfSave = GetDataFolder(1)
		
	SetDataFolder root:packages:SmartLitho:ArrayTrigger
	NVAR gXoffset, gYoffset, gXpos, gYpos, gRunMeter, gTolerance, gDoingLitho, gSortOrder, gDummy, gDriverSlope
	Wave gActive, gPrevIndex, gPrevIndex2, gCurrentIndex2

	gXpos = (gXoffset + td_RV("Input.X")*GV("XLVDTSens"))* 1E+6
	gYpos = (gYoffset + td_RV("Input.Y")*GV("YLVDTSens")) * 1E+6
		
	Variable i=0;
	
	if(!gDoingLitho)
		for(i=0;i<5; i=i+1) 
			gActive[i] = 0
		endfor
		SetDataFolder dfSave	
		td_WV("Output.A",0)
		td_WV("Output.B",0)
		return !gRunMeter	
	endif
	
	SetDataFolder root:packages:SmartLitho
	Wave layers, Master_XLitho, Master_YLitho
	NVAR gLayerNum
	
	if(gLayerNum < 5)
		DoAlert 0, "Error!!!\nInsufficient Litho layers.\nLayers 1-5 correspond to each tip.\nLayer 6 should encompass all other layers.\n"
		SetDataFolder dfSave	
		td_WV("Output.A",0)
		td_WV("Output.B",0)
		return gRunMeter	
	endif
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	if(gSortOrder == 1) // Unsorted Patterns
	
		Variable SubSlope;
	
		gDummy = enoise(10);
	
		for(i=0;i<5; i=i+1) 
	
			Variable hit=0;
		
			// Check if tip was doing litho during previous run:
			if(gPrevIndex[i] != -1)
				// yes: check if tip is still within this line
				hit = pointLineDist(Master_XLitho[gPrevIndex[i]],Master_YLitho[gPrevIndex[i]],Master_XLitho[gPrevIndex[i]+1],Master_YLitho[gPrevIndex[i]+1],gXpos*1e-6,gYpos*1e-6, gTolerance)
				
				SubSlope = (Master_YLitho[gPrevIndex[i]+1] - Master_YLitho[gPrevIndex[i]])/(Master_XLitho[gPrevIndex[i]+1] - Master_XLitho[gPrevIndex[i]])

				if(abs(SubSlope) == 0)
					SubSlope = 0;
				elseif(abs(SubSlope) == inf)
					SubSlope = inf;
				endif

				//print "looking within line (" + num2str(Master_XLitho[lineindex])+","+num2str(Master_YLitho[lineindex])+") - ("+num2str(Master_XLitho[lineindex+1])+","+num2str(Master_XLitho[lineindex+1])+"). Hit: " + num2str(hit)
				if(hit ==1 && SubSlope == gDriverSlope)

					gActive[i] = 1;
					////print "hit because of hit"
					continue; // equivalent of saying move to next iteration
	
				endif
				//print "no hit after hit"
				// Not a hit:
				gPrevIndex[i] = -1; // but still search all lines for a hit.
				// Might be worth looking at the immidiate next line alone once. 
			endif //else
				// If code comes here: tip may have been doing litho previously but is not on that previous line now
						
				// Start a loop to see if we get a hit for EVERY line:
				Variable j=Layers[i][1];
				gPrevIndex[i] = -1; // No more searching. Move to next cantilever
				gActive[i] = 0;	
				do	
					// 1. Check if hit:
					hit = pointLineDist(Master_XLitho[j],Master_YLitho[j],Master_XLitho[j+1],Master_YLitho[j+1],gXpos*1e-6,gYpos*1e-6, gTolerance)
					
					SubSlope = (Master_YLitho[j+1] - Master_YLitho[j])/(Master_XLitho[j+1] - Master_XLitho[j])

					if(abs(SubSlope) == 0)
						SubSlope = 0;
					elseif(abs(SubSlope) == inf)
						SubSlope = inf;
					endif
					
					//print "        Driver = " + num2str(gDriverSlope) + ", Sub = " + num2str(SubSlope)
					
					if(hit==1 && SubSlope == gDriverSlope)

						gActive[i] = 1;
						gPrevIndex[i] =j;
						//print "line " + num2str(j) +" was a hit!"
						
						break; // break this while loop only equivalent of saying move to next cantilever;
						
					endif
					//print "line " + num2str(j) +" was not a hit. Moving to next line"
					// 2. If not. move forward to next line
					if(numtype(Master_XLitho[j+2]) != 0)// End of this segment
						j = j + 3;
					else // Next line starting from same end point as prev
						j = j + 1;
					endif
								
				while(j <= Layers[i][2])	
		
		endfor
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	else // Sorted Patterns
	
		gDummy = 99; // This is one way of really telling which triggering method is being used
	
		// Assuming that the single cantilever layers are 1-5
		// Master layer (only one shown) is layer #6 or greater
		for(i=0;i<5; i=i+1) // Start with single cantilever for now. Replace with 5.
			// 1. Look up the start of the particular layer
			Variable layerstartindex = Layers[i][1];
			
			// 2. find the line using the stored indices as an offset to the start position of the layer
			Variable lineindex = gCurrentIndex2[i] + layerstartindex
			
			// 3. Find out if it was a hit by looking up the coordinates in the Master Litho waves:
			hit = pointLineDist(Master_XLitho[lineindex],Master_YLitho[lineindex],Master_XLitho[lineindex+1],Master_YLitho[lineindex+1],gXpos*1e-6,gYpos*1e-6, gTolerance)
			//print "looking within line (" + num2str(Master_XLitho[lineindex])+","+num2str(Master_YLitho[lineindex])+") - ("+num2str(Master_XLitho[lineindex+1])+","+num2str(Master_XLitho[lineindex+1])+"). Hit: " + num2str(hit)
			
			if(hit==1)
				gActive[i] = 1
				gPrevIndex2[i]=gCurrentIndex2[i]
				// no changes to gCurrentIndex
			else
				if(gPrevIndex2[i] != gCurrentIndex2[i])
					// Searching for new line (current index) but still did not find it
					// Don't look for the line after that. Just try again, next cycle.
					gActive[i] = 0
					//return !gSortedRunMeter	
				else
					// Look in next line
					if(numtype(Master_XLitho[lineindex+2]) != 0)// End of this segment
						gCurrentIndex2[i] = gCurrentIndex2[i] + 3
					else // Next line starting from same end point as prev
						gCurrentIndex2[i] = gCurrentIndex2[i] + 2
					endif
					lineindex = gCurrentIndex2[i] + layerstartindex
					hit = pointLineDist(Master_XLitho[lineindex],Master_YLitho[lineindex],Master_XLitho[lineindex+1],Master_YLitho[lineindex+1],gXpos*1e-6,gYpos*1e-6, gTolerance)
					if(hit==1)
						gActive[i] = 1
						gPrevIndex2[i]=gCurrentIndex2[i]
					else
						gActive[i] = 0
					endif
				endif
			endif
		endfor
	
	endif
	
	// Now trigger using the DACs
	// Output.A responsible for cant 1,2,3
	// Output.B responsible for cant 4,5
	Variable op = gActive[0]*1 + gActive[1]*2 + gActive[2]*4
	td_WV("Output.A", op)
	op = gActive[3]*1 + gActive[4]*2
	td_WV("Output.B",op)
	
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


Function TipPosCalibDriver(ctrlname) : ButtonControl
	String ctrlname
	
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
	Variable tolerance = NumVarOrDefault(":gtolerance",1E-7)
	Variable/G gtolerance= tolerance
	Variable bgFunRate = NumVarOrDefault(":gbgFunRate",10)
	Variable/G gbgFunRate= bgFunRate // Higher this number - faster the background function runs
	Variable sortOrder = NumVarOrDefault(":gsortOrder",1)
	Variable/G gsortOrder= sortOrder
	
	Variable/G GrunMeter = 1
	ARBackground("bgPosMonitor",gbgFunRate,"")
	calcDriverSlope(-1)

	// Create the control panel.
	Execute "TipPosCalibPanel()"
End

Window TipPosCalibPanel(): Panel
	
	PauseUpdate; Silent 1		// building window...
	NewPanel /K=1 /W=(185,145, 430,380) as "Tip Pos Calib Panel"
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
	SetVariable sv_Xoffset,fsize=14, limits={1E-8,1E-4,0}
	SetVariable sv_Xoffset, value=root:Packages:SmartLitho:ArrayTrigger:gXoffset
	
	SetVariable sv_Yoffset,pos={130,113},size={95,20},title="Y"
	SetVariable sv_Yoffset,fsize=14, limits={1E-8,1E-4,0}
	SetVariable sv_Yoffset, value=root:Packages:SmartLitho:ArrayTrigger:gYoffset
	
	SetVariable sv_tolerance,pos={14,158},size={211,20},title="Position Tolerance (m)"
	SetVariable sv_tolerance,fsize=14, limits={1E-8,1E-5,0}
	SetVariable sv_tolerance, value=root:Packages:SmartLitho:ArrayTrigger:GTolerance	

	SetDrawEnv fsize=16, textrgb= (0,0,65280),fstyle= 1
	DrawText 12,221, "Suhas Somnath, UIUC 2011"
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