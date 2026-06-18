#####################################################################################
#                      ____  ____  _     ____  _     ____ 	                        #
#                     /  _ \/ ___\/ \   /  __\/ \   / ___\	                        #
#                     | / \||    \| |   |  \/|| |   |    \	                        #
#                     | |-||\___ || |_/\|  __/| |_/\\___ |	                        #
#                     \_/ \|\____/\____/\_/   \____/\____/	                        #
#                       asl_pls / irc.underx.org #aslpls    	                    #
##################################################################################### 
#                                                                                   # 
#         guess_multiround.tcl by asl_pls @ irc.underx.org #aslpls                  # 
#         Robust Multi-round guessing game with flawless file saving.               #
#         Usage: !startguess [rounds] | !guess <number> | !top                      #
#                                                                                   # 
##################################################################################### 

namespace eval ::GuessGamePro {
    # --- Configuration ---
    variable min 1
    variable max 100
    variable time_limit 60; # Time limit per round (seconds)
    variable default_rounds 5; # Default number of rounds per game
    variable datafile "data/guess.dat"

    # --- Game State Variables ---
    variable secret_number 0
    variable game_active 0
    variable turn_count 0
    variable timer_id ""
    
    # Match tracking
    variable current_round 0
    variable total_rounds 0
    variable current_chan ""
    variable round_scores; # Array to track points scored *this game*

    # --- All-Time Leaderboard ---
    # Instantiated as a clean, serializable Tcl dictionary
    variable leaderboard [dict create]

    # Bindings
    bind pub - !guess [namespace current]::play_guess
    bind pub - !startguess [namespace current]::start_game
    bind pub - !top [namespace current]::show_leaderboard

    # Start a multi-round game
    proc start_game {nick uhost hand chan arg} {
        variable game_active
        variable default_rounds
        variable total_rounds
        variable current_round
        variable current_chan
        variable round_scores

        if {$game_active} {
            putquick "PRIVMSG $chan :A game is already in progress! Use [color_text 6 "!guess <number>"] to play."
            return
        }

        # Determine number of rounds
        set num [string trim $arg]
        if {[string is integer -strict $num] && $num > 0} {
            set total_rounds $num
        } else {
            set total_rounds $default_rounds
        }

        # Initialize game/match state
        set game_active 1
        set current_round 1
        set current_chan $chan
        if {[info exists round_scores]} { unset round_scores }
        array set round_scores [list]

        putquick "PRIVMSG $chan :[color_text 3 "=== Starting a $total_rounds-Round Guessing Match! ==="]"
        launch_round
    }

    # Internal helper to set up a new round
    proc launch_round {} {
        variable min
        variable max
        variable secret_number
        variable turn_count
        variable time_limit
        variable timer_id
        variable current_round
        variable total_rounds
        variable current_chan

        set secret_number [expr {int(rand() * ($max - $min + 1)) + $min}]
        set turn_count 0

        putquick "PRIVMSG $current_chan :[color_text 12 "Round $current_round of $total_rounds:"] I'm thinking of a number between $min and $max. You have **$time_limit seconds**!"
        set timer_id [utimer $time_limit [list [namespace current]::game_timeout]]
    }

    # Handle guesses
    proc play_guess {nick uhost hand chan arg} {
        variable secret_number
        variable game_active
        variable turn_count
        variable timer_id
        variable round_scores
        variable current_chan

        if {!$game_active || ![string equal -nocase $chan $current_chan]} { return }

        set guess [string trim $arg]
        if {![string is integer -strict $guess]} {
            putquick "PRIVMSG $chan :$nick, please enter a valid number."
            return
        }

        incr turn_count

        if {$guess < $secret_number} {
            putquick "PRIVMSG $chan :$nick: **Too LOW!** (Turn: $turn_count)"
        } elseif {$guess > $secret_number} {
            putquick "PRIVMSG $chan :$nick: **Too HIGH!** (Turn: $turn_count)"
        } else {
            # Won the round!
            killutimer $timer_id
            putquick "PRIVMSG $chan :[color_text 9 "CORRECT!"] $nick got it in **$turn_count** tries. The number was $secret_number."
            
            # Award 1 point for winning the round
            if {[info exists round_scores($nick)]} {
                incr round_scores($nick)
            } else {
                set round_scores($nick) 1
            }

            end_round
        }
    }

    # Handle round timeout
    proc game_timeout {} {
        variable secret_number
        variable current_chan

        putquick "PRIVMSG $current_chan :[color_text 5 "TIME'S UP!"] Nobody got it. The number was **$secret_number**."
        end_round
    }

    # Progress or end the match
    proc end_round {} {
        variable current_round
        variable total_rounds
        variable game_active
        variable current_chan
        variable round_scores

        if {$current_round < $total_rounds} {
            incr current_round
            utimer 3 [list [namespace current]::launch_round]
        } else {
            set game_active 0
            putquick "PRIVMSG $current_chan :[color_text 4 "=== Match Finished! ==="]"
            
            if {[array size round_scores] == 0} {
                putquick "PRIVMSG $current_chan :Nobody won any rounds this match. No points awarded!"
                return
            }

            # Build a structured key-value list for sorting match results safely
            set sort_list [list]
            foreach {player points} [array get round_scores] {
                lappend sort_list [list $player $points]
            }
            
            set sorted_players [lsort -integer -decreasing -index 1 $sort_list]
            set winner_data [lindex $sorted_players 0]
            set winner_nick [lindex $winner_data 0]
            set winner_points [lindex $winner_data 1]

            putquick "PRIVMSG $current_chan :[color_text 9 "Match Winner:"] **$winner_nick** with **$winner_points** round win(s)!"
            
            # Update and save the all-time leaderboard statistics
            update_leaderboard $winner_nick
        }
    }

    # Update all-time leaderboard using native dict utilities
    proc update_leaderboard {nick} {
        variable leaderboard
        
        # Lowercase check to merge variations like Nick and nick seamlessly
        set lookup_nick [string tolower $nick]

        # Use dict incr to handle calculation safely without looping lists manually
        if {[dict exists $leaderboard $lookup_nick]} {
            dict incr leaderboard $lookup_nick 1
        } else {
            dict set leaderboard $lookup_nick 1
        }

        # Save to disk immediately after updating the structural value
        save_stats
    }

    # Show Top 5 Leaderboard
    proc show_leaderboard {nick uhost hand chan arg} {
        variable leaderboard
        
        if {[dict size $leaderboard] == 0} {
            putquick "PRIVMSG $chan :The all-time leaderboard is empty. Start a game with !startguess!"
            return
        }

        putquick "PRIVMSG $chan :[color_text 4 "=== Top 5 Guessing Game Champions ==="]"
        
        # Convert dictionary to a structural sorting array layout cleanly
        set sort_list [list]
        dict for {name wins} $leaderboard {
            lappend sort_list [list $name $wins]
        }
        
        # Sort by total historical match wins
        set sorted_leaderboard [lsort -integer -decreasing -index 1 $sort_list]

        set rank 1
        foreach entry $sorted_leaderboard {
            set name [lindex $entry 0]
            set wins [lindex $entry 1]
            putquick "PRIVMSG $chan :$rank. **$name** - $wins Match Win(s)"
            incr rank
            if {$rank > 5} { break }; # Enforce Top 5 ceiling dynamically
        }
    }

    # Save stats to file
    proc save_stats {} {
        variable datafile
        variable leaderboard

        # Automatically check and build target folder if it's missing on the file system
        set dir [file dirname $datafile]
        if {![file exists $dir]} {
            catch {file mkdir $dir}
        }

        if {[catch {open $datafile w} fp]} {
            putlog "GuessGame Error: Could not open $datafile for writing: $fp"
            return
        }
        
        # Write clean flat dictionary format to the file system
        puts $fp $leaderboard
        close $fp
        putlog "GuessGame: Leaderboard successfully saved to $datafile"
    }

    # Load stats from file
    proc load_stats {} {
        variable datafile
        variable leaderboard

        set dir [file dirname $datafile]
        if {![file exists $dir]} {
            catch {file mkdir $dir}
            return
        }

        if {![file exists $datafile]} { return }
        if {[catch {open $datafile r} fp]} { return }

        set data [gets $fp]
        close $fp

        # Instantiation check to avoid loading anomalies breaking memory runtime
        if {[string length [string trim $data]] > 0} {
            set leaderboard $data
            putlog "GuessGame: Loaded leaderboard from $datafile"
        }
    }

    # Initialize
    load_stats

    # Helper function for IRC mIRC colors
    proc color_text {color text} {
        return "\003$color$text\003"
    }
}

putlog "Multi-round Guessing Game with Top 5 by asl_pls @ irc.underx.org Loaded Successfully!"
