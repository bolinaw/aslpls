######################################################################################
##                     ____  ____  _     ____  _     ____ 	                        ##
##                     /  _ \/ ___\/ \   /  __\/ \   / ___\	                        ##
##                    | / \||    \| |   |  \/|| |   |    \	                        ##
##                     | |-||\___ || |_/\|  __/| |_/\\___ |	                        ##
##                    \_/ \|\____/\____/\_/   \____/\____/	                        ##
##                      asl_pls / irc.underx.org #aslpls    	                    ##
##                                                                          06/2026 ##
######################################################################################
# chanlimit_pro.tcl - Advanced Dynamic Channel Limit Script                          #  
# Features: Multi-channel support, flood protection, and real-time activity logging. #
# Nickname / Context: asl_pls | irc.underx.org #aslpls                               # 
######################################################################################
#                                                                                    #
# Steps to Run:                                                                      #  
# Save this full block as a .tcl file (e.g., scripts/chanlimit_pro.tcl).             #
# Add source scripts/chanlimit_pro.tcl to your eggdrop.conf.                         #   
# Rehash your bot (.rehash on the partyline).                                        #
# Turn it on for your target channel by typing: .chanset #yourchannel +dynamiclimit  #
#                                                                                    #
######################################################################################

namespace eval ::ChanLimitPro {
    # --- CONFIGURATION ---
    # Default settings used if not customized per-channel
    variable defaultBuffer 3
    variable defaultMinLimit 10
    
    # Flood settings: If X joins happen in Y seconds, trigger strict mode
    variable floodJoins 5
    variable floodSeconds 3

    # --- INITIALIZATION ---
    # Register a custom channel flag (.chanset #channel +dynamiclimit)
    setudef flag dynamiclimit

    bind join - * [namespace current]::onJoin
    bind part - * [namespace current]::triggerCheck
    bind kick - * [namespace current]::triggerCheck
    bind quit - * [namespace current]::triggerCheck
    bind time - "* * * * *" [namespace current]::timerCheck

    # Track joins for flood control
    variable joinTicks
    if {![info exists joinTicks]} { array set joinTicks {} }

    proc onJoin {nick uhost hand chan} {
        variable floodJoins
        variable floodSeconds
        variable joinTicks

        if {![channel get $chan dynamiclimit]} { return }

        set now [clock seconds]
        lappend joinTicks($chan) $now

        # Clean up old timestamps outside our window
        set validTicks {}
        foreach tick $joinTicks($chan) {
            if {$now - $tick <= $floodSeconds} { lappend validTicks $tick }
        }
        set joinTicks($chan) $validTicks

        # If a flood is detected, enforce a tight limit immediately (0 buffer)
        if {[llength $joinTicks($chan)] >= $floodJoins} {
            putlog "\[ChanLimit\] FLOOD DETECTED in $chan! Locking down buffer immediately."
            enforceLimit $chan 0 
        } else {
            triggerCheck $nick $uhost $hand $chan
        }
    }

    proc triggerCheck {nick uhost hand chan args} {
        if {[channel get $chan dynamiclimit]} {
            # Use a short delay so the internal userlist updates before we recount
            utimer 2 [list [namespace current]::enforceLimit $chan]
        }
    }

    proc timerCheck {min hour day month year} {
        foreach chan [channels] {
            if {[channel get $chan dynamiclimit] && [botisop $chan]} {
                enforceLimit $chan
            }
        }
    }

    proc enforceLimit {chan {overrideBuffer ""}} {
        variable defaultBuffer
        variable defaultMinLimit
        
        if {![validchan $chan] || ! [botisop $chan]} { return }

        # Use override buffer if passed (for flood lockdown), otherwise default
        set buffer [expr {$overrideBuffer ne "" ? $overrideBuffer : $defaultBuffer}]
        
        set currentUsers [llength [chanlist $chan]]
        set targetLimit [expr {$currentUsers + $buffer}]
        
        if {$targetLimit < $defaultMinLimit} { set targetLimit $defaultMinLimit }

        set chanModes [getchanmode $chan]
        set currentLimit 0
        if {[regexp {l} [lindex $chanModes 0]]} {
            set currentLimit [lindex $chanModes end]
        }

        if {$targetLimit != $currentLimit} {
            # Log the change to the partyline and eggdrop.log before executing the mode change
            if {$overrideBuffer eq "0"} {
                putlog "\[ChanLimit\] FLOOD LOCKDOWN on $chan: Changing limit from $currentLimit to $targetLimit (Users: $currentUsers | Buffer: 0)"
            } else {
                putlog "\[ChanLimit\] Adjusting $chan: Changing limit from $currentLimit to $targetLimit (Users: $currentUsers | Buffer: $buffer)"
            }
            
            putquick "MODE $chan +l $targetLimit"
        }
    }
    
    putlog "Loaded ChanLimitPro successfully. Enable in channels using: .chanset #channel +dynamiclimit"
}
