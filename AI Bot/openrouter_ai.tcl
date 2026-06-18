#####################################################################################
#                      ____  ____  _     ____  _     ____ 	                        #
#                     /  _ \/ ___\/ \   /  __\/ \   / ___\	                        #
#                     | / \||    \| |   |  \/|| |   |    \	                        #
#                     | |-||\___ || |_/\|  __/| |_/\\___ |	                        #
#                     \_/ \|\____/\____/\_/   \____/\____/	                        #
#                       asl_pls / irc.underx.org #aslpls    	                    #
##################################################################################### 
#																					#
#     AI IRC Channel Companion Tcl Script											#	
#     Uses OpenRouter's free tier API to talk in an IRC channel						#
#     Includes a 15-minute channel announcement reminder							#
#																					#
#####################################################################################

package require http
package require tls

namespace eval ::AIChat {
    # --- CONFIGURATION ---
    variable apiKey "YOUR-API-KEY-HERE" #openrouter.ai (API)
    variable apiUrl "https://openrouter.ai/api/v1/chat/completions"
    variable model "openrouter/auto"
    
    # Space-separated list of channels where the bot is allowed to talk
    variable activeChans "#underx"
    
    # Prompt defining the bot's behavior in the channel
    variable systemPrompt "You are a helpful, witty, and concise IRC channel companion. Keep responses under 3 sentences, use internet slang sparingly, and adapt to the channel's vibe."
    
    # The announcement message sent every 15 minutes
    variable advertiseMsg "Hey everyone! I'm an AI companion powered by LLMs. Just highlight my name \00304(e.g., %botnick%: hello)\004 to chat with me anytime! About Everything. I'm here to learn."

    # --- BINDINGS & TIMERS ---
    # Responds when the bot is highlighted/pinged in the channel
    bind pub -|- "$::botnick" [namespace current]::handle_pub
    
    # --- FUNCTIONS ---
    proc handle_pub {nick uhost hand chan text} {
        variable activeChans
        
        # Check if the channel is enabled
        if {[lsearch -nocase $activeChans $chan] == -1} { return }
        
        # Clean up the input text (strip bot's nickname if it's a prefix)
        regsub -nocase "^${::botnick}\[: \]*" $text "" cleanText
        if {$cleanText eq ""} { return }
        
        putlog "AI Chat: Request from $nick in $chan -> $cleanText"
        
        # Call the API asynchronously so it doesn't freeze the IRC bot
        fetch_ai_response $chan $nick $cleanText
    }

    proc fetch_ai_response {chan nick prompt} {
        variable apiKey
        variable apiUrl
        variable model
        variable systemPrompt

        # Register TLS for secure HTTPS connections
        ::http::register https 443 [list ::tls::socket -autoservername 1]

        # Escape quotes safely for JSON construction
        set safePrompt [string map {\" \\\" \\ \\\\ \n \ } $prompt]
        set safeSystem [string map {\" \\\" \\ \\\\ \n \ } $systemPrompt]

        # Construct payload manually to avoid deep JSON library requirements
        set payload "\{"
        append payload "\"model\":\"$model\","
        append payload "\"messages\":\["
        append payload "\{\"role\":\"system\",\"content\":\"$safeSystem\"\},"
        append payload "\{\"role\":\"user\",\"content\":\"$safePrompt\"\}"
        append payload "\]\}"

        # Set headers
        set headers [list \
            "Authorization" "Bearer $apiKey" \
            "Content-Type" "application/json" \
            "X-Title" "Eggdrop AI Bot" \
        ]

        # Perform asynchronous HTTP POST request
        if {[catch {
            ::http::geturl $apiUrl \
                -query $payload \
                -headers $headers \
                -timeout 10000 \
                -command [list [namespace current]::http_callback $chan $nick]
        } err]} {
            putlog "AI Chat Error: Failed to initiate connection: $err"
            ::http::unregister https
        }
    }

    proc http_callback {chan nick token} {
        # Clean up TLS handler afterward
        ::http::unregister https

        set status [::http::status $token]
        if {$status ne "ok"} {
            putlog "AI Chat Error: HTTP transfer status: $status"
            ::http::cleanup $token
            return
        }

        set ncode [::http::ncode $token]
        set data [::http::data $token]
        ::http::cleanup $token

        if {$ncode != 200} {
            putlog "AI Chat Error: API returned HTTP code $ncode. Data: $data"
            return
        }

        # Parse JSON output using basic Tcl regex string manipulation
        if {[regexp {"content"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"} $data -> reply]} {
            set reply [string map {\\\" \" \\\\ \\ \\n " " \\t " "} $reply]
            
            foreach line [split $reply "\n"] {
                set trimmed [string trim $line]
                if {$trimmed ne ""} {
                    putserv "PRIVMSG $chan :\00306${nick}\003: $trimmed"
                }
            }
        } else {
            putlog "AI Chat Error: Could not extract response content from JSON payload."
        }
    }

    # --- AUTOMATIC ANNOUNCEMENT LOGIC ---
    proc start_announcement_timer {} {
        variable activeChans
        variable advertiseMsg

        # Swap out %botnick% tag dynamically inside the announcement text
        set formattedMsg [string map [list "%botnick%" $::botnick] $advertiseMsg]

        # Loop through active channels and send the announcement
        foreach chan $activeChans {
            if {[validchan $chan] && [botison $chan]} {
                putserv "PRIVMSG $chan :$formattedMsg"
            }
        }

        # Reschedule the timer to fire again in 15 minutes
        timer 15 [namespace current]::start_announcement_timer
    }
}

# Initialize the 15-minute loop once the script is loaded/rehashed
if {![info exists ::AIChat::timer_running]} {
    set ::AIChat::timer_running 1
    timer 15 [namespace current]::start_announcement_timer
}

putlog "openrouter_ai.tcl AI IRC Companion by asl_pls (with 15m announcement) loaded successfully."
