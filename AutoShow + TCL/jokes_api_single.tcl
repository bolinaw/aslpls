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
# 		Automated HTTP JSON Joke Loop for Eggdrop                            		
# 		Automatically posts a single-line joke to a channel every 5 minutes. 		
# 		joke_api.tcl by asl_pls @ irc.underx.org #aslpls                    		
#																					
###########################################################################################

package require http
package require tls
package require json

# Register the HTTPS protocol handler
::http::register https 443 [list ::tls::socket -autoservername 1]

# CONFIGURATION
# Set the EXACT channel you want the jokes to post to:
set joke_channel "#aslpls"

# Set how often to post (in minutes)
set joke_interval 30

set jokeurl "https://v2.jokeapi.dev/joke/Any?blacklistFlags=nsfw,religious,political,racist,sexist"
set joke_timeout 5000

# Initialize the loop when the script finishes loading/rehashing
if {![info exists joke_loop_started]} {
    set joke_loop_started 1
    utimer 10 [list auto_getjsonjoke]
}

proc auto_getjsonjoke {} {
    global jokeurl joke_timeout joke_channel joke_interval

    # 1. Schedule the NEXT joke to run in X minutes
    timer $joke_interval [list auto_getjsonjoke]

    # 2. Safety Check: Only fetch if the bot is actually sitting in the channel
    if {![validchan $joke_channel] || ![botonchan $joke_channel]} {
        putlog "Joke Timer: Skipping joke, I am not currently in $joke_channel"
        return
    }

    # 3. Configure headers to ask for JSON data
    set headers [list "User-Agent" "Eggdrop IRC Bot Joke Script" "Accept" "application/json"]

    # 4. Safely make the HTTP request
    if {[catch {
        set tok [::http::geturl $jokeurl -headers $headers -timeout $joke_timeout]
    } err]} {
        putlog "Joke Timer Error: $err"
        return
    }

    # Check the HTTP status
    set status [::http::status $tok]
    if {$status ne "ok"} {
        putlog "Joke Timer HTTP Error: $status"
        ::http::cleanup $tok
        return
    }

    # Grab the raw JSON string data
    set raw_json [::http::data $tok]
    ::http::cleanup $tok

    # Parse the JSON string into a Tcl dictionary
    if {[catch {
        set joke_dict [::json::json2dict $raw_json]
    } err]} {
        putlog "Joke Timer: Failed to parse JSON data."
        return
    }

    # 5. Extract, flatten, and print the joke to the channel on one line
    if {[dict exists $joke_dict "type"]} {
        set type [dict get $joke_dict "type"]
        set dynamic_joke ""
        
        if {$type eq "single"} {
            set dynamic_joke [dict get $joke_dict "joke"]
        } elseif {$type eq "twopart"} {
            set setup [dict get $joke_dict "setup"]
            set delivery [dict get $joke_dict "delivery"]
            # Combine setup and delivery horizontally with a clean separator
            set dynamic_joke "$setup \00304-->\003 $delivery"
        }

        if {$dynamic_joke ne ""} {
            # Strip out any actual newline or carriage return characters just in case
            set dynamic_joke [string map {"\r" "" "\n" " "} [string trim $dynamic_joke]]
            putquick "PRIVMSG $joke_channel :\[\00304Joke\003\00303Time\003\]: $dynamic_joke"
        }
    }
}

putlog "Loaded successfully: Automated joke_api.tcl by asl_pls @ irc.underx.org"
