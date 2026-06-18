#####################################################################################
#                      ____  ____  _     ____  _     ____ 	                        #
#                     /  _ \/ ___\/ \   /  __\/ \   / ___\	                        #
#                     | / \||    \| |   |  \/|| |   |    \	                        #
#                     | |-||\___ || |_/\|  __/| |_/\\___ |	                        #
#                     \_/ \|\____/\____/\_/   \____/\____/	                        #
#                       asl_pls / irc.underx.org #aslpls    	                    #
##################################################################################### 
# channel_monitor.tcl by asl_pls @ irc.underx.org #aslpls
# Monitors a specific channel's users, status, hosts, idle times, and writes an HTML file.
#####################################################################################

namespace eval ::ChanMonitor {
    # CONFIGURATION
    variable target_chan "#underx" ;# <-- CHANGE THIS to the specific channel you want to monitor
    variable datafile "data/chan_monitor.dat"
    variable check_interval 5           ;# How often (in minutes) to update idle times
    variable html_filepath "/home/stat/public_html/irc_stats.html"

    # Initialize database array
    variable db
    if {![info exists db]} { array set db [list] }

    # Bindings
    bind join - * [namespace current]::on_join
    bind part - * [namespace current]::on_part
    bind quit - * [namespace current]::on_quit
    bind nick - * [namespace current]::on_nick
    bind sign - * [namespace current]::on_sign

    proc init {} {
        variable check_interval
        variable target_chan
        
        putlog "ChanMonitor: Initializing target monitoring for $target_chan..."
        load_data
        
        # Start periodic data updater
        if {[string match "" [timers]]} {
            timer $check_interval [namespace current]::check_and_save
        }
        
        # Force a check and save on startup
        check_and_save
    }

    # Format idle time from seconds to "X day, Y hr"
    proc format_idle {seconds} {
        set days [expr {$seconds / 86400}]
        set hours [expr {($seconds % 86400) / 3600}]
        return "${days} day, ${hours} hr"
    }

    # Helper function to check if the channel matches our target
    proc is_target {chan} {
        variable target_chan
        return [string equal -nocase $target_chan $chan]
    }

    proc on_join {nick uhost hand chan} {
        if {![is_target $chan]} { return }
        variable db
        set lnick [string tolower $nick]
        set db($lnick,nick) $nick
        set db($lnick,host) $uhost
        set db($lnick,status) "online"
        set db($lnick,last_seen) [clock seconds]
        set db($lnick,idle) [format_idle 0]
        save_and_update
    }

    proc on_part {nick uhost hand chan msg} {
        if {![is_target $chan]} { return }
        variable db
        set lnick [string tolower $nick]
        set db($lnick,status) "offline"
        set db($lnick,last_seen) [clock seconds]
        save_and_update
    }

    proc on_quit {nick uhost hand msg} {
        variable db
        set lnick [string tolower $nick]
        
        # Because QUIT handles network-wide events, check if user was tracked online first
        if {[info exists db($lnick,status)] && $db($lnick,status) == "online"} {
            set db($lnick,status) "offline"
            set db($lnick,last_seen) [clock seconds]
            save_and_update
        }
    }

    proc on_nick {nick uhost hand chan newnick} {
        if {![is_target $chan]} { return }
        variable db
        set old_lnick [string tolower $nick]
        set new_lnick [string tolower $newnick]

        set db($new_lnick,nick) $newnick
        set db($new_lnick,host) $uhost
        set db($new_lnick,status) "online"
        set db($new_lnick,last_seen) [clock seconds]
        
        if {[info exists db($old_lnick,idle)]} {
            set db($new_lnick,idle) $db($old_lnick,idle)
        } else {
            set db($new_lnick,idle) [format_idle 0]
        }

        set db($old_lnick,status) "offline"
        set db($old_lnick,last_seen) [clock seconds]
        save_and_update
    }

    proc on_sign {nick reason} {
        save_and_update
    }

    # Scans ONLY the targeted channel
    proc check_and_save {} {
        variable db
        variable target_chan
        variable check_interval
        set found_users 0

        # FIXED: Using validchan and ischanjoined to see if the bot is in the room
        if {[validchan $target_chan] && [ischanjoined $target_chan]} {
            foreach nick [chanlist $target_chan] {
                set lnick [string tolower $nick]
                incr found_users
                set idle_secs [getchanidle $nick $target_chan]
                set idle_seconds [expr {$idle_secs * 60}]
                
                set db($lnick,nick) $nick
                set db($lnick,host) [getchanhost $nick $target_chan]
                set db($lnick,status) "online"
                set db($lnick,idle) [format_idle $idle_seconds]
                set db($lnick,last_seen) [clock seconds]
            }
        } else {
            putlog "ChanMonitor WARNING: Bot is not currently active in the target channel $target_chan"
        }
        
        putlog "ChanMonitor: Active scan found $found_users online users in $target_chan."
        save_and_update
        
        timer $check_interval [namespace current]::check_and_save
    }

    proc save_and_update {} {
        save_data
        write_html_page
    }

    proc save_data {} {
        variable db ; variable datafile
        set dir [file dirname $datafile]
        if {![file exists $dir]} { file mkdir $dir }

        if {[catch {
            set fileId [open $datafile w]
            foreach {key value} [array get db] { puts $fileId [list $key $value] }
            close $fileId
            putlog "ChanMonitor: Data successfully saved."
        } err]} {
            putlog "ChanMonitor ERROR: Cannot write database file: $err"
        }
    }

    proc load_data {} {
        variable db ; variable datafile
        if {![file exists $datafile]} { return }
        
        if {[catch {
            set fileId [open $datafile r]
            while {[gets $fileId line] >= 0} {
                if {[llength $line] == 2} { set db([lindex $line 0]) [lindex $line 1] }
            }
            close $fileId
            putlog "ChanMonitor: Database loaded."
        } err]} {
            putlog "ChanMonitor WARNING: Error reading database file: $err"
        }
    }

    proc write_html_page {} {
        variable db
        variable html_filepath
        variable target_chan
        
        set html_dir [file dirname $html_filepath]
        if {![file exists $html_dir]} { catch {file mkdir $html_dir} }

        set table_rows ""
        set nicks [list]
        foreach key [array names db "*,nick"] {
            lappend nicks [lindex [split $key ","] 0]
        }
        set nicks [lsort -unique $nicks]

        if {[llength $nicks] == 0} {
            set table_rows "<tr><td colspan='5' class='text-center text-muted'>No users monitored yet in $target_chan.</td></tr>"
        } else {
            foreach lnick $nicks {
                set nick $db($lnick,nick)
                set host $db($lnick,host)
                set status $db($lnick,status)
                set idle $db($lnick,idle)
                set last_seen [clock format $db($lnick,last_seen) -format "%Y-%m-%d %H:%M:%S"]
                
                if {$status == "online"} {
                    set status_html "<span class='badge bg-success'>Online</span>"
                } else {
                    set status_html "<span class='badge bg-secondary'>Offline</span>"
                }

                append table_rows "
                <tr>
                    <td><strong>$nick</strong></td>
                    <td><code class='text-muted'>$host</code></td>
                    <td>$status_html</td>
                    <td><span class='text-primary fw-bold'>$idle</span></td>
                    <td><small class='text-muted'>$last_seen</small></td>
                </tr>"
            }
        }

        set html "<!DOCTYPE html>
<html lang='en'>
<head>
    <meta charset='UTF-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <title>IRC Channel Presence Monitor ($target_chan)</title>
    <link href='https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css' rel='stylesheet'>
    <style>
        body { background-color: #f8f9fa; font-family: sans-serif; }
        .monitor-card { margin-top: 30px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); border-radius: 8px; }
    </style>
</head>
<body>
    <div class='container'>
        <div class='card monitor-card'>
            <div class='card-header bg-dark text-white d-flex justify-content-between align-items-center'>
                <h4 class='mb-0'>User Monitor for <span class='text-info'>$target_chan</span></h4>
                <span class='badge bg-info text-dark'>Live Updates</span>
            </div>
            <div class='card-body p-0'>
                <div class='table-responsive'>
                    <table class='table table-hover table-striped mb-0 align-middle'>
                        <thead class='table-light'>
                            <tr>
                                <th>Nickname</th>
                                <th>Hostname</th>
                                <th>Status</th>
                                <th>Idle Duration</th>
                                <th>Last Seen/Activity</th>
                            </tr>
                        </thead>
                        <tbody>
                            $table_rows
                        </tbody>
                    </table>
                </div>
            </div>
            <div class='card-footer text-center text-muted'>
                <small>Generated automatically by Eggdrop Monitor Script | Page updated: [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]</small>
            </div>
        </div>
    </div>
</body>
</html>"

        if {[catch {
            set fileId [open $html_filepath w]
            puts -nonewline $fileId $html
            close $fileId
            putlog "ChanMonitor: HTML updated for $target_chan."
        } error]} {
            putlog "ChanMonitor CRITICAL ERROR: Could not write HTML file to $html_filepath: $error"
        }
    }

    init
}

putlog "Loaded: Channel_monitor.tcl by asl_pls @ irc.underx.org #aslpls"
