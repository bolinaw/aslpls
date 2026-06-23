###########################################################################################
#                      ____  ____  _     ____  _     ____ 	                          
#                     /  _ \/ ___\/ \   /  __\/ \   / ___\	                          
#                     | / \||    \| |   |  \/|| |   |    \	                          
#                     | |-||\___ || |_/\|  __/| |_/\\___ |	                          
#                     \_/ \|\____/\____/\_/   \____/\____/	                          
#                       asl_pls / irc.underx.org #aslpls    	                          
#                                                                                         
########################################################################################### 
#
# EggTimeBomb.tcl - Added Dead Man's Switch & EMP Scrambling
# Usage: !timebomb <nick> | !cut <color> | !pass <nick> | !buy <tool> | !deadman | !bombstats
#
########################################################################################### 


namespace eval ::Timebomb {
    # --- Configuration ---
    variable kickReason "BOOM! You blew up!"
    variable duration 40
    variable wires {red blue green yellow black white magenta orange}
    variable statsFile "data/timebomb.stats"

    # --- Internal State ---
    variable active 0
    variable target ""
    variable attacker "" ;# Tracks who planted the bomb for the Dead Man's Switch
    variable channel ""
    variable timerId ""
    variable timeLeft 0
    variable correctWire ""
    variable trapWire ""
    variable dudWire ""
    variable activeWires {}
    variable deadmanPrimed 0 ;# 1 if the victim primed their revenge switch
    variable isEmp 0        ;# 1 if the current bomb is an EMP bomb
    
    # User Inventories & Stats maps
    variable inventory; array set inventory {}
    variable stats; array set stats {}

    # Bindings
    bind pub - !timebomb [namespace current]::plant_bomb
    bind pub - !cut      [namespace current]::cut_wire
    bind pub - !pass     [namespace current]::pass_bomb
    bind pub - !buy      [namespace current]::buy_tool
    bind pub - !deadman  [namespace current]::prime_deadman
    bind pub - !bombstats [namespace current]::show_stats

    proc init {} {
        variable statsFile; variable stats
        if {[file exists $statsFile]} {
            set fp [open $statsFile r]
            array set stats [read $fp]
            close $fp
        }
    }

    proc save_stats {} {
        variable statsFile; variable stats
        set fp [open $statsFile w]
        puts $fp [array get stats]
        close $fp
    }

    proc add_stat {nick type} {
        variable stats; set nick [string tolower $nick]
        if {![info exists stats($nick,$type)]} { set stats($nick,$type) 0 }
        incr stats($nick,$type); save_stats
    }

    proc get_stat {nick type} {
        variable stats; set nick [string tolower $nick]
        if {![info exists stats($nick,$type)]} { return 0 }
        return $stats($nick,$type)
    }

    proc plant_bomb {nick uhost hand chan arg} {
        variable active; variable target; variable attacker; variable channel; variable timerId
        variable duration; variable wires; variable correctWire; variable trapWire
        variable dudWire; variable activeWires; variable timeLeft; variable deadmanPrimed; variable isEmp

        if {$active} {
            putquick "PRIVMSG $chan :There is already a bomb ticking! Wait your turn."
            return
        }

        set victim [string trim [lindex [split $arg] 0]]
        if {$victim eq ""} {
            putquick "PRIVMSG $chan :Usage: !timebomb <nick>"
            return
        }

        if {![onchan $victim $chan]} {
            putquick "PRIVMSG $chan :I don't see $victim in here."
            return
        }

        if {[string tolower $victim] eq [string tolower $::botnick]} {
            putquick "PRIVMSG $chan :Nice try, but you can't bomb me!"
            return
        }

        set active 1
        set target $victim
        set attacker $nick
        set channel $chan
        set timeLeft $duration
        set deadmanPrimed 0
        
        # 20% chance of an EMP Bomb
        if {rand() < 0.20} { set isEmp 1 } else { set isEmp 0 }
        
        # Setup Wires
        set shuffled [shuffle $wires]
        set activeWires [lrange $shuffled 0 3]
        set correctWire [lindex $activeWires 0]
        set trapWire    [lindex $activeWires 1]
        set dudWire     [lindex $activeWires 2]
        set activeWires [shuffle $activeWires]

        add_stat $nick "plants"

        putquick "PRIVMSG $chan :\00304*TICK TOCK*\003 \002$nick\002 stuffed a bomb down \002$victim\002's pants!"
        
        if {$isEmp} {
            # Scramble the wire strings by reversing them
            set scrambled {}
            foreach wire $activeWires { lappend scrambled [string reverse $wire] }
            putquick "PRIVMSG $chan :\00311*EMP BLAST DETECTED* Display static encountered! Wires are corrupted!\003"
            putquick "PRIVMSG $chan :Scrambled Wires: [join $scrambled {, }]. Time: $timeLeft\s."
            putquick "PRIVMSG $chan :Hint: You must type the *correctly spelled* color to cut it! (e.g., if you see 'der', type !cut red)"
        } else {
            putquick "PRIVMSG $chan :Wires: [join $activeWires {, }]. Time: $timeLeft\s."
        }
        
        putquick "PRIVMSG $chan :Actions: \002!cut <color>\002 | \002!pass <nick>\002 | \002!deadman\002"

        set timerId [utimer $timeLeft [list [namespace current]::explode 0]]
    }

    proc cut_wire {nick uhost hand chan arg} {
        variable active; variable target; variable correctWire; variable trapWire
        variable dudWire; variable timerId; variable channel

        if {!$active || [string tolower $nick] ne [string tolower $target] || $chan ne $channel} { return }

        set chosen [string tolower [string trim [lindex [split $arg] 0]]]
        if {$chosen eq ""} {
            putquick "PRIVMSG $chan :$nick, specify a wire color!"
            return
        }

        killutimer $timerId

        if {$chosen eq [string tolower $correctWire]} {
            putquick "PRIVMSG $chan :\00303*PHEW*\003 $nick cut the correct wire ($chosen)! The bomb defuses smoothly."
            add_stat $nick "defuses"
            reset_bomb
        } \
        elseif {$chosen eq [string tolower $dudWire]} {
            putquick "PRIVMSG $chan :\00311*CLICK...*\003 $nick cut the $chosen wire. It hissed... then stopped. It was a fake dud bomb all along!"
            reset_bomb
        } \
        elseif {$chosen eq [string tolower $trapWire]} {
            putquick "PRIVMSG $chan :\00304*TRAP TRIGGERED!*\003 $nick cut the booby-trapped $chosen wire!"
            explode 1
        } \
        else {
            putquick "PRIVMSG $chan :\00304*BOOM*\003 Wrong wire ($chosen)! You crossed the circuits!"
            explode 1
        }
    }

    proc pass_bomb {nick uhost hand chan arg} {
        variable active; variable target; variable attacker; variable timerId; variable channel; variable timeLeft

        if {!$active || [string tolower $nick] ne [string tolower $target] || $chan ne $channel} { return }

        set newTarget [string trim [lindex [split $arg] 0]]
        if {$newTarget eq "" || ![onchan $newTarget $chan] || [string tolower $newTarget] eq [string tolower $::botnick] || [string tolower $newTarget] eq [string tolower $nick]} {
            putquick "PRIVMSG $chan :Invalid person to pass to."
            return
        }

        killutimer $timerId

        if {rand() < 0.25} {
            putquick "PRIVMSG $chan :\00304*FUMBLE!*\003 $nick tried to pass the bomb, but slipped and dropped it!"
            explode 1
            return
        }

        set timeLeft [expr {$timeLeft / 2}]
        if {$timeLeft < 5} { set timeLeft 5 }

        # When passed, the person who passed it becomes the new "attacker" contextually for Dead Man's Switch purposes
        set attacker $target
        set target $newTarget
        putquick "PRIVMSG $chan :\00307*HOT POTATO!*\003 $nick tossed the bomb to \002$target\002! \002$timeLeft seconds left!\002"
        
        set timerId [utimer $timeLeft [list [namespace current]::explode 0]]
    }

    proc prime_deadman {nick uhost hand chan arg} {
        variable active; variable target; variable deadmanPrimed; variable timerId; variable timeLeft; variable channel
        
        if {!$active || [string tolower $nick] ne [string tolower $target] || $chan ne $channel} { return }
        if {$deadmanPrimed} {
            putquick "PRIVMSG $chan :Your Dead Man's Switch is already wired up!"
            return
        }

        killutimer $timerId
        
        set deadmanPrimed 1
        set timeLeft [expr {$timeLeft - 5}]
        
        if {$timeLeft <= 0} {
            putquick "PRIVMSG $chan :\00304*OOPS*\003 Wire-tapping took too long! The bomb went off while you were messing with it!"
            explode 1
            return
        }

        putquick "PRIVMSG $chan :\00305*VENGEANCE PRIMED*\003 $nick rigged a Dead Man's Switch! If they explode, their attacker is going down with them. \00304Penalty: -5 seconds off the clock!\003 Remaining: $timeLeft\s"
        
        set timerId [utimer $timeLeft [list [namespace current]::explode 0]]
    }

    proc buy_tool {nick uhost hand chan arg} {
        variable inventory; variable active; variable target
        set item [string tolower [string trim [lindex [split $arg] 0]]]
        set user [string tolower $nick]

        if {$item ne "pliers" && $item ne "shield"} {
            putquick "PRIVMSG $chan :Available tools: \002pliers\002 | \002shield\002"
            return
        }

        set inventory($user,tool) $item
        putquick "PRIVMSG $chan :$nick bought a \002$item\002!"
    }

    proc explode {{forced 0}} {
        variable channel; variable target; variable attacker; variable kickReason; variable correctWire; variable inventory; variable deadmanPrimed
        
        set user [string tolower $target]

        if {$forced == 0} {
            putquick "PRIVMSG $channel :\00304*BOOM*\003 Time's up!"
        }

        add_stat $target "booms"

        # Check for Shield Protection
        if {[info exists inventory($user,tool)] && $inventory($user,tool) eq "shield"} {
            putquick "PRIVMSG $channel :\00311*SHIELD ACTIVATED*\003 $target's blast shield absorbed the explosion! They survive the kick!"
            unset inventory($user,tool)
            reset_bomb
            return
        }
        
        # Kick the target
        putkick $channel $target "$kickReason (Correct wire was: $correctWire)"
        
        # Trigger Dead Man's Switch if primed
        if {$deadmanPrimed && [onchan $attacker $channel]} {
            putquick "PRIVMSG $channel :\00305*CLICK... SNAP!*\003 The Dead Man's Switch triggers! A secondary blast rocks \002$attacker\002!"
            add_stat $attacker "booms"
            putkick $channel $attacker "Dragged into the grave by $target's Dead Man's Switch!"
        }
        
        reset_bomb
    }

    proc reset_bomb {} {
        variable active 0; variable target ""; variable attacker ""; variable correctWire ""; variable timerId ""; variable channel ""; variable deadmanPrimed 0; variable isEmp 0
    }

    proc show_stats {nick uhost hand chan arg} {
        set user [string trim [lindex [split $arg] 0]]
        if {$user eq ""} { set user $nick }

        set plants [get_stat $user "plants"]
        set defuses [get_stat $user "defuses"]
        set booms [get_stat $user "booms"]

        putquick "PRIVMSG $chan :\002Timebomb Stats for $user\002 :: Bombs Planted: $plants | Successfully Defused: $defuses | Blown Up: $booms"
    }

    proc shuffle {list} {
        set len [llength $list]
        while {$len > 0} {
            set n [expr {int(rand() * $len)}]
            lappend result [lindex $list $n]
            set list [lreplace $list $n $n]
            incr len -1
        }
        return $result
    }

    init
    putlog "Loaded EggTimeBomb.tcl v3.0 (EMP & Dead Man's Switch) successfully."
}
