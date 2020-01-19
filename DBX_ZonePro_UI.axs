MODULE_NAME='DBX_ZonePro_UI' (DEV vdvDBX_ZonePro, DEV dvTP, INTEGER nBUTTONS[],char cServerAddress[], LONG lServerPort, INTEGER serial,DEV dvDBX_IP)


(*  COMMENTS:  This Example will only work with device specific numbers. Only implemented
for 1 router 1 mixer and 1 input as determined in the .zpd file provided. needs changes to work with
API and to work for more than one router/mixer/input.*)
(*                                                         *)
(***********************************************************)
(*}}PS_SOURCE_INFO                                         *)
(***********************************************************)

DEFINE_CONSTANT

INTEGER MAX_OUTPUTS = 6
INTEGER MAX_INPUTS = 12
// TCP/IP constants
TCP = 1;
UDP = 2;

// Time for wait before reopening connection. 
RETRY_TIME = 30; // 3 seconds 
(********************************************************************)
DEFINE_VARIABLE

INTEGER bDebug=2   // stores the state of the debug feature
VOLATILE INTEGER bOnline     // stores the link state between AMX and the ZonePRO640
VOLATILE INTEGER bDeviceScale = 1  // sets wether to use the device scale or just 0-100 the touch panel included will online work if this is set to 1
VOLATILE INTEGER nNumOfZones
VOLATILE INTEGER nNumOfInputs
INTEGER nSelection  // stores the button index selected by user
VOLATILE INTEGER nZoneGain[MAX_OUTPUTS]// stores the Gain Level
VOLATILE INTEGER bZoneMute[MAX_OUTPUTS]// stores the mute state of the zone
INTEGER nScene      // stores the scene number last recalled 
VOLATILE INTEGER nIndex      // general purpose counter
VOLATILE CHAR cOutLabels[MAX_OUTPUTS][20] // storage for the Output Labels
VOLATILE CHAR cInLabels[MAX_INPUTS][20] // storage for the Input  Labels
VOLATILE INTEGER nInputLabelOffset  // used in order to properly store input Labels for all configurations
VOLATILE CHAR cSceneLabel[20]
VOLATILE CHAR cCurrentConfiguration[80]
VOLATILE INTEGER nOutput[MAX_OUTPUTS] // stores whatever input is assigned to each zone/output
VOLATILE INTEGER bStereoInputs[MAX_INPUTS] // stores the stereo state of the 12 inputs (0=mono 1=stereo)
INTEGER InputSelected // input that was selected from the touch panel
INTEGER OutputSelected // output selected from the touch panel
INTEGER MixerSelected // mixer input selected from the touch panel example: LOBBY Mic Gain
VOLATILE INTEGER MixerGain[MAX_INPUTS] // stores the mixer gain values for one mixer
VOLATILE INTEGER InputGain[MAX_INPUTS] // stores the input gains
INTEGER Box = 0  // tells what box we are connected to. 1-4
		// 1 - 1260/1261
		// 2 - 1260m/1261m
		// 3 - 640/641
		// 4 - 640m/641m
INTEGER Subscribe = 0 // are we subscribed to objects.
INTEGER Textbox = 0 // what textbox to use.
INTEGER nNumberOfTextboxes = 0 // number of objects found.
INTEGER bClientOnline; // Flag: TRUE when client is connected 
INTEGER bClientKeepOpen; // Flag: keep the client open at all times 
INTEGER discoReply = false // to check to see if we have received a disco recently.
INTEGER discoTime = 0 // number of second to test disco.
INTEGER bUpdate = 0 // Variable to update the Touch Panel at the right time.
INTEGER bTPOnline = 0 // Wether or not the touch panel is online
(********************************************************************) 
// This function will hide/show buttons on the touchpanel according to whatever configuration data
// is returned from the device. 
DEFINE_FUNCTION fnProcessConfiguration(CHAR cTmpConfigData[])
{
	stack_var char cConfigData[80]
	cConfigData = cTmpConfigData
	nNumOfInputs = ATOI(cConfigData)
	REMOVE_STRING(cConfigData,':M:',1)
	bStereoInputs[1]=ATOI(cConfigData) // store the mic line 1 stereo state
	bStereoInputs[2]=bStereoInputs[1]  // store the mic line 2 stereo state
	REMOVE_STRING(cConfigData,':L:',1)
	for(nIndex=3;nIndex<=MAX_INPUTS;nIndex++)
	{
		bStereoInputs[nIndex]=ATOI(cConfigData)
		if(bStereoInputs[nIndex]) 
		{
			bStereoInputs[nIndex+1]=1
			nIndex++
		}
	    REMOVE_STRING(cConfigData,':',1)
	}
	REMOVE_STRING(cConfigData,':S:',1)
	nNumOfZones=ATOI(cConfigData)
}

// This function will update all the label information for the inputs or outputs/zones installed.
DEFINE_FUNCTION fnProcessLabel(CHAR cLabel[])
{
	stack_var integer n
	SWITCH(REMOVE_STRING(cLabel,':',1))
	{
		CASE 'I:':
		{  // assigned input. Need to assign a label for all 12 inputs regardless of the configuration 
			n=ATOI(cLabel)
			REMOVE_STRING(cLabel,':',1)
			if(bStereoInputs[n+nInputLabelOffset]) 
			{
			   cInLabels[n+nInputLabelOffset]=cLabel
			   cInLabels[n+1+nInputLabelOffset]=cLabel
			   nInputLabelOffset++
			}
			else 
			{
				cInLabels[n+nInputLabelOffset]=cLabel
		    }
		}
		BREAK
		CASE 'O:':
		{  // output/zone label 
			n=ATOI(cLabel)
			REMOVE_STRING(cLabel,':',1)
			cOutLabels[n]=cLabel
			//SEND_COMMAND dvTP,"'@TXT',nButtons[n],cOutLabels[n]" // update the Output/Zone label
		}
		BREAK
		CASE 'S:':
		{
			cSceneLabel=cLabel
			//SEND_COMMAND dvTP,"'@TXT',nButtons[17],cSceneLabel" // update the Scene label 
		}
	}
}

// This function will update the output's/zone's and input's/zone's gain/volume level.
DEFINE_FUNCTION fnProcessLevel(CHAR cLevel[])
{
	stack_var integer n 
	IF(FIND_STRING(cLevel,':O:',1))
	{
		REMOVE_STRING(cLevel,':O:',1)
		OutputSelected=ATOI(cLevel) // store the output number
		REMOVE_STRING(cLevel,':',1)
		nZoneGain[OutputSelected]=ATOI(cLevel) // store the value
	}
	ELSE IF(FIND_STRING(cLevel,':I:',1))
	{
		REMOVE_STRING(cLevel,':I:',1)
		InputSelected=ATOI(cLevel) // store the input number
		REMOVE_STRING(cLevel,':',1)
		InputGain[InputSelected]=ATOI(cLevel) // store the value
	}
}
// This function will upate the output's/zone's mute state.
DEFINE_FUNCTION fnProcessMute(CHAR cMute[])
{
	stack_var integer n 
	IF(FIND_STRING(cMute,':O:',1))
	{
		REMOVE_STRING(cMute,':O:',1)
		OutputSelected=ATOI(cMute) // store the output number
		REMOVE_STRING(cMute,':',1)
		bZoneMute[OutputSelected]=ATOI(cMute) // store the state 
	}
}
// This function will handle the STATUS reply.
DEFINE_FUNCTION fnProcessStatus(CHAR cStatus[])
{
	IF(FIND_STRING(cStatus,'START',1) || FIND_STRING(cStatus,'RETRIEVING',1)) 
	{
		nInputLabelOffset=0
		SEND_COMMAND dvTP,"'@PPN-Wait'"
	}
	ELSE IF(FIND_STRING(cStatus,'DONE',1))
	{
	    SEND_COMMAND dvTP,"'@PPK-Wait'"
	    bUpdate = 1 // it's now ok to update the touch panel
	}
}

// This function will process a switch/route reply...
DEFINE_FUNCTION fnProcessSwitch(CHAR cSwitch[])
{
	stack_var integer in,out 
	REMOVE_STRING(cSwitch,':',1)
	in=ATOI(cSwitch) // store the input number 
	REMOVE_STRING(cSwitch,':',1)
	out=ATOI(cSwitch)// store the output number	
	nOutput[out]=in
	OutputSelected = out
}
// clears the textboxes on the touch panel
DEFINE_FUNCTION fnClearTextFields()
{
	stack_var integer n
	If(!bOnline) // only erase the values if the box goes offline.
	{
	    FOR(n=1;n<=24;n++)
	    {
		SEND_COMMAND dvTP,"'@TXT',nButtons[n],''" // clear text field
		SEND_COMMAND dvTP,"'@SHO',nButtons[n],1"  // make sure you can see buttons
	    }
	    FOR(n=59;n<=85;n++)
	    {
		SEND_COMMAND dvTP,"'@TXT',nButtons[n],''" // clear text field
		SEND_COMMAND dvTP,"'@SHO',nButtons[n],1"  // make sure you can see buttons
	    }
	}
}
// This function will update the output mixer/zone Input's gain/volume level.
DEFINE_FUNCTION fnProcessMixerLevel(CHAR cMixerLevel[])
{
	stack_var integer n 
	IF(FIND_STRING(cMixerLevel,':I:',1))
	{
		REMOVE_STRING(cMixerLevel,':I:',1)
		n=ATOI(cMixerLevel) // store the output number
		IF(n == 2) // this is coded to only use input from 1 mixer needs to be changed for multiple mixers
		{
		    REMOVE_STRING(cMixerLevel,':',1)
		    n=ATOI(cMixerLevel)
		    REMOVE_STRING(cMixerLevel,':',1)
		    MixerGain[n]=ATOI(cMixerLevel) // store the value
		}
	}
}
// This function gets what box the driver is connected to.
DEFINE_FUNCTION fnProcessBox(CHAR cBox[])
{
    Box = ATOI(cBox)
}
// This function receives wether or not you are subscribed to the objects in the box
DEFINE_FUNCTION fnProcessSubscribe(CHAR cSubscribe[])
{
	IF(FIND_STRING(cSubscribe,':',1))
	{
		REMOVE_STRING(cSubscribe,':',1)
		Subscribe=ATOI(cSubscribe) // store the output number
	}
}
//This function populates the textboxes on the touch panel
//The first string received here is the ZonePronode
//Then what box your connected to IE 1260, 1260m, 640, 640m
//Then the number of objects discovered
//Then all the objects that where discovered that you can subscribe to and control
//the objects discovered could be up to 48
//This function is also used to help with ZP power down or lose of connection
//If a DISCOFAIL is received it means the connection between the AMX controller and the
//ZP is down (for IP only) This was done to allow the user to have control of the socket.
DEFINE_FUNCTION fnProcessString(CHAR cString[])
{
    
    stack_var integer n
    // IP Connection lost close the port.
    IF(FIND_STRING(cString,'DISCOFAIL',1) && !serial)
    {
	IP_CLIENT_CLOSE(dvDBX_IP.port)
    }
    ELSE // Send a string to the Touch Panel
    {
	Textbox++
	IF(Textbox <= 24)
	{
	    SEND_COMMAND dvTP,"'@TXT',nButtons[Textbox],cString"
	    IF(Textbox == 24)
		Textbox = 58
	}
	ELSE IF(Textbox <= 85)
	{
	    SEND_COMMAND dvTP,"'@TXT',nButtons[Textbox],cString"
	}
	IF(FIND_STRING(cString,'FINISHED',1))
	{
	    IF(Textbox < 85)
	    {
		FOR(n=Textbox;n<=85;n++)
		    SEND_COMMAND dvTP,"'@SHO',nButtons[n],0"
	    }
	}
    }
}
//converts a value that is from 0-100 to a value from 0-221 This is for LEVEL's
DEFINE_FUNCTION INTEGER fnConvert221(SINTEGER ReceivedLevel)
{
    // this code was added to solve a rounding error that made the level not work correctly
    // needed for the level event to work properly.
    local_var INTEGER change
    IF(TYPE_CAST(fnConvert(ReceivedLevel,0,100,0,221)) != 0)
	change = TYPE_CAST(fnConvert(ReceivedLevel,0,100,0,221))+1
    else
	change = TYPE_CAST(fnConvert(ReceivedLevel,0,100,0,221))
    IF (ReceivedLevel == 100)
	change = 221
    return change
}
//converts a value that is from 0-100 to a value from 0-415 This is for MIXERLEVEL's
DEFINE_FUNCTION INTEGER fnConvert415(SINTEGER ReceivedLevel)
{
    // this code was added to solve a rounding error that made the level not work correctly
    // needed for the level event to work properly.
    local_var INTEGER change
    IF(TYPE_CAST(fnConvert(ReceivedLevel,0,100,0,415)) != 0)
	change = TYPE_CAST(fnConvert(ReceivedLevel,0,100,0,415))+1
    else
	change = TYPE_CAST(fnConvert(ReceivedLevel,0,100,0,415))
    IF (ReceivedLevel == 100)
	change = 415
    return change
}
// THIS FUNCTION CONVERTS A NUMBER IN AN OLD RANGE TO A NUMBER IN A NEW RANGE. IT TAKES
// AS PARAMETERS THE NUMBER WE WANT TO CONVERT, THE OLD RANGE OF THIS NUMBER, AND 
// THE NEW RANGE WE WANT THE NEW NUMBER (CONVERTED) TO BE IN. THE FUNCTION RETURNS THE NEW NUMBER or
// IF INCORRECT VALUES ARE ENTERED THE FUNCTION RETURNS THE NEW MAX OR NEW MIN DEPENDING ON THE VALUE PASSED
DEFINE_FUNCTION sinteger fnCONVERT(sinteger oldNUM, sinteger oldMIN, sinteger oldMAX, sinteger newMIN, sinteger newMAX)
{
    sinteger  oldSTEPS
    sinteger  newSTEPS
    sinteger  position1
    sinteger  position2
    if(oldMIN<oldMAX && newMIN<newMAX && oldNUM>=oldMIN && oldNUM<=oldMAX) //  if everything is the way it should...
        {
            oldSTEPS=oldMAX-oldMIN // remember the number of steps in the old range
            newSTEPS=newMAX-newMIN // remember the number of steps in the new range
            position1=oldNUM-oldMIN  // get the position of the number in the old range
            position2=(position1*newSTEPS/oldSTEPS) // get the position of the number in the new range
            return (newMIN+position2)
       }
    else if(oldNUM<oldMIN)
       return newMIN
    else if(oldNUM>oldMAX)
       return newMAX
}

DEFINE_START
    IF(!serial) // connect to the port on start up
    {
	IP_CLIENT_OPEN (dvDBX_IP.port,cServerAddress,lServerPort,TCP);
    }

DEFINE_EVENT

DATA_EVENT [dvDBX_IP]
{

    // Online handler runs when a successful connection is made.
    ONLINE:
    {
	IF(!serial)
	{
	    // We have communication. Can send strings to IP device now.
	    bClientOnline = TRUE;
	    bClientKeepOpen = TRUE; // This is so if the connection fails it will try to reconnect
	}
    }

    // Offline handler runs when connection is dropped/closed.
    OFFLINE:
    {
	If(!serial)
	{
	    // NOTE: Certain protocols (such as HTTP) drop the connection
	    // after sending a response to a request. For those protocols,
	    // this is a better place to parse the buffer than in the STRING
	    // handler. There will be a complete reply in the buffer.
	    bClientOnline = FALSE;
	    // Attempt to reestablish communications, if desired.
	    IF (bClientKeepOpen)
	    {
		WAIT RETRY_TIME
		IP_CLIENT_OPEN (dvDBX_IP.port,cServerAddress,lServerPort,TCP);
	    }
	}
    }

    // Onerror runs when attempt to connect fails.
    ONERROR:
    {
	IF(!serial)
	{
	    SWITCH (DATA.NUMBER)
	    {
		// No need to reopen socket in response to following two errors. 
		CASE 9: // Socket closed in response to IP_CLIENT_CLOSE. 
		CASE 17: // String was sent to a closed socket. 
		{
		}
		DEFAULT: // All other errors. May want to retry connection. 
		{
		    IF (bClientKeepOpen)
		    {
			WAIT RETRY_TIME
			IP_CLIENT_OPEN (dvDBX_IP.port,cServerAddress,lServerPort,TCP);
		    }
		}
	    }
	}
    }
}

DATA_EVENT[dvTP]
{
	ONLINE:
	{
	    bTPOnline = 1
	    fnProcessConfiguration(cCurrentConfiguration)
	    IF(!bOnline)
	    {
		fnClearTextFields()
	    }
	    ELSE
	    {
		// This code is to update the Output mixer level for Zone 2
		SEND_COMMAND vdvDBX_ZonePro,"'MIXERLEVEL=1:I:2:1:',ITOA(MixerGain[1])"
		SEND_COMMAND vdvDBX_ZonePro,"'MIXERLEVEL=1:I:2:2:',ITOA(MixerGain[2])"
		SEND_COMMAND vdvDBX_ZonePro,"'MIXERLEVEL=1:I:2:3:',ITOA(MixerGain[3])"
		SEND_COMMAND vdvDBX_ZonePro,"'MIXERLEVEL=1:I:2:4:',ITOA(MixerGain[4])"
		SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:O:2:',ITOA(nZoneGain[2])"
		// this is code to update Output router levels for Zone 1 and 3
		SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:O:1:',ITOA(nZoneGain[1])"
		SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:O:3:',ITOA(nZoneGain[3])"
		// This is code to update Input levels 1-8
		SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:I:1:',ITOA(InputGain[1])"
		SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:I:2:',ITOA(InputGain[2])"
		SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:I:3:',ITOA(InputGain[3])"
		SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:I:4:',ITOA(InputGain[4])"
		SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:I:5:',ITOA(InputGain[5])"
		SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:I:6:',ITOA(InputGain[6])"
		SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:I:7:',ITOA(InputGain[7])"
		SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:I:8:',ITOA(InputGain[8])"
	    }
	}
	OFFLINE:
	{
	    bTPOnline = 0
	}
}
DATA_EVENT[vdvDBX_ZonePro]   // virtual device events
{

	STRING:
		{
		  SEND_STRING 0,"'UI RECEIVED FROM COMM:',DATA.TEXT" 
          SWITCH(REMOVE_STRING(DATA.TEXT,'=',1))
          {
              CASE 'CONFIGURATION=': 
					{
						cCurrentConfiguration=DATA.TEXT
						fnProcessConfiguration(DATA.TEXT)
					}
                  BREAK
              CASE 'DEBUG=': bDebug = ATOI(DATA.TEXT)
                  BREAK
              CASE 'DEVICE_SCALE=': bDeviceScale=ATOI(DATA.TEXT)
                  BREAK
              CASE 'LABEL=': fnProcessLabel(DATA.TEXT)
                  BREAK
              CASE 'LEVEL=': fnProcessLevel(DATA.TEXT)
                  BREAK
              CASE 'MUTE=': fnProcessMute(DATA.TEXT)
                  BREAK
              CASE 'STATUS=': fnProcessStatus(DATA.TEXT)
                  BREAK
              CASE 'SWITCH=': fnProcessSwitch(DATA.TEXT)
                  BREAK
              CASE 'ONLINE=': 
		{
		    if(!ATOI(DATA.TEXT))
		    {
			Textbox = 0
			fnClearTextFields()
			bUpdate = 0
		    }
		    bOnline=ATOI(DATA.TEXT)
		}
                  BREAK
              CASE 'RECALL=': 
		{
		    REMOVE_STRING(DATA.TEXT,':',1)
		    nScene=ATOI(DATA.TEXT)
		}
                  BREAK
	      CASE 'MIXERLEVEL=': fnProcessMixerLevel(DATA.TEXT)
		  BREAK
	      CASE 'BOX=': fnProcessBox(DATA.TEXT)
		BREAK
	      CASE 'SUBSCRIBE=': fnProcessSubscribe(DATA.TEXT)
		BREAK
	      CASE 'STRING=': fnProcessString(DATA.TEXT)
		BREAK
	      CASE 'DBXNODE=': SEND_STRING 0,"'DBX NODE set to ',DATA.TEXT"
		BREAK
	      CASE 'AMXNODE=': SEND_STRING 0,"'AMX NODE set to ',DATA.TEXT"
		BREAK
          }
		}
}
BUTTON_EVENT [dvTP,26]
BUTTON_EVENT [dvTP,27]
BUTTON_EVENT [dvTP,29]
BUTTON_EVENT [dvTP,30]
BUTTON_EVENT [dvTP,32]
BUTTON_EVENT [dvTP,33]
BUTTON_EVENT [dvTP,35]
BUTTON_EVENT [dvTP,36]
BUTTON_EVENT [dvTP,38]
BUTTON_EVENT [dvTP,39]
BUTTON_EVENT [dvTP,40]
{
    // These are the buttons for Output Mixer Zone 2
    Push:
    {
	nSelection=BUTTON.INPUT.CHANNEL
	OutputSelected = 2 // Zone 2

	IF(bUpdate) // what until it has received all the objects to allow button functionality
	{
	    // Mixer controls
	    // for input mixer 1    
	    if(nSelection==26)
	    {
		// Lobby Mic Gain Ramp up
		SEND_COMMAND vdvDBX_ZonePro,"'MIXERLEVEL=1:I:',ITOA(OutputSelected),':1:+'"
		MixerSelected = 1;
	    }
	    else if(nSelection==27)
	    {
		// Lobby Mic Gain Ramp down
		SEND_COMMAND vdvDBX_ZonePro,"'MIXERLEVEL=1:I:',ITOA(OutputSelected),':1:-'"
		MixerSelected = 1;
	    }
	    // for input mixer 2
	    else if(nSelection==29)
	    {
		// Phone Page Gain Ramp up
		SEND_COMMAND vdvDBX_ZonePro,"'MIXERLEVEL=1:I:',ITOA(OutputSelected),':2:+'"
		MixerSelected = 2;
	    }
	    else if(nSelection==30)
	    {
		// Phone Page Ramp Down
		SEND_COMMAND vdvDBX_ZonePro,"'MIXERLEVEL=1:I:',ITOA(OutputSelected),':2:-'"
		MixerSelected = 2;
	    }
	    // for input mixer 3
	    else if(nSelection==32)
	    {
		// CDL Ramp up
		SEND_COMMAND vdvDBX_ZonePro,"'MIXERLEVEL=1:I:',ITOA(OutputSelected),':3:+'"
		MixerSelected = 3;
	    }
	    else if(nSelection==33)
	    {
		// CDL Ramp Down
		SEND_COMMAND vdvDBX_ZonePro,"'MIXERLEVEL=1:I:',ITOA(OutputSelected),':3:-'"
		MixerSelected = 3;
	    }
	    // for input mixer 4
	    else if(nSelection==35)
	    {
		// CDR Ramp up
		SEND_COMMAND vdvDBX_ZonePro,"'MIXERLEVEL=1:I:',ITOA(OutputSelected),':4:+'"
		MixerSelected = 4;
	    }
	    else if(nSelection==36)
	    {
		// CDR Ramp down
		SEND_COMMAND vdvDBX_ZonePro,"'MIXERLEVEL=1:I:',ITOA(OutputSelected),':4:-'"
		MixerSelected = 4;
	    }
	    // mixer
	    else if(nSelection==38)
	    {
		// mixer master gain ramp up
		SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:O:',ITOA(OutputSelected),':+'"
	    }
	    else if(nSelection==39)
	    {
		// mixer master gain ramp down
		SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:O:',ITOA(OutputSelected),':-'"
	    }
	    else if(nSelection==40)
	    {
		// mixer mute
		SEND_COMMAND vdvDBX_ZonePro,"'MUTE=1:O:',ITOA(OutputSelected),':T'"
	    }
	}
    }
    HOLD[.3,REPEAT]:
    {
	IF(bUpdate) // what until it has received all the objects to allow button functionality
	{
	    if(nSelection==26)
		SEND_COMMAND vdvDBX_ZonePro,"'MIXERLEVEL=1:I:',ITOA(OutputSelected),':1:+'"
	    else if(nSelection==27)
		SEND_COMMAND vdvDBX_ZonePro,"'MIXERLEVEL=1:I:',ITOA(OutputSelected),':1:-'"
	    else if(nSelection==29)
		SEND_COMMAND vdvDBX_ZonePro,"'MIXERLEVEL=1:I:',ITOA(OutputSelected),':2:+'"
	    else if(nSelection==30)
		SEND_COMMAND vdvDBX_ZonePro,"'MIXERLEVEL=1:I:',ITOA(OutputSelected),':2:-'"
	    else if(nSelection==32)
		SEND_COMMAND vdvDBX_ZonePro,"'MIXERLEVEL=1:I:',ITOA(OutputSelected),':3:+'"
	    else if(nSelection==33)
		SEND_COMMAND vdvDBX_ZonePro,"'MIXERLEVEL=1:I:',ITOA(OutputSelected),':3:-'"
	    else if(nSelection==35)
		SEND_COMMAND vdvDBX_ZonePro,"'MIXERLEVEL=1:I:',ITOA(OutputSelected),':4:+'"
	    else if(nSelection==36)
		SEND_COMMAND vdvDBX_ZonePro,"'MIXERLEVEL=1:I:',ITOA(OutputSelected),':4:-'"
	    else if(nSelection==38)
		SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:O:',ITOA(OutputSelected),':+'"
	    else if(nSelection==39)
		SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:O:',ITOA(OutputSelected),':-'"
	}
    }
}

BUTTON_EVENT [dvTP,41]
BUTTON_EVENT [dvTP,42]
BUTTON_EVENT [dvTP,43]
BUTTON_EVENT [dvTP,44]
BUTTON_EVENT [dvTP,46]
BUTTON_EVENT [dvTP,47]
BUTTON_EVENT [dvTP,48]
BUTTON_EVENT [dvTP,52]
BUTTON_EVENT [dvTP,53]
BUTTON_EVENT [dvTP,54]
BUTTON_EVENT [dvTP,55]
BUTTON_EVENT [dvTP,56]
BUTTON_EVENT [dvTP,57]
BUTTON_EVENT [dvTP,58]
BUTTON_EVENT [dvTP,107]
BUTTON_EVENT [dvTP,108]
BUTTON_EVENT [dvTP,109]
BUTTON_EVENT [dvTP,110]
BUTTON_EVENT [dvTP,111]
BUTTON_EVENT [dvTP,112]
BUTTON_EVENT [dvTP,113]
BUTTON_EVENT [dvTP,114]
BUTTON_EVENT [dvTP,115]
BUTTON_EVENT [dvTP,116]
BUTTON_EVENT [dvTP,117]
BUTTON_EVENT [dvTP,119]
BUTTON_EVENT [dvTP,120]
BUTTON_EVENT [dvTP,121]
{
    // These are the controls to Output Routers Zone 1 and 3
    Push:
    {
	IF(bUpdate) // what until it has received all the objects to allow button functionality
	{
	    nSelection=BUTTON.INPUT.CHANNEL
	    // determine what object was the button pressed for.
	    if((nSelection > 40 && nSelection < 49) || (nSelection > 51 && nSelection < 59))
		OutputSelected = 1
	    else if((nSelection > 106 && nSelection < 122))
		OutputSelected = 3
	    // Router controls
	    // switch to source 1
	    if(nSelection==41 || nSelection==107)
		SEND_COMMAND vdvDBX_ZonePro,"'SWITCH=1:1:',ITOA(OutputSelected)"
	    // switch to source 2
	    else if(nSelection==42 || nSelection==108)
		SEND_COMMAND vdvDBX_ZonePro,"'SWITCH=1:2:',ITOA(OutputSelected)"
	    // switch to source 3
	    else if(nSelection==43 || nSelection==109)
		SEND_COMMAND vdvDBX_ZonePro,"'SWITCH=1:3:',ITOA(OutputSelected)"
	    // switch to source 4
	    else if(nSelection==44 || nSelection==110)
		SEND_COMMAND vdvDBX_ZonePro,"'SWITCH=1:4:',ITOA(OutputSelected)"
	    // switch to source 5
	    else if(nSelection==52 || nSelection==111)
		SEND_COMMAND vdvDBX_ZonePro,"'SWITCH=1:5:',ITOA(OutputSelected)"
	    // switch to source 6
	    else if(nSelection==53 || nSelection==112)
		SEND_COMMAND vdvDBX_ZonePro,"'SWITCH=1:6:',ITOA(OutputSelected)"
	    // switch to source 7
	    else if(nSelection==54 || nSelection==113)
		SEND_COMMAND vdvDBX_ZonePro,"'SWITCH=1:7:',ITOA(OutputSelected)"
	    // switch to source 8
	    else if(nSelection==55 || nSelection==114)
		SEND_COMMAND vdvDBX_ZonePro,"'SWITCH=1:8:',ITOA(OutputSelected)"
	    // switch to source 9
	    else if(nSelection==56 || nSelection==115)
		SEND_COMMAND vdvDBX_ZonePro,"'SWITCH=1:9:',ITOA(OutputSelected)"
	    // switch to source 10
	    else if(nSelection==57 || nSelection==116)
		SEND_COMMAND vdvDBX_ZonePro,"'SWITCH=1:10:',ITOA(OutputSelected)"
	    // switch to source 11
	    else if(nSelection==58 || nSelection==117)
		SEND_COMMAND vdvDBX_ZonePro,"'SWITCH=1:11:',ITOA(OutputSelected)"
	    // Router Master Gain ramp up
	    else if(nSelection==46 || nSelection==119)
		SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:O:',ITOA(OutputSelected),':+'"
	    // Router Master gain ramp down
	    else if(nSelection==47 || nSelection==120)
		SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:O:',ITOA(OutputSelected),':-'"
	    // Router Master mute
	    else if(nSelection==48 || nSelection==121)
		SEND_COMMAND vdvDBX_ZonePro,"'MUTE=1:O:',ITOA(OutputSelected),':T'"
	}
    }
    HOLD[.3,REPEAT]:
    {
	IF(bUpdate) // what until it has received all the objects to allow button functionality
	{
	    if(nSelection==46 || nSelection==119)
		SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:O:',ITOA(OutputSelected),':+'"
	    else if(nSelection==47 || nSelection==120)
		SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:O:',ITOA(OutputSelected),':-'"
	}
    }
}
BUTTON_EVENT [dvTP,50]
BUTTON_EVENT [dvTP,51]
BUTTON_EVENT [dvTP,87]
BUTTON_EVENT [dvTP,88]
BUTTON_EVENT [dvTP,90]
BUTTON_EVENT [dvTP,91]
BUTTON_EVENT [dvTP,93]
BUTTON_EVENT [dvTP,94]
BUTTON_EVENT [dvTP,96]
BUTTON_EVENT [dvTP,97]
BUTTON_EVENT [dvTP,99]
BUTTON_EVENT [dvTP,100]
BUTTON_EVENT [dvTP,102]
BUTTON_EVENT [dvTP,103]
BUTTON_EVENT [dvTP,105]
BUTTON_EVENT [dvTP,106]
{
    // these are the controls to Inputs 1-8
    Push:
    {
	IF(bUpdate) // what until it has received all the objects to allow button functionality
	{
	    nSelection=BUTTON.INPUT.CHANNEL
	    if (nSelection = 50 || nSelection = 51)
		InputSelected = 1
	    else if (nSelection = 87 || nSelection = 88)
		InputSelected = 2
	    else if (nSelection = 90 || nSelection = 91)
		InputSelected = 3
	    else if (nSelection = 93 || nSelection = 94)
		InputSelected = 4
	    else if (nSelection = 96 || nSelection = 97)
		InputSelected = 5
	    else if (nSelection = 99 || nSelection = 100)
		InputSelected = 6
	    else if (nSelection = 102 || nSelection = 103)
		InputSelected = 7
	    else if (nSelection = 105 || nSelection = 106)
		InputSelected = 8
	    // Input controls
	    // Input Gain ramp up
	    if(nSelection==50 || nSelection==87 || nSelection==90 || nSelection==93 || nSelection==96 || nSelection==99 || nSelection==102 || nSelection==105)
		SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:I:',ITOA(InputSelected),':+'"
	    // Input Gain ramp down
	    else if(nSelection==51 || nSelection==88 || nSelection==91 || nSelection==94 || nSelection==97 || nSelection==100 || nSelection==103 || nSelection==106)
		SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:I:',ITOA(InputSelected),':-'"
	}
    }
    HOLD[.3,REPEAT]:
    {
	IF(bUpdate) // what until it has received all the objects to allow button functionality
	{
	    if(nSelection==50 || nSelection==87 || nSelection==90 || nSelection==93 || nSelection==96 || nSelection==99 || nSelection==102 || nSelection==105)
		SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:I:',ITOA(InputSelected),':+'"
	    else if(nSelection==51 || nSelection==88 || nSelection==91 || nSelection==94 || nSelection==97 || nSelection==100 || nSelection==103 || nSelection==106)
		SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:I:',ITOA(InputSelected),':-'"
	}
    }
}
BUTTON_EVENT [dvTP,122]
BUTTON_EVENT [dvTP,123]
BUTTON_EVENT [dvTP,124]
BUTTON_EVENT [dvTP,125]
{
    PUSH:
    {
	IF(bUpdate) // what until it has received all the objects to allow button functionality
	{
	    // These buttons are for the Scene changes
	    nSelection=BUTTON.INPUT.CHANNEL
	    IF(nSelection==122)	// recall scene 1
		SEND_COMMAND vdvDBX_ZonePro,"'RECALL=1:1'"
	    ELSE IF(nSelection==123) // recall scene 2
		SEND_COMMAND vdvDBX_ZonePro,"'RECALL=1:2'"
	    ELSE IF(nSelection==124) // recall scene 3
		SEND_COMMAND vdvDBX_ZonePro,"'RECALL=1:3'"
	    ELSE IF(nSelection==125) // recall scene 4
		SEND_COMMAND vdvDBX_ZonePro,"'RECALL=1:4'"
	}
    }
}
BUTTON_EVENT [dvTP,128]
{
    // This button is for the subscribe button
    PUSH:
    {
	IF(bUpdate) // what until it has received all the objects to allow button functionality
	{
	    IF(subscribe)
		SEND_COMMAND vdvDBX_ZonePro,"'SUBSCRIBE=1:0'"
	    ELSE
		SEND_COMMAND vdvDBX_ZonePro,"'SUBSCRIBE=1:1'"
	}
    }
}
LEVEL_EVENT[dvTP,25]
LEVEL_EVENT[dvTP,28]
LEVEL_EVENT[dvTP,31]
LEVEL_EVENT[dvTP,34]
LEVEL_EVENT[dvTP,37]
{
    // These are the level controls for Output Mixer Zone 2
    local_var INTEGER change
    IF(bTPOnline && bUpdate)
    {
	// This is the level for mixer lobby mic gain
	if(LEVEL.INPUT.LEVEL==25)
	{
	    OutputSelected = 2 // Zone 2
	    MixerSelected = 1; // Lobby Mic Input into the mixer
	    change = fnConvert415(LEVEL.VALUE)
	    SEND_COMMAND vdvDBX_ZonePro,"'MIXERLEVEL=1:I:',ITOA(OutputSelected),':1:',ITOA(change)"
	}
	// this is the level for mixer phone page gain
	else if(LEVEL.INPUT.LEVEL==28)
	{
	    OutputSelected = 2 // Zone 2
	    MixerSelected = 2; // Phone Page Input into the mixer
	    change = fnConvert415(LEVEL.VALUE)
	    SEND_COMMAND vdvDBX_ZonePro,"'MIXERLEVEL=1:I:',ITOA(OutputSelected),':2:',ITOA(change)"
	}
	// this is the level for mixer CD L gain
	else if(LEVEL.INPUT.LEVEL==31)
	{
	    OutputSelected = 2 // Zone 2
	    MixerSelected = 3; // CD L Input into the mixer
	    change = fnConvert415(LEVEL.VALUE)
	    SEND_COMMAND vdvDBX_ZonePro,"'MIXERLEVEL=1:I:',ITOA(OutputSelected),':3:',ITOA(change)"
	}
	// this is the level for mixer CD R gain
	else if(LEVEL.INPUT.LEVEL==34)
	{
	    OutputSelected = 2 // Zone 2
	    MixerSelected = 4; // CD R Input into the mixer
	    change = fnConvert415(LEVEL.VALUE)
	    SEND_COMMAND vdvDBX_ZonePro,"'MIXERLEVEL=1:I:',ITOA(OutputSelected),':4:',ITOA(change)"	    
	}
	// this is the level for mixer master gain
	else if(LEVEL.INPUT.LEVEL==37)
	{
	    OutputSelected = 2 // Zone 2
	    change = fnConvert221(LEVEL.VALUE)
	    SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:O:',ITOA(OutputSelected),':',ITOA(change)"
	}
    }
}
LEVEL_EVENT[dvTP,45]
LEVEL_EVENT[dvTP,118]
{
    // These are the Level events for Output Routers Zones 1 and 3
    local_var INTEGER change
    IF(bTPOnline && bUpdate)
    {
	// this is the level for router master gain
	if(LEVEL.INPUT.LEVEL==45)
	    OutputSelected = 1
	else if (LEVEL.INPUT.LEVEL==118)
	    OutputSelected = 3
	change = fnConvert221(LEVEL.VALUE)
	SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:O:',ITOA(OutputSelected),':',ITOA(change)"
    }
}
LEVEL_EVENT[dvTP,49]
LEVEL_EVENT[dvTP,86]
LEVEL_EVENT[dvTP,89]
LEVEL_EVENT[dvTP,92]
LEVEL_EVENT[dvTP,95]
LEVEL_EVENT[dvTP,98]
LEVEL_EVENT[dvTP,101]
LEVEL_EVENT[dvTP,104]
{
    local_var INTEGER change
    IF(bTPOnline && bUpdate)
    {
	// these are the level events for Inputs 1-8
	if(LEVEL.INPUT.LEVEL==49)
	{
	    InputSelected = 1
	    change = fnConvert221(LEVEL.VALUE)
	    SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:I:',ITOA(InputSelected),':',ITOA(change)"
	}
	else if(LEVEL.INPUT.LEVEL==86)
	{
	    InputSelected = 2
	    change = fnConvert221(LEVEL.VALUE)
	    SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:I:',ITOA(InputSelected),':',ITOA(change)"
	}
	else if(LEVEL.INPUT.LEVEL==89)
	{
	    InputSelected = 3
	    change = fnConvert221(LEVEL.VALUE)
	    SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:I:',ITOA(InputSelected),':',ITOA(change)"
	}
	else if(LEVEL.INPUT.LEVEL==92)
	{
	    InputSelected = 4
	    change = fnConvert221(LEVEL.VALUE)
	    SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:I:',ITOA(InputSelected),':',ITOA(change)"
	}
	else if(LEVEL.INPUT.LEVEL==95)
	{
	    InputSelected = 5
	    change = fnConvert221(LEVEL.VALUE)
	    SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:I:',ITOA(InputSelected),':',ITOA(change)"
	}
	else if(LEVEL.INPUT.LEVEL==98)
	{
	    InputSelected = 6
	    change = fnConvert221(LEVEL.VALUE)
	    SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:I:',ITOA(InputSelected),':',ITOA(change)"
	}
	else if(LEVEL.INPUT.LEVEL==101)
	{
	    InputSelected = 7
	    change = fnConvert221(LEVEL.VALUE)
	    SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:I:',ITOA(InputSelected),':',ITOA(change)"
	}
	else if(LEVEL.INPUT.LEVEL==104)
	{
	    InputSelected = 8
	    change = fnConvert221(LEVEL.VALUE)
	    SEND_COMMAND vdvDBX_ZonePro,"'LEVEL=1:I:',ITOA(InputSelected),':',ITOA(change)"
	}
    }
}

BUTTON_EVENT[dvTP,200]
{
    PUSH:
    {
	send_command vdvDBX_ZonePro,"'MIXERLEVEL=1:I:2:1:0'" //Send input 1 to output 1 to 0 level
	send_command vdvDBX_ZonePro,"'MIXERLEVEL=1:I:2:2:100'" //Send input 5 to output 1 to 0 level
	send_command vdvDBX_ZonePro,"'MIXERLEVEL=1:I:2:3:0'" //Send input 8 to output 1 to 0 level
	send_command vdvDBX_ZonePro,"'MIXERLEVEL=1:I:2:4:100'" //Send input 1 to output 2 to 0 level
	send_command vdvDBX_ZonePro,"'MIXERLEVEL=1:I:2:5:0'" //Send input 5 to output 2 to 0 level
	send_command vdvDBX_ZonePro,"'MIXERLEVEL=1:I:2:6:100'" //Send input 8 to output 2 to 0 level
	send_command vdvDBX_ZonePro,"'MUTE=1:O:1:0'" //Send input 8 to output 1 to 0 level
	send_command vdvDBX_ZonePro,"'MUTE=1:O:1:1'" //Send input 1 to output 2 to 0 level
	send_command vdvDBX_ZonePro,"'MUTE=1:O:1:T'" //Send input 5 to output 2 to 0 level
	send_command vdvDBX_ZonePro,"'MUTE=1:O:1:T'" //Send input 8 to output 2 to 0 level

    }
}
DEFINE_PROGRAM
// Code for the Example_Panel use this panel for your example
//code to update Textboxes
    IF(serial)
    {
	SEND_COMMAND dvTP,"'@TXT',nButtons[126],'serial'"
	SEND_COMMAND dvTP,"'@TXT',nButtons[127],'N/A'"
    }
    ELSE
    {
	SEND_COMMAND dvTP,"'@TXT',nButtons[126],'TCP/IP'"
	IF(bClientOnline)
	    SEND_COMMAND dvTP,"'@TXT',nButtons[127],'Connected'"
	ELSE
	    SEND_COMMAND dvTP,"'@TXT',nButtons[127],'DisConnected'"
    }
    // This code is to update the Output mixer level for Zone 2
    if( bDeviceScale && bOnline) SEND_LEVEL dvTP,25,TYPE_CAST(fnConvert(type_cast(MixerGain[1]),0,415,0,100))//Update Output Mixer Zone 2 Lobby Mic level
    if( bDeviceScale && bOnline) SEND_LEVEL dvTP,28,TYPE_CAST(fnConvert(type_cast(MixerGain[2]),0,415,0,100))//Update Output Mixer Zone 2 Phone Page level
    if( bDeviceScale && bOnline) SEND_LEVEL dvTP,31,TYPE_CAST(fnConvert(type_cast(MixerGain[3]),0,415,0,100))//Update Output Mixer Zone 2 CD L level
    if( bDeviceScale && bOnline) SEND_LEVEL dvTP,34,TYPE_CAST(fnConvert(type_cast(MixerGain[4]),0,415,0,100))//Update Output Mixer Zone 2 CD R level
    if( bDeviceScale && bOnline) SEND_LEVEL dvTP,37,TYPE_CAST(fnConvert(type_cast(nZoneGain[2]),0,221,0,100))//Update Output Mixer Zone 2 Master level
    [dvTP,nButtons[40]]=(bZoneMute[2]) // Update Output Mixer Zone 2 Mute
    
    // this is code to update Output router levels for Zone 1 and 3
    if( bDeviceScale && bOnline) SEND_LEVEL dvTP,45,TYPE_CAST(fnConvert(type_cast(nZoneGain[1]),0,221,0,100))//Update Output Router Zone 1 Master level
    if( bDeviceScale && bOnline) SEND_LEVEL dvTP,118,TYPE_CAST(fnConvert(type_cast(nZoneGain[3]),0,221,0,100))//Update Output Router Zone 3 Master level
    if (nOutput[1] == 1) // Update Output Router Zone 1 Source (Lobby Mic)
	[dvTP,nButtons[41]]=1
    else
	[dvTP,nButtons[41]]=0
    if (nOutput[3] == 1) // Update Output Router Zone 3 Source (Lobby Mic)
	[dvTP,nButtons[107]]=1
    else
	[dvTP,nButtons[107]]=0
    if (nOutput[1] == 2) // Update Output Router Zone 1 Source (Phone Page)
	[dvTP,nButtons[42]]=1
    else
	[dvTP,nButtons[42]]=0
    if (nOutput[3] == 2) // Update Output Router Zone 3 Source (Lobby Mic)
	[dvTP,nButtons[108]]=1
    else
	[dvTP,nButtons[108]]=0
    if (nOutput[1] == 3) // Update Output Router Zone 1 Source (CD L)
	[dvTP,nButtons[43]]=1
    else
	[dvTP,nButtons[43]]=0
    if (nOutput[3] == 3) // Update Output Router Zone 3 Source (Lobby Mic)
	[dvTP,nButtons[109]]=1
    else
	[dvTP,nButtons[109]]=0
    if (nOutput[1] == 4) // Update Output Router Zone 1 Source (CD R)
	[dvTP,nButtons[44]]=1
    else
	[dvTP,nButtons[44]]=0
    if (nOutput[3] == 4) // Update Output Router Zone 3 Source (Lobby Mic)
	[dvTP,nButtons[110]]=1
    else
	[dvTP,nButtons[110]]=0
    if (nOutput[1] == 5) // Update Output Router Zone 1 Source (Satellite L)
	[dvTP,nButtons[52]]=1
    else
	[dvTP,nButtons[52]]=0
    if (nOutput[3] == 5) // Update Output Router Zone 3 Source (Lobby Mic)
	[dvTP,nButtons[111]]=1
    else
	[dvTP,nButtons[111]]=0
    if (nOutput[1] == 6) // Update Output Router Zone 1 Source (Satellite R)
	[dvTP,nButtons[53]]=1
    else
	[dvTP,nButtons[53]]=0
    if (nOutput[3] == 6) // Update Output Router Zone 3 Source (Lobby Mic)
	[dvTP,nButtons[112]]=1
    else
	[dvTP,nButtons[112]]=0
    if (nOutput[1] == 7) // Update Output Router Zone 1 Source (Jukebox L)
	[dvTP,nButtons[54]]=1
    else
	[dvTP,nButtons[54]]=0
    if (nOutput[3] == 7) // Update Output Router Zone 3 Source (Lobby Mic)
	[dvTP,nButtons[113]]=1
    else
	[dvTP,nButtons[113]]=0
    if (nOutput[1] == 8) // Update Output Router Zone 1 Source (Jukebox R)
	[dvTP,nButtons[55]]=1
    else
	[dvTP,nButtons[55]]=0
    if (nOutput[3] == 8) // Update Output Router Zone 3 Source (Lobby Mic)
	[dvTP,nButtons[114]]=1
    else
	[dvTP,nButtons[114]]=0
    if (nOutput[1] == 9) // Update Output Router Zone 1 Source (TV L)
	[dvTP,nButtons[56]]=1
    else
	[dvTP,nButtons[56]]=0
    if (nOutput[3] == 9) // Update Output Router Zone 3 Source (Lobby Mic)
	[dvTP,nButtons[115]]=1
    else
	[dvTP,nButtons[115]]=0
    if (nOutput[1] == 10) // Update Output Router Zone 1 Source (TV R)
	[dvTP,nButtons[57]]=1
    else
	[dvTP,nButtons[57]]=0
    if (nOutput[3] == 10) // Update Output Router Zone 3 Source (Lobby Mic)
	[dvTP,nButtons[116]]=1
    else
	[dvTP,nButtons[116]]=0
    if (nOutput[1] == 11) // Update Output Router Zone 1 Source (DVD L)
	[dvTP,nButtons[58]]=1
    else
	[dvTP,nButtons[58]]=0
    if (nOutput[3] == 11) // Update Output Router Zone 3 Source (Lobby Mic)
	[dvTP,nButtons[117]]=1
    else
	[dvTP,nButtons[117]]=0
    [dvTP,nButtons[48]]=(bZoneMute[1]) // Update Output Router Zone 1 Mute
    [dvTP,nButtons[121]]=(bZoneMute[3]) // Update Output Router Zone 3 Mute
    
    // This is code to update Input levels 1-8
    if( bDeviceScale && bOnline) SEND_LEVEL dvTP,49,TYPE_CAST(fnConvert(type_cast(InputGain[1]),0,221,0,100))//Update Input level 1
    if( bDeviceScale && bOnline) SEND_LEVEL dvTP,86,TYPE_CAST(fnConvert(type_cast(InputGain[2]),0,221,0,100))//Update Input level 2
    if( bDeviceScale && bOnline) SEND_LEVEL dvTP,89,TYPE_CAST(fnConvert(type_cast(InputGain[3]),0,221,0,100))//Update Input level 3
    if( bDeviceScale && bOnline) SEND_LEVEL dvTP,92,TYPE_CAST(fnConvert(type_cast(InputGain[4]),0,221,0,100))//Update Input level 4
    if( bDeviceScale && bOnline) SEND_LEVEL dvTP,95,TYPE_CAST(fnConvert(type_cast(InputGain[5]),0,221,0,100))//Update Input level 5
    if( bDeviceScale && bOnline) SEND_LEVEL dvTP,98,TYPE_CAST(fnConvert(type_cast(InputGain[6]),0,221,0,100))//Update Input level 6
    if( bDeviceScale && bOnline) SEND_LEVEL dvTP,101,TYPE_CAST(fnConvert(type_cast(InputGain[7]),0,221,0,100))//Update Input level 7
    if( bDeviceScale && bOnline) SEND_LEVEL dvTP,104,TYPE_CAST(fnConvert(type_cast(InputGain[8]),0,221,0,100))//Update Input level 8
    
    // This code is to update scene buttons
    if(nScene == 1)
	[dvTP,nButtons[122]]=1
    else
	[dvTP,nButtons[122]]=0
    if(nScene == 2)
	[dvTP,nButtons[123]]=1
    else
	[dvTP,nButtons[123]]=0
    if(nScene == 3)
	[dvTP,nButtons[124]]=1
    else
	[dvTP,nButtons[124]]=0
    if(nScene == 4)
	[dvTP,nButtons[125]]=1
    else
	[dvTP,nButtons[125]]=0
    // This code is to update subscribe button
    if(Subscribe)
	[dvTP,nButtons[128]]=1
    ELSE
	[dvTP,nButtons[128]]=0
