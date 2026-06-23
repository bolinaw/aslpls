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
#     EggTarot-online.tcl - Eggdrop Tarot Script                                        
#                                                                                    
#     Description: Uses tarotapi.dev to pull random cards. Fixed hanging state bug.    
#     Commands:    !tarot                                                            
#     Requirements: Tcl 8.6+ with 'http', 'tls', and 'json' packages.                
#                                                                                    
###########################################################################################

package require http
package require tls
package require json

namespace eval ::tarotv2 {
    # --- Configuration ---
    variable cmd "!tarot"
    variable api_url "https://tarotapi.dev/api/v1/cards/random?n=1"
    
    # Initialize a secure, local cooldown array
    if {![info exists cooldown]} {
        array set cooldown [list]
    }
    
    catch { ::http::unregister https }
    ::http::register https 443 [list ::tls::socket -autoservername 1]
    
    bind pub - $cmd [namespace current]::pub_tarot

    proc pub_tarot {nick uhost hand chan arg} {
        variable api_url
        variable cooldown
        
        # 1. Enforce cooldown properly
        set now [clock seconds]
        if {[info exists cooldown($chan)]} {
            set diff [expr {$now - $cooldown($chan)}]
            if {$diff < 5} { return 0 }
        }
        set cooldown($chan) $now

        # 2. Local variable resetting to prevent bleeding data from prior hung states
        set name ""
        set meaning ""
        set orientation ""
        set tok ""
        set data ""

#        puthelp "PRIVMSG $chan :? \002$nick\002 shuffles the Rider-Waite deck..."

        if {[catch {
            set headers [list "User-Agent" "EggdropBot/1.8"]
            set tok [::http::geturl $api_url -timeout 5000 -headers $headers]
            
            set status [::http::status $tok]
            set ncode [::http::ncode $tok]
            
            if {$status ne "ok" || $ncode != 200} {
                putserv "PRIVMSG $chan :The deck is jammed (HTTP Status: $status, Code: $ncode). Try again."
                ::http::cleanup $tok
                return 1
            }

            set data [::http::data $tok]
            ::http::cleanup $tok

            if {[catch {set parsed [::json::json2dict $data]} json_err]} {
                putlog "Tarot Script JSON Parsing Error: $json_err"
                putserv "PRIVMSG $chan :Failed to interpret the layout. (JSON Parse Error)"
                return 1
            }
            
            set cards [dict get $parsed cards]
            set card [lindex $cards 0]
            set name [dict get $card name]
            
            # Flip a coin for card orientation
            if {[expr {int(rand()*2)}] == 1} {
                set orientation "\00304\[Reversed\]\003"
                set meaning [dict get $card meaning_rev]
            } else {
                set orientation "\00303\[Upright\]\003"
                set meaning [dict get $card meaning_up]
            }
            
            if {[string length $meaning] > 200} {
                set meaning "[string range $meaning 0 197]..."
            }

            putserv "PRIVMSG $chan :\00306\[Card\]:\003 \002$name\002 | Orientation: $orientation"
            putserv "PRIVMSG $chan :\00314\[Interpretation\]:\003 $meaning"

        } error_msg]} {
            # Safely catch cleanup if tok was opened but never closed during an mid-stream crash
            if {[info exists tok] && $tok ne ""} { catch {::http::cleanup $tok} }
            putlog "Tarot Runtime Error: $error_msg"
            putserv "PRIVMSG $chan :The cards slipped out of my hands. Check bot logs."
        }
        return 1
    }
}

putlog "Loaded: EggTarot-online.tcl Card Reading by asl_pls irc.underx.org #aslpls"
