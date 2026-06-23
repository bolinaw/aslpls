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
# 	EggHangman_mod.tcl - Dynamic File-Based Hangman Game with Persistent Top Scores	
#																					
# 	Commands: 																		
#	    !hangman start, !hangman stop, !hangman top                                 
#       !g <letters>, !hangman set <variable> <value>	                             
#																					
###########################################################################################

namespace eval ::Hangman {
    # ---- CONFIGURATION ----
    variable trigger "!"
    variable channels { "#aslpls" } ;# Change this to your channel list
    
    # Paths to text data files relative to the eggdrop binary location
    variable word_file   "scripts/hangman_words.txt"
    variable score_file  "scripts/hangman_scores.dat"

    # ---- INTERNAL GAME STATE ----
    variable active 0
    variable word ""
    variable guessed ""
    variable missed ""
    variable max_misses 6
    variable words [list]

    # Text art representation of the gallows (0 to 6 misses)
    variable gallows [list \
        "   +---+\n   |   |\n       |\n       |\n       |\n       |=========" \
        "   +---+\n   |   |\n   O   |\n       |\n       |\n       |=========" \
        "   +---+\n   |   |\n   O   |\n   |   |\n       |\n       |=========" \
        "   +---+\n   |   |\n   O   |\n  /|   |\n       |\n       |=========" \
        "   +---+\n   |   |\n   O   |\n  /|\\  |\n       |\n       |=========" \
        "   +---+\n   |   |\n   O   |\n  /|\\  |\n  /    |\n       |=========" \
        "   +---+\n   |   |\n   O   |\n  /|\\  |\n  / \\  |\n       |=========" \
    ]

    # ---- BINDINGS ----
    bind pub - "${trigger}hangman" [namespace current]::pub_hangman_router
    bind pub - "${trigger}g"       [namespace current]::pub_guess

    # ---- MAIN ROUTER COMMAND ----
    proc pub_hangman_router {nick uhost hand chan arg} {
        variable channels
        if {[lsearch -nocase $channels $chan] == -1} { return }

        set sub_cmd [string tolower [string trim [lindex $arg 0]]]

        switch -exact -- $sub_cmd {
            "start" {
                pub_start $nick $uhost $hand $chan
            }
            "stop" {
                pub_stop $nick $uhost $hand $chan
            }
            "top" {
                pub_top $nick $uhost $hand $chan
            }
            "set" {
                pub_set $nick $uhost $hand $chan [lrange $arg 1 end]
            }
            default {
                variable trigger
                putquick "PRIVMSG $chan :Usage: ${trigger}hangman \[start | stop | top | set <var> <val>\], or ${trigger}g <letter>"
            }
        }
    }

    # ---- LOAD WORDS FROM FILE ----
    proc load_words {} {
        variable word_file
        variable words
        
        if {![file exists $word_file]} {
            putlog "\[Hangman Error\]: Word file not found at: $word_file"
            return 0
        }

        set words [list]
        set fp [open $word_file r]
        
        while {[gets $fp line] != -1} {
            set clean_word [string trim $line]
            if {$clean_word ne "" && ![string match "#*" $clean_word]} {
                lappend words [string tolower $clean_word]
            }
        }
        close $fp

        if {[llength $words] == 0} {
            putlog "\[Hangman Error\]: Word file is empty or contains no valid words."
            return 0
        }
        return 1
    }

    # ---- PERSISTENT SCORE STORAGE ENGINE ----
    proc load_scores {} {
        variable score_file
        if {![file exists $score_file]} { return [dict create] }
        
        set fp [open $score_file r]
        set data [read $fp]
        close $fp
        
        if {[catch {dict size $data}]} {
            putlog "\[Hangman Warning\]: Score file corrupted. Resetting database."
            return [dict create]
        }
        return $data
    }

    proc save_score {nick} {
        variable score_file
        set scores [load_scores]
        set nick [string tolower $nick]
        
        set current_score 0
        if {[dict exists $scores $nick]} {
            set current_score [dict get $scores $nick]
        }
        
        incr current_score
        dict set scores $nick $current_score
        
        set fp [open $score_file w]
        puts -nonewline $fp $scores
        close $fp
    }

    # ---- START GAME ----
    proc pub_start {nick uhost hand chan} {
        variable active; variable word; variable guessed; variable missed; variable words

        if {$active} {
            variable trigger
            putquick "PRIVMSG $chan :A game is already running! Use ${trigger}g <letter> to play."
            return
        }

        if {![load_words]} {
            putquick "PRIVMSG $chan :Error: Unable to start game. Word database missing or empty."
            return
        }

        set active 1
        set word [lindex $words [expr {int(rand()*[llength $words])}]]
        set guessed ""
        set missed ""

        display_status $chan
    }

    # ---- STOP GAME ----
    proc pub_stop {nick uhost hand chan} {
        variable active; variable word
        if {!$active} {
            putquick "PRIVMSG $chan :There is no active Hangman game running right now."
            return
        }

        set active 0
        putquick "PRIVMSG $chan :Game forcefully stopped by $nick. The word was: \00304$word\003"
    }

    # ---- VARIABLE SET CONFIGURATION COMMAND ----
    proc pub_set {nick uhost hand chan arg} {
        # Optional restriction check example (e.g., only ops or channel masters can use it):
        # if {![isop $nick $chan] && ![matchattr $hand n]} { return }

        set var_name [string tolower [string trim [lindex $arg 0]]]
        set var_val [string trim [lrange $arg 1 end]]

        if {$var_name eq "" || $var_val eq ""} {
            variable trigger
            putquick "PRIVMSG $chan :Usage: ${trigger}hangman set <max_misses | word_file | score_file> <value>"
            return
        }

        switch -exact -- $var_name {
            "max_misses" {
                if {![string is integer -strict $var_val] || $var_val < 1 || $var_val > 6} {
                    putquick "PRIVMSG $chan :Error: max_misses must be an integer between 1 and 6."
                    return
                }
                set ::Hangman::max_misses $var_val
                putquick "PRIVMSG $chan :\[Config\] Variable \002max_misses\002 updated to: $var_val"
            }
            "word_file" {
                set ::Hangman::word_file $var_val
                putquick "PRIVMSG $chan :\[Config\] Variable \002word_file\002 updated to: $var_val"
            }
            "score_file" {
                set ::Hangman::score_file $var_val
                putquick "PRIVMSG $chan :\[Config\] Variable \002score_file\002 updated to: $var_val"
            }
            default {
                putquick "PRIVMSG $chan :Unknown or protected variable. Dynamic configuration allowed for: max_misses, word_file, score_file."
            }
        }
    }

    # ---- PROCESS GUESS ----
    proc pub_guess {nick uhost hand chan arg} {
        variable channels; variable active; variable word; variable guessed; variable missed
        if {[lsearch -nocase $channels $chan] == -1 || !$active} { return }

        set letter [string tolower [string trim [lindex $arg 0]]]
        if {[string length $letter] != 1 || ![string match {[a-z]} $letter]} {
            putquick "PRIVMSG $chan :$nick: Please guess a single letter from A to Z."
            return
        }

        if {[string first $letter $guessed] != -1 || [string first $letter $missed] != -1} {
            putquick "PRIVMSG $chan :$nick: That letter has already been tried!"
            return
        }

        if {[string first $letter $word] != -1} {
            append guessed $letter
            putquick "PRIVMSG $chan :Good guess, $nick!"
        } else {
            append missed $letter
            putquick "PRIVMSG $chan :Sorry $nick, '$letter' is not in the word."
        }

        check_game_over $chan $nick
    }

    # ---- UPDATE & DISPLAY ----
    proc display_status {chan} {
        variable word; variable guessed; variable missed; variable gallows; variable max_misses
        
        set display ""
        for {set i 0} {$i < [string length $word]} {incr i} {
            set char [string index $word $i]
            if {[string first $char $guessed] != -1} {
                append display "$char "
            } else {
                append display "_ "
            }
        }

        set miss_count [string length $missed]
        set art [lindex $gallows $miss_count]
        foreach line [split $art "\n"] {
            putquick "PRIVMSG $chan :$line"
        }

        set formatted_misses [join [split $missed ""] ", "]
        if {$formatted_misses eq ""} { set formatted_misses "None" }

        putquick "PRIVMSG $chan :Word: \002$display\002  |  Misses ($miss_count/$max_misses): \00304$formatted_misses\003"
    }

    # ---- CHECK WIN/LOSS CONDITION ----
    proc check_game_over {chan scoring_nick} {
        variable active; variable word; variable guessed; variable missed; variable max_misses
        
        set won 1
        for {set i 0} {$i < [string length $word]} {incr i} {
            if {[string first [string index $word $i] $guessed] == -1} {
                set won 0
                break
            }
        }

        if {$won} {
            putquick "PRIVMSG $chan :\002CONGRATULATIONS!\002 $scoring_nick solved it! The word was: \00303$word\003"
            save_score $scoring_nick
            set active 0
            return
        }

        if {[string length $missed] >= $max_misses} {
            variable gallows
            set art [lindex $gallows end]
            foreach line [split $art "\n"] { putquick "PRIVMSG $chan :$line" }
            
            putquick "PRIVMSG $chan :\002GAME OVER!\002 You ran out of lives. The word was: \00304$word\003"
            set active 0
            return
        }

        display_status $chan
    }

    # ---- PUBLIC TOP LEADERBOARD COMMAND ----
    proc pub_top {nick uhost hand chan} {
        set scores [load_scores]
        if {[dict size $scores] == 0} {
            putquick "PRIVMSG $chan :The Hangman leaderboard is currently empty!"
            return
        }

        set sorted_list [lsort -stride 2 -index 1 -integer -decreasing $scores]
        
        set rank 1
        set output_items [list]
        
        foreach {player score} $sorted_list {
            lappend output_items "#${rank} \002$player\002 ($score)"
            incr rank
            if {$rank > 10} { break }
        }

        set final_output [join $output_items " | "]
        putquick "PRIVMSG $chan :\[\002HANGMAN TOP PLAYERS\002\] $final_output"
    }
}

putlog "Successfully loaded: EggHangman_mod.tcl by asl_pls irc.underx.org"
