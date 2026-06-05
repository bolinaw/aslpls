###############################################################################
# christmas-countdown.tcl by asl_pls @ irc.underx.org #aslpls
# Christmas 2026 Countdown Auto-Topic Script for Eggdrop
# Updates the channel topic every 2 hours with the remaining time and a random topic.
###############################################################################

namespace eval ::XmasCountdown {
    # ------------ CONFIGURATION ------------
    
    # Target channels (space-separated, e.g., "#lobby #lounge")
    variable channels "#aslpls"
    
    # The base topic prefix. The countdown will be appended to this.
    variable topic_prefix "Welcome! | "
    
    # ------------ END OF CONFIGURATION ------------

    # Bind a time timer to run every 2 hours (at 00 mins past the hour)
    # Eggdrop 'time' binds use the format "minute hour day month weekday"
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
            set countdown_str "🎄 Merry Christmas 2026! 🎄"
        } else {
            # Calculate days, hours, and minutes
            set days [expr {$diff / 86400}]
            set rem [expr {$diff % 86400}]
            set hours [expr {$rem / 3600}]
            set mins [expr {($rem % 3600) / 60}]

            set countdown_str "🎄 Only $days days, $hours hours, and $mins minutes until Christmas 2026! 🎄"
        }

        # ---------------------------------------------------------------------
        # 3 RANDOM TOPICS POOL
        # ---------------------------------------------------------------------
        # You can easily edit the text inside these quotes to whatever you like!
        set random_topics [list \
            "[Global News] Scientists finally prove that looking at internet cats increases productivity by 42%." \
            "[Topic of the Day] If tomatoes are a fruit, then technically ketchup is a smoothie. Discuss." \
            "[Did You Know?] The first IRC network was created in 1988, making it older than World Wide Web websites!" \
        ]

        # Pick one of the 3 topics at random
        set random_pick [lindex $random_topics [expr {int(rand() * [llength $random_topics])}]]

        # Combine your static prefix, the countdown, and the selected random topic
        set new_topic "${topic_prefix}${countdown_str} | Current Buzz: ${random_pick}"

        # Loop through configured channels and update if the bot is on them
        foreach chan [split $channels] {
            if {[validchan $chan] && [botisop $chan]} {
                puthelp "TOPIC $chan :$new_topic"
            }
        }
    }
}

putlog "Loaded: Christmas 2026 Countdown Topic Script with 3 Random Topics (Every 2 Hours)"
