#####################################################################################
#                      ____  ____  _     ____  _     ____ 	                        #
#                     /  _ \/ ___\/ \   /  __\/ \   / ___\	                        #
#                     | / \||    \| |   |  \/|| |   |    \	                        #
#                     | |-||\___ || |_/\|  __/| |_/\\___ |	                        #
#                     \_/ \|\____/\____/\_/   \____/\____/	                        #
#                       asl_pls / irc.underx.org #aslpls    	                    #
#####################################################################################                                                                              
#                                                                                   #
# Advanced Eggdrop Weather Script with AQI, Forecasts, & Automated Channel Timers   #
# Triggers: !weather <city>   |   !forecast <city>    |    openweathermap.org (API) #
#                                                                                   #
#####################################################################################

package require http
package require tls
package require json

namespace eval ::ircweather {
    # --- CONFIGURATION ---
    variable apiKey "YOUR-API-KEY-HERE" #openweathermap.org
    variable units "metric" ;# "metric" (°C, m/s) or "imperial" (°F, mph)

    # --- AUTOMATIC CHANNEL BROADCAST CONFIG ---
    variable autoShow 1          ;# 1 = Enabled, 0 = Disabled
    variable autoInterval 120    ;# Frequency in minutes (e.g., 60, 120, 180)
    variable autoLocation "Dubai, AE" ;# Default location for the automated updates
    variable autoChannels {"#aslpls" "#familyfeud"} ;# List of channels to announce in

    # Register HTTPS protocol handler
    ::http::register https 443 [list ::tls::socket -autoservername 1]

    # Binds for public channel commands
    bind pub - !weather [namespace current]::pub_weather
    bind pub - !forecast [namespace current]::pub_forecast
    
    # Initialize the background timer loop if enabled
    bind evnt - init-server [namespace current]::initTimer

    # Map OpenWeather AQI integers to IRC color-coded strings
    proc getAqiString {aqi_val} {
        switch -- $aqi_val {
            1 { return "\00303Good\003" }
            2 { return "\00309Fair\003" }
            3 { return "\00311Moderate\003" }
            4 { return "\00307Poor\003" }
            5 { return "\00304Hazardous!\003" }
            default { return "Unknown" }
        }
    }

    # Helper function to fire safe HTTP GET requests
    proc apiCall {url} {
        if {[catch {
            set tok [::http::geturl $url -timeout 5000]
            set status [::http::status $tok]
            set data [::http::data $tok]
            ::http::cleanup $tok
        } err]} { return "" }
        if {$status ne "ok"} { return "" }
        return $data
    }

    # Build the current weather string
    proc buildWeatherString {query} {
        variable apiKey
        variable units

        set encodedQuery [::http::formatQuery q $query]
        set wUrl "https://api.openweathermap.org/data/2.5/weather?${encodedQuery}&units=${units}&appid=${apiKey}"
        set wData [apiCall $wUrl]

        if {$wData eq "" || [catch {set parsed [::json::json2dict $wData]}]} { return "" }
        if {[dict exists $parsed cod] && [dict get $parsed cod] != 200} { return "" }

        set cityName [dict get $parsed name]
        set country [dict get $parsed sys country]
        set temp [expr {round([dict get $parsed main temp])}]
        set feels [expr {round([dict get $parsed main feels_like])}]
        set humidity [dict get $parsed main humidity]
        set desc [dict get [lindex [dict get $parsed weather] 0] description]
        
        set lat [dict get $parsed coord lat]
        set lon [dict get $parsed coord lon]
        set aqiUrl "https://api.openweathermap.org/data/2.5/air_pollution?lat=${lat}&lon=${lon}&appid=${apiKey}"
        set aqiData [apiCall $aqiUrl]
        set aqiStr "N/A"
        
        if {$aqiData ne "" && ![catch {set aqiParsed [::json::json2dict $aqiData]}]} {
            set aqiVal [dict get [lindex [dict get $aqiParsed list] 0] main aqi]
            set aqiStr [getAqiString [expr {round($aqiVal)}]]
        }

        set uSign [expr {$units eq "metric" ? "°C" : "°F"}]
        set b "\002"

        set out "\00306Current Weather\003 for \00303${cityName}, ${country}\003: [string totitle $desc] | "
        append out "Temp: ${b}${temp}${uSign}${b} (Feels: ${feels}${uSign}) | "
        append out "Humidity: ${humidity}% | Air Quality: ${aqiStr}"
        return $out
    }

    # Build the 3-day forecast string
    proc buildForecastString {query} {
        variable apiKey
        variable units

        set encodedQuery [::http::formatQuery q $query]
        set fUrl "https://api.openweathermap.org/data/2.5/forecast?${encodedQuery}&units=${units}&appid=${apiKey}"
        set fData [apiCall $fUrl]

        if {$fData eq "" || [catch {set parsed [::json::json2dict $fData]}]} { return "" }
        if {[dict exists $parsed cod] && [dict get $parsed cod] != 200} { return "" }

        set cityName [dict get $parsed city name]
        set country [dict get $parsed city country]
        set forecastList [dict get $parsed list]

        set out "\003043-Day Forecast\003 for \00312${cityName}, ${country}:\003"
        set targetIndices {8 16 24}
        set stepCount 1

        foreach idx $targetIndices {
            if {[llength $forecastList] > $idx} {
                set chunk [lindex $forecastList $idx]
                set fTemp [expr {round([dict get $chunk main temp])}]
                set fDesc [dict get [lindex [dict get $chunk weather] 0] main]
                set fHum [dict get $chunk main humidity]
                set uSign [expr {$units eq "metric" ? "°C" : "°F"}]
                
                if {$stepCount == 1} {
                    set dayLabel "Tomorrow"
                } else {
                    set epochTime [dict get $chunk dt]
                    set dayLabel [clock format $epochTime -format "%A"]
                }
                append out " | \00303${dayLabel}:\003 ${fTemp}${uSign} ($fDesc, ${fHum}% Hum)"
                incr stepCount
            }
        }
        return $out
    }

    # TRIGGER 1: Manual !weather
    proc pub_weather {nick uhost hand chan arg} {
        set query [string trim $arg]
        if {$query eq ""} {
            puthelp "PRIVMSG $chan :Usage: !weather <city,country> or <zipcode>"
            return
        }
        set output [buildWeatherString $query]
        if {$output ne ""} {
            puthelp "PRIVMSG $chan :$output"
        } else {
            puthelp "PRIVMSG $chan :Error fetching or parsing weather metrics."
        }
    }

    # TRIGGER 2: Manual !forecast
    proc pub_forecast {nick uhost hand chan arg} {
        set query [string trim $arg]
        if {$query eq ""} {
            puthelp "PRIVMSG $chan :Usage: !forecast <city,country> or <zipcode>"
            return
        }
        set output [buildForecastString $query]
        if {$output ne ""} {
            puthelp "PRIVMSG $chan :$output"
        } else {
            puthelp "PRIVMSG $chan :Error fetching or parsing forecast maps."
        }
    }

    # The Background Loop Processor
    proc initTimer {type} {
        variable autoShow
        if {$autoShow} {
            # Kill any orphaned script instances before starting a clean one
            foreach t [utimers] {
                if {[lindex $t 1] eq "[namespace current]::runAutoShow"} {
                    killutimer [lindex $t 2]
                }
            }
            runAutoShow
        }
    }

    proc runAutoShow {} {
        variable autoShow
        variable autoInterval
        variable autoLocation
        variable autoChannels

        if {!$autoShow} { return }

        set current [buildWeatherString $autoLocation]
        set forecast [buildForecastString $autoLocation]

        foreach chan $autoChannels {
            if {[validchan $chan] && [botisop $chan] || [file exists $::userfile]} {
                if {$current ne ""}  { puthelp "PRIVMSG $chan :$current" }
                if {$forecast ne ""} { puthelp "PRIVMSG $chan :$forecast" }
            }
        }

        # Re-schedule the next execution window (Interval converted from minutes to seconds)
        utimer [expr {$autoInterval * 60}] [namespace current]::runAutoShow
    }
}

# Check if the bot is already linked to a server during a manual .rehash
if {[info exists ::serveraddress] && $::serveraddress ne ""} { 
    ::ircweather::initTimer "init" 
}

putlog "Loaded successfully: Weather_asl.tcl script by asl_pls @ irc.underx.org #aslpls."
