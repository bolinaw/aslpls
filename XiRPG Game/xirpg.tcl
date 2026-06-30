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
# XiRPG Automated Script for Eggdrop BOTS
# Version: 2.5.0 (2026 Remastered Progression + 50-Amulet Relic Quest)
# Features: 8 Playable Classes, Native Minute Timers, 15-Tier Scaling Hunt Engine,
#           True Class Passives, Alchemist Shop System, Bounty Board Engines,
#           50 Unique Relic Amulet Quest, Hourly PvP Arena Tournaments.
#
###############################################################################

namespace eval XiRPG {
    # --- CONFIGURATION ---
    variable channel "#xirpg"                    ;# Public stream for world updates/drama
    variable savefile "scripts/irpg/xirpg.db"    ;# Where player data is saved
    variable tick_rate 60                        ;# Game loop tick rate for hunts/gains (seconds)
    variable pvp_rate_mins 120                   ;# PvP Arena Tournament interval (Strictly 60 Minutes / 1 Hour)
    variable top10_rate_mins 180                 ;# Top 10 Leaderboard update interval (Strictly 30 Minutes)
    variable bounty_rate_mins 240                ;# Elite Bounty Board rotation interval (4 Hours)
    variable boss_chance 8                       ;# % chance a 60s tick spawns a World Boss
    variable boss_duration 200                   ;# How many seconds the World Boss stays
    variable amulet_drop_chance 6                ;# % chance a successful hunt drops a rare amulet

    # --- INTERNAL STORAGE ---
    variable players
    if {![info exists players]} { array set players {} }

    variable boss_active 0
    variable boss_hp 0
    variable boss_max_hp 0
    variable boss_name ""
    variable boss_index 0                ;# Tracks the sequential boss queue
    variable raid_party [list]
    variable boss_damage_pool
    if {![info exists boss_damage_pool]} { array set boss_damage_pool {} }

    # Bounty Board States
    variable bounty_mob ""
    variable bounty_zone ""
    variable bounty_reward 1200

    # --- 50 UNIQUE AMULETS QUEST DATABANK ---
    variable amulet_db {
        1 {"Ruby Scarab" "\00304" "Ignites strikes (+3% Hunt Success)"}
        2 {"Sapphire Tear" "\00312" "Cool focus (+5 Gold passive gain)"}
        3 {"Emerald Eye" "\00303" "Keen vision (+2% Hunt Success)"}
        4 {"Topaz Spark" "\00307" "Shocking speed (+4 Gold passive gain)"}
        5 {"Amethyst Void" "\00306" "Stellar manipulation (+5% Boss Damage)"}
        6 {"Onyx Ward" "\00314" "Sturdy shadow defense (Halves faint gold loss)"}
        7 {"Diamond Core" "\00300" "Flawless composition (+5% Hunt Success)"}
        8 {"Jade Serpent" "\00309" "Regenerative speed (+3 Gold passive gain)"}
        9 {"Obsidian Mirror" "\00314" "Reflects bad environment outcomes (+2% Success)"}
        10 {"Opal Dream" "\00311" "Ethereal haze allocation (+4% Hunt Success)"}
        11 {"Sunstone Crest" "\00307" "Solar energy flare (+8% Boss Damage)"}
        12 {"Moonstone Veil" "\00315" "Luminous stealth matrix (+5% PvP Power)"}
        13 {"Bloodstone Sigil" "\00305" "Vampiric extraction (+5% Bounty success)"}
        14 {"Amber Fossil" "\00307" "Ancient preservation (Halves faint gold loss)"}
        15 {"Peridot Leaf" "\00303" "Nature's stride (+3 Gold passive gain)"}
        16 {"Aquamarine Drop" "\00310" "Fluid ocean alignment (+3% Hunt Success)"}
        17 {"Malachite Cross" "\00309" "Spiritual conviction (+4% Hunt Success)"}
        18 {"Garnet Talon" "\00304" "Aggressive pressure (+10% Boss Damage)"}
        19 {"Turquoise Bead" "\00311" "Warding sky barrier (+3% Hunt Success)"}
        20 {"Lapis Lazuli" "\00302" "Deep cosmic knowledge (+5% PvP Power)"}
        21 {"Carnelian Star" "\00304" "Fiery determination (+4% Hunt Success)"}
        22 {"Tiger Eye" "\00307" "Calculated precision (+5% Bounty success)"}
        23 {"Citrine Geode" "\00308" "Magnified capitalism (+8 Gold passive gain)"}
        24 {"Tourmaline Prism" "\00306" "Refracted spectrum barriers (+3% Success)"}
        25 {"Titanium Loop" "\00314" "Indestructible framework (+6% Hunt Success)"}
        26 {"Platinum Coil" "\00300" "Exquisite metallic flow (+10 Gold passive gain)"}
        27 {"Bronze Scarab" "\00307" "Old-world mechanical precision (+2% Success)"}
        28 {"Meteorite Shard" "\00306" "Out-of-world weight (+12% Boss Damage)"}
        29 {"Bone Reliquary" "\00314" "Morbid harvest acceleration (+5% PvP Power)"}
        30 {"Coral Branch" "\00304" "Deep-sea pressure tolerance (+4% Hunt Success)"}
        31 {"Pearl Essence" "\00315" "Pure radiant cleansing aura (+5% Success)"}
        32 {"Spinel Spike" "\00305" "Prickly feedback loops (+6% Boss Damage)"}
        33 {"Zircon Prism" "\00310" "Imitation divinity reflection (+3% Success)"}
        34 {"Pyrite Nugget" "\00308" "Fool's gold attraction (+15 Gold passive gain)"}
        35 {"Quartz Needle" "\00311" "Piezoelectric frequency sharpening (+4% Success)"}
        36 {"Apatite Charm" "\00312" "Insatiable hunger for progression (+5% Success)"}
        37 {"Azurite Heart" "\00302" "Psychic deep blue resonance (+5% Bounty success)"}
        38 {"Beryl Sphere" "\00309" "Aerodynamic equilibrium matrix (+4% Success)"}
        39 {"Fluorite Cube" "\00313" "Orderly structural matrix (+6% Hunt Success)"}
        40 {"Hematite Disc" "\00314" "Magnetic grounding gravity pull (+5% Success)"}
        41 {"Kunzanite Petal" "\00313" "Delicate aesthetic dominance (+5% PvP Power)"}
        42 {"Morganite Cross" "\00311" "High-frequency compassion focus (+5% Success)"}
        43 {"Nephrite Slab" "\00303" "Imperial endurance allocation (+7% Success)"}
        44 {"Sodalite Knot" "\00302" "Rational logic optimization (+5% Hunt Success)"}
        45 {"Sunken Anchor" "\00314" "Heavy sea floor positioning (+15% Boss Damage)"}
        46 {"Void Star" "\00306" "Singularity distortion field (+8% Hunt Success)"}
        47 {"Chrono Hourglass" "\00308" "Time-dilation presence tracker (+10% Hunt Success)"}
        48 {"Draconic Jaw" "\00304" "Ancient dragon raw fury (+20% Boss Damage)"}
        49 {"Angelic Feathers" "\00300" "Divine aura protection (+12% Hunt Success)"}
        50 {"Infinity Paradox" "\00313" "Absolute reality-shattering relic (+15% All Stats)"}
    }

    # --- PRIVMSG & CHANNEL EVENT BINDINGS ---
    bind msg - register [namespace current]::msg_register
    bind msg - stats    [namespace current]::msg_stats
    bind msg - attack   [namespace current]::msg_attack
    bind msg - forge    [namespace current]::msg_forge
    bind msg - pet      [namespace current]::msg_pet
    bind msg - buy      [namespace current]::msg_buy
    bind msg - bounty   [namespace current]::msg_bounty
    bind msg - amulet   [namespace current]::msg_amulet
    bind msg - rpghelp  [namespace current]::msg_help
    
    # Presence & Join detection hooks
    bind join - *       [namespace current]::on_channel_join
    bind evnt - init-server [namespace current]::init

    proc init {type} {
        variable tick_rate; variable pvp_rate_mins; variable top10_rate_mins; variable bounty_rate_mins
        variable bounty_mob
        load_data
        
        # Core short-loop engine (60s)
        utimer $tick_rate [namespace current]::game_tick
        
        # Native macro minute trackers 
        timer $pvp_rate_mins [namespace current]::pvp_tick
        timer $top10_rate_mins [namespace current]::top10_tick
        timer $bounty_rate_mins [namespace current]::rotate_bounty_tick
        
        # Init bounty pool targets if blank
        if {$bounty_mob == ""} { rotate_bounty }
        
        utimer 10 [namespace current]::voice_present_players
        putlog "XiRPG Engine v2.5.0 Loaded with 50-Amulet Collector Quest Framework by asl_pls."
    }

    proc voice_present_players {} {
        variable channel; variable players
        if {![validchan $channel]} { return }
        foreach nick [chanlist $channel] {
            if {[info exists players($nick,level)]} {
                pushmode $channel +v $nick
            }
        }
    }

    proc on_channel_join {nick uhost hand chan} {
        variable channel; variable players
        if {[string tolower $chan] != [string tolower $channel]} { return }

        if {[info exists players($nick,level)]} {
            putquick "PRIVMSG $channel :Welcome back, \002$nick\002! has detected your account-your active status is restored, and passive leveling has resumed."
            pushmode $channel +v $nick
        }
    }

    # Helper to calculate dynamic requirement based on current level tier
    proc get_xp_needed {lvl} {
        if {$lvl <= 10} { return [expr {1000 + ($lvl * 150)}] }
        if {$lvl <= 25} { return [expr {3000 + ($lvl * 300)}] }
        if {$lvl <= 50} { return [expr {8000 + ($lvl * 600)}] }
        if {$lvl <= 100} { return [expr {25000 + ($lvl * 1200)}] }
        if {$lvl <= 150} { return [expr {75000 + ($lvl * 2500)}] }
        if {$lvl <= 200} { return [expr {150000 + ($lvl * 5000)}] }
        if {$lvl <= 300} { return [expr {350000 + ($lvl * 10000)}] }
        if {$lvl <= 400} { return [expr {750000 + ($lvl * 20000)}] }
        if {$lvl <= 500} { return [expr {1500000 + ($lvl * 40000)}] }
        if {$lvl <= 600} { return [expr {3000000 + ($lvl * 80000)}] }
        if {$lvl <= 700} { return [expr {6000000 + ($lvl * 150000)}] }
        if {$lvl <= 800} { return [expr {12000000 + ($lvl * 300000)}] }
        if {$lvl <= 900} { return [expr {25000000 + ($lvl * 600000)}] }
        if {$lvl <= 1000} { return [expr {60000000 + ($lvl * 1500000)}] }
        return [expr {150000000 + (($lvl - 1000) * 5000000)}]
    }

    # --- CORE AUTOMATED GAME LOOP (EVERY 60 SECONDS) ---
    proc game_tick {} {
        variable tick_rate; variable channel; variable players; variable boss_chance; variable boss_active

        utimer $tick_rate [namespace current]::game_tick

        set active_players [array names players "*,level"]
        if {[llength $active_players] == 0} { return }

        set bard_online 0
        foreach p_key $active_players {
            set n [lindex [split $p_key ","] 0]
            if {[onchan $n $channel] && [info exists players($n,class)] && $players($n,class) == "Bard"} {
                set bard_online 1
                break
            }
        }

        # Presence Passive Progression Allocation
        foreach player_key $active_players {
            set nick [lindex [split $player_key ","] 0]
            if {[onchan $nick $channel]} {
                set lvl $players($nick,level)
                set req [get_xp_needed $lvl]
                
                # Base Passive XP is roughly 0.05% of target bracket requirement per minute
                set base_xp [expr {int($req * 0.0005)}]
                if {$base_xp < 5} { set base_xp 5 }
                
                if {[info exists players($nick,class)] && $players($nick,class) == "Mage"} {
                    set base_xp [expr {int($base_xp * 1.2)}]
                }
                
                # Shop Alchemy Effect: Elixir of Mind Check (Double XP)
                if {[info exists players($nick,elixir)] && [unixtime] < $players($nick,elixir)} {
                    set base_xp [expr {$base_xp * 2}]
                }
                incr players($nick,xp) $base_xp
                
                # Pet Aura Check
                set gold_gain [expr {2 + int($lvl * 0.1)}]
                if {[info exists players($nick,pet)] && $players($nick,pet) == "Courier"} {
                    set gold_gain [expr {$gold_gain * 2}]
                }
                
                if {$bard_online && $players($nick,class) != "Bard"} {
                    incr gold_gain [expr {1 + int($lvl * 0.02)}]
                }
                
                # Specific Flat Gold Amulet Passive Injections
                if {[info exists players($nick,amulet)]} {
                    set am_id $players($nick,amulet)
                    if {$am_id == 2}  { incr gold_gain 5 }
                    if {$am_id == 4}  { incr gold_gain 4 }
                    if {$am_id == 8}  { incr gold_gain 3 }
                    if {$am_id == 15} { incr gold_gain 3 }
                    if {$am_id == 23} { incr gold_gain 8 }
                    if {$am_id == 26} { incr gold_gain 10 }
                    if {$am_id == 34} { incr gold_gain 15 }
                }

                # Complete Quest Completionist Passive Multiplier (+20% Total Gold Passive Gain)
                if {[info exists players($nick,amulets_collected)] && [llength $players($nick,amulets_collected)] >= 50} {
                    set gold_gain [expr {int($gold_gain * 1.20)}]
                }
                
                incr players($nick,gold) $gold_gain
                check_levelup $nick
            }
        }

        if {!$boss_active && [expr {int(rand()*100)}] < $boss_chance} {
            spawn_world_boss
        } else {
            trigger_automated_hunt
        }
        save_data
    }

    proc pvp_tick {} {
        variable pvp_rate_mins
        timer $pvp_rate_mins [namespace current]::pvp_tick
        trigger_pvp_tournament
        save_data
    }

    proc top10_tick {} {
        variable top10_rate_mins; variable channel; variable players
        timer $top10_rate_mins [namespace current]::top10_tick

        set active_keys [array names players "*,level"]
        if {[llength $active_keys] == 0} { return }

        set player_list [list]
        foreach key $active_keys {
            set nick [lindex [split $key ","] 0]
            set lvl $players($nick,level)
            set cls "Unknown"
            if {[info exists players($nick,class)]} { set cls $players($nick,class) }
            lappend player_list [list $nick $lvl $cls]
        }

        set sorted_list [lsort -integer -decreasing -index 1 $player_list]
        set top10 [lrange $sorted_list 0 9]

        putquick "PRIVMSG $channel :\00300,04\[ XIRPG TOP 10 HEROES LEADERBOARD \]\003"
        set rank 1
        foreach player $top10 {
            set nick [lindex $player 0]; set lvl [lindex $player 1]; set cls [lindex $player 2]
            putquick "PRIVMSG $channel :\00306Rank $rank:\003 \002$nick\002 the \002LEVEL $lvl\002 \00304$cls\003"
            incr rank
        }
        putquick "PRIVMSG $channel :\00304==============================================\003"
    }

    # --- AUTOMATED HUNT SYSTEM (WITH NEW 15-TIER RE-BALANCING MATRIX) ---
    proc trigger_automated_hunt {} {
        variable players; variable channel; variable amulet_drop_chance; variable amulet_db
        set active_keys [array names players "*,level"]
        set online_nicks [list]
        
        foreach key $active_keys {
            set nick [lindex [split $key ","] 0]
            if {[onchan $nick $channel]} { lappend online_nicks $nick }
        }
        
        if {[llength $online_nicks] == 0} { return }
        set nick [lindex $online_nicks [expr {int(rand()*[llength $online_nicks])}]]

        set lvl $players($nick,level)
        set eq_lvl 0
        if {[info exists players($nick,eq_level)]} { set eq_lvl $players($nick,eq_level) }

        # Percentage maps directly configured from your requested chart structure
        if {$lvl >= 1001} {    set data [list "Cosmic Catalyst" 30 100000 250000 1.00 1.20 "\00305" { "Cosmic Being" "Reality-Shaper" "Universe-Level Threat" }]
        } elseif {$lvl >= 901} { set data [list "Divine Domain" 35 50000 120000 0.91 0.99 "\00304" { "God-Tier Entity" "Asgardian Defiler" }]
        } elseif {$lvl >= 801} { set data [list "Primordial Expanse" 40 30000 70000 0.81 0.90 "\00306" { "Demi-God" "Primordial Beast" }]
        } elseif {$lvl >= 701} { set data [list "Elder Rifts" 45 18000 40000 0.71 0.80 "\00306" { "Mythic Titan" "Elder Horror" }]
        } elseif {$lvl >= 601} { set data [list "The Doomed World" 50 12000 25000 0.61 0.70 "\00305" { "World-Threatening Creature" "Doomsday Titan" }]
        } elseif {$lvl >= 501} { set data [list "Titan Peaks" 55 8000 16000 0.51 0.60 "\00307" { "Titan-Class Monster" "Mountain Breaker" }]
        } elseif {$lvl >= 401} { set data [list "Legend Realms" 60 5000 10000 0.41 0.50 "\00312" { "Legendary Creature" "Fabled Phoenix" }]
        } elseif {$lvl >= 301} { set data [list "Dragon Canyons" 65 3000 6500 0.31 0.40 "\00312" { "Greater Dragon" "War Demon" }]
        } elseif {$lvl >= 201} { set data [list "Ancient Ruins" 70 1800 3800 0.21 0.30 "\00303" { "Ancient Beast" "Giant Monster" }]
        } elseif {$lvl >= 151} { set data [list "Demon Strongholds" 75 1000 2200 0.16 0.20 "\00302" { "Lesser Dragon" "Demon Scout" }]
        } elseif {$lvl >= 101} { set data [list "Elemental Wilds" 80 600 1300 0.11 0.15 "\00310" { "Wyvern" "Unstable Elemental" }]
        } elseif {$lvl >= 51} {  set data [list "Elite Highlands" 83 350 750 0.06 0.10 "\00312" { "Troll" "Ogre" "Elite Beast" }]
        } elseif {$lvl >= 26} {  set data [list "Outlaw Outposts" 86 150 350 0.04 0.05 "\00302" { "Orc" "Giant Spider" "Bandit" }]
        } elseif {$lvl >= 11} {  set data [list "The Deep Woods" 90 50 120 0.02 0.03 "\00303" { "Wolf" "Goblin" "Wild Beast" }]
        } else {                set data [list "The Dark Basements" 95 10 30 0.01 0.01 "\00302" { "Rat" "Insects" "Weak Creature" }] }

        set env [lindex $data 0];        set win_rate [lindex $data 1]
        set min_g [lindex $data 2];      set max_g [lindex $data 3]
        set min_xp_pct [lindex $data 4]; set max_xp_pct [lindex $data 5]
        set zone_color [lindex $data 6]; set mob_list [lindex $data 7]

        set target_mob [lindex $mob_list [expr {int(rand()*[llength $mob_list])}]]
        
        set final_win_rate [expr {$win_rate + ($eq_lvl * 2)}]
        if {[info exists players($nick,pet)] && $players($nick,pet) == "Wisp"} { incr final_win_rate 10 }
        if {[info exists players($nick,class)] && $players($nick,class) == "Ranger"} { incr final_win_rate 5 }
        
        # Amulet Specific Hunt Multiplier Hooks
        if {[info exists players($nick,amulet)]} {
            set am_id $players($nick,amulet)
            switch -- $am_id {
                1 { incr final_win_rate 3 }
                3 { incr final_win_rate 2 }
                7 { incr final_win_rate 5 }
                9 { incr final_win_rate 2 }
                10 { incr final_win_rate 4 }
                16 { incr final_win_rate 3 }
                17 { incr final_win_rate 4 }
                19 { incr final_win_rate 3 }
                21 { incr final_win_rate 4 }
                24 { incr final_win_rate 3 }
                25 { incr final_win_rate 6 }
                27 { incr final_win_rate 2 }
                30 { incr final_win_rate 4 }
                31 { incr final_win_rate 5 }
                33 { incr final_win_rate 3 }
                35 { incr final_win_rate 4 }
                36 { incr final_win_rate 5 }
                38 { incr final_win_rate 4 }
                39 { incr final_win_rate 6 }
                40 { incr final_win_rate 5 }
                42 { incr final_win_rate 5 }
                43 { incr final_win_rate 7 }
                44 { incr final_win_rate 5 }
                46 { incr final_win_rate 8 }
                47 { incr final_win_rate 10 }
                49 { incr final_win_rate 12 }
                50 { incr final_win_rate 15 }
            }
        }

        # Complete Collector Permanent Buff (+25% Flat Hunt Win Accuracy)
        if {[info exists players($nick,amulets_collected)] && [llength $players($nick,amulets_collected)] >= 50} {
            incr final_win_rate 25
        }

        if {$final_win_rate > 95 && $lvl > 10} { set final_win_rate 95 }
        
        set roll [expr {int(rand()*100)}]
        set is_victory [expr {$roll < $final_win_rate}]

        if {!$is_victory && [info exists players($nick,class)] && $players($nick,class) == "Cleric"} {
            if {[expr {int(rand()*100)}] < 15} {
                set is_victory 1
                putquick "PRIVMSG $channel :\[\00304DIVINE INTERVENTION\003\] Cleric passive triggered! \002$nick\002 reversed fatal damage into a clutch win!"
            }
        }

        if {$is_victory} {
            set g_gain [expr {int(rand()*($max_g - $min_g + 1)) + $min_g}]
            
            # XP Gain calculated dynamically as percentage of current target level requirements
            set xp_needed [get_xp_needed $lvl]
            set pct [expr {$min_xp_pct + (rand() * ($max_xp_pct - $min_xp_pct))}]
            set x_gain [expr {int($xp_needed * $pct)}]
            if {$x_gain < 1} { set x_gain 1 }
            
            if {[info exists players($nick,class)] && $players($nick,class) == "Rogue"} { incr g_gain [expr {10 + int($lvl * 0.5)}] }
            
            incr players($nick,gold) $g_gain
            incr players($nick,xp) $x_gain
            
            # --- CHANNELS VICTORY DRAMA MATRIX ENGINE ---
            set drama_roll [expr {int(rand()*27)}]
            switch -- $drama_roll {
                0  { putquick "PRIVMSG $channel :${zone_color}\[$env Hunt\]\003 \00303$nick\003 encountered a \00302$target_mob\003 and completely crushed it! Reward: \002+${g_gain}g\002 / \002+${x_gain}XP\002" }
                1  { putquick "PRIVMSG $channel :${zone_color}\[$env Hunt\]\003 \00303$nick\003 ambushed a sleeping \00302$target_mob\003, executing a lethal final strike before it could move! Reward: \002+${g_gain}g\002 / \002+${x_gain}XP\002" }
                2  { putquick "PRIVMSG $channel :${zone_color}\[$env Hunt\]\003 A wild \00302$target_mob\003 picked the wrong day to fight! \00303$nick\003 unleashed a flawless combo and wiped it out. Reward: \002+${g_gain}g\002 / \002+${x_gain}XP\002" }
                3  { putquick "PRIVMSG $channel :${zone_color}\[$env Hunt\]\003 Whispers echo as \00303$nick\003 stands over the shattered, smoking remains of a \00302$target_mob\003. Total dominance! Reward: \002+${g_gain}g\002 / \002+${x_gain}XP\002" }
                4  { putquick "PRIVMSG $channel :${zone_color}\[$env Hunt\]\003 After an intense, tactical dance of blades and elements, \00303$nick\003 outsmarted the \00302$target_mob\003! Reward: \002+${g_gain}g\002 / \002+${x_gain}XP\002" }
                5  { putquick "PRIVMSG $channel :${zone_color}\[$env Hunt\]\003 \00303$nick\003 deflected an aggressive charge from a \00302$target_mob\003 and countered with absolute, devastating fury! Reward: \002+${g_gain}g\002 / \002+${x_gain}XP\002" }
                6  { putquick "PRIVMSG $channel :${zone_color}\[$env Hunt\]\003 The local wildlife panics! \00303$nick\003 hunted down a high-value \00302$target_mob\003 and quickly claimed its treasures. Reward: \002+${g_gain}g\002 / \002+${x_gain}XP\002" }
                7  { putquick "PRIVMSG $channel :${zone_color}\[$env Hunt\]\003 \00303$nick\003 styled on a \00302$target_mob\003, dodging every attack blindly before delivering a spectacular, cinematic coup de grace! Reward: \002+${g_gain}g\002 / \002+${x_gain}XP\002" }
                8  { putquick "PRIVMSG $channel :${zone_color}\[$env Hunt\]\003 \00303$nick\003 was cornered by a ferocious \00302$target_mob\003, but broke the trap open with a sheer showcase of raw power! Reward: \002+${g_gain}g\002 / \002+${x_gain}XP\002" }
                9  { putquick "PRIVMSG $channel :${zone_color}\[$env Hunt\]\003 With unmatched precision, \00303$nick\003 severed the core of a terrifying \00302$target_mob\003, leaving nothing but dust! Reward: \002+${g_gain}g\002 / \002+${x_gain}XP\002" }
                10 { putquick "PRIVMSG $channel :${zone_color}\[$env Hunt\]\003 A thunderous blast sounds as \00303$nick\003 completely obliterates an elite \00302$target_mob\003 from existence! Reward: \002+${g_gain}g\002 / \002+${x_gain}XP\002" }
                11 { putquick "PRIVMSG $channel :${zone_color}\[$env Hunt\]\003 \00303$nick\003 baited a \00302$target_mob\003 into a devastating counter-trap, securing an incredibly clean execution! Reward: \002+${g_gain}g\002 / \002+${x_gain}XP\002" }
                12 { putquick "PRIVMSG $channel :${zone_color}\[$env Hunt\]\003 In an absolute bloodbath, \00303$nick\003 overpowered a raging \00302$target_mob\003 and looted its glowing remains! Reward: \002+${g_gain}g\002 / \002+${x_gain}XP\002" }
                13 { putquick "PRIVMSG $channel :${zone_color}\[$env Hunt\]\003 \00303$nick\003 weaponized the environment, causing a collapse that instantly crushed a helpless \00302$target_mob\003! Reward: \002+${g_gain}g\002 / \002+${x_gain}XP\002" }
                14 { putquick "PRIVMSG $channel :${zone_color}\[$env Hunt\]\003 The battle was brief! \00303$nick\003 decapitated a menacing \00302$target_mob\003 with a single, flawless legendary strike! Reward: \002+${g_gain}g\002 / \002+${x_gain}XP\002" }
                15 { putquick "PRIVMSG $channel :${zone_color}\[$env Hunt\]\003 Standing victorious against all odds, \00303$nick\003 harvested premium materials from the corpse of a \00302$target_mob\003! Reward: \002+${g_gain}g\002 / \002+${x_gain}XP\002" }
                16 { putquick "PRIVMSG $channel :${zone_color}\[$env Hunt\]\003 \00303$nick\003 read every single move of the \00302$target_mob\003, completely rendering it helpless before the execution blow! Reward: \002+${g_gain}g\002 / \002+${x_gain}XP\002" }
                17 { putquick "PRIVMSG $channel :${zone_color}\[$env Hunt\]\003 Teleporting through space, \00303$nick\003 reappeared behind the \00302$target_mob\003, shredding it to pieces in the blink of an eye! Reward: \002+${g_gain}g\002 / \002+${x_gain}XP\002" }
                18 { putquick "PRIVMSG $channel :${zone_color}\[$env Hunt\]\003 Space reality cracked! \00303$nick\003 channeled ancient power, banishing the \00302$target_mob\003 into a pocket dimension of pure agony! Reward: \002+${g_gain}g\002 / \002+${x_gain}XP\002" }
                19 { putquick "PRIVMSG $channel :${zone_color}\[$env Hunt\]\003 A glorious shockwave echoed out as \00303$nick\003 parried a lethal strike from the \00302$target_mob\003 and returned it tenfold! Reward: \002+${g_gain}g\002 / \002+${x_gain}XP\002" }
                20 { putquick "PRIVMSG $channel :${zone_color}\[$env Hunt\]\003 \00303$nick\003 entered a temporary state of absolute nirvana, dismantling the complex defenses of the \00302$target_mob\003 seamlessly! Reward: \002+${g_gain}g\002 / \002+${x_gain}XP\002" }
                21 { putquick "PRIVMSG $channel :${zone_color}\[$env Hunt\]\003 Overwhelmed by raw aura, the \00302$target_mob\003 froze in absolute terror right before \00303$nick\003 finalized the execution command! Reward: \002+${g_gain}g\002 / \002+${x_gain}XP\002" }
                22 { putquick "PRIVMSG $channel :${zone_color}\[$env Hunt\]\003 Gravity inverted! \00303$nick\003 forced the heavy weight of the world onto the \00302$target_mob\003, flattening it into a puddle of loot! Reward: \002+${g_gain}g\002 / \002+${x_gain}XP\002" }
                23 { putquick "PRIVMSG $channel :${zone_color}\[$env Hunt\]\003 With an ultimate burst of tactical speed, \00303$nick\003 struck the \00302$target_mob\003 from a thousand different directions simultaneously! Reward: \002+${g_gain}g\002 / \002+${x_gain}XP\002" }
                24 { putquick "PRIVMSG $channel :${zone_color}\[$env Hunt\]\003 Total annihilation! \00303$nick\003 fused magic and steel, manifesting a destructive beam that evaporated the \00302$target_mob\003! Reward: \002+${g_gain}g\002 / \002+${x_gain}XP\002" }
                25 { putquick "PRIVMSG $channel :${zone_color}\[$env Hunt\]\003 \00303$nick\003 calculated a flawless mathematical weakpoint on the \00302$target_mob\003, shattering its armor with a basic flick! Reward: \002+${g_gain}g\002 / \002+${x_gain}XP\002" }
                26 { putquick "PRIVMSG $channel :${zone_color}\[$env Hunt\]\003 The skies open up! \00303$nick\003 marks the location of a \00302$target_mob\003, raining down cataclysmic elemental fire to clear the zone! Reward: \002+${g_gain}g\002 / \002+${x_gain}XP\002" }
            }

            # --- AMULET QUEST LOOT LOGIC TRACKER ---
            if {[expr {int(rand()*100)}] < $amulet_drop_chance} {
                set random_id [expr {int(rand()*50) + 1}]
                set am_info [dict get $amulet_db $random_id]
                set am_name [lindex $am_info 0]; set am_col [lindex $am_info 1]
                
                set players($nick,amulet) $random_id
                
                if {![info exists players($nick,amulets_collected)]} { set players($nick,amulets_collected) [list] }
                if {[lsearch -exact $players($nick,amulets_collected) $random_id] == -1} {
                    lappend players($nick,amulets_collected) $random_id
                    putquick "PRIVMSG $channel :\[\00313AMULET QUEST UPDATE\003\] \002$nick\002 discovered a brand new relic: ${am_col}Amulet of the $am_name\003! Unique Collection Status: \002[llength $players($nick,amulets_collected)]/50\002."
                    if {[llength $players($nick,amulets_collected)] == 50} {
                        putquick "PRIVMSG $channel :\[\00307QUEST COMPLETE\003\] \002\00304$nick\003\002 has collected ALL 50 AMULETS! They have unlocked the permanent title of \002Global Collector\002 and gained a perpetual +25% Success and +20% Gold multiplier!"
                    }
                } else {
                    putquick "PRIVMSG $channel :\[\00312AMULET SLOT\003\] \002$nick\002 looted a duplicate ${am_col}Amulet of the $am_name\003 and equipped it for passive traits."
                }
            }

            check_levelup $nick
        } else {
            set loss [expr {int(rand()*$min_g) + 10}]
            if {[info exists players($nick,class)] && $players($nick,class) == "Warrior"} { set loss [expr {$loss / 2}] }
            
            # Onyx Ward & Amber Fossil Defensive Mitigation Hook
            if {[info exists players($nick,amulet)] && ($players($nick,amulet) == 6 || $players($nick,amulet) == 14)} {
                set loss [expr {$loss / 2}]
            }

            if {$players($nick,gold) < $loss} { set loss $players($nick,gold) }
            set players($nick,gold) [expr {$players($nick,gold) - $loss}]
            putquick "PRIVMSG $channel :${zone_color}\[$env Hunt\]\003 \002$nick\002 was blindsided by an aggressive \002$target_mob\002 and fainted! Lost ${loss}g."
            
            foreach pk $active_keys {
                set nec [lindex [split $pk ","] 0]
                if {$nec != $nick && [onchan $nec $channel] && [info exists players($nec,class)] && $players($nec,class) == "Necromancer"} {
                    set target_req [get_xp_needed $players($nec,level)]
                    set bonus_xp [expr {int($target_req * 0.005)}]
                    if {$bonus_xp < 20} { set bonus_xp 20 }
                    incr players($nec,xp) $bonus_xp
                    putquick "PRIVMSG $nec :\[SOUL HARVEST\] You extracted +$bonus_xp XP because $nick fainted in the field!"
                    check_levelup $nec
                }
            }
        }
    }

    # --- WORLD BOSS INFRASTRUCTURE ---
    proc spawn_world_boss {} {
        variable boss_active; variable boss_hp; variable boss_max_hp; variable boss_name; variable boss_damage_pool; variable channel
        variable boss_duration; variable raid_party; variable players; variable boss_index
        
        set bosses { "Primal Beast" "Pudge" "Sand King" "Slardar" "Sven" "Tidehunter" "Tiny" "Wraith King" }
        set boss_name [lindex $bosses $boss_index]
        incr boss_index
        if {$boss_index >= [llength $bosses]} { set boss_index 0 }
        
        set boss_max_hp [expr {int(rand()*5000) + 5000}]
        set boss_hp $boss_max_hp
        set boss_active 1
        array unset boss_damage_pool *

        set active_keys [array names players "*,level"]
        
        set raid_party [list]
        foreach pk $active_keys {
            set n [lindex [split $pk ","] 0]
            if {[onchan $n $channel] && [info exists players($n,ration)] && $players($n,ration) == 1} {
                lappend raid_party $n
                set players($n,ration) 0
                if {[llength $raid_party] >= 6} { break }
            }
        }

        set available_nicks [list]
        foreach key $active_keys {
            set nick [lindex [split $key ","] 0]
            if {[onchan $nick $channel] && [lsearch -exact $raid_party $nick] == -1} { lappend available_nicks $nick }
        }
        
        while {[llength $raid_party] < 6 && [llength $available_nicks] > 0} {
            set idx [expr {int(rand()*[llength $available_nicks])}]
            lappend raid_party [lindex $available_nicks $idx]
            set available_nicks [lreplace $available_nicks $idx $idx]
        }

        set party_list [join $raid_party ", "]
        if {$party_list == ""} { set party_list "No heroes active." }

        putquick "PRIVMSG $channel :\00300,01\[WORLD BOSS SPAWNED\]\003 \00304\002$boss_name\002\003 has Entered the Channel! \00303HP: $boss_hp/$boss_max_hp\003. \00304Timer: ${boss_duration}s\003."
        putquick "PRIVMSG $channel :\00312Raid Party:\003 \002$party_list\002 have engaged combat ranges."
        
        utimer 20 [namespace current]::automated_boss_combat
        utimer $boss_duration [namespace current]::boss_timeout
    }

    proc automated_boss_combat {} {
        variable boss_active; variable boss_hp; variable boss_name; variable boss_damage_pool; variable channel; variable raid_party; variable players
        if {!$boss_active || [llength $raid_party] == 0} { return }

        foreach nick $raid_party {
            if {![info exists players($nick,level)] || !$boss_active} { continue }
            set eq_lvl 0
            if {[info exists players($nick,eq_level)]} { set eq_lvl $players($nick,eq_level) }

            set dmg [expr {$players($nick,level) * 4 + ($eq_lvl * 8) + int(rand()*15) + 5}]
            if {[info exists players($nick,pet)] && $players($nick,pet) == "Roshan"} { set dmg [expr {int($dmg * 1.25)}] }
            if {[info exists players($nick,class)] && $players($nick,class) == "Paladin"} { set dmg [expr {int($dmg * 1.15)}] }
            
            # Amulet Damage Modification Integration
            if {[info exists players($nick,amulet)]} {
                set am_id $players($nick,amulet)
                switch -- $am_id {
                    5  { set dmg [expr {int($dmg * 1.05)}] }
                    11 { set dmg [expr {int($dmg * 1.08)}] }
                    18 { set dmg [expr {int($dmg * 1.10)}] }
                    28 { set dmg [expr {int($dmg * 1.12)}] }
                    32 { set dmg [expr {int($dmg * 1.06)}] }
                    45 { set dmg [expr {int($dmg * 1.15)}] }
                    48 { set dmg [expr {int($dmg * 1.20)}] }
                    50 { set dmg [expr {int($dmg * 1.15)}] }
                }
            }

            set boss_hp [expr {$boss_hp - $dmg}]
            if {![info exists boss_damage_pool($nick)]} { set boss_damage_pool($nick) 0 }
            incr boss_damage_pool($nick) $dmg

            if {$boss_hp <= 0} { process_boss_defeat $nick; return }
        }

        putquick "PRIVMSG $channel :\00304\[Combat Report\]\003 Raid Party trades blows with \002$boss_name\002! Structural HP Remaining: $boss_hp"
        utimer 30 [namespace current]::automated_boss_combat
    }

    # --- ALCHEMIST SHOP INTERFACE LAYER ---
    proc msg_buy {nick uhost hand arg} {
        variable players
        if {![info exists players($nick,level)]} {
            putquick "PRIVMSG $nick :Error: You must be registered before visiting the alchemy shop counters."
            return
        }
        
        set item [string tolower [string trim $arg]]
        set gold $players($nick,gold)

        if {$item == "catalyst"} {
            set cost 1500
            if {$gold < $cost} { putquick "PRIVMSG $nick :Error: Forge Insurance Catalyst costs $cost g. Current: ${gold}g"; return }
            set players($nick,catalyst) 1
            incr players($nick,gold) -$cost
            putquick "PRIVMSG $nick :Purchase Confirmed: Bought Forge Insurance Catalyst. Your next failed forge will be shielded."
        } elseif {$item == "elixir"} {
            set cost 300
            if {$gold < $cost} { putquick "PRIVMSG $nick :Error: Elixir of Mind costs $cost g. Current: ${gold}g"; return }
            set players($nick,elixir) [expr {[unixtime] + 7200}]
            incr players($nick,gold) -$cost
            putquick "PRIVMSG $nick :Purchase Confirmed: Drank Elixir of Mind. +100% Passive Presence Loop active for 2 Hours."
        } elseif {$item == "ration"} {
            set cost 500
            if {$gold < $cost} { putquick "PRIVMSG $nick :Error: Priority Combat Ration costs $cost g. Current: ${gold}g"; return }
            set players($nick,ration) 1
            incr players($nick,gold) -$cost
            putquick "PRIVMSG $nick :Purchase Confirmed: Combat Ration integrated. Forced priority placement active for next Boss queue."
        } else {
            putquick "PRIVMSG $nick :--- THE ALCHEMIST PREMIUM SHOP ---"
            putquick "PRIVMSG $nick :buy catalyst - 1500g | Prevents weapon reset/shatter rules on next forge failure"
            putquick "PRIVMSG $nick :buy elixir   - 300g  | Grants double passive presence level-up speed for 2 Hours"
            putquick "PRIVMSG $nick :buy ration   - 500g  | Guarantees entry placement into the next World Boss raid group"
        }
        save_data
    }

    # --- COMPREHENSIVE CONTRACT BOUNTY BOARD ---
    proc rotate_bounty_tick {} {
        variable bounty_rate_mins
        timer $bounty_rate_mins [namespace current]::rotate_bounty_tick
        rotate_bounty
    }

    proc rotate_bounty {} {
        variable bounty_mob; variable bounty_zone; variable bounty_reward; variable channel
        set targets {
            {"Sewer Abomination" "The Dark Basements"} {"Alpha Feral Warg" "The Deep Woods"}
            {"Deepwater Kraken" "Elemental Wilds"}    {"Apex Sky Ruler" "Ancient Ruins"}
            {"Lich Necromancer" "Dragon Canyons"}     {"Reality Sunderer" "Cosmic Catalyst"}
        }
        set roll [expr {int(rand()*[llength $targets])}]
        set choice [lindex $targets $roll]
        
        set bounty_mob [lindex $choice 0]
        set bounty_zone [lindex $choice 1]
        set bounty_reward [expr {int(rand()*2500) + 1500}]
        
        putquick "PRIVMSG $channel :\[\00304BOUNTY BOARD\003\] The King posted a new elite global contract target: \002$bounty_mob\002 location: \002$bounty_zone\002! Prize Pool: ${bounty_reward}g. Execute via PM: bounty hunt"
    }

    proc msg_bounty {nick uhost hand arg} {
        variable players; variable bounty_mob; variable bounty_zone; variable bounty_reward; variable channel
        if {![info exists players($nick,level)]} { return }
        
        set sub [string tolower [string trim $arg]]
        if {$sub != "hunt"} {
            putquick "PRIVMSG $nick :Current Active Elite Bounty: \002$bounty_mob\002 lurking in \002$bounty_zone\002. Prize allocation: ${bounty_reward}g."
            putquick "PRIVMSG $nick :To track and execute this contract challenge, utilize query command: bounty hunt"
            return
        }

        if {[info exists players($nick,bounty_cd)] && [unixtime] < $players($nick,bounty_cd)} {
            set rem [expr {$players($nick,bounty_cd) - [unixtime]}]
            putquick "PRIVMSG $nick :Error: Tracking mechanics are cooling down. Re-evaluation algorithms operational in $rem seconds."
            return
        }

        set players($nick,bounty_cd) [expr {[unixtime] + 1800}]
        
        set eq_lvl 0
        if {[info exists players($nick,eq_level)]} { set eq_lvl $players($nick,eq_level) }
        set base_success 40
        incr base_success [expr {$eq_lvl * 2}]
        if {[info exists players($nick,class)] && $players($nick,class) == "Ranger"} { incr base_success 5 }
        
        # Bounty Specific Amulet Buff Modifiers
        if {[info exists players($nick,amulet)]} {
            set am_id $players($nick,amulet)
            if {$am_id == 13 || $am_id == 22 || $am_id == 37} { incr base_success 5 }
            if {$am_id == 50} { incr base_success 15 }
        }

        if {$base_success > 85} { set base_success 85 }

        set battle_roll [expr {int(rand()*100)}]
        if {$battle_roll < $base_success} {
            set target_req [get_xp_needed $players($nick,level)]
            set exp_bonus [expr {int($target_req * 0.15)}]
            if {$exp_bonus < 100} { set exp_bonus 100 }
            
            incr players($nick,gold) $bounty_reward
            incr players($nick,xp) $exp_bonus
            
            putquick "PRIVMSG $channel :\[BOUNTY CLAIMED\] \002$nick\002 successfully hunted down and assassinated elite mark \002$bounty_mob\002 inside the $bounty_zone! Collected: ${bounty_reward}g and +${exp_bonus}XP."
            check_levelup $nick
            rotate_bounty
        } else {
            set fine [expr {200 + int($players($nick,level) * 10)}]
            if {$players($nick,gold) < $fine} { set fine $players($nick,gold) }
            set players($nick,gold) [expr {$players($nick,gold) - $fine}]
            putquick "PRIVMSG $channel :\[BOUNTY FAILURE\] \002$nick\002 attempted to claim the contract on \002$bounty_mob\002 but was overpowered! Dropped ${fine}g fleeing."
        }
        save_data
    }

    # --- WEAPON FORGE MATRIX ---
    proc msg_forge {nick uhost hand arg} {
        variable players; variable channel
        if {![info exists players($nick,level)]} { return }
        set cur_lvl $players($nick,eq_level); set eq_name $players($nick,equipment)
        if {$cur_lvl >= 10} { return }

        if {$cur_lvl < 3} { set cost 100; set success_rate 100; set risk "None"
        } elseif {$cur_lvl < 5} { set cost 250; set success_rate 70;  set risk "Reset"
        } elseif {$cur_lvl < 9} { set cost 500; set success_rate 40;  set risk "Shatter"
        } else { set cost 1500; set success_rate 15; set risk "Shatter" }

        if {$players($nick,gold) < $cost} { return }
        incr players($nick,gold) -$cost
        
        if {[expr {int(rand()*100)}] < $success_rate} {
            incr players($nick,eq_level)
            putquick "PRIVMSG $channel :\[BLACKSMITH\] \002$nick\002 upgraded their $eq_name to +$players($nick,eq_level)!"
        } else {
            if {[info exists players($nick,catalyst)] && $players($nick,catalyst) == 1} {
                set players($nick,catalyst) 0
                putquick "PRIVMSG $nick :Forge Failure Event! Your Premium Alchemist Catalyst dissolved, entirely shielding item upgrades from degradation down to +0."
            } else {
                if {$risk == "Reset"} { set players($nick,eq_level) 0
                } elseif {$risk == "Shatter"} { set players($nick,equipment) "\[Common\] Bare Fists"; set players($nick,eq_level) 0 }
                putquick "PRIVMSG $nick :Forge failed! Structural risk configuration: $risk executed."
            }
        }
        save_data
    }

    # --- PROGRESSION & HOURLY GRAND ARENA PVP ENGINE ---
    proc trigger_pvp_tournament {} {
        variable players; variable channel
        set active_keys [array names players "*,level"]
        set available_nicks [list]
        foreach key $active_keys {
            set nick [lindex [split $key ","] 0]
            if {[onchan $nick $channel]} { lappend available_nicks $nick }
        }
        if {[llength $available_nicks] < 2} { return }
        set pool $available_nicks; set matched [list]
        while {[llength $pool] > 0} {
            set idx [expr {int(rand()*[llength $pool])}]
            lappend matched [lindex $pool $idx]
            set pool [lreplace $pool $idx $idx]
        }
        putquick "PRIVMSG $channel :\00304THE GRAND ARENA IS OPEN: PVP SHOWDOWN\003"
        set total_pairs 0
        for {set i 0} {$i < [llength $matched]} {incr i 2} {
            if {$total_pairs >= 5} { break }
            set p1 [lindex $matched $i]; set p2 [lindex $matched [expr {$i + 1}]]
            if {$p2 == ""} { break } 
            set lvl1 $players($p1,level); set eq1 0
            if {[info exists players($p1,eq_level)]} { set eq1 $players($p1,eq_level) }
            set power1 [expr {$lvl1 * 8 + $eq1 * 4 + int(rand()*50) + 1}]
            
            # P1 Arena Amulet Power Injections
            if {[info exists players($p1,amulet)]} {
                set a1 $players($p1,amulet)
                if {$a1 == 12 || $a1 == 20 || $a1 == 29 || $a1 == 41} { incr power1 [expr {int($power1 * 0.05)}] }
                if {$a1 == 50} { incr power1 [expr {int($power1 * 0.15)}] }
            }

            set lvl2 $players($p2,level); set eq2 0
            if {[info exists players($p2,eq_level)]} { set eq2 $players($p2,eq_level) }
            set power2 [expr {$lvl2 * 8 + $eq2 * 4 + int(rand()*50) + 1}]
            
            # P2 Arena Amulet Power Injections
            if {[info exists players($p2,amulet)]} {
                set a2 $players($p2,amulet)
                if {$a2 == 12 || $a2 == 20 || $a2 == 29 || $a2 == 41} { incr power2 [expr {int($power2 * 0.05)}] }
                if {$a2 == 50} { incr power2 [expr {int($power2 * 0.15)}] }
            }

            if {$power1 >= $power2} { set winner $p1; set loser $p2; set win_pow $power1; set los_pow $power2
            } else { set winner $p2; set loser $p1; set win_pow $power2; set los_pow $power1 }
            
            set current_lvl $players($winner,level)
            set xp_needed [get_xp_needed $current_lvl]
            set xp_gain [expr {int($xp_needed * 0.05)}]
            if {$xp_gain < 50} { set xp_gain 50 }
            
            incr players($winner,xp) $xp_gain
            putquick "PRIVMSG $channel :\[Match [expr {$total_pairs + 1}]\] \002$winner\002 ($win_pow Power) defeated \002$loser\002 ($los_pow Power)! Reward: +$xp_gain XP"
            check_levelup $winner
            incr total_pairs
        }
    }

    proc process_boss_defeat {killer_nick} {
        variable boss_active; variable boss_name; variable boss_damage_pool; variable channel; variable players
        set boss_active 0
        set gold_reward [expr {int(rand()*1500) + 1000}]
        incr players($killer_nick,gold) $gold_reward
        set item_string [generate_boss_loot]
        set players($killer_nick,equipment) $item_string
        set players($killer_nick,eq_level) 0
        putquick "PRIVMSG $channel :\00300,03\[RAID VICTORY\]\003 \00304\002$boss_name\002\003 has been entirely \00304executed!\003"
        putquick "PRIVMSG $channel :\00300,04\[FATAL BLOW\]\003 \002$killer_nick\002 dealt the final blow, earning an extra $gold_reward g bounty!"
        putquick "PRIVMSG $channel :\00306\[LEGENDARY CACHE\]\003 Dropped Weapon: $item_string"
        foreach contributor [array names boss_damage_pool] {
            set dmg $boss_damage_pool($contributor); set share [expr {$dmg * 3}]; set xp_share [expr {$share * 4}]
            incr players($contributor,gold) $share; incr players($contributor,xp) $xp_share
            putquick "PRIVMSG $channel :\002$contributor\002 You dealt $dmg dmg. Allocation: +$share Gold / +$xp_share XP!"
            check_levelup $contributor
        }
        save_data
    }

    proc boss_timeout {} {
        variable boss_active; variable boss_name; variable channel
        if {!$boss_active} { return }
        set boss_active 0
        putquick "PRIVMSG $channel :\[TIME EXPIRED\] \002$boss_name\002 completely overwhelmed the raid composition elements and escaped!"
    }

    proc generate_boss_loot {} {
        set table {{55 "Common" "\00314"} {30 "Rare" "\00312"} {12 "Epic" "\00306"} {3 "Legendary" "\00307"}}
        set bases { "Greatsword" "Spire Staff" "Dagger" "Longbow" "Spiked Shield" }
        set suffixes { "of Shattering Flame" "of the Void" "of Divine Power" "of Doom" }
        set roll [expr {int(rand()*100)}]; set selected_rarity "Common"; set selected_color "\00314"; set running_weight 0
        foreach tier $table {
            incr running_weight [lindex $tier 0]
            if {$roll < $running_weight} { set selected_rarity [lindex $tier 1]; set selected_color [lindex $tier 2]; break }
        }
        set base [lindex $bases [expr {int(rand()*[llength $bases])}]]; set suffix [lindex $suffixes [expr {int(rand()*[llength $suffixes])}]]
        return "$selected_color\[$selected_rarity\] \002$base $suffix\002\003"
    }

    proc msg_pet {nick uhost hand arg} {
        variable players; variable channel
        set subcmd [string tolower [lindex [split $arg] 0]]; set pet_type [string totitle [lindex [split $arg] 1]]
        if {$subcmd == "buy"} {
            if {[info exists players($nick,pet)] && $players($nick,pet) != ""} {
                putquick "PRIVMSG $nick :Error: You already possess an active companion."
                return
            }
            if {$pet_type == "Courier"} { set cost 500; set desc "Midas Aura (+Passive Gold/min scales on Lvl)"
            } elseif {$pet_type == "Roshan"} { set cost 2500; set desc "Aegis Fury (+25% Raid Boss Damage)"
            } elseif {$pet_type == "Wisp"} { set cost 5000; set desc "Relocate (+10% Hunt Survival Accuracy)"
            } else { putquick "PRIVMSG $nick :Companions: Courier (500g) | Roshan (2500g) | Wisp (5000g). Use: pet buy <type>"; return }
            if {$players($nick,gold) < $cost} { putquick "PRIVMSG $nick :Error: Insufficient funds."; return }
            incr players($nick,gold) -$cost; set players($nick,pet) $pet_type
            putquick "PRIVMSG $channel :\[COMPANION\] \002$nick\002 summoned a \002$pet_type\002! Status Buff: $desc."
        } elseif {$subcmd == "dismiss"} {
            if {![info exists players($nick,pet)] || $players($nick,pet) == ""} { return }
            set players($nick,pet) ""; putquick "PRIVMSG $nick :Companion slot safely de-allocated."
        } else {
            set current_pet "None"
            if {[info exists players($nick,pet)] && $players($nick,pet) != ""} { set current_pet $players($nick,pet) }
            putquick "PRIVMSG $nick :Companion status allocation: \002$current_pet\002. Interface syntax: pet buy <Courier|Roshan|Wisp> | pet dismiss"
        }
        save_data
    }

    # --- INTERACTIVE AMULET TRACKER DISPLAY ---
    proc msg_amulet {nick uhost hand arg} {
        variable players; variable amulet_db
        if {![info exists players($nick,level)]} { return }
        
        set active_id "None"
        set active_desc "No active attributes."
        if {[info exists players($nick,amulet)] && $players($nick,amulet) != "None"} {
            set active_id $players($nick,amulet)
            set am_info [dict get $amulet_db $active_id]
            set active_id "[lindex $am_info 1]Amulet of the [lindex $am_info 0]\003"
            set active_desc [lindex $am_info 2]
        }
        
        set count 0
        if {[info exists players($nick,amulets_collected)]} { set count [llength $players($nick,amulets_collected)] }
        
        putquick "PRIVMSG $nick :--- GLOBAL AMULET COLLECTOR QUEST STATUS ---"
        putquick "PRIVMSG $nick :Active Amulet Slot: $active_id"
        putquick "PRIVMSG $nick :Passive Attribute: \002$active_desc\002"
        putquick "PRIVMSG $nick :Unique Collection Progress: \002$count / 50 Completed\002"
        if {$count >= 50} {
            putquick "PRIVMSG $nick :Completionist Status: \00304\[Global Collector Unlocked! (+25% Win Rate / +20% Gold Permanent)\]\003"
        }
    }

    proc msg_register {nick uhost hand arg} {
        variable players; variable channel
        set class [string totitle [string trim $arg]]
        variable valid_classes { "Warrior" "Mage" "Rogue" "Cleric" "Paladin" "Ranger" "Necromancer" "Bard" }
        if {[info exists players($nick,level)]} { putquick "PRIVMSG $nick :Error: Character profile is already operational."; return }
        if {[lsearch -exact $valid_classes $class] == -1} {
            putquick "PRIVMSG $nick :Error: Choose out of the 8 parameters: Warrior, Mage, Rogue, Cleric, Paladin, Ranger, Necromancer, Bard."; return
        }
        set players($nick,level) 1; set players($nick,class) $class; set players($nick,xp) 0; set players($nick,gold) 150
        set players($nick,equipment) "\[Common\] Bare Fists"; set players($nick,eq_level) 0; set players($nick,pet) ""
        set players($nick,amulet) "None"; set players($nick,amulets_collected) [list]
        putquick "PRIVMSG $nick :Success: Account profile written down as a Level 1 $class."
        putquick "PRIVMSG $channel :\00303\[REGISTRATION\]\003 Welcome \00303\002$nick\002\003 the \00304\002$class\002\003 to XiRPG!"
        if {[onchan $nick $channel]} { pushmode $channel +v $nick }
        save_data
    }

    proc msg_stats {nick uhost hand arg} {
        variable players; variable amulet_db
        set target [string trim $arg]; if {$target == ""} { set target $nick }
        if {![info exists players($target,level)]} { return }
        set eq $players($target,equipment); set eq_lvl $players($target,eq_level); set xp_needed [get_xp_needed $players($target,level)]
        set active_pet "None"; if {[info exists players($target,pet)] && $players($target,pet) != ""} { set active_pet $players($target,pet) }
        
        set active_am "None"
        if {[info exists players($target,amulet)] && $players($target,amulet) != "None"} {
            set am_info [dict get $amulet_db $players($target,amulet)]
            set active_am "[lindex $am_info 1][lindex $am_info 0]\003"
        }

        putquick "PRIVMSG $nick :Player: \002$target\002 | Class: $players($target,class) | Lvl: $players($target,level) | XP: $players($target,xp)/$xp_needed | Gold: $players($target,gold)g | Pet: \002$active_pet\002"
        putquick "PRIVMSG $nick :Weapon slot allocation: $eq (+$eq_lvl) | Amulet: $active_am"
    }

    proc msg_attack {nick uhost hand arg} {
        variable players; variable boss_active; variable boss_hp; variable boss_name; variable boss_damage_pool
        if {!$boss_active || ![info exists players($nick,level)]} { return }
        set eq_lvl 0; if {[info exists players($nick,eq_level)]} { set eq_lvl $players($nick,eq_level) }
        set dmg [expr {$players($nick,level) * 5 + ($eq_lvl * 12) + int(rand()*15) + 5}]
        if {[info exists players($nick,class)] && $players($nick,class) == "Paladin"} { set dmg [expr {int($dmg * 1.15)}] }
        
        # Attack Amulet Damage Modification Injection
        if {[info exists players($nick,amulet)]} {
            set am_id $players($nick,amulet)
            if {$am_id == 5 || $am_id == 11 || $am_id == 18 || $am_id == 28 || $am_id == 32 || $am_id == 45 || $am_id == 48 || $am_id == 50} {
                set dmg [expr {int($dmg * 1.10)}]
            }
        }

        set boss_hp [expr {$boss_hp - $dmg}]
        if {![info exists boss_damage_pool($nick)]} { set boss_damage_pool($nick) 0 }
        incr boss_damage_pool($nick) $dmg
        putquick "PRIVMSG $nick :Enacted manual attack vector! Dealt $dmg impact forces to $boss_name."
        if {$boss_hp <= 0} { process_boss_defeat $nick }
    }

    proc msg_help {nick uhost hand arg} {
        putquick "PRIVMSG $nick :======================================================================="
        putquick "PRIVMSG $nick :                       XiRPG CORE COMMAND ENGINE                    "
        putquick "PRIVMSG $nick :======================================================================="
        putquick "PRIVMSG $nick : \002CORE COMMANDS:\002 - https://eggtcl.us/xirpg/xirpg-commands.txt"
        putquick "PRIVMSG $nick : \002AMULET QUEST:\002 - Type 'amulet' via PM to review collection progress."
        putquick "PRIVMSG $nick :======================================================================="
    }

    proc check_levelup {nick} {
        variable players; variable channel
        while {1} {
            set current_lvl $players($nick,level)
            set xp_needed [get_xp_needed $current_lvl]
            if {$players($nick,xp) >= $xp_needed} {
                incr players($nick,xp) -$xp_needed
                incr players($nick,level)
                putquick "PRIVMSG $channel :\00303\[LEVEL UP\]\003 \00306\002$nick\002\003 advanced to \00303Level \002$players($nick,level)\002\003! \00304Class: $players($nick,class)\003."
            } else {
                break
            }
        }
    }

    proc save_data {} {
        variable savefile; variable players
        set fileId [open $savefile w]; puts $fileId [array get players]; close $fileId
    }

    proc load_data {} {
        variable savefile; variable players
        if {[file exists $savefile]} {
            set fileId [open $savefile r]; array set players [read $fileId]; close $fileId
        }
    }

}

if {[info exists server] && $server != ""} { XiRPG::init "rehash" }
