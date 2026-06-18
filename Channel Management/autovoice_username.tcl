#####################################################################################
#                      ____  ____  _     ____  _     ____ 	                        #
#                     /  _ \/ ___\/ \   /  __\/ \   / ___\	                        #
#                     | / \||    \| |   |  \/|| |   |    \	                        #
#                     | |-||\___ || |_/\|  __/| |_/\\___ |	                        #
#                     \_/ \|\____/\____/\_/   \____/\____/	                        #
#                       asl_pls / irc.underx.org #aslpls    	                    #
##################################################################################### 
#                                                                                   # 
#             autovoice_username.tcl by asl_pls @ irc.underx.org #aslpls            # 
#             Automatically voices users who are logged into UndernX's              #   
#                       service upon joining a channel.                             #   
#                                                                                   # 
##################################################################################### 

namespace eval ::UnderXVoice {
    # CONFIGURATION
    # Enter the specific channels where this script should work (space-separated).
    # Example: "#mychan #lounge"
    variable target_chans "#UnderX"

    # BINDINGS
    bind join - * [namespace current]::on_join

    # MAIN PROCEDURE
    proc on_join {nick uhost hand chan} {
        variable target_chans

        # 1. Ensure the bot itself is doing the action and has ops in the channel
        if {![botisop $chan]} { return 0 }

        # 2. Check if the channel is one of your specific target channels (case-insensitive)
        if {[lsearch -nocase $target_chans $chan] == -1} { return 0 }

        # 3. Ignore the bot itself to prevent loops
        if {[isbotnick $nick]} { return 0 }

        # 4. Check if the user's hostmask matches the UnderX X login format
        # Undernet masks registered users as: ident@username.users.underx.org
        if {[string match -nocase "*.users.underx.org" $uhost]} {
            # Put the mode change in the queue to avoid flooding the server
            putserv "MODE $chan +v $nick"
        }

        return 0
    }
    
    putlog "Loaded: Undernet X Auto-Voice Script by asl_pls @ irc.underx.org"
}
