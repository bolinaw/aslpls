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
# EggGridrun_beta.tcl - A Unique Cyberpunk Grid Hacking Game for Eggdrop				
# Version: 1.1.0																	
# Features: Added flat-file score persistence and a !top high scores leaderboard.	
#																					
#																								
###########################################################################################

namespace eval ::GridRun {
    variable version "1.1.0"
    variable channel "#aslpls"        ;# Change to your game channel
    variable save_file "scripts/gridrun_scores.txt" ;# Path to save player credits
    variable grid_size 5
    
    # Game State Variables
    variable grid
    variable alarm 0
    variable active 0
    
    # Bindings
    bind pub -|- !gridrun ::GridRun::cmd_start
    bind pub -|- !scan    ::GridRun::cmd_scan
    bind pub -|- !status  ::GridRun::cmd_status
    bind pub -|- !top     ::GridRun::cmd_top

    # Helper: Load all player scores from file into a dict
    proc load_scores {} {
        variable save_file
        set scores [dict create]
        if {![file exists $save_file]} {
            return $scores
        }
        set fp [open $save_file r]
        while {[gets $fp line] >= 0} {
            if {[regexp {^(\S+)\s+(\d+)} $line -> user credits]} {
                dict set scores [string tolower $user] [list $user $credits]
            }
        }
        close $fp
        return $scores
    }

    # Helper: Save player scores back to file
    proc save_scores {scores} {
        variable save_file
        # Ensure directory exists
        set dir [file dirname $save_file]
        if {![file exists $dir]} { file mkdir $dir }
        
        set fp [open $save_file w]
        dict for {key info} $scores {
            lassign $info user credits
            puts $fp "$user $credits"
        }
        close $fp
    }

    # Helper: Add credits to a specific user
    proc add_credits {username amount} {
        set scores [load_scores]
        set key [string tolower $username]
        
        if {[dict exists $scores $key]} {
            lassign [dict get $scores $key] user current_credits
            set new_credits [expr {$current_credits + $amount}]
        } else {
            set user $username
            set new_credits $amount
        }
        
        dict set scores $key [list $user $new_credits]
        save_scores $scores
        return $new_credits
    }

    # Initialize or reset the grid
    proc init_grid {} {
        variable grid
        variable grid_size
        variable alarm 0
        variable active 1
        
        array unset grid
        set node_types [list "Credit Cache" "Empty" "Firewall" "Empty" "ICE Trap" "Credit Cache" "Empty"]
        
        for {set x 1} {$x <= $grid_size} {incr x} {
            for {set y 1} {$y <= $grid_size} {incr y} {
                set r [expr {int(rand()*[llength $node_types])}]
                set type [lindex $node_types $r]
                set grid($x,$y,type) $type
                set grid($x,$y,status) "Unscanned"
            }
        }
    }

    # Convert Letter-Number (A1, B3) to Coordinates
    proc parse_coords {coord_str} {
        if {![regexp -nocase {^([a-e])([1-5])$} $coord_str -> col row]} {
            return ""
        }
        set col_map [dict create a 1 b 2 c 3 d 4 e 5]
        set x [dict get $col_map [string tolower $col]]
        return [list $x $row]
    }

    # Command: Start Game
    proc cmd_start {nick uhost hand chan arg} {
        variable channel
        variable active
        if {[string tolower $chan] != [string tolower $channel]} return
        
        if {$active} {
            putquick "PRIVMSG $chan :\00304\[GridRun\]\003 A mainframe intrusion is already in progress! Use !status."
            return
        }
        
        init_grid
        putquick "PRIVMSG $chan :\00311\[GridRun\]\003 \002NEW MAINFRAME DETECTED.\002 A 5x5 grid (A1 to E5) has been initialized."
        putquick "PRIVMSG $chan :\00311\[GridRun\]\003 Use \002!scan <coords>\002 (e.g., !scan B3) to probe the network. Watch the Alarm level!"
    }

    # Command: Scan Node
    proc cmd_scan {nick uhost hand chan arg} {
        variable channel
        variable active
        variable grid
        variable alarm
        
        if {[string tolower $chan] != [string tolower $channel]} return
        if {!$active} {
            putquick "PRIVMSG $chan :\00304\[GridRun\]\003 No active mainframe. Type \002!gridrun\002 to boot a session."
            return
        }
        
        set coords [parse_coords [string trim $arg]]
        if {$coords eq ""} {
            putquick "PRIVMSG $chan :\00304\[GridRun\]\003 Invalid coordinates, $nick. Use format A1 through E5."
            return
        }
        
        lassign $coords x y
        set clean_arg [string toupper [string trim $arg]]
        
        if {$grid($x,$y,status) eq "Scanned"} {
            putquick "PRIVMSG $chan :\00306\[GridRun\]\003 Node $clean_arg has already been breached. Content: $grid($x,$y,type)."
            return
        }
        
        # Reveal Node
        set type $grid($x,$y,type)
        set grid($x,$y,status) "Scanned"
        
        switch -- $type {
            "Credit Cache" {
                set credits [expr {int(rand()*400) + 100}]
                set total [add_credits $nick $credits]
                putquick "PRIVMSG $chan :\00309\[GridRun\]\003 SUCCESS! $nick scanned $clean_arg and extracted \002$credits\002 credits! (Total: $total)"
                incr alarm 5
            }
            "Empty" {
                putquick "PRIVMSG $chan :\00314\[GridRun\]\003 Node $clean_arg is empty. Ghost in the machine."
                incr alarm 2
            }
            "Firewall" {
                putquick "PRIVMSG $chan :\00304\[GridRun\]\003 WARNING! $nick hit a Firewall at $clean_arg. System alert triggered!"
                incr alarm 20
            }
            "ICE Trap" {
                putquick "PRIVMSG $chan :\00304\[GridRun\]\003 DANGER! Counter-intrusion ICE triggered at $clean_arg! System lockdown imminent!"
                incr alarm 40
            }
        }
        
        # Check Fail Condition
        if {$alarm >= 100} {
            putquick "PRIVMSG $chan :\00304\[GridRun\]\003 \002!!! LOCKDOWN !!!\002 System trace reached 100%. The mainframe booted you out. Session terminated."
            set active 0
        } else {
            putquick "PRIVMSG $chan :\00311\[GridRun\]\003 Current System Alarm Trace: \002$alarm%\002"
        }
    }

    # Command: Status
    proc cmd_status {nick uhost hand chan arg} {
        variable channel
        variable active
        variable alarm
        if {[string tolower $chan] != [string tolower $channel]} return
        
        if {!$active} {
            putquick "PRIVMSG $chan :\[GridRun\] Mainframe is offline. Type !gridrun to initiate an exploit."
        } else {
            putquick "PRIVMSG $chan :\[GridRun\] Intrusion Active | Trace Level: \002$alarm%\002 | Use !scan to advance."
        }
    }

    # Command: Leaderboard
    proc cmd_top {nick uhost hand chan arg} {
        variable channel
        if {[string tolower $chan] != [string tolower $channel]} return
        
        set scores [load_scores]
        if {[dict size $scores] == 0} {
            putquick "PRIVMSG $chan :\00311\[GridRun\]\003 The data registers are empty. No high scores recorded yet."
            return
        }
        
        # Flatten and sort by credits descending
        set sort_list {}
        dict for {key info} $scores {
            lappend sort_list $info
        }
        
        # Custom sorting logic by index 1 (credits) descending
        set sorted [lsort -integer -decreasing -index 1 $sort_list]
        
        putquick "PRIVMSG $chan :\00311\[GridRun\]\003 \002=== TOP ELITE DECKERS ===\002"
        set rank 1
        foreach player_info [lrange $sorted 0 4] { ;# Top 5 players
            lassign $player_info user credits
            putquick "PRIVMSG $chan :\00311\[GridRun\]\003 Rank $rank: \00309$user\003 - \002$credits\002 credits"
            incr rank
        }
    }
}

putlog "Loaded GridRun IRC Game Script v$::GridRun::version safely with persistence."
