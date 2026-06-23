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
# 	EggBigtwo_beta.tcl - A simplified Big Two IRC game script for Eggdrop				
# 																					
#	Commands: 																			
#
#		!bigtwo (start/join), !cards (check hand), !play <cards>, !pass, !stoptwo	
#																					
#	How to play: https://www.youtube.com/watch?v=U28DKiVQpVM						
#																								
############################################################################################

namespace eval ::BigTwo {
    # Game Configuration
    variable channel "#aslpls"  ;# Change to your target channel
    variable min_players 3
    
    # Game State Variables
    variable players [list]
    variable hands; array set hands {}
    variable game_active 0
    variable current_turn 0
    variable last_play ""
    variable last_play_by ""
    variable pass_count 0

    # Card definitions (Rank: 3=0 .. 2=12, Suit: D=0, C=1, H=2, S=3)
    variable suits [list "♦" "♣" "♥" "♠"]
    variable ranks [list "3" "4" "5" "6" "7" "8" "9" "10" "J" "Q" "K" "A" "2"]

    # Bind IRC commands
    bind pub - !bigtwo ::BigTwo::cmd_bigtwo
    bind pub - !play ::BigTwo::cmd_play
    bind pub - !pass ::BigTwo::cmd_pass
    bind pub - !stoptwo ::BigTwo::cmd_stop
    bind pub - !cards ::BigTwo::cmd_cards

    proc msg {text} {
        variable channel
        putquick "PRIVMSG $channel :$text"
    }

    proc pmsg {nick text} {
        putquick "PRIVMSG $nick :$text"
    }

    # Start or Join a game
    proc cmd_bigtwo {nick uhost hand chan arg} {
        variable channel; variable game_active; variable players; variable min_players
        if {[string tolower $chan] != [string tolower $channel]} return
        
        if {$game_active == 2} {
            pmsg $nick "A game is already in progress."
            return
        }

        if {[lsearch -exact $players $nick] != -1} {
            pmsg $nick "You are already in the game."
            return
        }

        if {[llength $players] >= $min_players} {
            pmsg $nick "The game is full!"
            return
        }

        lappend players $nick
        set needed [expr {$min_players - [llength $players]}]
        
        if {$needed > 0} {
            msg "$nick joined Big Two! Need $needed more player(s) to start. Type !bigtwo to join."
            set game_active 1
        } else {
            msg "$nick joined! We have 4 players. Dealing the deck..."
            start_game
        }
    }

    # Initialize deck, shuffle, and deal
    proc start_game {} {
        variable players; variable hands; variable game_active; variable current_turn
        variable ranks; variable suits
        
        set game_active 2
        set deck [list]
        
        # Build deck of 52 integers (0-51)
        # card_id = (rank_index * 4) + suit_index
        for {set r 0} {$r < 13} {incr r} {
            for {set s 0} {$s < 4} {incr s} {
                lappend deck [expr {($r * 4) + $s}]
            }
        }

        # Fisher-Yates Shuffle
        set n [llength $deck]
        while {$n > 1} {
            set j [expr {int(rand()*$n)}]
            incr n -1
            set temp [lindex $deck $n]
            lset deck $n [lindex $deck $j]
            lset deck $j $temp
        }

        # Deal 13 cards to each player
        set p_idx 0
        foreach player $players {
            set p_hand [lsort -integer [lrange $deck [expr {$p_idx * 13}] [expr {($p_idx * 13) + 12}]]]
            set hands($player) $p_hand
            pmsg $player "Your Hand: [show_hand $p_hand]"
            incr p_idx
        }

        # Find who has the 3 of Diamonds (ID: 0) to start
        set current_turn 0
        for {set i 0} {$i < 4} {incr i} {
            if {[lindex $hands([lindex $players $i]) 0] == 0} {
                set current_turn $i
                break
            }
        }

        msg "The game has begun! [lindex $players $current_turn] has the 3 of Diamonds and goes first."
    }

    # Helper to convert card IDs to readable text
    proc show_hand {card_list} {
        variable ranks; variable suits
        set out [list]
        foreach card $card_list {
            set r_idx [expr {$card / 4}]
            set s_idx [expr {$card % 4}]
            lappend out "[lindex $ranks $r_idx][lindex $suits $s_idx]"
        }
        return [join $out " "]
    }

    # Command to privately re-check hand
    proc cmd_cards {nick uhost hand chan arg} {
        variable hands; variable game_active
        if {$game_active != 2} return
        if {[info exists hands($nick)]} {
            pmsg $nick "Your Hand: [show_hand $hands($nick)]"
        }
    }

    # Handle a player attempting to play cards
    proc cmd_play {nick uhost hand chan arg} {
        variable game_active; variable players; variable current_turn; variable hands
        variable last_play; variable last_play_by; variable pass_count

        if {$game_active != 2} return
        if {$nick != [lindex $players $current_turn]} {
            pmsg $nick "It is not your turn!"
            return
        }

        if {$arg == ""} {
            pmsg $nick "Usage: !play <cards> (e.g., !play 3D or !play 5H 5S)"
            return
        }

        # --- ARCHITECTURAL NOTE ---
        # Real-world parser validation goes here:
        # 1. Translate string input (like "3D") back to Card IDs.
        # 2. Check if player actually owns those card IDs in $hands($nick).
        # 3. Validate hand composition (Single, Pair, Triple, 5-card groups).
        # 4. Compare strength against $last_play (unless $pass_count == 3 or $last_play_by == $nick).

        # Temporary basic simulation placeholder logic:
        msg "$nick plays: $arg"
        
        # Advance turn
        set pass_count 0
        set last_play $arg
        set last_play_by $nick
        
        next_turn
    }

    # Handle a pass
    proc cmd_pass {nick uhost hand chan arg} {
        variable game_active; variable players; variable current_turn; variable pass_count; variable last_play

        if {$game_active != 2} return
        if {$nick != [lindex $players $current_turn]} return

        if {$last_play == ""} {
            pmsg $nick "You cannot pass; you must open the round!"
            return
        }

        incr pass_count
        msg "$nick passes."

        if {$pass_count == 3} {
            msg "Everyone passed! The field is cleared. $last_play_by gets to open a new round."
            set last_play ""
        }

        next_turn
    }

    # Cycle to the next player
    proc next_turn {} {
        variable current_turn; variable players
        set current_turn [expr {($current_turn + 1) % 4}]
        msg "It is now [lindex $players $current_turn]'s turn."
    }

    # Force reset/stop game
    proc cmd_stop {nick uhost hand chan arg} {
        variable game_active; variable players; variable hands
        if {$game_active == 0} return
        set game_active 0
        set players [list]
        array unset hands
        msg "The Big Two game has been stopped and reset."
    }
}

putlog "EggBigtwo_beta.tcl Big Two IRC Script Loaded successfully."
