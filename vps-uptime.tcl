###############################################################################
# Christmas 2026 Countdown Auto-Topic Script for Eggdrop
# Updates the channel topic every 2 hours with the remaining time.
###############################################################################

namespace eval ::XmasCountdown {
    # ------------ CONFIGURATION ------------
    
    # Target channels (space-separated, e.g., "#lobby #lounge")
    variable channels "#aslpls"
    
    # The base topic prefix. The countdown will be appended to this.
    variable topic_prefix "0,4 H 2,7 e 2,8 y 2,9 ! 2,15 *  "
    
    # ------------ END OF CONFIGURATION ------------

    # Bind a time timer to run every 2 hours (at 00, 02, 04, etc. mins past the hour)
    # Eggdrop 'time' binds use the format "minute hour day month weekday"
    # A minute value of "00" triggers once an hour. We'll filter for every 2 hours inside.
    bind time - "00 * * * *" [namespace current]::check_time

    proc check_time {min hour day month weekday} {
        # Check if the current hour is even (every 2 hours: 0, 2, 4, 6...)
        if {$hour % 2 == 0} {
            update_topic
        }
    }

    proc update_topic {} {
        variable channels
        variable topic_prefix

        # Target timestamp: Christmas Day 2026 (Dec 25, 2026 00:00:00)
        set xmas_time [clock scan "2026-12-25 00:00:00" -format "%Y-%m-%d %H:%M:%S"]
        set now [clock seconds]
        
        set diff [expr {$xmas_time - $now}]

        if {$diff <= 0} {
            set countdown_str "? Merry Christmas 2026! ?"
        } else {
            # Calculate days, hours, and minutes
            set days [expr {$diff / 86400}]
            set rem [expr {$diff % 86400}]
            set hours [expr {$rem / 3600}]
            set mins [expr {($rem % 3600) / 60}]

            set countdown_str "1Only4 $days days1,7 $hours hours1, and6 $mins minutes101 until Christmas Day 2026! "
        }

        # Combine your static prefix with the countdown string
        set new_topic "${topic_prefix}${countdown_str}"

        # Loop through configured channels and update if the bot is on them
        foreach chan [split $channels] {
            if {[validchan $chan] && [botisop $chan]} {
                puthelp "TOPIC $chan :$new_topic"
            }
        }
    }
}

putlog "Loaded: Christmas 2026 Countdown Topic Script (Every 2 Hours)"
