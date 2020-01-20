PROGRAM_NAME='DBX_ZonePro'

(********************************************************************)
(* FILE CREATED ON: 07/14/04  AT: 10:41:05                          *)
(********************************************************************)
(*  FILE_LAST_MODIFIED_ON: 07/14/04 AT: 10:41:05           *)
(***********************************************************)
(*  ORPHAN_FILE_PLATFORM: 1                                *)
(***********************************************************)
(*!!FILE REVISION: Rev 2.1                                 *)
(*  REVISION DATE: 06/10/09                                *)
(*                                                         *)
(*  COMMENTS:  Remember to check the serial variable       *)
(*     before trying to connect over IP or RS232           *)
(***********************************************************)
(*}}PS_SOURCE_INFO                                         *)
(***********************************************************)
DEFINE_DEVICE
//WARNING!!!! must only use one dev with the name dvDBX_ZonePro. Must be either serial or IP
// and the serial variable needs to match whatever you pick!!!

// WARNING!!!!! must change the variable serial to 1 below
//dvDBX_ZonePro=5001:1:0 //real device for serial

// WARNING!!!!!! must change the variable serial to 0 below, and
// you must type in the address into cServerAddress variable also below.



DEFINE_CONSTANT

// Booleans
TRUE = 1;
FALSE = 0;

INTEGER DBX_ZonePro_BUTTONS[]=
{
  1,  //  Text box for the zonepro ID.
  2,  //  Text box for the zonepro box type.
  3,  //  Text box for the # of objects found.
  4,  //4-24 Text boxes representing objects found.
  5,    
  6,    
  7,    
  8,     
  9,    
  10,   
  11,  
  12,  
  13,  
  14,  
  15,  
  16,  
  17,  
  18,  
  19,  
  20,   
  21,  
  22,  
  23,  
  24,  
  25, // Mixer Input control 1 volume
  26, // Up volume for 25
  27, // down volume for 25
  28, // Mixer input control 2 volume
  29, // Up volume for 28
  30, // Down volume for 29
  31, // Mixer input control 3 volume
  32, // Up volume for 30
  33, // Down volume for 30
  34, // Mixer input control 4 volume
  35, // Up volume for 34
  36, // Down volume for 35
  37, // Master Mixer Volume
  38, // Up volume for 37
  39, // Down volume for 37
  40, // Mixer Mute
  41, // Source button 1
  42, // Source button 2
  43, // Source button 3
  44, // Source button 4
  45, // Router volume
  46, // Up volume for 45
  47, // Down volume for 45
  48, // Router mute
  49, // Input 1 volume
  50, // Up volume for 49
  51, // Down volume for 49
  52, // Source button 5
  53, // Source button 6
  54, // Source button 7
  55, // Source button 8
  56, // Source button 9
  57, // Source button 10
  58, // Source button 11
  59, //59-85 are the rest of the text boxes for the objects found.
  60, 
  61,
  62,
  63,
  64,
  65,
  66,
  67,
  68,
  69,
  70,
  71,
  72,
  73,
  74,
  75,
  76,
  77,
  78,
  79,
  80,
  81,
  82,
  83,
  84,
  85,
  86, // Input 2 volume
  87, // Up volume for 86
  88, // Down volume for 86
  89, // Input 3 volume
  90, // Up volume for 89
  91, // Down volume for 89
  92, // Input 4 volume
  93, // Up volume for 92
  94, // Down volume for 92
  95, /* Input 5 volume*/
  96, // Up volume for 95
  97, // Down volume for 95
  98, // Input 6 volume
  99, // Up volume for 98
  100, // Down volume for 98
  101, // Input 7 volume
  102, // Up volume for 101
  103, // Down volume for 101
  104, /* Input 8 volume*/
  105, // Up volume for 104
  106, // Down volume for 104
  107, // Source button 1
  108, // Source button 2
  109, // Source button 3
  110, // Source button 4
  111, // Source button 5
  112, // Source button 6
  113, // Source button 7
  114, // Source button 8
  115, // Source button 9
  116, // Source button 10
  117, // Source button 11
  118, // Router volume
  119, // Up volume for 118
  120, // Down volume for 118
  121, // Router mute 
  122, // Scene 1 
  123, // Scene 2 
  124, // Scene 3  
  125, // Scene 4 
  126, // Text box for Connected to serial or TCP/IP 
  127, // Textbox to show socket connection status With TCP/IP Connection 
  128  // Subscribe BUTTON 
}

DEFINE_VARIABLE

char cServerAddress[15] = '10.1.5.215' // IP Address of the ZonePro

LONG lServerPort = 3804 // port of the Box
VOLATILE INTEGER serial = 0 // determines if this is to send serial messages or ip messages. default is serial.
		    // 0 = IP 1 = serial







