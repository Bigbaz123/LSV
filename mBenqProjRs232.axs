MODULE_NAME='mBenqProjRs232' (DEV vdvControl, DEV dvDevice)

INCLUDE 'CustomFunctions'
/******************************************************************************
	Basic control of BENQ Projector
	Verify model against functions
	vdvControl Commands
	DEBUG-X 				= Debugging Off (Default)
	INPUT-XXX 			= Go to Input, power on if required
		[VIDEO|SVIDEO|RGB1|RGB2|AUX|DVI]
	POWER-ON|OFF 		= Send input X to ouput Y
	FREEZE-ON|OFF		= Picture Freeze
	BLANK-ON|OFF		= Video Mute
	Feedback Channels:
	211 = Picture Freeze
	214 = Video Mute
	251 = Communicating
	252 = Busy
	253 = Warming
	254 = Cooling
	255 = Power
******************************************************************************/
/******************************************************************************
	Module Constructs
******************************************************************************/
DEFINE_TYPE STRUCTURE uBenQProj{

	// Comms Settings
	INTEGER 	DEBUG
	CHAR 		BAUD[20]
	CHAR		Tx[1000]
	CHAR		Rx[1000]
	INTEGER 	isIP
	INTEGER	CONN_STATE
	INTEGER	IP_PORT
	CHAR		IP_HOST[255]
	CHAR		IP_USER[30]
	CHAR		IP_PASS[30]
	CHAR 		IP_HASH[255]
	CHAR   	LAST_SENT[20]
	CHAR	 	DES_INPUT[10]
	INTEGER  DesVMUTE

	// State Values
	INTEGER	PROJ_STATE
	INTEGER 	FREEZE
	INTEGER 	VMUTE
	INTEGER 	ASPECT_RATIO
	INTEGER  POWER
}
/******************************************************************************
	Module Constants
******************************************************************************/
DEFINE_CONSTANT
INTEGER PROJ_STATE_OFF	= 1
INTEGER PROJ_STATE_ON	= 2
INTEGER PROJ_STATE_WARM	= 3
INTEGER PROJ_STATE_COOL	= 4

INTEGER CONN_STATE_OFFLINE	= 0
INTEGER CONN_STATE_TRYING	= 1
INTEGER CONN_STATE_SECURITY= 2
INTEGER CONN_STATE_ONLINE	= 3

LONG TLID_BUSY 	= 1;		// Warm / Cool Timeline
LONG TLID_ADJ 		= 2;		// AutoAdjust Timeline
LONG TLID_POLL 		= 3		// Polling Timeline
LONG TLID_SEND			= 4		// Staggered Sending Timeline
LONG TLID_COMMS		= 5		// Comms Timeout Timeline

INTEGER chnFreeze		= 211		// Picture Freeze Feedback
INTEGER chnVMUTE	   = 214		// Picture Mute Feedback
INTEGER chnPOWER		= 255		// Proj Power Feedback

/******************************************************************************
	Module Variables
******************************************************************************/
DEFINE_VARIABLE
VOLATILE uBenQProj myBenQProj

LONG TLT_1s[] 			= {1000}
LONG TLT_SEND[] 		= {100}	// Stagger Send - 100ms between commands
LONG TLT_COMMS[]		= {60000}// Comms Timeout - 60s
LONG TLT_POLL[] 		= {15000}	// Poll Time
LONG TLT_ADJ[] 		= {3000}	// Auto Adjust Delay

/******************************************************************************
	Startup Code
******************************************************************************/
DEFINE_START{
	CREATE_BUFFER dvDevice, myBenQProj.Rx
	myBenQProj.isIP = (dvDevice.Number)
}

/******************************************************************************
	Functions
******************************************************************************/
DEFINE_FUNCTION fnProcessFeedback(CHAR pData[]){

	SWITCH(myBenQProj.LAST_SENT){
		CASE 'QPW':{
			myBenQProj.POWER = ATOI(pData)
			// Request Shutter Status
			fnSendCommand('QSH','')
		}

		CASE 'QSH':{
			myBenQProj.VMUTE = ATOI(pData)
			IF(myBenQProj.VMUTE !=myBenQProj.DesVMUTE){
				SWITCH(myBenQProj.desVMute){
					CASE TRUE:  fnSendCommand('OSH','1')
					CASE FALSE: fnSendCommand('OSH','0')
				}
			}
		}
	}
}
DEFINE_FUNCTION fnSendCommand(CHAR pCmd[], CHAR pParam[]){
	STACK_VAR CHAR pPacket[100]

	// Build Command
	pPacket = "pCmd"
	IF(LENGTH_ARRAY(pParam)) pPacket = "'*',pPacket, '=', pParam,'#'"

	// Store Command
	myBenQProj.LAST_SENT = pPacket

	// Add delims
	pPacket = "$0D,pPacket,$0D"

	// Send it out
	SEND_STRING dvDevice, pPacket

	// Reset Polling
	fnInitPoll()
}

DEFINE_FUNCTION fnDebug(CHAR Msg[], CHAR MsgData[]){
	IF(myBenQProj.DEBUG = 1){
		SEND_STRING 0:0:0, "ITOA(vdvControl.Number),':',Msg, ':', MsgData"
	}
}
DEFINE_FUNCTION fnSendInputCommand(){
	SWITCH(myBenQProj.DES_INPUT){
		  CASE 'HDMI1':
		  CASE 'HDMI':		fnSendCommand('sour','hdmi');
		  CASE 'HDMI2':		fnSendCommand('sour','hdmi2');
	}
	SWITCH(myBenQProj.DES_INPUT){
		CASE 'RGB1':		fnSendCommand('sour','RGB');
		CASE 'RGB2':{		fnSendCommand('sour','RGB2');
			//IF(TIMELINE_ACTIVE(TLID_ADJ)){TIMELINE_KILL(TLID_ADJ)}
//			TIMELINE_CREATE(TLID_ADJ,TLT_ADJ,LENGTH_ARRAY(TLT_ADJ),TIMELINE_ABSOLUTE,TIMELINE_ONCE)
		}
	}
	myBenQProj.DES_INPUT = ''
}
/******************************************************************************
	Events
******************************************************************************/
DEFINE_FUNCTION fnInitPoll(){
	IF(TIMELINE_ACTIVE(TLID_POLL)){TIMELINE_KILL(TLID_POLL)}
	TIMELINE_CREATE(TLID_POLL,TLT_POLL,LENGTH_ARRAY(TLT_POLL),TIMELINE_ABSOLUTE,TIMELINE_REPEAT)
}

DEFINE_FUNCTION fnPoll(){
	fnSendCommand('pow','?')
}

DEFINE_EVENT TIMELINE_EVENT[TLID_POLL]{
	fnPoll()
}

DEFINE_EVENT DATA_EVENT[dvDevice]{
	ONLINE:{
		IF(myBenQProj.BAUD = ''){myBenQProj.BAUD = '115200'}
		SEND_COMMAND dvDevice, "'SET MODE DATA'"
		SEND_COMMAND dvDevice, "'SET BAUD ',myBenQProj.BAUD,' N 8 1 485 DISABLE'"
		fnPoll()
	}
	STRING:{
		fnDebug('BenQProj->AMX',DATA.TEXT)
		WHILE(FIND_STRING(myBenQProj.Rx,"$03",1)){
			REMOVE_STRING(myBenQProj.Rx,"$02",1)
			fnProcessFeedback(fnStripCharsRight(REMOVE_STRING(myBenQProj.Rx,"$03",1),1));
		}
		IF(TIMELINE_ACTIVE(TLID_COMMS)){TIMELINE_KILL(TLID_COMMS)}
		TIMELINE_CREATE(TLID_COMMS,TLT_COMMS,LENGTH_ARRAY(TLT_COMMS),TIMELINE_ABSOLUTE,TIMELINE_ONCE)
	}
}

DEFINE_EVENT DATA_EVENT[vdvControl]{
	COMMAND:{
		SWITCH(fnStripCharsRight(REMOVE_STRING(DATA.TEXT,'-',1),1)){
			CASE 'PROPERTY':{
				SWITCH(fnStripCharsRight(REMOVE_STRING(DATA.TEXT,',',1),1)){
					CASE 'BAUD':{
						myBenQProj.BAUD = DATA.TEXT
						SEND_COMMAND dvDevice, "'SET MODE DATA'"
						SEND_COMMAND dvDevice, "'SET BAUD ',myBenQProj.BAUD,' N 8 1 485 DISABLE'"
						fnPoll()
					}
					CASE 'DEBUG':{myBenQProj.DEBUG = ATOI(DATA.TEXT) }
				}
			}
			CASE 'RAW':{
				SEND_STRING dvDevice,"$0D,DATA.TEXT,$0D"
			}
			CASE 'AUTO':{
				SWITCH(DATA.TEXT){
					CASE 'ADJUST':		fnSendCommand('OAS','');
				}
			}
			CASE 'INPUT':{
				myBenQProj.DES_INPUT = DATA.TEXT
				IF([vdvControl,chnPOWER]){
					fnSendInputCommand()
				}
				ELSE{
					SEND_COMMAND vdvControl, 'POWER-ON'
				}
			}
			CASE 'POWER':{
				myBenQProj.desVMute = FALSE
				SWITCH(DATA.TEXT){
					CASE 'ON':{
						fnSendCommand('pow','on');
					}
					CASE 'OFF':{
						fnSendCommand('pow','off');
					}
				}
			}

			CASE 'VMUTE':{
				SWITCH(DATA.TEXT){
					CASE 'ON':    myBenQProj.desVMute = TRUE
					CASE 'OFF':   myBenQProj.desVMute = FALSE
					CASE 'TOGGLE':myBenQProj.desVMute = !myBenQProj.desVMute
				}
				SWITCH(myBenQProj.desVMute){
					CASE TRUE:  fnSendCommand('blank','on')
					CASE FALSE: fnSendCommand('blank','off')
				}
			}
		}
	}
}

DEFINE_EVENT TIMELINE_EVENT[TLT_ADJ]{
	SEND_COMMAND vdvControl, 'AUTO-ADJUST'
}
DEFINE_PROGRAM{
	[vdvControl,251] = (TIMELINE_ACTIVE(TLID_COMMS))
	[vdvControl,252] = (TIMELINE_ACTIVE(TLID_COMMS))
	[vdvControl,chnPOWER] 	= (myBenQProj.POWER)
	[vdvControl,chnFreeze] 	= (myBenQProj.FREEZE )
	[vdvControl,chnVMUTE]   = (myBenQProj.VMUTE )
}






































//$0D,'*pow=on#',$0D
//$0D,'*pow=off#',$0D
//$0D,'*pow=?#',$0D
//$0D,'*sour=RGB#',$0D
//$0D,'*sour=RGB2#',$0D
//$0D,'*sour=ypbr#',$0D
//$0D,'*sour=ypbr2#',$0D
//$0D,'*sour=dviA#',$0D
//$0D,'*sour=dvid#',$0D
//$0D,'*sour=hdmi#',$0D
//$0D,'*sour=hdmi2#',$0D
//$0D,'*sour=vid#',$0D
//$0D,'*sour=svid#',$0D
//$0D,'*sour=network#',$0D
//$0D,'*sour=usbdisplay#',$0D
//$0D,'*sour=usbreader#',$0D
//$0D,'*sour=?#',$0D
//$0D,'*mute=on#',$0D
//$0D,'*mute=off#',$0D
//$0D,'*mute=?#',$0D
//$0D,'*vol=+#',$0D
//$0D,'*vol=-#',$0D
//$0D,'*vol=?#',$0D
//$0D,'*micvol=+#',$0D
//$0D,'*micvol=-#',$0D
//$0D,'*micvol=?#',$0D
//$0D,'*audiosour=off#',$0D
//$0D,'*audiosour=RGB#',$0D
//$0D,'*audiosour=RGB2#',$0D
//$0D,'*audiosour=vid#',$0D
//$0D,'*audiosour=ypbr#',$0D
//$0D,'*audiosour=hdmi#',$0D
//$0D,'*audiosour=hdmi2',$0D