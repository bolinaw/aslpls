###############################################################################
# Eggdrop Top 5 Channel Stats Timer Script by asl_pls @ irc.underx.org #aslpls
# Tracks lines said by users and announces the Top 5 every 1 hour.
# Commands:
#   !top5          - Manually view the top 5 stats (Public)
#   !resetstats    - Resets all tracked stats (Requires Global Master 'm')
###############################################################################

namespace eval ::ChanStats {
    # -------------------------------------------------------------------------
    # CONFIGURATION
    # -------------------------------------------------------------------------
    
    # CHANGE THIS: The specific channel you want to track and announce in.
    variable target_chan "#aslpls"
    
    # Filename where statistics will be saved so they survive bot restarts
    variable stats_file "data/chanstats.dat"
    
    # -------------------------------------------------------------------------
    # SCRIPT LOGIC
    # -------------------------------------------------------------------------
    variable user_lines
    array set user_lines {}

    bind pub - !top5 [namespace current]::pub_showtop5
    bind pub m !resetstats [namespace current]::pub_resetstats
    bind pubm - * [namespace current]::track_line

    # Track lines said by users
    proc track_line {nick uhost hand chan text} {
        variable target_chan
        variable user_lines
        
        # Only track lines in our target channel
        if {[string tolower $chan] ne [string tolower $target_chan]} { return 0 }
        
        # Ignore bots, Undernet services, or users with bot flags
        if {[string match -nocase "X" $nick] || [isbotnick $nick] || [matchattr $hand b]} { 
            return 0 
        }

        set nick [string tolower $nick]
        
        # Optimized tracking logic
        incr user_lines($nick)
        return 0
    }

    # Generate and display the Top 5 list in a horizontal line
    proc display_stats {} {
        variable target_chan
        variable user_lines
        
        if {![validchan $target_chan]} {
            return 0
        }

        set raw_data [array get user_lines]
        if {[llength $raw_data] == 0} {
            putquick "PRIVMSG $target_chan :\002Channel Stats:\002 No lines recorded yet!"
            return 0
        }

        # FIXED: Using -stride 2 to treat pairs correctly, sorting by index 1 (the count)
        set sorted_list [lsort -stride 2 -index 1 -integer -decreasing $raw_data]

        set rank 1
        set horizontal_output [list]
        
        foreach {user lines} $sorted_list {
            # Build each rank item nicely
            lappend horizontal_output "#$rank \002$user\002 ($lines)"
            incr rank
            if {$rank > 5} { break }
        }
        
        # Join the list elements horizontally separated by a stylish divider
        set output_string [join $horizontal_output " \00314|\003 "]

        # Send the finalized single line output to IRC
        putquick "PRIVMSG $target_chan : ▂ ▃ ▅ ▆ ▇ \002Top 5 Chatters:\002 $output_string  ▇ ▆ ▅ ▃ ▂ "
        
        # Save stats to file
        save_stats
        return 1
    }

    # Public command trigger for !top5
    proc pub_showtop5 {nick uhost hand chan arg} {
        variable target_chan
        if {[string tolower $chan] eq [string tolower $target_chan]} {
            display_stats
        }
        return 1
    }

    # Public command trigger to reset statistics
    proc pub_resetstats {nick uhost hand chan arg} {
        variable user_lines
        variable target_chan
        array unset user_lines
        array set user_lines {}
        save_stats
        putquick "PRIVMSG $chan :\002Stats Reset:\002 Statistics for $target_chan have been cleared."
        return 1
    }

    # Timer function that loops every 60 minutes
    proc run_timer {} {
        display_stats
        # Reschedule the timer for 60 minutes (3600 seconds) from now
        timer 60 [namespace current]::run_timer
    }

    # Save stats array to flat file
    proc save_stats {} {
        variable stats_file
        variable user_lines
        
        # Ensure the data directory exists before trying to write
        if {![file exists "data"]} {
            catch {file mkdir "data"}
        }
        
        set file_id [open $stats_file w]
        puts $file_id [array get user_lines]
        close $file_id
    }

    # Load stats array from flat file on script startup
    proc load_stats {} {
        variable stats_file
        variable user_lines
        if {[file exists $stats_file]} {
            set file_id [open $stats_file r]
            set data [read $file_id]
            close $file_id
            if {$data ne ""} {
                array set user_lines $data
            }
        }
    }

    # Initialize Script
    load_stats
    
    # Start the 1-hour recurring timer loop if it isn't running already
    if {![string match "*run_timer*" [timers]]} {
        timer 60 [namespace current]::run_timer
    }

    putlog "Loaded: Top 5 Channel Stats Timer by asl_pls (Horizontal Output)"
}
