#################################################################
# DALnet Channel & User Administration Script                   #
# Built for strict DALnet compatibility & Eggdrop security      #
#################################################################

namespace eval ::DalnetAdmin {
    # -----------------------------------------------------------
    # BINDINGS
    # -----------------------------------------------------------
    # Channel Management (Requires Master flag 'm')
    bind pub m !join  [namespace current]::pub_join
    bind pub m !part  [namespace current]::pub_part
    bind pub m !cycle [namespace current]::pub_cycle

    # User Management (Requires Operator flag 'o')
    bind pub o !op    [namespace current]::pub_op
    bind pub o !deop  [namespace current]::pub_deop
    bind pub o !voice [namespace current]::pub_voice
    bind pub o !dv    [namespace current]::pub_devoice
    bind pub o !k     [namespace current]::pub_kick
    bind pub o !b     [namespace current]::pub_ban
    bind pub o !ub    [namespace current]::pub_unban

    # -----------------------------------------------------------
    # CORE PROCEDURES
    # -----------------------------------------------------------

    # !join <channel>
    proc pub_join {nick uhost hand chan arg} {
        set target [lindex [split $arg] 0]
        if {$target eq ""} {
            putserv "PRIVMSG $chan :Usage: !join <#channel>"
            return 0
        }
        if {![string match "#*" $target]} { set target "#$target" }
        putlog "\[DALnet-Admin\] $nick ($hand) ordered me to join $target"
        putserv "JOIN $target"
        return 1
    }

    # !part <channel>
    proc pub_part {nick uhost hand chan arg} {
        set target [lindex [split $arg] 0]
        if {$target eq ""} { set target $chan }
        if {![string match "#*" $target]} { set target "#$target" }
        putlog "\[DALnet-Admin\] $nick ($hand) ordered me to part $target"
        putserv "PART $target :Requested by admin"
        return 1
    }

    # !cycle <channel>
    proc pub_cycle {nick uhost hand chan arg} {
        set target [lindex [split $arg] 0]
        if {$target eq ""} { set target $chan }
        if {![string match "#*" $target]} { set target "#$target" }
        
        putlog "\[DALnet-Admin\] $nick ($hand) cycling channel $target"
        putserv "PART $target :Cycling channel..."
        putserv "JOIN $target"
        return 1
    }

    # !op <nick>
    proc pub_op {nick uhost hand chan arg} {
        set target [lindex [split $arg] 0]
        if {$target eq ""} { set target $nick }
        if {![onchan $target $chan]} {
            putserv "PRIVMSG $chan :I don't see $target in here."
            return 0
        }
        putserv "MODE $chan +o $target"
        return 1
    }

    # !deop <nick>
    proc pub_deop {nick uhost hand chan arg} {
        set target [lindex [split $arg] 0]
        if {$target eq ""} { set target $nick }
        if {![onchan $target $chan]} {
            putserv "PRIVMSG $chan :I don't see $target in here."
            return 0
        }
        putserv "MODE $chan -o $target"
        return 1
    }

    # !voice <nick>
    proc pub_voice {nick uhost hand chan arg} {
        set target [lindex [split $arg] 0]
        if {$target eq ""} { set target $nick }
        if {![onchan $target $chan]} {
            putserv "PRIVMSG $chan :I don't see $target in here."
            return 0
        }
        putserv "MODE $chan +v $target"
        return 1
    }

    # !dv <nick>
    proc pub_devoice {nick uhost hand chan arg} {
        set target [lindex [split $arg] 0]
        if {$target eq ""} { set target $nick }
        if {![onchan $target $chan]} {
            putserv "PRIVMSG $chan :I don't see $target in here."
            return 0
        }
        putserv "MODE $chan -v $target"
        return 1
    }

    # !k <nick> - kick specific user in the channel with reason message
    proc pub_kick {nick uhost hand chan arg} {
        set target [lindex [split $arg] 0]
        set reason [lrange [split $arg] 1 end]
        if {$target eq ""} {
            putserv "PRIVMSG $chan :Usage: !k <nickname> \[reason\]"
            return 0
        }
        if {![onchan $target $chan]} {
            putserv "PRIVMSG $chan :I don't see $target in here."
            return 0
        }
        if {$reason eq ""} { set reason "Requested by administrator." }
        putserv "KICK $chan $target :$reason"
        return 1
    }

    # !b <nick> - ban specific user in the channel with reason message
    proc pub_ban {nick uhost hand chan arg} {
        set target [lindex [split $arg] 0]
        set reason [lrange [split $arg] 1 end]
        if {$target eq ""} {
            putserv "PRIVMSG $chan :Usage: !b <nickname> \[reason\]"
            return 0
        }
        if {![onchan $target $chan]} {
            putserv "PRIVMSG $chan :I don't see $target inside $chan"
            return 0
        }
        if {$reason eq ""} { set reason "Banned by administrator." }

        # Fetch user's actual hostmask dynamically from internal tracking
        set target_host [getchanhost $target $chan]
        if {$target_host eq ""} {
            # Fallback format if internal state hasn't fully synched
            set banmask "*!*@[lindex [split [getchanhost $target $chan] @] 1]"
        } else {
            # Standard safe wildcard ban mask (*!*@host.domain.com)
            set banmask "*!*@[lindex [split $target_host @] 1]"
        }

        # Kick the user first, then apply the network layer mode ban
        putserv "KICK $chan $target :$reason"
        putserv "MODE $chan +b $banmask"
        return 1
    }

    # !ub <nick> - unban specific user in the channel
    proc pub_unban {nick uhost hand chan arg} {
        set target [lindex [split $arg] 0]
        if {$target eq ""} {
            putserv "PRIVMSG $chan :Usage: !ub <nickname or mask>"
            return 0
        }

        # If they passed a nickname, try to resolve the standard wildcard mask
        if {![string match "*!*@*" $target]} {
            set target_host [getchanhost $target $chan]
            if {$target_host ne ""} {
                set target "*!*@[lindex [split $target_host @] 1]"
            } else {
                # If the user isn't physically present, we fall back to searching 
                # the channel ban list via standard wildcards if they just typed a string.
                set target "$target!*@*"
            }
        }

        putserv "MODE $chan -b $target"
        return 1
    }
}

putlog "Loaded DALnet Administrative Basic Command Suite."
