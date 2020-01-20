PROGRAM_NAME='Main'
(***********************************************************)
(***********************************************************)
(*  FILE_LAST_MODIFIED_ON: 04/05/2006  AT: 09:00:25        *)
(***********************************************************)
(* System Type : NetLinx                                   *)
(***********************************************************)
(* REV HISTORY:                                            *)
(***********************************************************)
(*
    $History: $
*)
(***********************************************************)
(*          DEVICE NUMBER DEFINITIONS GO BELOW             *)
(***********************************************************)


DEFINE_DEVICE
tpmain 		=	10001:0:0
dvTP   		=	10001:1:0

dvAtenMatrix	=	05001:01:01
vdvAtenMatrix	=	33001:01:01

dvBenqProj	=	05001:02:01
vdvBenqProj	=	33002:01:01

dvLGScreen	=	05001:03:01
vdvLGscreen	=	33003:01:01

dvDBX_ZonePro 	= 	0:2:0 
vdvDBX_ZonePro	=	33004:1:0 

#INCLUDE 'DBX_ZonePro_Main'
#INCLUDE 'CustomFunctions'
#INCLUDE 'StandardCodeDiagnostics'

DEFINE_MODULE 'mAtenMatrix' Matrix(vdvAtenMatrix,dvAtenMatrix)
DEFINE_MODULE 'mBenqProjRs232' Projector(vdvBenqProj,dvBenqProj)
DEFINE_MODULE 'mBenqProjRs232' Display(vdvLGscreen,dvLGScreen)
DEFINE_MODULE 'DBX_ZonePro_COMM' comm_code(vdvDBX_ZonePro,dvDBX_ZonePro,serial)
DEFINE_MODULE 'DBX_ZonePro_UI' ui_code(vdvDBX_ZonePro, dvTP, DBX_ZonePro_BUTTONS,cServerAddress,lServerPort,serial,dvDBX_ZonePro)

DEFINE_CONSTANT

(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

(***********************************************************)
(*               LATCHING DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_LATCHING

(***********************************************************)
(*       MUTUALLY EXCLUSIVE DEFINITIONS GO BELOW           *)
(***********************************************************)
DEFINE_MUTUALLY_EXCLUSIVE

(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)
(* EXAMPLE: DEFINE_FUNCTION <RETURN_TYPE> <NAME> (<PARAMETERS>) *)
(* EXAMPLE: DEFINE_CALL '<NAME>' (<PARAMETERS>) *)

(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT

(*****************************************************************)
(*                                                               *)
(*                      !!!! WARNING !!!!                        *)
(*                                                               *)
(* Due to differences in the underlying architecture of the      *)
(* X-Series masters, changing variables in the DEFINE_PROGRAM    *)
(* section of code can negatively impact program performance.    *)
(*                                                               *)
(* See “Differences in DEFINE_PROGRAM Program Execution” section *)
(* of the NX-Series Controllers WebConsole & Programming Guide   *)
(* for additional and alternate coding methodologies.            *)
(*****************************************************************)

DEFINE_PROGRAM

(*****************************************************************)
(*                       END OF PROGRAM                          *)
(*                                                               *)
(*         !!!  DO NOT PUT ANY CODE BELOW THIS COMMENT  !!!      *)
(*                                                               *)
(*****************************************************************)


