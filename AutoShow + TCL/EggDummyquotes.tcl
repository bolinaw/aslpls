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
# quote_dummyjson.tcl - Eggdrop script to fetch random quotes via DummyJSON API		
# Requires: tls and http packages													
#																					
# Command: !quote 	/  Autoshow every 10 minutes									
#																					
###########################################################################################

package require http
package require tls

namespace eval ::ircquotes {
    # Configuration
    variable cmd "!quote"
    variable api_url "https://dummyjson.com/quotes/random"
    
    # Target channels for the automated quotes (separated by spaces)
    variable channels "#aslpls"
    
    # Timer interval in minutes
    variable interval 10

    # Bindings
    bind pub - $cmd ::ircquotes::pub_quote
    bind time - "* * * * *" ::ircquotes::timer_quote

    # Public command trigger
    proc pub_quote {nick uhost hand chan arg} {
        set quote_msg [fetch_quote_data]
        if {$quote_msg ne ""} {
            putquick "PRIVMSG $chan :$quote_msg"
        } else {
            putquick "PRIVMSG $chan :Error fetching quote from DummyJSON. Try again later."
        }
    }

    # Automated timer trigger
    proc timer_quote {min hour day month year} {
        variable interval
        variable channels
        global botnick

        # Check if the current minute is a multiple of the interval
        if {[expr {[string trimleft $min 0] % $interval}] == 0 || $min eq "00"} {
            set quote_msg [fetch_quote_data]
            if {$quote_msg ne ""} {
                foreach chan [split $channels] {
                    # Corrected: Using validchan and onchan with the global botnick
                    if {[validchan $chan] && [onchan $botnick $chan]} {
                        putquick "PRIVMSG $chan :$quote_msg"
                    }
                }
            }
        }
    }

    # Core function to fetch and parse data from DummyJSON
    proc fetch_quote_data {} {
        variable api_url
        
        # Register TLS for HTTPS requests
        ::http::register https 443 [list ::tls::socket -autoservername 1]

        # Fetch the data from the API
        catch {
            set token [::http::geturl $api_url -timeout 5000]
            set data [::http::data $token]
            ::http::cleanup $token
        } error_msg

        if {[info exists error_msg] && $error_msg ne ""} {
            return ""
        }

        # Match JSON schema: {"id":X, "quote":"...", "author":"..."}
        if {[regexp {"quote":"([^"]+)"} $data -> content] && [regexp {"author":"([^"]+)"} $data -> author]} {
            # Standardize escaped JSON slashes/quotes
            set content [string map {\\\" \" \\\\ \\} $content]
            return "\"$content\" — \002$author\002"
        } else {
            return ""
        }
    }
}

putlog "Loaded: quote_dummyjson.tcl Script / asl_pls irc.underx.org #aslpsl (Trigger: !quote | Interval: 10m)"
