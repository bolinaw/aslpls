###########################################################################################
#                      ____  ____  _     ____  _     ____ 	                          #
#                     /  _ \/ ___\/ \   /  __\/ \   / ___\	                          #
#                     | / \||    \| |   |  \/|| |   |    \	                          #
#                     | |-||\___ || |_/\|  __/| |_/\\___ |	                          #
#                     \_/ \|\____/\____/\_/   \____/\____/	                          #
#                       asl_pls / irc.underx.org #aslpls    	                          #
#                                                                                         #
###########################################################################################  
#
#                 underx-access.tcl by asl_pls @ irc.underx.org #aslpls                        
#                         UnderX Access Manager Script for Eggdrop                                
#                                                                                                
#     Commands:                                                                                 
#       !add <user> <access>   - Adds a user to X access list (Requires Op/Master)             
#       !remove <user>        - Removes a user from X access list (Requires Op/Master)         
#       !autoop <user>        - Sets user's automode to OP ON via X (Requires Op/Master)        
#       !autovoice <user>     - Sets user's automode to VOICE ON via X (Requires Op/Master)    
#                                                                                                
############################################################################################

namespace eval ::XAccess {
    # CHANGE THIS: Set the flag required to use these commands.
    # 'o|o' means the user must have the 'o' flag globally OR locally on the channel.
    variable required_flag "o|o"

    # Bindings for channel commands
    bind pub $required_flag !add        [namespace current]::pub_xadd
    bind pub $required_flag !remove     [namespace current]::pub_xrem
    bind pub $required_flag !autoop     [namespace current]::pub_xautoop
    bind pub $required_flag !autovoice  [namespace current]::pub_xautovoice

    # Proc for adding a user
    proc pub_xadd {nick uhost hand chan arg} {
        set user [lindex [split $arg] 0]
        set level [lindex [split $arg] 1]

        if {$user eq "" || $level eq ""} {
            putquick "NOTICE $nick :Usage: !add <username> <level>"
            return 0
        }

        # Syntax: /msg x@channels.underx.org ADDUSER #channel user level
        putquick "PRIVMSG x@channels.underx.org :ADDUSER $chan $user $level"
        putquick "PRIVMSG $chan :Requested X to add \002$user\002 with access \002$level\002."
        return 1
    }

    # Proc for removing a user
    proc pub_xrem {nick uhost hand chan arg} {
        set user [lindex [split $arg] 0]

        if {$user eq ""} {
            putquick "NOTICE $nick :Usage: !remove <username>"
            return 0
        }

        # Syntax: /msg x@channels.underx.org REMUSER #channel user
        putquick "PRIVMSG x@channels.underx.org :REMUSER $chan $user"
        putquick "PRIVMSG $chan :Requested X to remove \002$user\002."
        return 1
    }

    # Proc for setting Auto-Op
    proc pub_xautoop {nick uhost hand chan arg} {
        set user [lindex [split $arg] 0]

        if {$user eq ""} {
            putquick "NOTICE $nick :Usage: !autoop <username>"
            return 0
        }

        # Syntax: /msg x modinfo #channel automode username op on
        putquick "PRIVMSG x@channels.underx.org :MODINFO $chan AUTOMODE $user OP ON"
        putquick "PRIVMSG $chan :Requested X to set automode for \002$user\002 to OP ON."
        return 1
    }

    # Proc for setting Auto-Voice
    proc pub_xautovoice {nick uhost hand chan arg} {
        set user [lindex [split $arg] 0]

        if {$user eq ""} {
            putquick "NOTICE $nick :Usage: !autovoice <username>"
            return 0
        }

        # Syntax: /msg x modinfo #channel automode username voice on
        putquick "PRIVMSG x@channels.underx.org :MODINFO $chan AUTOMODE $user VOICE ON"
        putquick "PRIVMSG $chan :Requested X to set automode for \002$user\002 to VOICE ON."
        return 1
    }

    putlog "Loaded: UnderX X Access Manager Script by asl_pls @ irc.underx.org"
}
