###########################################################################################
##                     ____  ____  _     ____  _     ____ 	                         ##
##                     /  _ \/ ___\/ \   /  __\/ \   / ___\	                         ##
##                    | / \||    \| |   |  \/|| |   |    \	                         ##
##                     | |-||\___ || |_/\|  __/| |_/\\___ |	                         ##
##                    \_/ \|\____/\____/\_/   \____/\____/	                         ##
##                      asl_pls / irc.underx.org #aslpls    	                         ##
##                                                                               06/2026 ##
########################################################################################### 
# EggCmds.tcl by asl_pls @ irc.underx.org #aslpls                                    
# Eggdrop Administrative and UnderX Service Automation Script                             
# Updated with extended channel modes and X modinfo capabilities.                         
###########################################################################################

namespace eval ::AdminX {
    # -----------------------------------------------------------------
    # BINDINGS (Public channel commands)
    # -----------------------------------------------------------------
    
    # Channel Management (Requires global or channel 'o' operator flag)
    bind pub o|o "!op"       [namespace current]::pub_op
    bind pub o|o "!deop"     [namespace current]::pub_deop
    bind pub o|o "!v"        [namespace current]::pub_voice
    bind pub o|o "!dv"       [namespace current]::pub_devoice
    bind pub o|o "!kick"     [namespace current]::pub_kick
    bind pub o|o "!ban"      [namespace current]::pub_ban
    bind pub o|o "!ub"       [namespace current]::pub_unban
    
    # Channel Modes (+/- m, s, i, p)
    bind pub o|o "!m"        [namespace current]::pub_moderated
    bind pub o|o "!-m"       [namespace current]::pub_unmoderated
    bind pub o|o "!s"        [namespace current]::pub_secret
    bind pub o|o "!-s"       [namespace current]::pub_unsecret
    bind pub o|o "!i"        [namespace current]::pub_invite
    bind pub o|o "!-i"       [namespace current]::pub_uninvite
    bind pub o|o "!p"        [namespace current]::pub_private
    bind pub o|o "!-p"       [namespace current]::pub_unprivate

    # UnderX Management (Requires global 'n' owner flag for master controls)
    bind pub n "!adduser"  [namespace current]::pub_x_adduser
    bind pub n "!deluser"  [namespace current]::pub_x_deluser
    bind pub n "!autoop"   [namespace current]::pub_x_autoop
    bind pub n "!autovoice" [namespace current]::pub_x_autovoice
    bind pub n "!modinfo"  [namespace current]::pub_x_modinfo

    # -----------------------------------------------------------------
    # CHANNEL & MODERATION PROCEDURES
    # -----------------------------------------------------------------
    proc pub_op {nick uhost hand chan arg} {
        set target [lindex [split $arg] 0]
        if {$target eq ""} { set target $nick }
        if {![botisop $chan]} { return }
        putserv "MODE $chan +o $target"
    }

    proc pub_deop {nick uhost hand chan arg} {
        set target [lindex [split $arg] 0]
        if {$target eq ""} { set target $nick }
        if {![botisop $chan]} { return }
        putserv "MODE $chan -o $target"
    }

    proc pub_voice {nick uhost hand chan arg} {
        set target [lindex [split $arg] 0]
        if {$target eq ""} { set target $nick }
        if {![botisop $chan]} { return }
        putserv "MODE $chan +v $target"
    }

    proc pub_devoice {nick uhost hand chan arg} {
        set target [lindex [split $arg] 0]
        if {$target eq ""} { set target $nick }
        if {![botisop $chan]} { return }
        putserv "MODE $chan -v $target"
    }

    proc pub_kick {nick uhost hand chan arg} {
        set args [split $arg]
        set target [lindex $args 0]
        set reason [join [lrange $args 1 end]]
        if {$target eq ""} { putserv "PRIVMSG $chan :Usage: !kick <nick> [reason]"; return }
        if {$reason eq ""} { set reason "Requested by $nick" }
        if {![botisop $chan]} { return }
        putserv "KICK $chan $target :$reason"
    }

    proc pub_ban {nick uhost hand chan arg} {
        set target [lindex [split $arg] 0]
        if {$target eq ""} { putserv "PRIVMSG $chan :Usage: !ban <nick>"; return }
        if {![botisop $chan]} { return }
        set mask [getchanhost $target $chan]
        if {$mask eq ""} { set banmask "$target!*@*" } { set banmask "*!*@[lindex [split $mask @] 1]" }
        putserv "MODE $chan +b $banmask"
        putserv "KICK $chan $target :Banned"
    }

    proc pub_unban {nick uhost hand chan arg} {
        set target [lindex [split $arg] 0]
        if {$target eq ""} { putserv "PRIVMSG $chan :Usage: !ub <nick/mask>"; return }
        if {![botisop $chan]} { return }
        set mask [getchanhost $target $chan]
        if {$mask eq ""} { set banmask $target } { set banmask "*!*@[lindex [split $mask @] 1]" }
        putserv "MODE $chan -b $banmask"
    }

    # Mode Control Procedures
    proc pub_moderated {nick uhost hand chan arg} {
        set target [lindex [split $arg] 0]; if {$target eq ""} { set target $chan }
        if {![botisop $target]} { return }; putserv "MODE $target +m"
    }

    proc pub_unmoderated {nick uhost hand chan arg} {
        set target [lindex [split $arg] 0]; if {$target eq ""} { set target $chan }
        if {![botisop $target]} { return }; putserv "MODE $target -m"
    }

    proc pub_secret {nick uhost hand chan arg} {
        set target [lindex [split $arg] 0]; if {$target eq ""} { set target $chan }
        if {![botisop $target]} { return }; putserv "MODE $target +s"
    }

    proc pub_unsecret {nick uhost hand chan arg} {
        set target [lindex [split $arg] 0]; if {$target eq ""} { set target $chan }
        if {![botisop $target]} { return }; putserv "MODE $target -s"
    }

    proc pub_invite {nick uhost hand chan arg} {
        set target [lindex [split $arg] 0]; if {$target eq ""} { set target $chan }
        if {![botisop $target]} { return }; putserv "MODE $target +i"
    }

    proc pub_uninvite {nick uhost hand chan arg} {
        set target [lindex [split $arg] 0]; if {$target eq ""} { set target $chan }
        if {![botisop $target]} { return }; putserv "MODE $target -i"
    }

    proc pub_private {nick uhost hand chan arg} {
        set target [lindex [split $arg] 0]; if {$target eq ""} { set target $chan }
        if {![botisop $target]} { return }; putserv "MODE $target +p"
    }

    proc pub_unprivate {nick uhost hand chan arg} {
        set target [lindex [split $arg] 0]; if {$target eq ""} { set target $chan }
        if {![botisop $target]} { return }; putserv "MODE $target -p"
    }

    # -----------------------------------------------------------------
    # UNDERX SERVICE PROCEDURES
    # -----------------------------------------------------------------
    proc pub_x_adduser {nick uhost hand chan arg} {
        set args [split $arg]
        set username [lindex $args 0]
        set access [lindex $args 1]
        if {$username eq "" || $access eq ""} {
            putserv "PRIVMSG $chan :Usage: !adduser <X-username> <access-level>"
            return
        }
        putserv "PRIVMSG x :adduser $chan $username $access"
        putserv "PRIVMSG $chan :Sent Request to X: adduser $chan $username $access"
    }

    proc pub_x_deluser {nick uhost hand chan arg} {
        set username [lindex [split $arg] 0]
        if {$username eq ""} {
            putserv "PRIVMSG $chan :Usage: !deluser <X-username>"
            return
        }
        putserv "PRIVMSG x :remuser $chan $username"
        putserv "PRIVMSG $chan :Sent Request to X: remuser $chan $username"
    }

    proc pub_x_autoop {nick uhost hand chan arg} {
        set username [lindex [split $arg] 0]
        if {$username eq ""} {
            putserv "PRIVMSG $chan :Usage: !autoop <X-username>"
            return
        }
        putserv "PRIVMSG x :modinfo $chan automode $username op on"
        putserv "PRIVMSG $chan :Sent Request to X: Automode OP enabled for $username"
    }

    proc pub_x_autovoice {nick uhost hand chan arg} {
        set username [lindex [split $arg] 0]
        if {$username eq ""} {
            putserv "PRIVMSG $chan :Usage: !autovoice <X-username>"
            return
        }
        putserv "PRIVMSG x :modinfo $chan automode $username voice on"
        putserv "PRIVMSG $chan :Sent Request to X: Automode VOICE enabled for $username"
    }

    proc pub_x_modinfo {nick uhost hand chan arg} {
        set args [split $arg]
        set username [lindex $args 0]
        set new_level [lindex $args 1]
        if {$username eq "" || $new_level eq ""} {
            putserv "PRIVMSG $chan :Usage: !modinfo <X-username> <new-level>"
            return
        }
        putserv "PRIVMSG x :modinfo $chan access $username $new_level"
        putserv "PRIVMSG $chan :Sent Request to X: modinfo $chan access $username $new_level"
    }

    putlog "Loaded: EggCmds.tcl Extended UnderX Admin Engine by asl_pls @ irc.underx.org #aslpls"
}
