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
# EggXmas.tcl by asl_pls @ irc.underx.org #aslpls
# Christmas 2026 Countdown Auto-Topic Script (Modified for 24-hr PHT Sync)
#
##########################################################################################

namespace eval ::XmasCountdown {
    # ------------ CONFIGURATION ------------
    
    # Target channels (space-separated, e.g., "#lobby #lounge")
    variable channels "#aslpls"
    
    # The base topic prefix. The countdown will be appended to this.
    variable topic_prefix "\00306Hey!\003 "

    # ------------ END OF CONFIGURATION ------------

    # Internal tracking variables for the timer ID
    variable topic_timer_id ""

    # Bind DCC commands for masters/owners to edit timers in partyline
    bind dcc m forcekicktopic [namespace current]::dcc_force_topic
    bind dcc m showtimers [namespace current]::dcc_show_timers

    # Initialization function to start the loops
    proc init {} {
        # Stop any accidental duplicate timers on rehash
        stop_timers

        # Start the loop aligned to PHT midnight
        start_topic_loop
    }

    proc stop_timers {} {
        variable topic_timer_id
        if {$topic_timer_id != ""} { killutimer $topic_timer_id; set topic_timer_id "" }
    }

    # --- TOPIC LOOP ---
    proc start_topic_loop {} {
        variable topic_timer_id
        
        # 1. Update the topic right now
        update_topic

        # 2. Calculate seconds until the NEXT midnight Philippine Time (PHT)
        # PHT is UTC+8. We use 'clock' with -timezone to strictly follow Manila time.
        set pht_zone ":Asia/Manila"
        set now [clock seconds]
        
        # Get today's date in PHT
        set today_pht [clock format $now -format "%Y-%m-%d" -timezone $pht_zone]
        
        # Get the epoch time for midnight of *tonight* (which becomes tomorrow)
        set midnight_pht [clock scan "$today_pht 00:00:00" -format "%Y-%m-%d %H:%M:%S" -timezone $pht_zone]
        set next_midnight [expr {$midnight_pht + 86400}]
        
        # Seconds left until midnight PHT
        set seconds_left [expr {$next_midnight - $now}]
        
        # Guard rail: if something goes weird and seconds_left is 0 or negative, default to 10 seconds
        if {$seconds_left <= 0} { set seconds_left 10 }

        # 3. Schedule the next run precisely at PHT midnight
        set topic_timer_id [utimer $seconds_left [list [namespace current]::topic_cron_trigger]]
    }

    # This bridge proc ensures the cycle repeats continuously 
    proc topic_cron_trigger {} {
        variable topic_timer_id
        set topic_timer_id ""
        start_topic_loop
    }

    proc update_topic {} {
        variable channels
        variable topic_prefix

        # Target timestamp: Christmas Day 2026 (Dec 25, 2026 00:00:00 PHT)
        set xmas_time [clock scan "2026-12-25 00:00:00" -format "%Y-%m-%d %H:%M:%S" -timezone ":Asia/Manila"]
        set now [clock seconds]
        set diff [expr {$xmas_time - $now}]

        if {$diff <= 0} {
            set countdown_str "ðŸŽ„ Merry Christmas 2026! ðŸŽ„"
        } else {
            set days [expr {$diff / 86400}]
            set rem [expr {$diff % 86400}]
            set hours [expr {$rem / 3600}]
            set mins [expr {($rem % 3600) / 60}]

            set countdown_str "\0031Only\0034 $days days\0031,\0037 $hours hours\0031, and\0036 $mins minutes\00310\0031 until \00303Christmas Day 2026!\003"
        }

        set new_topic "${topic_prefix}${countdown_str}"

        foreach chan [split $channels] {
            if {[validchan $chan] && [botisop $chan]} {
                puthelp "TOPIC $chan :$new_topic"
            }
        }
    }

    # --- DCC COMMAND HANDLERS ---
    proc dcc_force_topic {hand idx arg} {
        variable topic_timer_id
        
        if {$topic_timer_id != ""} { killutimer $topic_timer_id }
        start_topic_loop
        
        putdcc $idx "Christmas topic forced to update. Next automatic update rescheduled for midnight PHT."
        return 1
    }

    proc dcc_show_timers {hand idx arg} {
        variable topic_timer_id
        putdcc $idx "--- Xmas Bot Timer Status ---"
        if {$topic_timer_id != ""} {
            putdcc $idx "Topic Countdown Loop: Active. Updating everyday exactly at 00:00:00 Philippine Time."
        } else {
            putdcc $idx "Topic Countdown Loop: Inactive!"
        }
        return 1
    }

    # Fire the initializer
    init
}

putlog "Loaded: Christmas 2026 Countdown Topic Script (24h PHT Edition)"
