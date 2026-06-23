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
# 				EggSlots.tcl - A simple IRC Slots Game for Eggdrop						
# 				 Triggers: !slots <bet>, !points, !daily, !top						
#																					
###########################################################################################

namespace eval ::Slots {
    # --- Configuration ---
    variable target_channel "#aslpls"               ;# The ONLY channel where this game can be played
    variable score_file "scripts/slots_scores.dat"  ;# Where to save user points
    variable starting_points 500                    ;# Points given to new players
    variable daily_bonus 250                        ;# Points awarded by !daily
    variable min_bet 10                             ;# Minimum bet allowed
    variable max_bet 500                            ;# Maximum bet allowed
    variable top_limit 5                            ;# Number of players to show in !top

    # Symbol emojis/text and their payout multipliers
    variable symbols [list "🍒" "🍋" "🍊" "🍇" "🔔" "💎"]
    variable multipliers [dict create "🍒" 3 "🍋" 5 "🍊" 8 "🍇" 12 "🔔" 20 "💎" 50]

    # --- Binds ---
    bind pub - !bet [namespace current]::play_slots
    bind pub - !points [namespace current]::check_points
    bind pub - !daily [namespace current]::claim_daily
    bind pub - !top [namespace current]::show_top

    # --- Data Management ---
    variable scores [dict create]
    variable dailies [dict create]

    # Load scores on script startup
    proc init {} {
        variable score_file
        variable scores
        if {[file exists $score_file]} {
            set fp [open $score_file r]
            set scores [read $fp]
            close $fp
        }
    }

    # Save scores to file
    proc save_scores {} {
        variable score_file
        variable scores
        set fp [open $score_file w]
        puts -nonewline $fp $scores
        close $fp
    }

    # Helper to get or initialize a user's balance
    proc get_balance {nick} {
        variable scores
        variable starting_points
        set nick [string tolower $nick]
        if {![dict exists $scores $nick]} {
            dict set scores $nick $starting_points
            save_scores
        }
        return [dict get $scores $nick]
    }

    # Helper to update user balance
    proc update_balance {nick amount} {
        variable scores
        set nick [string tolower $nick]
        set current [get_balance $nick]
        dict set scores $nick [expr {$current + $amount}]
        save_scores
    }

    # --- Core Commands ---

    # !slots <bet>
    proc play_slots {nick uhost hand chan arg} {
        variable target_channel
        variable symbols
        variable multipliers
        variable min_bet
        variable max_bet

        if {[string tolower $chan] ne [string tolower $target_channel]} { return 0 }

        set bet [string trim [lindex [split $arg] 0]]
        
        if {$bet eq "" || ![string is integer -strict $bet]} {
            putquick "PRIVMSG $chan :\00304\[SLOTS\]\003 Usage: !slots <bet_amount>"
            return
        }

        if {$bet < $min_bet || $bet > $max_bet} {
            putquick "PRIVMSG $chan :\00304\[SLOTS\]\003 Bets must be between $min_bet and $max_bet points."
            return
        }

        set balance [get_balance $nick]
        if {$bet > $balance} {
            putquick "PRIVMSG $chan :\00304\[SLOTS\]\003 You don't have enough points! Your balance: $balance. Try \002!daily\002."
            return
        }

        # Spin the reels
        set r1 [lindex $symbols [expr {int(rand()*[llength $symbols])}]]
        set r2 [lindex $symbols [expr {int(rand()*[llength $symbols])}]]
        set r3 [lindex $symbols [expr {int(rand()*[llength $symbols])}]]

        putquick "PRIVMSG $chan :\00306\[SLOTS\]\003 \002$nick\002 pulls the lever... \[ $r1 | $r2 | $r3 \]"

        # Check winnings
        if {$r1 eq $r2 && $r2 eq $r3} {
            set mult [dict get $multipliers $r1]
            set winnings [expr {$bet * $mult}]
            update_balance $nick $winnings
            putquick "PRIVMSG $chan :\00309\[WIN\]\003 \002$nick\002 hit the JACKPOT! 3x $r1! Won \002$winnings\002 points! New balance: [get_balance $nick]"
        } elseif {$r1 eq $r2 || $r2 eq $r3 || $r1 eq $r3} {
            set winnings [expr {int($bet * 1.5)}]
            update_balance $nick $winnings
            putquick "PRIVMSG $chan :\00303\[WIN\]\003 Two of a kind! \002$nick\002 won \002$winnings\002 points. New balance: [get_balance $nick]"
        } else {
            update_balance $nick -$bet
            putquick "PRIVMSG $chan :\00304\[LOSE\]\003 Aw, no match for \002$nick\002. Lost \002$bet\002 points. Remaining balance: [get_balance $nick]"
        }
    }

    # !points
    proc check_points {nick uhost hand chan arg} {
        variable target_channel
        if {[string tolower $chan] ne [string tolower $target_channel]} { return 0 }

        set target $nick
        set input [string trim [lindex [split $arg] 0]]
        if {$input ne ""} { set target $input }
        
        set balance [get_balance $target]
        putquick "PRIVMSG $chan :\[CASINO\] \002$target\002 currently has \002$balance\002 points."
    }

    # !daily
    proc claim_daily {nick uhost hand chan arg} {
        variable target_channel
        variable dailies
        variable daily_bonus

        if {[string tolower $chan] ne [string tolower $target_channel]} { return 0 }

        set user_id [string tolower $nick]
        set now [clock seconds]

        if {[dict exists $dailies $user_id]} {
            set last_claim [dict get $dailies $user_id]
            if {[expr {$now - $last_claim}] < 86400} {
                set remaining [expr {86400 - ($now - $last_claim)}]
                set hours [expr {$remaining / 3600}]
                set mins [expr {($remaining % 3600) / 60}]
                putquick "PRIVMSG $chan :\00304\[DAILY\]\003 \002$nick\002, you've already claimed your daily bonus. Come back in ${hours}h ${mins}m."
                return
            }
        }

        dict set dailies $user_id $now
        update_balance $nick $daily_bonus
        putquick "PRIVMSG $chan :\00309\[DAILY\]\003 \002$nick\002 claimed their daily bonus of \00309$daily_bonus\003 points! Total: [get_balance $nick]"
    }

    # !top
    proc show_top {nick uhost hand chan arg} {
        variable target_channel
        variable scores
        variable top_limit

        if {[string tolower $chan] ne [string tolower $target_channel]} { return 0 }

        if {[dict size $scores] == 0} {
            putquick "PRIVMSG $chan :\[CASINO\] No high scores recorded yet."
            return
        }

        # Convert dictionary to a sortable list structure
        set score_list [list]
        dict for {player points} $scores {
            lappend score_list [list $player $points]
        }

        # Sort descending based on index 1 (the points)
        set sorted [lsort -integer -decreasing -index 1 $score_list]

        # Build the horizontal string
        set output_items [list]
        set rank 1
        foreach entry [lrange $sorted 0 [expr {$top_limit - 1}]] {
            set p_name [string totitle [lindex $entry 0]]
            set p_score [lindex $entry 1]
            
            lappend output_items "\002#$rank\002 $p_name ($p_score)"
            incr rank
        }

        # Join the players with a clean middle-dot separator
        set leaderboard_line [join $output_items " \00315•\003 "]

        # Send the final horizontal line to the channel
        putquick "PRIVMSG $chan :\00311,01 -= CASINO LEADERBOARD =- \003 $leaderboard_line"
    }

    # Run the initializer
    init
}

putlog "Loaded Slots Casino Script v1.0 by asl_pls @ irc.underx.org"
