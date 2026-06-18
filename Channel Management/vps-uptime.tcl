#####################################################################################
#                      ____  ____  _     ____  _     ____ 	                        #
#                     /  _ \/ ___\/ \   /  __\/ \   / ___\	                        #
#                     | / \||    \| |   |  \/|| |   |    \	                        #
#                     | |-||\___ || |_/\|  __/| |_/\\___ |	                        #
#                     \_/ \|\____/\____/\_/   \____/\____/	                        #
#                       asl_pls / irc.underx.org #aslpls    	                    #
##################################################################################### 
#                                                                                   #
#         vps_uptime.tcl by asl_pls @ irc.underx.org #aslpls                        #
#         Displays VPS uptime strictly as "Days running" and the "Boot Date"        #
#                                                                                   # 
#         Usage: !uptime                                                            #
#                                                                                   #         
#####################################################################################

set uptime_trigger "!uptime"

bind pub - $uptime_trigger pub_vps_uptime

proc pub_vps_uptime {nick uhost hand chan arg} {
    # 1. Calculate precise days from /proc/uptime
    if {[catch {open "/proc/uptime" r} fp_uptime]} {
        putquick "PRIVMSG $chan :Error: Cannot read system uptime."
        return
    }
    set uptime_seconds [lindex [gets $fp_uptime] 0]
    close $fp_uptime
    
    # Convert total seconds to whole days
    set uptime_days [expr {int($uptime_seconds / 86400)}]

    # 2. Get the boot timestamp from /proc/stat
    if {[catch {open "/proc/stat" r} fp_stat]} {
        putquick "PRIVMSG $chan :Error: Cannot read system stats."
        return
    }
    
    set boot_time 0
    while {[gets $fp_stat line] >= 0} {
        if {[string match "btime *" $line]} {
            set boot_time [lindex $line 1]
            break
        }
    }
    close $fp_stat

    if {$boot_time == 0} {
        putquick "PRIVMSG $chan :Error: Could not determine boot date."
        return
    }

    # Format the boot timestamp into a clean Date (e.g., "Day-Month-Year")
    set boot_date [clock format $boot_time -format "%d-%b-%Y"]

    # 3. Output the clean response to IRC
    # Handles singular/plural for days
    if {$uptime_days == 1} {
        set day_label "day"
    } else {
        set day_label "days"
    }

    putquick "PRIVMSG $chan :\002VPS Status:\002 $uptime_days $day_label | \002Boot Date:\002 $boot_date"
}

putlog "Loaded: VPS Clean Uptime Script (Trigger: $uptime_trigger) by asl_pls @ irc.underx.org"
