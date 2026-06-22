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
# 	acro_unlimited.tcl - v.3 Automated Infinite Acrophobia Game Script				
#																					
# 	Changes:																		
# 		- Run continuously without manual start commands.							
# 		- Spits out 3 hints at the start of the submission round (spaced 10s apart).
# 		- Automatically cycles to the next game after a cooldown period.			
#																					
# 	Commands:																		
#																					
# 		!acro start   - Starts the continuous loop (Admin only).					
# 		!acro stop    - Stops the continuous loop (Admin only).						
# 		/msg bot acro - Submits your acronym phrase.								
# 		/msg bot vote - Casts your vote.											
#																					
#############################################################################################

namespace eval ::Acro {
    # --- CONFIGURATION ---
    variable channel      "#aslpls" ;# The channel where the game runs
    variable trigger      "!"            ;# Public trigger character
    variable min_len      4              ;# Minimum length of acronyms
    variable max_len      6              ;# Maximum length of acronyms
    
    # Timers (in seconds)
    variable time_submit  50             ;# Total time allowed to submit answers
    variable time_vote    45             ;# Time allowed to vote
    variable delay_game   20             ;# Delay between consecutive games
    variable hint_interval 10            ;# Delay between each hint (10 seconds)
    
    # --- INTERNAL VARIABLES ---
    variable game_state   0              ;# 0=idle/stopped, 1=submitting, 2=voting, 3=cooldown
    variable loop_active  0              ;# 1=Unlimited loop is running, 0=Stopped
    variable letters      ""
    variable submissions  [dict create]
    variable votes        [dict create]
    variable scores       [dict create]
    variable lookup       [list]
    
    variable alphabet [list A B C D E F G H I J K L M N O P Q R S T U V W Y Z]

    # Bindings
    bind pub n [string trim "${trigger}acro"] [namespace current]::pub_control
    bind msg - "acro"                         [namespace current]::msg_submit
    bind msg - "vote"                         [namespace current]::msg_vote
}

# --- CONTROL INTERFACE ---

proc ::Acro::pub_control {nick uhost hand chan arg} {
    variable channel
    variable loop_active
    variable game_state

    # FIXED: string tolower used correctly here
    if {[string tolower $chan] ne [string tolower $channel]} { return }
    set cmd [string tolower [lindex [regexp -all -inline {\S+} $arg] 0]]

    if {$cmd eq "start"} {
        if {$loop_active == 1} {
            putquick "PRIVMSG $channel :\[ACRO\] The automated game loop is already running!"
            return
        }
        set loop_active 1
        putquick "PRIVMSG $channel :\002\00303\[ACRO\]\003\002 Unlimited mode enabled! Starting the engine..."
        start_round
    } elseif {$cmd eq "stop"} {
        set loop_active 0
        set game_state 0
        # Kill any pending utility timers to safely halt execution
        foreach t [utimers] {
            if {[string match "*Acro*" [lindex $t 1]]} { killutimer [lindex $t 2] }
        }
        putquick "PRIVMSG $channel :\002\00304\[ACRO\]\003\002 Automated game loop stopped safely after this phase."
    } else {
        putquick "NOTICE $nick :Usage: ${::Acro::trigger}acro <start|stop>"
    }
}

# --- ENGINE CORE ---

# Generates acronym and schedules hint sequences
proc ::Acro::start_round {} {
    variable channel
    variable game_state
    variable loop_active
    variable letters
    variable alphabet
    variable min_len
    variable max_len
    variable time_submit
    variable submissions
    variable votes
    variable lookup
    variable hint_interval

    if {$loop_active == 0} { return }

    set game_state 1
    set submissions [dict create]
    set votes [dict create]
    set lookup [list]
    
    # Generate random acronym
    set len [expr {int(rand() * ($max_len - $min_len + 1)) + $min_len}]
    set letters ""
    for {set i 0} {$i < $len} {incr i} {
        append letters [lindex $alphabet [expr {int(rand() * [llength $alphabet])}]] " "
    }
    set letters [string trim $letters]

    putquick "PRIVMSG $channel :\002\00303\[ACRO\]\003\002 Round Up! Your Acronym is: \002\00304$letters\003\002"
    putquick "PRIVMSG $channel :Send entries to bot: \002/msg $::botnick acro <your phrase>\002 (Total time: $time_submit\s)"

    # Cascade the hint sequence every 10 seconds
    utimer $hint_interval [list [namespace current]::send_hint 1]
    utimer [expr {$hint_interval * 2}] [list [namespace current]::send_hint 2]
    utimer [expr {$hint_interval * 3}] [list [namespace current]::send_hint 3]

    # Handle the submission expiration window
    utimer $time_submit [namespace current]::end_submissions
}

# Generates contextual aids dynamically 
proc ::Acro::send_hint {hint_num} {
    variable game_state
    variable channel
    variable letters
    
    # Only reveal hints if the game is actively accepting answers
    if {$game_state != 1} { return }

    set clean_letters [string map {" " ""} $letters]
    
    switch -- $hint_num {
        1 {
            putquick "PRIVMSG $channel :\[ACRO Hint 1/3\] Stuck? Remember, your sentence needs exactly \002[string length $clean_letters]\002 words."
        }
        2 {
            set first [string index $clean_letters 0]
            set last [string index $clean_letters end]
            putquick "PRIVMSG $channel :\[ACRO Hint 2/3\] The target phrase must start with \002$first\002 and end with \002$last\002."
        }
        3 {
            # Construct a layout placeholder pattern (e.g., "B... R... B...")
            set structural_hint ""
            foreach char [split $clean_letters ""] { append structural_hint "$char... " }
            putquick "PRIVMSG $channel :\[ACRO Hint 3/3\] Structure breakdown: \002[string trim $structural_hint]\002. HURRY UP!"
        }
    }
}

# --- PLAYBACK INTERACTION (PMs) ---

proc ::Acro::msg_submit {nick uhost hand arg} {
    variable game_state
    variable letters
    variable submissions

    if {$game_state != 1} {
        putquick "NOTICE $nick :Submissions are currently locked."
        return
    }

    set phrase [string trim $arg]
    set clean_letters [string map {" " ""} $letters]
    set words [regexp -all -inline {\S+} $phrase]

    if {[llength $words] != [string length $clean_letters]} {
        putquick "NOTICE $nick :Your entry must have exactly [string length $clean_letters] words."
        return
    }

    for {set i 0} {$i < [llength $words]} {incr i} {
        set first_letter [string toupper [string index [lindex $words $i] 0]]
        set target_letter [string index $clean_letters $i]
        if {$first_letter ne $target_letter} {
            putquick "NOTICE $nick :Word [expr {$i + 1}] ('[lindex $words $i]') does not start with '$target_letter'."
            return
        }
    }

    dict set submissions $nick $phrase
    putquick "NOTICE $nick :Entry accepted: \"$phrase\""
}

proc ::Acro::msg_vote {nick uhost hand arg} {
    variable game_state
    variable lookup
    variable votes

    if {$game_state != 2} {
        putquick "NOTICE $nick :Voting is currently closed."
        return
    }

    set vote_idx [string trim $arg]
    if {![string is integer -strict $vote_idx] || $vote_idx < 1 || $vote_idx > [llength $lookup]} {
        putquick "NOTICE $nick :Invalid choice matrix index."
        return
    }

    incr vote_idx -1
    set target_nick [lindex $lookup $vote_idx]

    if {$target_nick eq $nick} {
        putquick "NOTICE $nick :Self-voting is strictly forbidden!"
        return
    }

    dict set votes $nick $target_nick
    putquick "NOTICE $nick :Vote saved for entry #[expr {$vote_idx + 1}]."
}

# --- TIMED STAGE MANAGEMENT ---

proc ::Acro::end_submissions {} {
    variable game_state
    variable submissions
    variable channel
    variable lookup
    variable time_vote
    variable delay_game
    variable loop_active

    if {$game_state != 1} { return }

    if {[dict size $submissions] < 2} {
        putquick "PRIVMSG $channel :\[ACRO\] Not enough structural entries to compile a voting block. Skipping round..."
        set game_state 3
        if {$loop_active == 1} { utimer $delay_game [namespace current]::start_round }
        return
    }

    set game_state 2
    set nicks [dict keys $submissions]
    while {[llength $nicks] > 0} {
        set idx [expr {int(rand() * [llength $nicks])}]
        lappend lookup [lindex $nicks $idx]
        set nicks [lreplace $nicks $idx $idx]
    }

    putquick "PRIVMSG $channel :\002\00303\[ACRO\]\003\002 Submission window closed. Vote via PM: \002/msg $::botnick vote <number>\002"
    
    set item_num 1
    foreach target_nick $lookup {
        putquick "PRIVMSG $channel :  \002$item_num.\002 [dict get $submissions $target_nick]"
        incr item_num
    }
    
    utimer $time_vote [namespace current]::end_voting
}

proc ::Acro::end_voting {} {
    variable game_state
    variable votes
    variable submissions
    variable channel
    variable scores
    variable lookup
    variable delay_game
    variable loop_active

    if {$game_state != 2} { return }
    set game_state 3

    set tally [dict create]
    foreach nick $lookup { dict set tally $nick 0 }
    dict for {voter target} $votes { dict incr tally $target }

    set max_votes -1
    dict for {nick count} $tally {
        if {$count > $max_votes} { set max_votes $count }
    }

    putquick "PRIVMSG $channel :\002\00303\[ACRO\]\003\002 Final Tally:"
    dict for {nick phrase} $submissions {
        putquick "PRIVMSG $channel :  $nick: \"$phrase\" -> \002[dict get $tally $nick]\002 votes"
    }

    if {$max_votes <= 0} {
        putquick "PRIVMSG $channel :\[ACRO\] No votes registered. No points awarded."
    } else {
        set winners [list]
        dict for {nick count} $tally {
            if {$count == $max_votes} {
                lappend winners $nick
                if {![dict exists $scores $nick]} { dict set scores $nick 0 }
                dict incr scores $nick [expr {3 + $count}]
            }
        }
        
        if {[llength $winners] == 1} {
            putquick "PRIVMSG $channel :\002\00303\[ACRO\]\003\002 \00303Winner:\003 \002[lindex $winners 0]\002 (Total score: [dict get $scores [lindex $winners 0]])"
        } else {
            putquick "PRIVMSG $channel :\002\00303\[ACRO\]\003\002 \00303Tie Winners:\003 \002[join $winners {, }]\002"
        }
    }

    # Automatically fire up the next game loop if loop flag remains true
    if {$loop_active == 1} {
        putquick "PRIVMSG $channel :Next game starting in \002$delay_game\002 seconds..."
        utimer $delay_game [namespace current]::start_round
    }
	
	putlog "acro_unlimited.tcl - Automated Infinite Acrophobia Game Script $targetChan."
	
}