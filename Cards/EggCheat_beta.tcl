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
# EggCheat_beta.tcl - Cheat / Bullshit IRC Card Game for Eggdrop							
# Version 1.0 (2026)																
#																					
#	How to Play in the Channel															
#																						
#	Start a game: Type !cheat in the channel.										
#																						
#	Join the game: Other users type !join (Up to 13 players total, minimum 3).		
#																					
#	Check your hand: The bot will automatically notice you your hand, but you 		
#		can type !cards at any time to see it again.								
#																					
#	Play your turn: When it's your turn, the bot tells you what rank you 			
#		must claim to play.															
#																						
#	If the bot says: It is your turn. You must play Kings.							
#																					
#	You type: !play K K (if you are dropping two cards and claiming they are Kings).
#		You can bluff and drop a 5 and a 7, but you must type !play <the ranks in 	
#		your hand you are physically putting down>. The bot translates it to the	
#		current claim target automatically.												
#																					
#	Call "Cheat": If another player thinks you lied about what cards you put down, 	
#		they type !cheat in the channel before the next player takes a turn. If 	
#		you were lying, you take the center pile. If you were telling the truth, .	
#		the accuser takes the pile!													
#																						
#	How to play: https://www.youtube.com/watch?v=ajVs_z8yLdk						
#																					
#																							
#	Commands: !cheat [start the game] \ !cheat stop [stop the game]					
#																					
##############################################################################################

namespace eval ::Cheat {
    # --- Configuration ---
    variable cmd_prefix "!"
    variable channel "#aslpls" ;# Change to your game channel, or leave blank to allow any channel

    # --- Game State Variables ---
    variable game_state "IDLE" ;# IDLE, JOINING, PLAYING
    variable players [list]
    variable hands; array set hands {}
    variable pile [list]
    variable current_turn 0
    variable current_rank 1 ;# 1=Ace, 2=2... 11=Jack, 12=Queen, 13=King
    variable last_play_cards [list]
    variable last_play_player ""
    variable join_timer ""
    variable game_starter ""  ;# Tracks who initialized the game

    # Bindings
    bind pub - "${::Cheat::cmd_prefix}cheat" ::Cheat::pub_cheat
    bind pub - "${::Cheat::cmd_prefix}join" ::Cheat::pub_join
    bind pub - "${::Cheat::cmd_prefix}play" ::Cheat::pub_play
    bind pub - "${::Cheat::cmd_prefix}cards" ::Cheat::pub_cards
    bind pub - "${::Cheat::cmd_prefix}status" ::Cheat::pub_status

    # Rank helpers
    variable rank_names {? A 2 3 4 5 6 7 8 9 10 J Q K}

    proc pub_cheat {nick uhost hand chan arg} {
        variable game_state
        variable players
        variable join_timer
        variable channel
        variable cmd_prefix
        variable game_starter
        
        if {$channel ne "" && [string tolower $chan] ne [string tolower $channel]} { return }

        set first_arg [string tolower [lindex [split $arg] 0]]

        # --- Handle "!cheat stop" ---
        if {$first_arg eq "stop"} {
            if {$game_state eq "IDLE"} {
                putquick "NOTICE $nick :There is no game running to stop."
                return
            }
            # Authorization check: Must be the starter, or have +o/+m bot flags
            if {[string tolower $nick] eq [string tolower $game_starter] || [matchattr $hand om]} {
                if {$join_timer ne ""} { killutimer $join_timer; set join_timer "" }
                putquick "PRIVMSG $chan :\00304\[CHEAT\]\003 Game forcibly stopped by \002$nick\002."
                reset_game
            } else {
                putquick "NOTICE $nick :You cannot stop the game. Only the game starter ($game_starter) or a bot admin can."
            }
            return
        }

        # --- Standard Game Loop Functions ---
        switch $game_state {
            "PLAYING" {
                handle_challenge $nick $chan
            }
            "JOINING" {
                putquick "PRIVMSG $chan :A game is already forming! Type ${cmd_prefix}join to enter."
            }
            "IDLE" {
                set game_state "JOINING"
                set game_starter $nick
                set players [list $nick]
                putquick "PRIVMSG $chan :\00303\[CHEAT\]\003 $nick has started a game of Cheat (Bullshit)! Type \002${cmd_prefix}join\002 to play (3-13 players required). Starting in 45 seconds. (To abort, type \002${cmd_prefix}cheat stop\002)"
                set join_timer [utimer 45 [list ::Cheat::start_game_check $chan]]
            }
        }
    }

    proc pub_join {nick uhost hand chan arg} {
        variable game_state
        variable players
        variable channel
        if {$channel ne "" && [string tolower $chan] ne [string tolower $channel]} { return }

        if {$game_state ne "JOINING"} {
            putquick "NOTICE $nick :There is no game open for joins right now."
            return
        }
        if {[lsearch -exact $players $nick] != -1} {
            putquick "NOTICE $nick :You are already in the game."
            return
        }
        if {[llength $players] >= 13} {
            putquick "NOTICE $nick :The game is full (max 13 players)."
            return
        }

        lappend players $nick
        putquick "PRIVMSG $chan :$nick has joined the game. Total players: [llength $players]"
    }

    proc start_game_check {chan} {
        variable game_state
        variable players
        variable join_timer
        
        set join_timer ""
        if {[llength $players] < 3} {
            putquick "PRIVMSG $chan :\00304\[CHEAT\]\003 Not enough players to start (Minimum 3 required). Game cancelled."
            reset_game
        } else {
            start_game $chan
        }
    }

    proc start_game {chan} {
        variable game_state
        variable players
        variable hands
        variable pile
        variable current_turn
        variable current_rank

        set game_state "PLAYING"
        set pile [list]
        set current_turn 0
        set current_rank 1

        set deck [list]
        for {set r 1} {$r <= 13} {incr r} {
            for {set s 0} {$s < 4} {incr s} {
                lappend deck $r
            }
        }

        set shuffled [list]
        while {[llength $deck] > 0} {
            set idx [expr {int(rand()*[llength $deck])}]
            lappend shuffled [lindex $deck $idx]
            set deck [lreplace $deck $idx $idx]
        }

        foreach p $players { set hands($p) [list] }
        set p_idx 0
        foreach card $shuffled {
            set p [lindex $players $p_idx]
            lappend hands($p) $card
            set p_idx [expr {($p_idx + 1) % [llength $players]}]
        }

        putquick "PRIVMSG $chan :\00303\[CHEAT\]\003 The deck is dealt! Check your cards via PM/Notice. Turn order: [join $players { -> }]"
        
        foreach p $players {
            send_hand $p
        }

        announce_turn $chan
    }

    proc announce_turn {chan} {
        variable players
        variable current_turn
        variable current_rank
        variable rank_names
        variable pile

        set active_player [lindex $players $current_turn]
        set target_rank [lindex $rank_names $current_rank]

        putquick "PRIVMSG $chan :\00311\[TURN\]\003 It is \002$active_player\002's turn. They must play one or more \002$target_rank\002s. (Center pile: [llength $pile] cards)"
    }

    proc pub_play {nick uhost hand chan arg} {
        variable game_state
        variable players
        variable current_turn
        variable current_rank
        variable hands
        variable pile
        variable last_play_cards
        variable last_play_player
        variable rank_names
        variable channel
        variable cmd_prefix

        if {$channel ne "" && [string tolower $chan] ne [string tolower $channel]} { return }
        if {$game_state ne "PLAYING"} { return }

        set active_player [lindex $players $current_turn]
        if {[string tolower $nick] ne [string tolower $active_player]} {
            putquick "NOTICE $nick :It is not your turn."
            return
        }

        set played_ranks [string toupper [string trim $arg]]
        if {$played_ranks eq ""} {
            putquick "NOTICE $nick :Usage: ${cmd_prefix}play <rank1> \[rank2\] ... (e.g., ${cmd_prefix}play A A)"
            return
        }

        set mapped_cards [list]
        foreach r $played_ranks {
            set internal_rank [lsearch -exact $rank_names $r]
            if {$internal_rank == -1} {
                putquick "NOTICE $nick :Invalid card rank: $r. Use A, 2-10, J, Q, K."
                return
            }
            lappend mapped_cards $internal_rank
        }

        set temp_hand $hands($active_player)
        foreach card $mapped_cards {
            set idx [lsearch -exact $temp_hand $card]
            if {$idx == -1} {
                putquick "NOTICE $nick :You don't have enough '[lindex $rank_names $card]' cards in your hand to play that."
                return
            }
            set temp_hand [lreplace $temp_hand $idx $idx]
        }

        set hands($active_player) $temp_hand
        set last_play_cards $mapped_cards
        set last_play_player $active_player
        set qty [llength $mapped_cards]
        
        foreach card $mapped_cards { lappend pile $card }

        set target_rank [lindex $rank_names $current_rank]
        putquick "PRIVMSG $chan :\002$active_player\002 played \00304$qty\003 card(s) claiming to be \002${target_rank}s\002. Anyone can challenge by typing \002${cmd_prefix}cheat\002 now, or wait for the next turn."

        set current_turn [expr {($current_turn + 1) % [llength $players]}]
        set current_rank [expr {$current_rank == 13 ? 1 : $current_rank + 1}]

        send_hand $active_player
        
        if {[llength $hands($active_player)] == 0} {
            putquick "PRIVMSG $chan :\002$active_player\002 has 0 cards left! If they survive this round without being called a Cheat, they win!"
        }

        announce_turn $chan
    }

    proc handle_challenge {challenger chan} {
        variable players
        variable hands
        variable pile
        variable last_play_cards
        variable last_play_player
        variable current_rank
        variable rank_names

        if {$last_play_player eq ""} {
            putquick "NOTICE $challenger :Nothing has been played yet to challenge."
            return
        }

        set claimed_rank [expr {$current_rank == 1 ? 13 : $current_rank - 1}]

        putquick "PRIVMSG $chan :\00304\[CHALLENGE\]\003 \002$challenger\002 accuses \002$last_play_player\002 of cheating!"

        set was_bluffing 0
        set actual_cards [list]
        foreach card $last_play_cards {
            lappend actual_cards [lindex $rank_names $card]
            if {$card != $claimed_rank} {
                set was_bluffing 1
            }
        }

        putquick "PRIVMSG $chan :$last_play_player actually played: [join $actual_cards {, }]"

        if {$was_bluffing} {
            putquick "PRIVMSG $chan :\00304CAUGHT!\003 $last_play_player was bluffing! $last_play_player picks up the entire pile ([llength $pile] cards)."
            foreach card $pile { lappend hands($last_play_player) $card }
            set pile [list]
            send_hand $last_play_player
        } else {
            putquick "PRIVMSG $chan :\00303LEGIT!\003 $last_play_player was telling the truth! $challenger picks up the entire pile ([llength $pile] cards) for false accusation."
            foreach card $pile { lappend hands($challenger) $card }
            set pile [list]
            send_hand $challenger
        }

        set last_play_player ""
        set last_play_cards [list]

        check_victory $chan
    }

    proc check_victory {chan} {
        variable players
        variable hands
        
        foreach p $players {
            if {[llength $hands($p)] == 0} {
                putquick "PRIVMSG $chan :\00305\[GAME OVER\]\003 \002$p\002 has successfully discarded all their cards and WINS THE GAME! Congratulations! \00302\u261E\u261E"
                reset_game
                return
            }
        }
    }

    proc send_hand {p} {
        variable hands
        variable rank_names
        
        set display_hand [list]
        set sorted_hand [lsort -integer $hands($p)]
        foreach card $sorted_hand {
            lappend display_hand [lindex $rank_names $card]
        }
        
        putquick "NOTICE $p :Your Hand ([llength $sorted_hand] cards): [join $display_hand {, }]"
    }

    proc pub_cards {nick uhost hand chan arg} {
        variable game_state
        variable players
        if {$game_state eq "PLAYING" && [lsearch -exact $players $nick] != -1} {
            send_hand $nick
        }
    }

    proc pub_status {nick uhost hand chan arg} {
        variable game_state
        variable players
        variable hands
        variable pile
        variable channel

        if {$channel ne "" && [string tolower $chan] ne [string tolower $channel]} { return }
        if {$game_state ne "PLAYING"} {
            putquick "PRIVMSG $chan :No game currently active."
            return
        }

        set stat [list]
        foreach p $players {
            lappend stat "$p ([llength $hands($p)] cards)"
        }
        putquick "PRIVMSG $chan :\[STATUS\] Pile: [llength $pile] cards | Players: [join $stat {, }]"
    }

    proc reset_game {} {
        variable game_state "IDLE"
        variable players [list]
        variable pile [list]
        variable last_play_player ""
        variable last_play_cards [list]
        variable game_starter ""
        array unset hands
        array set hands {}
    }

    putlog "EggCheat_beta.tcl / Bullshit Engine v1.0 by asl_pls irc.underx.org Loaded successfully."
}
