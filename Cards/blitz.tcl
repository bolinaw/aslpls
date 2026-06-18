#####################################################################################
#                      ____  ____  _     ____  _     ____ 	                        #
#                     /  _ \/ ___\/ \   /  __\/ \   / ___\	                        #
#                     | / \||    \| |   |  \/|| |   |    \	                        #
#                     | |-||\___ || |_/\|  __/| |_/\\___ |	                        #
#                     \_/ \|\____/\____/\_/   \____/\____/	                        #
#                       asl_pls / irc.underx.org #aslpls    	                    #
#####################################################################################
#																					#
# 	Blitz.tcl (31 / Scat) Eggdrop IRC Game Script									#
# 	Version: 1.0																	#		
# 	Description: A fully automated IRC card game for 2-12 players.					#
#              Players draw and discard to get their 3-card hand as close to 		#
#              31 points in a single suit as possible.								#
#																					#
#####################################################################################

namespace eval ::Blitz {
    # --- Configuration ---
    variable channel "#aslpls"       ;# Channel where the game can be played
    variable cmd_char "!"           ;# Command prefix

    # --- Game State Variables ---
    variable game_active 0          ;# 0 = stopped, 1 = joining, 2 = playing
    variable players [list]         ;# List of player nicks
    variable hands;                 ;# Array: hands(nick) = list of 3 cards (e.g., "H10 DA SA")
    variable scores;                ;# Array: scores(nick) = current blitz score
    variable deck [list]            ;# Current deck of cards
    variable discard_pile [list]    ;# Discard pile
    variable current_turn 0         ;# Index of the player whose turn it is
    variable player_has_drawn 0     ;# Track if current player has drawn a card this turn
    variable knocker ""             ;# Nick of the player who knocked
    variable join_timer_id ""       ;# ID for the signup countdown timer

    # --- Bindings ---
    bind pub - "${cmd_char}blitz" ::Blitz::pub_blitz
    bind pub - "${cmd_char}join"  ::Blitz::pub_join
    bind pub - "${cmd_char}hand"  ::Blitz::pub_hand
    bind pub - "${cmd_char}draw"  ::Blitz::pub_draw
    bind pub - "${cmd_char}discard" ::Blitz::pub_discard
    bind pub - "${cmd_char}knock" ::Blitz::pub_knock
    bind pub - "${cmd_char}status" ::Blitz::pub_status
    bind pub - "${cmd_char}stopblitz" ::Blitz::pub_stop

    # --- Core Deck Functions ---
    proc make_deck {} {
        variable deck
        set deck [list]
        set suits [list "H" "D" "C" "S"] ;# Hearts, Diamonds, Clubs, Spades
        set ranks [list "2" "3" "4" "5" "6" "7" "8" "9" "10" "J" "Q" "K" "A"]
        foreach s $suits {
            foreach r $ranks {
                lappend deck "$s$r"
            }
        }
        # Shuffle deck using Fisher-Yates
        set i [llength $deck]
        while {$i > 1} {
            set j [expr {int(rand()*$i)}]
            incr i -1
            if {$i != $j} {
                set tmp [lindex $deck $i]
                set deck [lreplace $deck $i $i [lindex $deck $j]]
                set deck [lreplace $deck $j $j $tmp]
            }
        }
    }

    proc card_name {card} {
        set suit [string index $card 0]
        set rank [string range $card 1 end]
        set s_name ""
        switch -- $suit {
            "H" { set s_name "\00304♥\003" }
            "D" { set s_name "\00304♦\003" }
            "C" { set s_name "\00303♣\003" }
            "S" { set s_name "\00301♠\003" }
        }
        return "$rank$s_name"
    }

    proc print_cards {cards} {
        set out [list]
        foreach c $cards { lappend out [card_name $c] }
        return [join $out ", "]
    }

    # --- Game Logic ---
    proc calc_score {hand} {
        # Group cards by suit
        set suits(H) 0; set suits(D) 0; set suits(C) 0; set suits(S) 0
        
        # Check for 3 of a kind (Special rule: 3 of a kind is worth 30.5 points)
        set r1 [string range [lindex $hand 0] 1 end]
        set r2 [string range [lindex $hand 1] 1 end]
        set r3 [string range [lindex $hand 2] 1 end]
        if {$r1 == $r2 && $r2 == $r3} {
            return 30.5
        }

        foreach card $hand {
            set s [string index $card 0]
            set r [string range $card 1 end]
            set val 0
            if {$r == "A"} { set val 11 } \
            elseif {$r == "K" || $r == "Q" || $r == "J" || $r == "10"} { set val 10 } \
            else { set val $r }
            set suits($s) [expr {$suits($s) + $val}]
        }
        
        # Return the highest single suit total
        set max 0
        foreach s [array names suits] {
            if {$suits($s) > $max} { set max $suits($s) }
        }
        return $max
    }

    # --- Public Commands ---
    proc pub_blitz {nick uhost hand chan arg} {
        variable channel; variable game_active; variable players; variable join_timer_id
        if {[string tolower $chan] != [string tolower $channel]} { return }
        if {$game_active != 0} {
            putquick "PRIVMSG $chan :A game is already active or forming!"
            return
        }
        set game_active 1
        set players [list $nick]
        putquick "PRIVMSG $chan :\00303\[BLITZ\]\003 $nick has started a game of Blitz (31)! Type \002!join\002 to play. Need 2-12 players. Game starts in 60 seconds."
        set join_timer_id [utimer 60 [list ::Blitz::start_game $chan]]
    }

    proc pub_join {nick uhost hand chan arg} {
        variable channel; variable game_active; variable players
        if {[string tolower $chan] != [string tolower $channel]} { return }
        if {$game_active != 1} { putquick "NOTICE $nick :No game is currently accepting signups."; return }
        if {[lsearch -exact $players $nick] != -1} { putquick "NOTICE $nick :You are already in the game."; return }
        if {[llength $players] >= 12} { putquick "NOTICE $nick :The game is full (max 12 players)."; return }
        
        lappend players $nick
        putquick "PRIVMSG $chan :\00303\[BLITZ\]\003 $nick joins the table! Total players: [llength $players]"
    }

    proc start_game {chan} {
        variable game_active; variable players; variable deck; variable discard_pile; variable hands; variable current_turn; variable knocker; variable player_has_drawn
        if {[llength $players] < 2} {
            putquick "PRIVMSG $chan :\00304\[BLITZ\]\003 Not enough players to start. Game cancelled."
            reset_game
            return
        }
        set game_active 2
        set knocker ""
        set player_has_drawn 0
        set current_turn 0
        
        make_deck

        # Deal 3 cards to each player
        foreach p $players {
            set hands($p) [list [lindex $deck 0] [lindex $deck 1] [lindex $deck 2]]
            set deck [lrange $deck 3 end]
            putquick "NOTICE $p :Your hand: [print_cards $hands($p)] (Score: [calc_score $hands($p)])"
        }

        # Set up Discard Pile
        set discard_pile [list [lindex $deck 0]]
        set deck [lrange $deck 1 end]

        putquick "PRIVMSG $chan :\00303\[BLITZ\]\003 The cards are dealt! Top of the discard pile is: [card_name [lindex $discard_pile end]]"
        announce_turn $chan
    }

    proc announce_turn {chan} {
        variable players; variable current_turn; variable discard_pile; variable knocker
        set p [lindex $players $current_turn]
        
        if {$p == $knocker} {
            end_game $chan
            return
        }

        set msg "\00303\[BLITZ\]\003 It's \002$p\002's turn! Discard Pile: [card_name [lindex $discard_pile end]]. Options: \002!draw deck\002, \002!draw discard\002"
        if {$knocker == ""} {
            append msg ", or \002!knock\002 if you think your hand can win."
        } else {
            append msg " (\002$knocker\002 knocked! Final round!)"
        }
        putquick "PRIVMSG $chan :$msg"
    }

    proc pub_draw {nick uhost hand chan arg} {
        variable channel; variable game_active; variable players; variable current_turn; variable deck; variable discard_pile; variable hands; variable player_has_drawn
        if {[string tolower $chan] != [string tolower $channel]} { return }
        if {$game_active != 2} { return }
        if {$nick != [lindex $players $current_turn]} { putquick "NOTICE $nick :It is not your turn."; return }
        if {$player_has_drawn} { putquick "NOTICE $nick :You already drew a card. You must discard one using !discard <card>"; return }

        set target [string tolower [lindex [split $arg] 0]]
        set drawn_card ""

        if {$target == "deck"} {
            # Check if deck empty, if so, recycle discard
            if {[llength $deck] == 0} { recycle_deck $chan }
            set drawn_card [lindex $deck 0]
            set deck [lrange $deck 1 end]
            lappend hands($nick) $drawn_card
            putquick "NOTICE $nick :You drew from the deck: [card_name $drawn_card]. Current hand: [print_cards $hands($nick)]"
            putquick "PRIVMSG $chan :\00303\[BLITZ\]\003 $nick drew a card from the deck."
        } elseif {$target == "discard"} {
            set drawn_card [lindex $discard_pile end]
            set discard_pile [lrange $discard_pile 0 end-1]
            lappend hands($nick) $drawn_card
            putquick "NOTICE $nick :You picked up the discard: [card_name $drawn_card]. Current hand: [print_cards $hands($nick)]"
            putquick "PRIVMSG $chan :\00303\[BLITZ\]\003 $nick picked up [card_name $drawn_card] from the discard pile."
        } else {
            putquick "NOTICE $nick :Invalid draw source. Use \002!draw deck\002 or \002!draw discard\002."
            return
        }

        set player_has_drawn 1
        
        # Instant Blitz rule (if a player hits exactly 31 mid-draw)
        if {[calc_score $hands($nick)] == 31} {
            putquick "PRIVMSG $chan :\00303\[BLITZ!\]\003 $nick instantly hit 31 points!"
            end_game $chan
        }
    }

    proc pub_discard {nick uhost hand chan arg} {
        variable channel; variable game_active; variable players; variable current_turn; variable discard_pile; variable hands; variable player_has_drawn
        if {[string tolower $chan] != [string tolower $channel]} { return }
        if {$game_active != 2} { return }
        if {$nick != [lindex $players $current_turn]} { putquick "NOTICE $nick :It is not your turn."; return }
        if {!$player_has_drawn} { putquick "NOTICE $nick :You need to draw a card first via !draw."; return }

        set card_input [string toupper [string trim $arg]]
        if {$card_input == ""} { putquick "NOTICE $nick :Specify which card to discard. Example: !discard H10"; return }

        set idx [lsearch -exact $hands($nick) $card_input]
        if {$idx == -1} {
            putquick "NOTICE $nick :You don't hold '$card_input'. Format examples: H10, DA, C2, SQ. Your cards: [join $hands($nick) {, }]"
            return
        }

        # Move card to discard pile
        set discard_card [lindex $hands($nick) $idx]
        set hands($nick) [lreplace $hands($nick) $idx $idx]
        lappend discard_pile $discard_card

        putquick "PRIVMSG $chan :\00303\[BLITZ\]\003 $nick discards [card_name $discard_card]."
        putquick "NOTICE $nick :Your final hand: [print_cards $hands($nick)] (Score: [calc_score $hands($nick)])"

        # Check for 31 after discard
        if {[calc_score $hands($nick)] == 31} {
            putquick "PRIVMSG $chan :\00303\[BLITZ!\]\003 $nick announces a Blitz (31 points)!"
            end_game $chan
            return
        }

        # Move to next turn
        set player_has_drawn 0
        set current_turn [expr {($current_turn + 1) % [llength $players]}]
        announce_turn $chan
    }

    proc pub_knock {nick uhost hand chan arg} {
        variable channel; variable game_active; variable players; variable current_turn; variable knocker; variable player_has_drawn
        if {[string tolower $chan] != [string tolower $channel]} { return }
        if {$game_active != 2} { return }
        if {$nick != [lindex $players $current_turn]} { putquick "NOTICE $nick :It is not your turn."; return }
        if {$player_has_drawn} { putquick "NOTICE $nick :You cannot knock after drawing a card this turn."; return }
        if {$knocker != ""} { putquick "NOTICE $nick :Someone has already knocked!"; return }

        set knocker $nick
        putquick "PRIVMSG $chan :\00304\[KNOCK\]\003 \002$nick\002 has knocked! Everyone else gets exactly ONE final turn to improve their hands."
        
        # Advance turn right away
        set current_turn [expr {($current_turn + 1) % [llength $players]}]
        announce_turn $chan
    }

    proc recycle_deck {chan} {
        variable deck; variable discard_pile
        if {[llength $discard_pile] <= 1} { return }
        set top_card [lindex $discard_pile end]
        set deck [lrange $discard_pile 0 end-1]
        set discard_pile [list $top_card]
        putquick "PRIVMSG $chan :\00303\[BLITZ\]\003 The deck ran out! Shuffling the discard pile back into the deck..."
    }

    proc end_game {chan} {
        variable players; variable hands
        putquick "PRIVMSG $chan :\00303\[GAME OVER\]\003 Let's reveal the hands and calculate scores!"
        
        set results [list]
        set high_score -1
        set winners [list]

        foreach p $players {
            set score [calc_score $hands($p)]
            lappend results [list $p $score $hands($p)]
            if {$score > $high_score} {
                set high_score $score
            }
        }

        # Sort descending by score
        set results [lsort -decreasing -real -index 1 $results]

        foreach res $results {
            set p [lindex $res 0]
            set scr [lindex $res 1]
            set h [lindex $res 2]
            putquick "PRIVMSG $chan :Player: \002$p\002 | Score: \002$scr\002 | Hand: [print_cards $h]"
            if {$scr == $high_score} { lappend winners $p }
        }

        putquick "PRIVMSG $chan :\00303\[WINNER\]\003 Congratulations to the winner(s) with a score of \002$high_score\002: [join $winners {, }]"
        reset_game
    }

    proc pub_hand {nick uhost hand chan arg} {
        variable channel; variable game_active; variable hands
        if {[string tolower $chan] != [string tolower $channel]} { return }
        if {$game_active != 2} { return }
        if {[info exists hands($nick)]} {
            putquick "NOTICE $nick :Your hand: [print_cards $hands($nick)] (Current Score: [calc_score $hands($nick)])"
        }
    }

    proc pub_status {nick uhost hand chan arg} {
        variable channel; variable game_active; variable players; variable current_turn; variable knocker
        if {[string tolower $chan] != [string tolower $channel]} { return }
        if {$game_active == 0} { putquick "PRIVMSG $chan :No game running right now."; return }
        if {$game_active == 1} { putquick "PRIVMSG $chan :Game forming. Players joined: [join $players {, }]"; return }
        
        set active_p [lindex $players $current_turn]
        set msg "Game in progress. Players order: [join $players { -> }]. Current Turn: \002$active_p\002."
        if {$knocker != ""} { append msg " (\002$knocker\002 knocked!)" }
        putquick "PRIVMSG $chan :$msg"
    }

    proc pub_stop {nick uhost hand chan arg} {
        variable channel; variable game_active
        if {[string tolower $chan] != [string tolower $channel]} { return }
        if {!$game_active} { return }
        if {![matchattr $nick n|n $chan]} { putquick "NOTICE $nick :Only channel operators or global admins can force stop the game."; return }
        
        reset_game
        putquick "PRIVMSG $chan :\00304\[BLITZ\]\003 Game abruptly stopped by admin."
    }

    proc reset_game {} {
        variable game_active; variable players; variable hands; variable deck; variable discard_pile; variable knocker; variable join_timer_id
        set game_active 0
        set players [list]
        catch {unset hands}
        set deck [list]
        set discard_pile [list]
        set knocker ""
        catch {killutimer $join_timer_id}
    }

    putlog "Blitz.tcl Card Game Script asl_pls irc.underx.org !Loaded Successfully."
}