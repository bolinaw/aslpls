##############################################################
#	_______ ______________ ________ ______ ________
#	___    |__  ___/___  / ___  __ \___  / __  ___/
#	__  /| |_____ \ __  /  __  /_/ /__  /  _____ \ 
#	_  ___ |____/ / _  /____  ____/ _  /_______/ / 
#	/_/  |_|/____/  /_____//_/      /_____//____/  
#		  asl_pls / irc.underx.org	
#							
##############################################################
#
# Eggdrop Automated HTML Web Upload Script via FTP
# Version: 1.7 (Automated Cron Upload Every 10 Minutes)
#
##############################################################

namespace eval ::FtpAutoTransfer {
    # --- CONFIGURATION ---
    
    # The local directory on your Eggdrop server where your local HTML files live
    variable local_base_dir "/home/talker/public_html/"
    
    variable ftp_user       "your-ftp-username"
    variable ftp_pass       "your-ftp-password"
    variable ftp_host       "your-ftp-host"
    variable ftp_port       "21"
    
    # Path configuration - Make sure this directory matches your hosting structure
    #variable remote_base_dir "/aslpls" #from your root (public_html) then foldername, it will create automatically the folder aslpls
    #variable remote_base_dir "/" #from the folder you created it will upload the html files directly
    variable remote_base_dir "/" 

    
    # Channels where the bot should output successful or failed automation logs (Optional)
    # Leave empty "" if you want it to log silently strictly to the bot partyline
    variable log_channel    "#aslpls"

    # --- BINDS ---
    # This bind triggers every minute. We will filter it to run every 10th minute.
    bind time - "*" [namespace current]::cron_upload_check

    # --- CORE FUNCTIONS ---
    proc cron_upload_check {min hour day month year} {
        # Check if the current minute is divisible by 10 (00, 10, 20, 30, 40, 50)
        if {$min % 10 != 0} {
            return 0
        }
        
        variable local_base_dir
        variable log_channel

        putlog "\[FTP-Auto\] Starting scheduled 10-minute file sync..."
        if {$log_channel ne ""} {
            putquick "PRIVMSG $log_channel :\00302\[Automation\]\003 Running scheduled 10-minute website upload sync..."
        }

        # Extensions we want to check and upload automatically
        set valid_extensions [list *.html *.htm *.php *.txt *.css *.js]
        set upload_count 0
        set error_count 0

        foreach mask $valid_extensions {
            set search_path [file join $local_base_dir $mask]
            
            # Find matching files in the directory
            if {[catch {glob -nocomplain $search_path} files]} {
                continue
            }

            foreach local_full_path $files {
                set filename [file tail $local_full_path]
                
                # Execute individual file upload
                if {[file_upload_worker $local_full_path $filename]} {
                    incr upload_count
                } else {
                    incr error_count
                }
            }
        }

        # Summary Log Output
        set summary "Sync complete. Uploaded: $upload_count files. Errors: $error_count."
        putlog "\[FTP-Auto\] $summary"
        if {$log_channel ne "" && ($upload_count > 0 || $error_count > 0)} {
            putquick "PRIVMSG $log_channel :\00302\[Automation\]\003 $summary"
        }
    }

    # Worker function that handles the exact curl execution mechanics
    proc file_upload_worker {local_path filename} {
        variable ftp_user
        variable ftp_pass
        variable ftp_host
        variable ftp_port
        variable remote_base_dir

        set target_path "${remote_base_dir}${filename}"

        # Construct safe silent system curl argument matrix array
        set cmd [list curl -s -S \
                           --user "${ftp_user}:${ftp_pass}" \
                           --upload-file [file normalize $local_path] \
                           --ftp-create-dirs \
                           "ftp://${ftp_host}:${ftp_port}/${target_path}" "2>&1"]

        if {[catch {exec {*}$cmd} result]} {
            set clean_err [string map {"\n" " " "\r" ""} $result]
            putlog "\[FTP-Auto\] Failed uploading $filename: [string range $clean_err 0 100]"
            return 0
        } else {
            putlog "\[FTP-Auto\] Automatically synced $filename seamlessly."
            return 1
        }
    }
    
    putlog "Loaded Automated HTML Web FTP Transfer Script v1.7 by asl_pls (10-minute intervals)"
}