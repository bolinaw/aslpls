#########################################################################################################################
#                     					 ____  ____  _     ____  _     ____ 	                        				#
#                    					/  _ \/ ___\/ \   /  __\/ \   / ___\	                        				#
#                     					| / \||    \| |   |  \/|| |   |    \	                        				#
#                     					| |-||\___ || |_/\|  __/| |_/\\___ |	                        				#
#                     					\_/ \|\____/\____/\_/   \____/\____/	                        				#
#                       					asl_pls / irc.underx.org #aslpls    	                    				#
#																														#
#########################################################################################################################
#																														#
# 	russian_roulette_master_edition.tcl v1.0																					#
#																														#
# 	The Russian Roulette Master Edition Game for Eggdrop IRC bots.															#
#																														#
# 	Features: Persistent Cylinder, Multi-Bullets, Stats Tracking, Cooldowns, Auto-Invite,								#
#           1v1 Duels with 5-turn Win conditions, Achievements, Special Tricks, Points Economy,							#
#           Randomized Gory Kicks, Leveling System, and 3/5 Win Caps.													#
#																														#
# 	Commands: !roulette [bullets] [bet] | !rrstats [nick] | !rrtop | !challenge <nick> | !accept | !peek | !tilt		#
#																														#
#	Russian Roulette Master Edition v1.0 — Quick Play Guide																#
#																														#
#	Command,Action,Example																								#
#																														#
#	!rr or !roulette					-	Pull the trigger on a default 1-bullet chamber.								#
#	!rr [bullets] [bet] | !rr 2 200		-	Load 1 to 5 bullets and bet your wallet points.,							#
#	!challenge <nick>					-	Call out another player for a high-stakes 1v1 duel.,!challenge Joker		#
#	!accept								-	Accept an incoming 1v1 duel challenge within 60 seconds.,!accept			#
#	!rrstats [nick], !rrstats			-	View your (or someone else's) Level, XP, Wallet, and Streaks.				#
#	!rrtop								-	Display the top Level rankings leaderboard and current Jackpot.,!rrtop		#
#																														#
#########################################################################################################################


namespace eval ::Roulette {
    variable triggers [list "!roulette" "!rr"]
    variable stats_file "scripts/aslpls/roulette_master_stats.dat"
    variable cooldown_time 30
    variable invite_delay 10

    # Global States
    variable cylinder [list]
    variable cooldowns; array set cooldowns {}
    variable stats;     array set stats {}
    
    # 1v1 Duel States
    variable duel_challenger ""
    variable duel_target ""
    variable duel_chan ""
    variable duel_active 0
    variable duel_turn ""
    variable duel_timer ""
    variable duel_turn_count 0 ;# Track turns in duel to force a winner at 5

    # Economy & Levels Config
    variable jackpot 500

    # Death Messages Pool
    variable death_messages [list \
        "BOOM! Your brains splatter all over the channel walls." \
        "PULL... *BANG*! You didn't even see it coming." \
        "💥 HEADSHOT! Better luck next life." \
        "*CLICK*... wait, no, *BOOM*! Say goodbye to your frontal lobe." \
        "You hear a loud pop as your virtual skull exits the chat." \
        "The cylinder turns, a flash of fire, and you are history." \
        "You gambled with fate and fate brought a cleanup crew." \
        "BOOM! That's going to leave a mark on the server logs." \
        "A sudden ringing in your ears... followed by eternal channel darkness." \
        "CRACK! You successfully painted the channel background dark red." \
    ]

    # Binds
    foreach trigger $triggers { bind pub - $trigger [namespace current]::play }
    bind pub - "!rrstats"   [namespace current]::show_stats
    bind pub - "!rrtop"     [namespace current]::show_top
    bind pub - "!challenge" [namespace current]::init_challenge
    bind pub - "!accept"    [namespace current]::accept_challenge
    bind pub - "!peek"      [namespace current]::use_peek
    bind pub - "!tilt"      [namespace current]::use_tilt
    bind time - "00 * * * *" [namespace current]::save_stats

    proc init {} {
        variable stats_file
        variable stats
        if {[file exists $stats_file]} {
            set fp [open $stats_file r]
            array set stats [read $fp]
            close $fp
        }
        reset_cylinder
    }

    proc reset_cylinder {} {
        variable cylinder
        set cylinder [list 0 0 0 0 0 0]
    }

    # Initialize / Check user stats structure
    proc check_user {nick} {
        variable stats
        foreach key {streak maxstreak deaths points wallet first_pull_deaths items_peek items_tilt level experience} {
            if {![info exists stats($nick,$key)]} { set stats($nick,$key) 0 }
        }
        if {$stats($nick,wallet) == 0} { set stats($nick,wallet) 1000 } ;# Starting credits
        if {$stats($nick,level) == 0} { set stats($nick,level) 1 }       ;# Start at level 1
    }

    # Core Play Logic
    proc play {nick uhost hand chan arg} {
        variable cylinder; variable cooldowns; variable cooldown_time; variable jackpot; variable duel_active; variable stats
        if {![botisop $chan]} { putserv "PRIVMSG $chan :I need op (@) status to play!"; return 0 }
        if {$duel_active} { putserv "PRIVMSG $chan :Please wait, a 1v1 duel is currently active!"; return 0 }
        
        check_user $nick
        
        # Anti-spam check
        set now [clock seconds]
        if {[info exists cooldowns($nick)] && [expr {$now - $cooldowns($nick)}] < $cooldown_time} {
            putserv "NOTICE $nick :The gun is still warm! Wait [expr {$cooldown_time - ($now - $cooldowns($nick))}]s."
            return 0
        }
        set cooldowns($nick) $now

        set bullets 1; set bet 0
        set args [split [string trim $arg]]
        if {[llength $args] >= 1 && [string is integer -strict [lindex $args 0]]} {
            set bullets [lindex $args 0]
            if {$bullets < 1 || $bullets > 5} { set bullets 1 }
        }
        if {[llength $args] >= 2 && [string is integer -strict [lindex $args 1]]} {
            set bet [lindex $args 1]
            if {$bet < 0} { set bet 0 }
            if {$bet > $stats($nick,wallet)} {
                putserv "PRIVMSG $chan :$nick, you don't have enough points! Wallet: $stats($nick,wallet)"
                return 0
            }
        }

        set fresh 0
        if {[lsearch -exact $cylinder 1] == -1} {
            reset_cylinder
            set loaded 0
            while {$loaded < $bullets} {
                set slot [expr {int(rand() * 6)}]
                if {[lindex $cylinder $slot] == 0} {
                    set cylinder [lreplace $cylinder $slot $slot 1]
                    incr loaded
                }
            }
            set fresh 1
        }

        set stats($nick,wallet) [expr {$stats($nick,wallet) - $bet}]
        set jackpot [expr {$jackpot + $bet}]

        if {$fresh} {
            putserv "PRIVMSG $chan :\00306$nick\003 bets $bet pts and loaded \00304$bullets\003 bullet(s) into a fresh cylinder!"
        } else {
            putserv "PRIVMSG $chan :\00306$nick\003 risks $bet pts on the current cylinder alignment..."
        }
        
        putserv "PRIVMSG $chan :...places the muzzle against their temple and squeezes..."
        utimer 2 [list [namespace current]::pull_trigger $nick $chan $bet 0]
        return 1
    }

    # Pulling the trigger
    proc pull_trigger {nick chan bet is_duel} {
        variable cylinder; variable stats; variable invite_delay; variable jackpot; variable death_messages
        variable duel_active; variable duel_challenger; variable duel_target; variable duel_turn; variable duel_turn_count

        set total_slots [llength $cylinder]
        set live_round [lindex $cylinder 0]
        set cylinder [lvarpop cylinder 0]

        check_user $nick

        if {$live_round == 1} {
            # BOOM
            putserv "PRIVMSG $chan :\00304*BOOM*\003 \00304*BOOM*\003 \00304*BOOM*\003"
            incr stats($nick,deaths)
            if {$total_slots == 6} { incr stats($nick,first_pull_deaths) } else { set stats($nick,first_pull_deaths) 0 }
            
            set current_streak $stats($nick,streak)
            set stats($nick,streak) 0

            set random_kick [lindex $death_messages [expr {int(rand() * [llength $death_messages])}]]
            putkick $chan $nick $random_kick
            utimer $invite_delay [list putserv "INVITE $nick $chan"]
            reset_cylinder
            
            if {$is_duel} {
                set winner [expr {$nick == $duel_challenger ? $duel_target : $duel_challenger}]
                award_duel_win $winner $chan
            } else {
                putserv "PRIVMSG $chan :The local jackpot pool reset! It is back to 500 points."
                set jackpot 500
            }
            check_achievements $nick $chan $total_slots 1 $current_streak
        } else {
            # SURVIVED
            incr stats($nick,streak)
            if {$stats($nick,streak) > $stats($nick,maxstreak)} { set stats($nick,maxstreak) $stats($nick,streak) }
            
            # Grant EXP for surviving a trigger pull
            incr stats($nick,experience) 20
            
            set payout [expr {$bet + int($bet * (1.0 / $total_slots))}]
            if {$bet > 0} {
                set stats($nick,wallet) [expr {$stats($nick,wallet) + $payout}]
                putserv "PRIVMSG $chan :\00303Click! Safe.\003 $nick wins back $payout points."
            } else {
                putserv "PRIVMSG $chan :\00303Click! Safe...\003 (Current Streak: $stats($nick,streak))"
            }

            # 15% Chance to find a utility trick card
            if {[expr {rand()}] < 0.15} {
                set item [expr {rand() > 0.5 ? "items_peek" : "items_tilt"}]
                incr stats($nick,$item)
                set item_name [expr {$item == "items_peek" ? "!peek" : "!tilt"}]
                putserv "PRIVMSG $chan :🎁 $nick picked up a \00311$item_name\003 action trick card!"
            }

            check_level_up $nick $chan
            check_achievements $nick $chan $total_slots 0 $stats($nick,streak)

            if {$is_duel} {
                incr duel_turn_count
                
                # Check for 5-turn limit completion
                if {$duel_turn_count >= 5} {
                    putserv "PRIVMSG $chan :⏱️ \00307\[LIMIT REACHED\]\003 Both players survived 5 tense turns! The match concludes by structural decision."
                    # Randomly select a winner from the survivors to close out cleanly
                    set survivor_winner [expr {rand() > 0.5 ? $duel_challenger : $duel_target}]
                    award_duel_win $survivor_winner $chan
                    return
                }

                set duel_turn [expr {$nick == $duel_challenger ? $duel_target : $duel_challenger}]
                putserv "PRIVMSG $chan :\00306It's now turn $duel_turn_count/5. Your play, $duel_turn!\003 (Type \00312!rr\003)"
                start_duel_timer
            } else {
                # Regular Mode: Win instantly if you survive a 5-streak without exploding
                if {$stats($nick,streak) >= 5} {
                    putserv "PRIVMSG $chan :🎉 \00303SUCCESS!\003 \00306$nick\003 has cleared 5 consecutive safe clicks! They beat the house, clean out the jackpot pool of \00312$jackpot\003 points, and gain massive bonus EXP!"
                    set stats($nick,wallet) [expr {$stats($nick,wallet) + $jackpot}]
                    incr stats($nick,experience) 100
                    set jackpot 500
                    set stats($nick,streak) 0
                    reset_cylinder
                    check_level_up $nick $chan
                } elseif {[llength $cylinder] == 0} { 
                    reset_cylinder 
                }
            }
        }
        save_stats
    }

    # Helper to resolve match prizes, experience injections, and reset the duel configuration
    proc award_duel_win {winner chan} {
        variable jackpot; variable stats
        check_user $winner
        set prize [expr {$jackpot / 2}]
        set stats($winner,wallet) [expr {$stats($winner,wallet) + $prize}]
        incr stats($winner,experience) 150 ;# 150 Bonus exp for winning matches
        putserv "PRIVMSG $chan :\00303🏆 $winner wins the duel, claiming $prize points and bonus experience!\003"
        check_level_up $winner $chan
        clean_duel
    }

    # Experience Calculation and level advancement framework
    proc check_level_up {nick chan} {
        variable stats
        set xp_needed [expr {$stats($nick,level) * 120}]
        if {$stats($nick,experience) >= $xp_needed} {
            set stats($nick,experience) [expr {$stats($nick,experience) - $xp_needed}]
            incr stats($nick,level)
            putserv "PRIVMSG $chan :✨ \00306$nick\003 HAS LEVELLED UP! They are now \00312Level $stats($nick,level)\003! ✨"
        }
    }

    # Trick: !peek
    proc use_peek {nick uhost hand chan arg} {
        variable cylinder; variable stats; variable duel_active; variable duel_turn
        if {![botisop $chan]} return
        if {$duel_active && $nick != $duel_turn} { putserv "NOTICE $nick :It's not your turn!"; return }
        
        check_user $nick
        if {$stats($nick,items_peek) <= 0} { putserv "NOTICE $nick :You don't have any !peek action cards."; return }
        if {[llength $cylinder] == 0 || [lsearch -exact $cylinder 1] == -1} { return }

        set stats($nick,items_peek) [expr {$stats($nick,items_peek) - 1}]
        set next_round [lindex $cylinder 0]
        
        if {$next_round == 1} {
            putserv "PRIVMSG $chan :👁️ \00306$nick\003 stealthily peers down the barrel... \00304THE NEXT CHAMBER IS LIVE!\003"
        } else {
            putserv "PRIVMSG $chan :👁️ \00306$nick\003 stealthily peers down the barrel... The next chamber is empty."
        }
    }

    # Trick: !tilt
    proc use_tilt {nick uhost hand chan arg} {
        variable cylinder; variable stats; variable duel_active; variable duel_turn
        if {![botisop $chan]} return
        if {$duel_active && $nick != $duel_turn} { putserv "NOTICE $nick :It's not your turn!"; return }
        
        check_user $nick
        if {$stats($nick,items_tilt) <= 0} { putserv "NOTICE $nick :You don't have any !tilt action cards."; return }
        if {[llength $cylinder] <= 1} { return }

        set stats($nick,items_tilt) [expr {$stats($nick,items_tilt) - 1}]
        set immediate [lindex $cylinder 0]
        set cylinder [lvarpop cylinder 0]
        lappend cylinder $immediate
        
        putserv "PRIVMSG $chan :🔄 \00306$nick\003 smoothly tilts the revolver, shifting the current chamber setup without pulling the trigger!"
    }

    # Achievement Evaluator
    proc check_achievements {nick chan total_slots died streak} {
        variable stats
        if {!$died && $total_slots == 2 && $streak >= 1} {
            announce_achievement $nick $chan "Neo" "Survived an immediate pull when only 2 chambers were left!"
        }
        if {$died && $stats($nick,first_pull_deaths) >= 3} {
            announce_achievement $nick $chan "Bullet Magnet" "Died on a completely fresh 6-slot pull 3 times in a row."
            set stats($nick,first_pull_deaths) 0
        }
        if {$stats($nick,wallet) >= 5000} {
            announce_achievement $nick $chan "High Roller" "Amassed a fortune of 5,000 points or more."
        }
        if {!$died && $stats($nick,maxstreak) >= 10} {
            announce_achievement $nick $chan "Immortal" "Achieved a legendary overall lifetime streak of 10 safe clicks!"
        }
    }

    proc announce_achievement {nick chan name desc} {
        putserv "PRIVMSG $chan :🏆 \00312\[ACHIEVEMENT UNLOCKED\]\003 \00306$nick\003 earned the badge: **$name** ($desc)"
    }

    # 1v1 Duels Setup
    proc init_challenge {nick uhost hand chan arg} {
        variable duel_challenger; variable duel_target; variable duel_chan; variable duel_active; variable duel_timer
        if {$duel_active} { putserv "PRIVMSG $chan :A match is already playing out."; return }
        
        set target [string trim $arg]
        if {$target == "" || [string equal -nocase $target $nick]} {
            putserv "NOTICE $nick :Specify a valid rival to challenge."
            return
        }

        set duel_challenger $nick
        set duel_target $target
        set duel_chan $chan
        set duel_active 1
        
        putserv "PRIVMSG $chan :⚔️ \00304$nick\003 has challenged \00306$target\003 to a high-stakes Russian Roulette Duel! Type \00303!accept\003 within 60s to play."
        set duel_timer [utimer 60 [namespace current]::timeout_duel]
    }

    proc accept_challenge {nick uhost hand chan arg} {
        variable duel_challenger; variable duel_target; variable duel_chan; variable duel_active; variable duel_timer; variable duel_turn; variable cylinder; variable duel_turn_count
        if {!$duel_active || $nick != $duel_target || $chan != $duel_chan} return
        
        catch {killutimer $duel_timer}
        
        reset_cylinder
        set cylinder [lreplace $cylinder 0 0 1]
        set shuffled [list]
        while {[llength $cylinder] > 0} {
            set idx [expr {int(rand() * [llength $cylinder])}]
            lappend shuffled [lindex $cylinder $idx]
            set cylinder [lreplace $cylinder $idx $idx]
        }
        set cylinder $shuffled
        
        set duel_turn_count 0
        set duel_turn $duel_challenger
        putserv "PRIVMSG $chan :⚔️ \00304The duel begins!\003 Max length is set to 5 turns. \00306$duel_turn\003 takes the opening shot. Type \00312!rr\003 to pull!"
        
        unbind pub - "!rr" [namespace current]::play
        unbind pub - "!roulette" [namespace current]::play
        bind pub - "!rr" [namespace current]::duel_pull
        bind pub - "!roulette" [namespace current]::duel_pull
        
        start_duel_timer
    }

    proc duel_pull {nick uhost hand chan arg} {
        variable duel_turn; variable duel_active; variable duel_chan; variable duel_timer
        if {!$duel_active || $chan != $duel_chan || $nick != $duel_turn} return
        catch {killutimer $duel_timer}
        
        putserv "PRIVMSG $chan :\00306$nick\003 steadies their hand, places the gun, and pulls..."
        utimer 2 [list [namespace current]::pull_trigger $nick $chan 0 1]
    }

    proc start_duel_timer {} {
        variable duel_timer; variable duel_turn
        catch {killutimer $duel_timer}
        set duel_timer [utimer 30 [namespace current]::timeout_turn]
    }

    proc timeout_turn {} {
        variable duel_turn; variable duel_chan
        putserv "PRIVMSG $duel_chan :⏱️ $duel_turn froze up! Auto-pulling due to inactivity timeout."
        pull_trigger $duel_turn $duel_chan 0 1
    }

    proc timeout_duel {} {
        putserv "PRIVMSG $::Roulette::duel_chan :⏱️ The duel challenge expired."
        clean_duel
    }

    proc clean_duel {} {
        variable duel_active; variable triggers
        set duel_active 0
        unbind pub - "!rr" [namespace current]::duel_pull
        unbind pub - "!roulette" [namespace current]::duel_pull
        foreach trigger $triggers { bind pub - $trigger [namespace current]::play }
    }

    # Stats Displays
    proc show_stats {nick uhost hand chan arg} {
        variable stats
        set target [string trim $arg]
        if {$target == ""} { set target $nick }
        check_user $target

        set xp_needed [expr {$stats($target,level) * 120}]
        putserv "PRIVMSG $chan :\00312\[Profile for $target\]\003 Level: $stats($target,level) ($stats($target,experience)/$xp_needed XP) | Wallet: $stats($target,wallet) pts | Streak: $stats($target,streak) (Max: $stats($target,maxstreak)) | Deaths: $stats($target,deaths) | Tricks: \[Pk: $stats($target,items_peek) / Tl: $stats($target,items_tilt)\]"
    }

    # Leaderboard output (Horizontal formatting)
    proc show_top {nick uhost hand chan arg} {
        variable stats; variable jackpot
        set players [list]
        foreach key [array names stats "*,level"] {
            set p [lindex [split $key ,] 0]
            lappend players [list $p $stats($key)]
        }
        set sorted [lsort -integer -decreasing -index 1 $players]
        
        set top_list [list]
        set i 1
        foreach entry [lrange $sorted 0 4] {
            lappend top_list "\002#$i\002 [lindex $entry 0] (Lvl [lindex $entry 1])"
            incr i
        }
        
        set horizontal_output [join $top_list " \00306•\003 "]
        putserv "PRIVMSG $chan :\00304\[Top Level Rankings\]\003 $horizontal_output | \00304\[Jackpot Pool\]\003 $jackpot pts"
    }

    proc save_stats {args} {
        variable stats_file; variable stats
        catch {file mkdir [file dirname $stats_file]}
        set fp [open $stats_file w]
        puts $fp [array get stats]
        close $fp
    }

    proc lvarpop {varName {index 0}} {
        upvar 1 $varName list
        set val [lindex $list $index]
        set list [lreplace $list $index $index]
        return $val
    }

    init
    putlog "Loaded: Russian Roulette Master Edition v1.0 by asl_pls irc.underx.org"
}