#####################################################################################
#                      ____  ____  _     ____  _     ____ 	                        #
#                     /  _ \/ ___\/ \   /  __\/ \   / ___\	                        #
#                     | / \||    \| |   |  \/|| |   |    \	                        #
#                     | |-||\___ || |_/\|  __/| |_/\\___ |	                        #
#                     \_/ \|\____/\____/\_/   \____/\____/	                        #
#                       asl_pls / irc.underx.org #aslpls    	                    #
##################################################################################### 
#             quote_auto.tcl by asl_pls @ irc.underx.org #aslpls			        #
#																                    #
#           Ensure required packages are loaded							            #
#           Prerequisites													        #
#             - Make sure your IRC bot's shell has tls installed. 		            #
#               You can usually install it via your package manager		            #
#																                    #
#####################################################################################

package require http
package require tls

# Register TLS for HTTPS requests
::http::register https 443 [list ::tls::socket -autoservername 1]

namespace eval ::AutoQuoteBot {
    # ----------------------------------------------------
    # Configuration Settings
    # ----------------------------------------------------
    variable targetChan "#aslpls"
    variable apiUrl     "https://zenquotes.io/api/random"
    
    # Set the timer interval in minutes (e.g., 5, 10, 30, 60)
    variable interval   5
    # ----------------------------------------------------

    # Keep track of the elapsed minutes internally
    variable minuteCounter 0

    # Bind to Eggdrop's minute-by-minute internal clock
    bind time - "* * * * *" [namespace current]::timer_check

    proc timer_check {min hour day month year} {
        variable interval
        variable minuteCounter

        # Increment our internal tracker by 1 minute
        incr minuteCounter

        # If we have reached or exceeded the interval, fire the quote
        if {$minuteCounter >= $interval} {
            set minuteCounter 0; # Reset the counter
            fetch_quote
        }
    }

    # Helper procedure to strip HTML tags and decode entities
    proc clean_text {text} {
        # Process standard Tcl backslash escapes first
        set text [subst -nocommands -novariables $text]

        # Strip out any HTML tags entirely
        regsub -all {<[^>]*>} $text "" text

        # Map common HTML entities to clean text characters
        set htmlMap {
            "&#039;" "'"
            "&quot;" "\""
            "&ldquo;" "\""
            "&rdquo;" "\""
            "&lsquo;" "'"
            "&rsquo;" "'"
            "&mdash;" " — "
            "&ndash;" " - "
            "&amp;"   "&"
            "&lt;"    "<"
            "&gt;"    ">"
        }
        
        set text [string map $htmlMap $text]
        
        # Clean up any accidental double spaces or trailing trash
        return [string trim [regsub -all {\s+} $text " "]]
    }

    proc fetch_quote {} {
        variable apiUrl
        variable targetChan

        # Ensure the bot is actually active in the target channel
        if {![validchan $targetChan] || ![onchan $::botnick $targetChan]} {
            return
        }

        # Set a reasonable timeout (8 seconds)
        set token [::http::geturl $apiUrl -timeout 8000]
        set status [::http::status $token]
        
        if {$status ne "ok"} {
            ::http::cleanup $token
            return
        }

        set data [::http::data $token]
        ::http::cleanup $token

        # Tightened RegExp: Look explicitly for "q":"TEXT" and "a":"NAME" keys
        # This safely stops right at the closing quote of the author string.
        if {[regexp {"q":"([^"]+)","a":"([^"]+)"} $data -> quote author]} {
            # Clean up both strings completely
            set quote [clean_text $quote]
            set author [clean_text $author]
            
            # Broadcast the clean quote and pure author name
            putserv "PRIVMSG $targetChan :\"$quote\" — \002$author\002"
        }
    }
    
    putlog "AutoQuote Script loaded. $targetChan by asl_pls @ irc.underx.org #aslpls."
}
