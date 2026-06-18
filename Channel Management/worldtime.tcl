#####################################################################################
#                      ____  ____  _     ____  _     ____ 	                        #
#                     /  _ \/ ___\/ \   /  __\/ \   / ___\	                        #
#                     | / \||    \| |   |  \/|| |   |    \	                        #
#                     | |-||\___ || |_/\|  __/| |_/\\___ |	                        #
#                     \_/ \|\____/\____/\_/   \____/\____/	                        #
#                       asl_pls / irc.underx.org #aslpls    	                    #
##################################################################################### 
#
# Eggdrop World Time Tracker Script by asl_pls @ irc.underx.org #aslpls
# Allows users to check local times around the world in 12-hour AM/PM format.
#
# Commands (Public):
#   !time <country/city>      - Shows current local time for that zone
#
# Management Commands (Requires Global or Local Op 'o'):
#   !settime <name> <tz>      - Adds/Updates a timezone mapping
#   !deltime <name>           - Removes a country/city from mapping
#
###############################################################################

namespace eval ::WorldTime {
    # File to save your custom country mappings so they survive bot restarts
    variable tz_file "data/worldtimes.dat"

    # Operator flag required to add/remove zones ('o|o' = global or channel op)
    variable op_flag "o|o"

    # Internal array to store mapping data
    variable zones
    array set zones {}

    # Bindings
    bind pub - !time [namespace current]::pub_gettime
    bind pub $op_flag !settime [namespace current]::pub_settime
    bind pub $op_flag !deltime [namespace current]::pub_deltime

    # -------------------------------------------------------------------------
    # Core Logic
    # -------------------------------------------------------------------------

    # Command: !time <country/city>
    proc pub_gettime {nick uhost hand chan arg} {
        variable zones
        set target [string tolower [lindex [split $arg] 0]]

        if {$target eq ""} {
            putquick "NOTICE $nick :Usage: !time <country_or_city_name> (e.g., !time japan)"
            return 0
        }

        if {![info exists zones($target)]} {
            putquick "PRIVMSG $chan :Sorry $nick, I don't have time data for '\002$arg\002'. An operator can add it using !settime."
            return 0
        }

        set tz_string $zones($target)
        set now [clock seconds]

        # Fetch the time using Tcl's timezone wrapper safely
        if {[catch {
            # Format pattern: Sunday, June 06, 2026 - 02:30:15 PM (Zone)
            set local_time [clock format $now -format "%A, %B %d, %Y - %I:%M:%S %p (%Z)" -timezone $tz_string]
        } err]} {
            putquick "PRIVMSG $chan :Error reading timezone database for $tz_string."
            return 0
        }

        # Capitalize the first letter of the location for a cleaner readout
        set display_name [string totitle $target]
        putquick "PRIVMSG $chan :🕒 Current time in \002$display_name\002 is: $local_time"
        return 1
    }

    # Command: !settime <name> <timezone_string>
    proc pub_settime {nick uhost hand chan arg} {
        variable zones
        set name [string tolower [lindex [split $arg] 0]]
        set tz [lindex [split $arg] 1]

        if {$name eq "" || $tz eq ""} {
            putquick "NOTICE $nick :Usage: !settime <short_name> <TZ_Database_String>"
            putquick "NOTICE $nick :Example: !settime japan :Asia/Tokyo"
            putquick "NOTICE $nick :Example: !settime ny :America/New_York"
            return 0
        }

        # Test if the timezone string is valid before saving it
        if {[catch {clock format [clock seconds] -timezone $tz} err]} {
            putquick "NOTICE $nick :Error: '$tz' is not a recognized timezone string. Use standard TZ database names (e.g. :Europe/London, :Asia/Dubai)."
            return 0
        }

        set zones($name) $tz
        save_zones
        putquick "PRIVMSG $chan :\002[string totitle $name]\002 has been set to timezone \002$tz\002."
        return 1
    }

    # Command: !deltime <name>
    proc pub_deltime {nick uhost hand chan arg} {
        variable zones
        set name [string tolower [lindex [split $arg] 0]]

        if {$name eq ""} {
            putquick "NOTICE $nick :Usage: !deltime <short_name>"
            return 0
        }

        if {![info exists zones($name)]} {
            putquick "NOTICE $nick :Location '$arg' does not exist in my list."
            return 0
        }

        unset zones($name)
        save_zones
        putquick "PRIVMSG $chan :\002[string totitle $name]\002 has been removed from the world time list."
        return 1
    }

    # Save mapping helper
    proc save_zones {} {
        variable tz_file
        variable zones
        if {![file exists "data"]} { catch {file mkdir "data"} }
        set file_id [open $tz_file w]
        puts $file_id [array get zones]
        close $file_id
    }

    # Load mapping helper
    proc load_zones {} {
        variable tz_file
        variable zones
        if {[file exists $tz_file]} {
            set file_id [open $tz_file r]
            set data [read $file_id]
            close $file_id
            if {$data ne ""} { array set zones $data }
        } else {
            # Seed some defaults on first run if file doesn't exist
            set zones(london) ":Europe/London"
            set zones(tokyo)  ":Asia/Tokyo"
            set zones(ny)     ":America/New_York"
            set zones(dubai)  ":Asia/Dubai"
            save_zones
        }
    }

    # Initialize
    load_zones
    putlog "Loaded: World Time Tracker Script (12h format) by asl_pls @ irc.underx.org #aslpls"
}
