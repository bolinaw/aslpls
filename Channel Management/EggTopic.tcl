###########################################################################################
##                     ____  ____  _     ____  _     ____ 	                         ##
##                     /  _ \/ ___\/ \   /  __\/ \   / ___\	                         ##
##                    | / \||    \| |   |  \/|| |   |    \	                         ##
##                     | |-||\___ || |_/\|  __/| |_/\\___ |	                         ##
##                    \_/ \|\____/\____/\_/   \____/\____/	                         ##
##                      asl_pls / irc.underx.org #aslpls    	                         ##
##                                                                               06/2026 ##
########################################################################################### 
#                                                                                          
#            EggTopic.tcl by asl_pls @ irc.underx.org #aslpls                     
#                     Eggdrop Random Channel Topic Rotator                                  
#                                                                                          
#             Features:                                                                   
#               - Cycles through 5 pre-defined topics randomly.                           
#               - Changes the topic automatically every 5 hours.                          
#               - Tracks an internal counter so it survives bot splits/reconnects.          
#                                                                                                  
###########################################################################################

namespace eval ::topic_rotator {
    # --- Configuration ---
    
    # Specify the channel where the topic should change (must be lowercase)
    variable target_chan "#aslpls"

    # Define your 5 random topics here (IRC bold control codes "\002" can be used)
    variable topic_pool {
        "\002Welcome to the channel!\002 | Be kind, unwind, and enjoy the chat."
        "Did you know? The first computer bug was a real moth trapped in a relay in 1947."
        "Current Vibe: Chill music and terminal windows. What are you working on today?"
        "\002Rule #1:\002 Don't feed the bots after midnight. Rule #2: Enjoy your stay!"
        "Looking for project ideas? Ask the community or check out our repository pins."
    }

    # Internal tracking variable to count hours
    variable hour_counter 0

    # Bind to Eggdrop's internal clock - triggers exactly at minute 00 of every hour
    bind time - "00 * * * *" [namespace current]::check_hour_trigger

    # Core execution proc
    proc check_hour_trigger {min hour day month year} {
        variable hour_counter
        variable target_chan
        variable topic_pool

        # Increment our hourly tracker
        incr hour_counter

        # If 5 hours have elapsed, perform the topic switch
        if {$hour_counter >= 5} {
            # Reset the counter
            set hour_counter 0

            # Ensure the bot is actually sitting in the target channel first
            if {![validchan $target_chan] || ![botison $target_chan]} {
                putlog "\[Topic Rotator\] Skipped: Not active in channel $target_chan"
                return
            }

            # Pick a completely random index from our list (0 to 4)
            set list_size [llength $topic_pool]
            set random_index [expr {int(rand() * $list_size)}]
            set new_topic [lindex $topic_pool $random_index]

            # Send the TOPIC command to the server via puthelp (queued safely)
            puthelp "TOPIC $target_chan :$new_topic"
            putlog "\[Topic Rotator\] Rotated topic in $target_chan to index: $random_index"
        }
    }

    putlog "EggTopic.tcl loaded successfully. Target: $target_chan (Every 5 hours) by asl_pls"
}
