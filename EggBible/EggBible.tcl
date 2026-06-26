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
# EggBible_random.tcl - Auto-posts a random Bible verse every 60 minutes.         
# Uses the free, no-auth api from bible-api.com                              
# HARDENED: Swapped to root parameter layout & added raw fallback debug tracing
#
########################################################################################### 

package require http
package require json

# Attempt to load the TLS package for HTTPS capability
if {[catch {package require tls} tls_error]} {
    putlog "\[Bible Error\] Critical: The 'tls' package is required for HTTPS but is not installed ($tls_error)."
} else {
    # Register the https protocol with the http package using tls sockets
    ::http::register https 443 [list ::tls::socket -tls1 1 -tls1.2 1 -tls1.3 1]
}

namespace eval ::Bible {
    # ---- CONFIGURATION ----
    # Space-separated list of channels to output to
    variable channels "#aslpls #underx"
    
    # Interval in minutes
    variable interval 60
    
    # Translation to use (e.g., web, kjv, asv, bbe)
    variable translation "web"

    # ---- INITIALIZATION ----
    proc init {} {
        variable interval
        # Remove any existing running instance of this specific timer on rehash
        foreach t [utimers] {
            if {[lindex $t 1] eq "::Bible::trigger_auto_read"} {
                killutimer [lindex $t 2]
            }
        }
        # Start the cycling loop (converts minutes to seconds)
        utimer [expr {$interval * 60}] ::Bible::trigger_auto_read
        putlog "EggBible.tcl Auto-Read Script loaded. Interval set to $interval minutes."
    }

    # ---- TIMER TRIGGER ----
    proc trigger_auto_read {} {
        variable interval
        # Schedule the next iteration first
        utimer [expr {$interval * 60}] ::Bible::trigger_auto_read
        
        # Fetch and display the verse
        fetch_verse
    }

    # ---- FETCH LOGIC ----
    proc fetch_verse {} {
        variable translation
        variable channels
        
        # Switched to the alternative root random API endpoint structure
        set url "https://bible-api.com/?random=verse&translation=${translation}"
        
        # Configure http package to handle connections elegantly
        ::http::config -useragent "Eggdrop Bot Bible Reader (Tcl)"
        
        catch {
            set token [::http::geturl $url -timeout 8000]
            set status [::http::status $token]
            set ncode [::http::ncode $token]
            
            if {$status eq "ok" && $ncode == 200} {
                set data [::http::data $token]
                ::http::cleanup $token
                
                # Parse the raw JSON payload
                if {![catch {::json::json2dict $data} dictData]} {
                    
                    # Direct check for root keys or nested fallback structures
                    set targetDict $dictData
                    if {![dict exists $targetDict reference] && [dict exists $targetDict random_verse]} {
                        set targetDict [dict get $dictData random_verse]
                    }
                    
                    # Safe dictionary parsing
                    if {[dict exists $targetDict reference] && [dict exists $targetDict verses]} {
                        set reference [dict get $targetDict reference]
                        set verses [dict get $targetDict verses]
                        
                        # Compile the verse lines into a single formatted string
                        set full_text ""
                        foreach verse $verses {
                            if {[dict exists $verse text]} {
                                set text [dict get $verse text]
                                # Clean up stray newlines or excessive whitespace
                                regsub -all {\s+} $text " " text
                                set full_text [string trim "$full_text $text"]
                            }
                        }
                        
                        # Construct IRC output string with subtle bold styling
                        set output " \002\[Bible\]\002 $reference - $full_text"
                        
                        # Broadcast to target channels
                        foreach chan [split $channels] {
                            putquick "PRIVMSG $chan :$output"
                        }
                    } else {
                        putlog "\[Bible Error\] Layout mismatch. Raw API structure: $data"
                    }
                } else {
                    putlog "\[Bible Error\] Failed to parse incoming JSON payload."
                }
            } else {
                ::http::cleanup $token
                putlog "\[Bible Error\] API HTTP error code: $ncode ($status)"
            }
        } error_msg
        
        if {[info exists error_msg] && $error_msg ne ""} {
            putlog "\[Bible Error\] Connection failure: $error_msg"
        }
    }
}

# Fire up the loop initialization
::Bible::init