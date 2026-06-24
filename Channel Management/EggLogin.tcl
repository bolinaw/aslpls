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
#     EggLogin.tcl by asl_pls @ irc.underx.org #aslpls                            
#     Eggdrop script to autologin to UnderX's X services and set user modes.        
#                                                                                    
########################################################################################### 

namespace eval ::UndernetLogin {
    # -----------------------------------------------------------------
    # CONFIGURATION
    # -----------------------------------------------------------------
    variable username "xusername"
    variable password "xpassword"
    variable usermodes "+x"
    # -----------------------------------------------------------------

    # Bind to raw server numeric 001 (RPL_WELCOME)
    bind raw - 001 [namespace current]::on_connect

    proc on_connect {from keyword text} {
        variable username
        variable password
        variable usermodes

        # Use putquick to bypass the standard traffic queues for instant execution
        # 1. Log in to X channels service
        putquick "PRIVMSG x@channels.underx.org :login $username $password"

        # 2. Set the bot's user modes (e.g., +x for host hiding)
        # ::botnick is a built-in Eggdrop global variable for the current nickname
        putquick "MODE $::botnick $usermodes"

        putlog "Undernet Auth: Sent login to X and set modes ($usermodes) for $::botnick"
        return 0
    }
}

putlog "Loaded EggLogin.tcl successfully by asl_pls @ irc.underx.org"
