#####################################################################################
#                      ____  ____  _     ____  _     ____ 	                        #
#                     /  _ \/ ___\/ \   /  __\/ \   / ___\	                        #
#                     | / \||    \| |   |  \/|| |   |    \	                        #
#                     | |-||\___ || |_/\|  __/| |_/\\___ |	                        #
#                     \_/ \|\____/\____/\_/   \____/\____/	                        #
#                       asl_pls / irc.underx.org #aslpls    	                    #
#																					#				
#####################################################################################
#																					#
# 				ers.tcl - Egyptian Ratscrew for Eggdrop IRC Bots					#	
#																					#
# 	Commands: !ers join, !ers start, !play (or !p), !slap (or !s), !ers stop		#
#																					#			
#	How to play: https://www.youtube.com/watch?v=Ny-WfBjaiSo						#
#																					#					
#####################################################################################

namespace eval ::ERS {
    variable channel "#aslpls"   ;# Change this to your preferred channel
    variable players [list]
    variable turn 0
    variable deck [list]
    variable pile [list]
    variable active 0
    variable joined 0
    variable target_player ""
    variable chances 0
    variable last_face ""

    bind pub - !ers  ::ERS::cmd_ers
    bind pub - !play ::ERS::play_card
    bind pub - !p    ::ERS::play_card
    bind pub - !slap ::ERS::slap_pile
    bind pub - !s    ::ERS::slap_pile

    proc cmd_ers {nick uhost hand chan arg} {
        variable channel
        if {[string tolower $chan] != [string tolower $channel]} { return }
        set sub [string tolower [lindex [split $arg] 0]]
        
        switch $sub {
            "join" { ::ERS::player_join $nick }
            "start" { ::ERS::game_start }
            "stop" { ::ERS::game_reset "Game stopped by $nick." }
            default { putquick "PRIVMSG $channel :Usage: !ers join | !ers start | !ers stop" }
        }
    }

    proc game_reset {msg} {
        variable players; variable deck; variable pile; variable active; variable joined
        variable turn; variable target_player; variable chances; variable channel
        set players [list]; set deck [list]; set pile [list]
        set active 0; set joined 0; set turn 0; set target_player ""; set chances 0
        if {$msg != ""} { putquick "PRIVMSG $channel :$msg" }
    }

    proc player_join {nick} {
        variable active; variable joined; variable players; variable channel
        if {$active} { putquick "PRIVMSG $channel :$nick: A game is already in progress."; return }
        if {[lsearch -exact $players $nick] != -1} { putquick "PRIVMSG $channel :$nick: You are already joined."; return }
        if {[llength $players] >= 6} { putquick "PRIVMSG $channel :$nick: Game is full (max 6 players)."; return }
        
        lappend players $nick
        set joined 1
        putquick "PRIVMSG $channel :$nick joined the game! ([llength $players]/6 players) Type !ers start when ready."
    }

    proc init_deck {} {
        set suits [list "H" "D" "C" "S"]
        set values [list "2" "3" "4" "5" "6" "7" "8" "9" "10" "J" "Q" "K" "A"]
        set d [list]
        foreach s $suits {
            foreach v $values { lappend d "$v$s" }
        }
        # Shuffle deck
        set shuffled [list]
        while {[llength $d] > 0} {
            set idx [expr {int(rand()*[llength $d])}]
            lappend shuffled [lindex $d $idx]
            set d [lreplace $d $idx $idx]
        }
        return $shuffled
    }

    proc game_start {} {
        variable active; variable joined; variable players; variable channel; variable deck; variable turn
        if {$active} return
        if {[llength $players] < 2} { putquick "PRIVMSG $channel :Need at least 2 players to start."; return }
        
        set active 1
        set full_deck [init_deck]
        
        # Deal cards evenly into global arrays named by player nick
        foreach p $players { global ::ERS::hand_$p; set ::ERS::hand_$p [list] }
        set i 0
        foreach card $full_deck {
            set p [lindex $players [expr {$i % [llength $players]}]]
            global ::ERS::hand_$p
            lappend ::ERS::hand_$p $card
            incr i
        }
        
        set turn 0
        set current [lindex $players $turn]
        putquick "PRIVMSG $channel :The deck is dealt! **Egyptian Ratscrew Begin!**"
        putquick "PRIVMSG $channel :It is $current's turn. Type !play (or !p)"
    }

    proc play_card {nick uhost hand chan arg} {
        variable active; variable players; variable turn; variable channel; variable pile
        variable target_player; variable chances; variable last_face
        if {!$active} return
        if {[string tolower $chan] != [string tolower $channel]} return
        
        if {$target_player != ""} {
            if {$nick != $target_player} { return }
        } else {
            if {$nick != [lindex $players $turn]} { return }
        }

        global ::ERS::hand_$nick
        if {[llength [set ::ERS::hand_$nick]] == 0} {
            putquick "PRIVMSG $channel :$nick has no cards remaining! Skipping turn."
            next_turn
            return
        }

        # Play top card
        set card [lindex [set ::ERS::hand_$nick] 0]
        set ::ERS::hand_$nick [lreplace [set ::ERS::hand_$nick] 0 0]
        lappend pile $card
        
        set val [string range $card 0 end-1]
        putquick "PRIVMSG $channel :\[$nick\] plays: **$card**  (Pile total: [llength $pile])"

        # Check face card rules
        if {[lsearch {J Q K A} $val] != -1} {
            set last_face $nick
            set target_player [get_next_player $nick]
            switch $val {
                "J" { set chances 1 }
                "Q" { set chances 2 }
                "K" { set chances 3 }
                "A" { set chances 4 }
            }
            putquick "PRIVMSG $channel :Face card! $target_player has $chances chance(s) to play a Face card/Ace."
            return
        }

        # Handling defensive turns if a Face card is outstanding
        if {$target_player != ""} {
            incr chances -1
            if {$chances <= 0} {
                # target failed to defend, last_face wins the pile
                global ::ERS::hand_$last_face
                set ::ERS::hand_$last_face [concat [set ::ERS::hand_$last_face] $pile]
                putquick "PRIVMSG $channel :$target_player failed to defend! $last_face scoops the pile ([llength $pile] cards)."
                set pile [list]
                set target_player ""
                # Turn goes to the pile winner
                set turn [lsearch -exact $players $last_face]
                check_win_condition
                if {$active} { putquick "PRIVMSG $channel :It is now $last_face's turn." }
                return
            } else {
                putquick "PRIVMSG $channel :$target_player has $chances chance(s) left."
                return
            }
        }

        next_turn
    }

    proc get_next_player {current} {
        variable players
        set idx [lsearch -exact $players $current]
        while {1} {
            set idx [expr {($idx + 1) % [llength $players]}]
            set next [lindex $players $idx]
            global ::ERS::hand_$next
            if {[llength [set ::ERS::hand_$next]] > 0} { return $next }
        }
    }

    proc next_turn {} {
        variable players; variable turn; variable channel; variable active
        check_win_condition
        if {!$active} return
        
        while {1} {
            set turn [expr {($turn + 1) % [llength $players]}]
            set current [lindex $players $turn]
            global ::ERS::hand_$current
            if {[llength [set ::ERS::hand_$current]] > 0} { break }
        }
        putquick "PRIVMSG $channel :It is $current's turn. Type !play"
    }

    proc slap_pile {nick uhost hand chan arg} {
        variable active; variable pile; variable channel; variable players; variable target_player
        if {!$active || [llength $pile] < 2} return
        if {[string tolower $chan] != [string tolower $channel]} return
        
        # Verify slapper is a valid player
        if {[lsearch -exact $players $nick] == -1} return

        set len [llength $pile]
        set top [lindex $pile end]
        set top_val [string range $top 0 end-1]
        
        set prev [lindex $pile [expr {$len - 2}]]
        set prev_val [string range $prev 0 end-1]
        
        set valid 0
        set type ""

        # Rule 1: Double
        if {$top_val == $prev_val} {
            set valid 1
            set type "DOUBLE ($top_val's)"
        }

        # Rule 2: Sandwich
        if {!$valid && $len >= 3} {
            set sand [lindex $pile [expr {$len - 3}]]
            set sand_val [string range $sand 0 end-1]
            if {$top_val == $sand_val} {
                set valid 1
                set type "SANDWICH ($top_val over $prev_val)"
            }
        }

        if {$valid} {
            global ::ERS::hand_$nick
            set ::ERS::hand_$nick [concat [set ::ERS::hand_$nick] $pile]
            putquick "PRIVMSG $channel :   **SLAP!** $nick correctly slapped a $type and wins the pile ([llength $pile] cards)!"
            set pile [list]
            set target_player ""
            set variable turn [lsearch -exact $players $nick]
            check_win_condition
            if {$active} { putquick "PRIVMSG $channel :It is now $nick's turn." }
        } else {
            # Slap burn penalty (bottom of the pile gets one of their cards)
            global ::ERS::hand_$nick
            if {[llength [set ::ERS::hand_$nick]] > 0} {
                set burn [lindex [set ::ERS::hand_$nick] 0]
                set ::ERS::hand_$nick [lreplace [set ::ERS::hand_$nick] 0 0]
                set pile [insert_at_bottom $pile $burn]
                putquick "PRIVMSG $channel :❌ Bad slap, $nick! You burn a card ($burn) to the bottom of the pile."
            }
        }
    }

    proc insert_at_bottom {lst item} {
        return [concat [list $item] $lst]
    }

    proc check_win_condition {} {
        variable players; variable active; variable channel
        set alive [list]
        foreach p $players {
            global ::ERS::hand_$p
            if {[llength [set ::ERS::hand_$p]] > 0} { lappend alive $p }
        }
        
        if {[llength $alive] == 1} {
            set winner [lindex $alive 0]
            putquick "PRIVMSG $channel :   **GAME OVER!** $winner has gathered all the cards and won Egyptian Ratscrew! "
            game_reset ""
        }
    }
}
putlog "Egyptian Ratscrew Script v1.0 Loaded."
