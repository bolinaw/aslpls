##############################################################
#	_______ ______________ ________ ______ ________
#	___    |__  ___/___  / ___  __ \___  / __  ___/
#	__  /| |_____ \ __  /  __  /_/ /__  /  _____ \ 
#	_  ___ |____/ / _  /____  ____/ _  /_______/ / 
#	/_/  |_|/____/  /_____//_/      /_____//____/  
#		  asl_pls / irc.underx.org	
#							
##############################################################
#
#	EggRegisteredNick.tcl Fix Bug and Modified.
#	This will apply to all Chanserv Network
#
#	* Identified users in the network upon joining the channel
#		will get voice (+v) automatically from the bot.
#
#	* Salute the OG's script coder for the script.
#		I scanned my files, i cannot find the exact scripter.
#		Remind me if you remember, cause i cannot remembem them.
#
##############################################################

namespace eval RegVoice {
    # -------------------------------------------------------------
    # CONFIGURATION
    # -------------------------------------------------------------
    # Add your channels here separated by spaces. Example: {"#cebu" "#manila" "#davao"}
    variable targetChans [list "#cebu" "#aslpls" "#dumaguete"]
    
    variable verifieduser "*has identified for*"
    variable checkAuth [list]

    # -------------------------------------------------------------
    # BINDS
    # -------------------------------------------------------------
    bind join - * [namespace current]::joinCheck
    bind raw - 307 [namespace current]::isReg
    bind time - * [namespace current]::cleanUp

    proc cleanUp {minute hour day month year} {
        variable checkAuth
        if {[llength $checkAuth] == 0} { return }
        
        set updatedList [list]
        foreach nick $checkAuth {
            if {[onchan $nick]} {
                lappend updatedList $nick
            }
        }
        set checkAuth $updatedList
    }
     
    proc joinCheck {nick uhost hand chan} {
        variable targetChans
        variable checkAuth
        
        if {[isbotnick $nick]} { return }
        if {[lsearch -nocase $targetChans $chan] == -1} { return }
        if {[validuser $hand]} { return }
        if {[lsearch -nocase $checkAuth $nick] != -1} { return }
        
        lappend checkAuth $nick
        puthelp "WHOIS $nick"
    }

    proc isReg {from keyword text} {
        variable targetChans
        variable checkAuth
        variable verifieduser

        set nick [lindex [split $text] 1]
        
        set pos [lsearch -nocase $checkAuth $nick]
        if {$pos != -1} {
            set checkAuth [lreplace $checkAuth $pos $pos]
        }
        
        if {![string match $verifieduser $text]} { return }
        if {[validuser [nick2hand $nick]]} { return }
        
        foreach chan $targetChans {
            if {![validchan $chan] || ![botonchan $chan]} { continue }
            if {![onchan $nick $chan] || [isop $nick $chan] || [isvoice $nick $chan]} { continue }
            if {![botisop $chan]} { continue }
            
            pushmode $chan +v $nick
        }
    }
}
 
putlog "EggRegisteredNick.tcl modified by asl_pls (AutoVoice Only) loaded"