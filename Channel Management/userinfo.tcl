########################################################################################
# userinfo_pro.tcl - Channel & User Info Script
# Features: Idle time, mutual channels, channel flags, and last-seen activity tracker.
# Nickname / Context: asl_pls | irc.underx.org #aslpls                                
########################################################################################
#                                                                                    #
# Steps to Run:                                                                      #  
# Save this full block as a .tcl file (e.g., scripts/userinfo.tcl).             #
# Add source scripts/userinfo.tcl to your eggdrop.conf.                         #   
# Rehash your bot (.rehash on the partyline).                                        #
#                                                                                    #
######################################################################################

bind pub - !info pub_userinfo
bind pubm - * pubm_track_activity

# Global array to track user text and lines
if {![info exists activity_data]} {
    array set activity_data {}
}

# 1. Background tracker to catch when a user last spoke
proc pubm_track_activity {nick uhost hand chan text} {
    global activity_data
    set lnick [string tolower $nick]
    
    # Increment line count
    if {[info exists activity_data($lnick:lines)]} {
        incr activity_data($lnick:lines)
    } else {
        set activity_data($lnick:lines) 1
    }
    
    # Store timestamp and snippet
    set activity_data($lnick:time) [clock seconds]
    set activity_data($lnick:text) [string range $text 0 30]
}

# 2. Main command processor
proc pub_userinfo {nick uhost hand chan arg} {
    global activity_data
    set target [lindex [split $arg] 0]
    
    if {$target == ""} { set target $nick }
    set target [string map {":" "" "," "" " " ""} $target]

    if {! [onchan $target $chan]} {
        putnotc $nick "Error: $target is not in $chan."
        return 0
    }

    # --- Fetch Basic Host & Idle ---
    set gethost [getchanhost $target $chan]
    if {$gethost == ""} { set gethost "Unknown" }
    set fullhost "$target@$gethost"

    set idletime [getchanidle $target $chan]
    set days [expr {$idletime / 1440}]
    set hours [expr {($idletime % 1440) / 60}]
    set minutes [expr {$idletime % 60}]
    
    set d_lbl [expr {$days == 1 ? "day" : "days"}]
    set h_lbl [expr {$hours == 1 ? "hour" : "hours"}]
    set m_lbl [expr {$minutes == 1 ? "minute" : "minutes"}]
    set idle_string "$days $d_lbl, $hours $h_lbl: $minutes $m_lbl"

    # --- Feature 1: Channel Permissions ---
    set status "Regular User"
    
    if {[isop $target $chan]} {
        set status "Operator (@)"
    } elseif {[ishalfop $target $chan]} {
        set status "Half-Op (%)"
    } elseif {[isvoice $target $chan]} {
        set status "Voice (+)"
    }

    # Check for Owner/Founder using bot account flags if matched
    set thand [nick2hand $target $chan]
    if {$thand ne "*" && $thand ne ""} {
        if {[matchattr $thand n] || [matchattr $thand q $chan]} {
            set status "Owner (~)"
        } elseif {[matchattr $thand a $chan]} {
            set status "Admin (&)"
        }
    }

    # --- Feature 2: Last Spoken Tracking ---
    set ltarget [string tolower $target]
    set active_string "Never since bot join"
    
    if {[info exists activity_data($ltarget:time)]} {
        set diff [expr {[clock seconds] - $activity_data($ltarget:time)}]
        set lines $activity_data($ltarget:lines)
        set last_text $activity_data($ltarget:text)
        
        if {$diff < 60} {
            set active_string "$diff secs ago (\"$last_text...\") \[$lines lines today\]"
        } else {
            set diff_mins [expr {$diff / 60}]
            set active_string "$diff_mins mins ago (\"$last_text...\") \[$lines lines today\]"
        }
    }

    # --- Build Mutual Channels List ---
    set mutual_chans [list]
    foreach ch [channels] {
        if {[onchan $target $ch]} { lappend mutual_chans $ch }
    }
    set chan_list [join $mutual_chans ", "]

    # --- Send Formatted Outputs via PM Notice ---
    putnotc $nick "\00303Joined\003: $chan | \00303Nick\003: $target | \00303Host\003: $fullhost | \00303Idle Time\003: $idle_string | \00303Status\003: $status | \00303Last Spoken\003: $active_string | \00303Channel\003: $chan_list"

    return 1
}

putlog "Loaded: Channel & User Info Script v2.3 by asl_pls @ irc.underx.org #aslpls"