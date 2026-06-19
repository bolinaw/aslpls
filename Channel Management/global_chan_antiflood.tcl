# ====================================================================
# global_chan_antiflood.tcl
# A global firewall that protects the channel and bot from text floods.
# ====================================================================

namespace eval ::GlobalGuard {
    # ----------------------------------------------------------------
    # CONFIGURATION
    # ----------------------------------------------------------------
    variable flood_lines  4     ;# Number of lines allowed...
    variable flood_time   3     ;# ...within this many seconds.
    variable punishment   "kick" ;# Action to take: "notice", "kick", or "kickban"
    variable ban_time     5     ;# If kickban is chosen, ban duration in minutes

    # Storage array for tracking user hit counters
    variable flood_history
    array set flood_history {}

    # Bind to ALL public messages in the channel
    bind pubm - * [namespace current]::check_global_flood

    # ----------------------------------------------------------------
    # Main Flood Control Engine
    # ----------------------------------------------------------------
    proc check_global_flood {nick uhost hand chan text} {
        variable flood_lines
        variable flood_time
        variable punishment
        variable ban_time
        variable flood_history

        # Ignore bot owners, masters, or ops so regular administration isn't blocked
        if {[matchattr $hand n|n $chan] || [isop $nick $chan]} {
            return 0
        }

        set current_time [unixtime]
        set user_key "$chan:$uhost"

        # Initialize tracking data for new users
        if {![info exists flood_history($user_key)]} {
            set flood_history($user_key) [list $current_time 1]
            return 0
        }

        # Unpack the stored variables (First timestamp, and current strike count)
        lassign $flood_history($user_key) first_seen count

        # If the time window has expired, reset their counter
        if {[expr {$current_time - $first_seen}] > $flood_time} {
            set flood_history($user_key) [list $current_time 1]
            return 0
        }

        # Otherwise, they are talking within the window. Increment their count.
        incr count
        set flood_history($user_key) [list $first_seen $count]

        # If they haven't crossed the line yet, let them pass
        if {$count < $flood_lines} {
            return 0
        }

        # --- FLOOD TRIGGERED ---
        # Wipe their history log so they don't get caught in an infinite loop
        unset flood_history($user_key)

        switch -exact -- $punishment {
            "notice" {
                putquick "NOTICE $nick :[Stop Spamming] You are moving too fast! Please slow down."
            }
            "kick" {
                putkick $chan $nick "Please do not flood the channel. Slow down!"
            }
            "kickban" {
                set ban_mask "*!*@[lindex [split $uhost @] 1]"
                newchanban $chan $ban_mask "GlobalGuard" "Flooding/Spamming detected" $ban_time
                putkick $chan $nick "You have been banned for $ban_time minutes due to flooding."
            }
        }

        # Returning 1 tells Eggdrop the message was handled and "dropped".
        # This prevents other scripts from processing their command if they are flooding!
        return 0
    }

    # Hourly memory cleanup loop
    bind time - "05 * * * *" [namespace current]::clean_guard_array
    proc clean_guard_array {min hour day month year} {
        variable flood_history
        variable flood_time
        set now [unixtime]

        foreach {key data} [array get flood_history] {
            set first_seen [lindex $data 0]
            if {[expr {$now - $first_seen}] > $flood_time} {
                unset flood_history($key)
            }
        }
    }

    putlog "--- [GlobalGuard] Global Channel Firewall Active! ---"
}
