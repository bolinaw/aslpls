#####################################################################################
#                      ____  ____  _     ____  _     ____ 	                        #
#                     /  _ \/ ___\/ \   /  __\/ \   / ___\	                        #
#                     | / \||    \| |   |  \/|| |   |    \	                        #
#                     | |-||\___ || |_/\|  __/| |_/\\___ |	                        #
#                     \_/ \|\____/\____/\_/   \____/\____/	                        #
#                       asl_pls / irc.underx.org #aslpls    	                    #
#																					#
#####################################################################################
#																					#	
# 	horoscope_aslpls.tcl for Eggdrop												#
# 	Powered by API-Ninjas (api-ninjas.com/api/horoscope)							#
#																					#
# 	Features included:																#
#   	- Resilient TLS 1.2/1.3 handling with spoofed User-Agent					#
#   	- Per-User & Per-Channel Anti-Flood Matrix (Cooldowns)						#
#   	- Automated Daily Channel Announcement (Cron Blast at 08:00 AM)				#
#																					#
#	Command: !horo <sign>															#
#																					#
#####################################################################################

package require http
package require tls
package require json

namespace eval ::horoscope {
    # --- CONFIGURATION ---
    variable trigger "!"
    variable cmd "horo"
    
    # Sign up at api-ninjas.com to get your free API key
    variable api_key "YOUR-API-KEY" #api-ninjas.com

    # Anti-Flood Matrix Settings (in seconds)
    variable cooldown_time 15

    # Daily Announcement Settings
    # Format: "Minute Hour" (e.g., "00 08" for 08:00 AM every day)
    variable blast_time "00 08"
    # List the exact channels to dump the daily overview into
    variable blast_channels {"#aslpls" "#underx"}
    # ---------------------
    
    # Internal tracking arrays for the flood matrix
    variable user_flood
    variable chan_flood
    variable valid_signs {aries taurus gemini cancer leo virgo libra scorpio sagittarius capricorn aquarius pisces}

    # Bindings
    bind pub - "${trigger}${cmd}" ::horoscope::fetch_ninja_horo
    bind time - "${blast_time} * * *" ::horoscope::daily_announcement

    proc fetch_ninja_horo {nick uhost hand chan arg} {
        variable cooldown_time
        variable user_flood
        variable chan_flood
        variable valid_signs

        set now [clock seconds]

        # --- ANTI-FLOOD MATRIX CHECKS ---
        # 1. Per-Channel Check
        if {[info exists chan_flood($chan)] && ($now - $chan_flood($chan)) < $cooldown_time} {
            # Silent drop to protect channel scroll buffer
            return 0
        }
        # 2. Per-User Check
        if {[info exists user_flood($nick)] && ($now - $user_flood($nick)) < $cooldown_time} {
            set remaining [expr {$cooldown_time - ($now - $user_flood($nick))}]
            putserv "NOTICE $nick :Please wait $remaining more seconds before requesting another horoscope."
            return 0
        }

        set sign [string tolower [string trim $arg]]
        if {$sign eq "" || [lsearch -exact $valid_signs $sign] == -1} {
            putserv "PRIVMSG $chan :Usage: !horo <sign> (e.g., !horo leo, !horo scorpio)"
            return 0
        }

        # Update the flood timestamps immediately to lock entry window
        set user_flood($nick) $now
        set chan_flood($chan) $now

        # Trigger the main API engine fetch
        set output [execute_api_fetch $sign]
        if {$output ne ""} {
            putserv "PRIVMSG $chan :$output"
        } else {
            putserv "PRIVMSG $chan :Could not process horoscope query for [string totitle $sign] at this moment."
        }
        
        return 1
    }

    # --- CORE REUSABLE API ENGINE ---
    proc execute_api_fetch {sign} {
        variable api_key
        set sign_cap [string totitle $sign]
        set url "https://api.api-ninjas.com/v1/horoscope?zodiac=${sign}"

        ::http::register https 443 [list ::tls::socket -autoservername 1 -request 0 -require 0 -tls1.2 1 -tls1.3 1]
        
        set headers [list \
            "User-Agent" "EggdropBot/1.9-NinjaHoroscope" \
            "X-Api-Key" "$api_key" \
            "Accept" "application/json" \
        ]

        if {[catch {set tok [::http::geturl $url -timeout 8000 -headers $headers]} err]} {
            return ""
        }

        set status_code [::http::ncode $tok]
        if {[::http::status $tok] ne "ok" || $status_code != 200} {
            ::http::cleanup $tok
            return ""
        }

        set data [::http::data $tok]
        ::http::cleanup $tok

        if {[catch {set parsed [::json::json2dict $data]} json_err]} {
            return ""
        }

        if {[dict exists $parsed horoscope]} {
            set text [dict get $parsed horoscope]
            set date [dict get $parsed date]
            return "\002\00306\[Horoscope\]\003\002 \002$sign_cap\002 ($date): $text"
        }
        
        return ""
    }

    # --- CRON DAILY ANNOUNCEMENT BLAST ---
    proc daily_announcement {min hour day month year} {
        variable blast_channels
        variable valid_signs

        # Grab a quick variety assortment to blast so the channel gets broad coverage
        # (e.g., picking 3 random signs or a set rotation to keep things fresh without spamming all 12)
        set sample_signs [list "aries" "leo" "scorpio"]

        foreach chan $blast_channels {
            if {![validchan $chan] || ![botisop $chan]} { 
                # Skip if eggdrop isn't active/opped inside the channel safety framework
                continue 
            }
            
            putserv "PRIVMSG $chan :\002\00306\[Daily Blast\]\003\002 Good morning! Here are today's featured celestial forecasts:"
            
            foreach sign $sample_signs {
                set report [execute_api_fetch $sign]
                if {$report ne ""} {
                    putserv "PRIVMSG $chan :$report"
                    # Small 1-second delay between automatic dumps to prevent trigger flags on tight servers
                    after 1000 
                }
            }
        }
        return 1
    }
}

putlog "Loaded successfully: Horoscope API Script (With Flood Matrix & Daily Cron)"
