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
#																					
# 	EggJoke_icanhazdadjoke.tcl														
#		- Eggdrop script to fetch random jokes from an API with automation			
#																					
#																					
# 	Requires: Tcl 8.5+ and the 'json' package (usually in tcllib)					
#																					
#																					
#	On Debian/Ubuntu Linux:		sudo apt-get install tcllib							
#	On CentOS/RHEL: 			sudo yum install tcllib								
#																					
#																					
###########################################################################################

package require http
package require json

namespace eval ::JokeBot {
    # ------------------ CONFIGURATION ------------------
    
    variable cmd "!joke"
    variable channelflags "-|"   ;# Trigger flags for manual use
    
    # Automation Settings
    variable auto_post 1         ;# Set to 1 to enable timer, 0 to disable
    variable post_interval 30    ;# Time interval in MINUTES between jokes
    
    # Target channels for automated jokes (space-separated)
    # Example: variable auto_chans "#Lobby #FunZone"
    variable auto_chans "#aslpls" 
    
    # ---------------------------------------------------

    # Bind manual command
    bind pub $channelflags $cmd [namespace current]::pub_fetch_joke

    proc pub_fetch_joke {nick uhost hand chan arg} {
        get_and_post_joke $chan
    }

    # This handles the recurring timer loop
    proc timer_loop {} {
        variable auto_post
        variable post_interval
        variable auto_chans

        # If automation is disabled, stop the loop
        if {!$auto_post} { return }

        # Broadcast joke to all designated channels
        foreach chan [string tolower $auto_chans] {
            if {[validchan $chan] && [botisop $chan] || [botishalfop $chan] || [onchan $::botnick $chan]} {
                get_and_post_joke $chan
            }
        }

        # Reschedule the timer (minutes converted to minutes for Eggdrop 'timer' command)
        timer $post_interval [namespace current]::timer_loop
    }

    # Core procedure to fetch from API and send to a channel
    proc get_and_post_joke {chan} {
        set url "https://icanhazdadjoke.com/"
        set headers [list "Accept" "application/json" "User-Agent" "EggdropIRCJokeScript"]

        if {[catch {set tok [::http::geturl $url -headers $headers -timeout 5000]} err]} {
            # Only put errors log internally to avoid spamming channels on network hiccups
            putlog "JokeBot Error contacting API: $err"
            return
        }

        if {[::http::status $tok] ne "ok"} {
            ::http::cleanup $tok
            return
        }

        set data [::http::data $tok]
        ::http::cleanup $tok

        if {[catch {set json_dict [::json::json2dict $data]} err]} {
            return
        }

        if {[dict exists $json_dict joke]} {
            set joke [dict get $json_dict joke]
            set joke [regsub -all {\s+} $joke " "]

            # Send to channel
            putquick "PRIVMSG $chan :\00303\[Joke\]\003 $joke"
        }
    }

    # Initialize the loop on load/rehash if enabled
    if {$auto_post} {
        # Remove any existing instances of this timer first to prevent duplicate loops on .rehash
        foreach t [timers] {
            if {[string match "*timer_loop*" [lindex $t 1]]} {
                killtimer [lindex $t 2]
            }
        }
        # Start the loop
        timer $post_interval [namespace current]::timer_loop
    }

    putlog "Loaded EggJoke_icanhazdadjoke.tcl Script (Trigger: $cmd | Auto-post: every $post_interval mins to $auto_chans)"
}
