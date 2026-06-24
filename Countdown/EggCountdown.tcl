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
# EggCountdown.tcl - Eggdrop script to announce Christmas and New Year countdowns
# Runs completely locally — Xmas & New Year Countdown.
#
########################################################################################### 

namespace eval ::XmasAutoshow {
    # --- CONFIGURATION ---
    # Target channel where the messages should be broadcast
    variable channel "#aslpls"
    
    # Time intervals in minutes
    variable xmas_interval 120
    variable ny_interval   190
    # ---------------------

    variable xmas_timer_id ""
    variable ny_timer_id   ""
    
    # Sequential index pointers
    variable xmas_index 0
    variable ny_index   0

    # Sequential list of 60 inspirational Christmas quotes
    variable xmas_list {
        "Christmas waves a magic wand over this world, and behold, everything is softer and more beautiful."
        "The best of all gifts around any Christmas tree: the presence of a happy family all wrapped up in each other."
        "Christmas is a necessity. There has to be at least one day of the year to remind us that we're here for something else besides ourselves."
        "Gifts of time and love are surely the basic ingredients of a truly merry Christmas."
        "Peace on earth will come to stay, when we live Christmas every day."
        "Christmas is a tonic for our souls. It moves us to think of others rather than of ourselves."
        "The world has grown weary through the years, but at Christmas, it is young."
        "Christmas is not a time nor a season, but a state of mind. To cherish peace and goodwill is to have the real spirit of Christmas."
        "May you never be too grown up to search the skies on Christmas Eve."
        "Christmas is the day that holds all time together."
        "Love the giver more than the gift."
        "Christmas gives us the opportunity to pause and reflect on the important things around us."
        "He who has not Christmas in his heart will never find it under a tree."
        "One of the most glorious messes in the world is the mess created in the living room on Christmas Day."
        "Christmas is a bridge. We need bridges as the river of time flows past."
        "Blessed is the season which engages the whole world in a conspiracy of love."
        "The joy of brightening other lives becomes for us the magic of the holidays."
        "Unless we make Christmas an occasion to share our blessings, all the snow in Alaska won't make it white."
        "Christmas is doing a little something extra for someone."
        "The spirit of Christmas is the spirit of love and of generosity and of goodness."
        "At Christmas, all roads lead home."
        "The teacher asked, 'What is the spirit of Christmas?' and the student replied, 'It's the love that remains when the gifts are gone.'"
        "Kindness is like snow. It beautifies everything it covers."
        "The best way to view Christmas is through the eyes of a child."
        "Remember this December, that love weighs more than gold."
        "Christmas is built upon a beautiful and intentional paradox; that the birth of the homeless should be celebrated in every home."
        "Let us keep Christmas beautiful without a thought of greed."
        "A good conscience is a continual Christmas."
        "Peace, goodwill, and abundance to you and yours this holiday season."
        "Christmas isn't just a day, it's a frame of mind."
        "The light of the Christmas star guide you to a path of peace and happiness."
        "Christmas is the spirit of giving without a thought of getting."
        "Small acts of kindness during the holidays can light up the darkest corners of someone's world."
        "What is Christmas? It is tenderness for the past, courage for the present, hope for the future."
        "May the warmth of the holiday season fill your home with joy and your heart with love."
        "True hope is found not in what we receive, but in the connections we build and protect."
        "Christmas magic is silent. You don't hear it—you feel it, you know it, you believe it."
        "Our hearts grow tender with childhood memories and love of kindred, and we are better throughout the year for having, in spirit, become a child again at Christmastime."
        "Let us remember that the Christmas heart is a giving heart, a wide open heart that thinks of others first."
        "There's nothing cozier than a house lit up for the holidays and filled with people you care about."
        "The ultimate value of the holiday season is found in the laughter shared and memories made."
        "Christmas time is a wonderful reminder that we have the capacity to love deeply and give selflessly."
        "As we look back on the year, may the coming winter season ground us in gratitude."
        "Sharing the holidays with those you love is the ultimate definition of being rich."
        "May your holidays be filled with the things that money cannot buy."
        "The finest gift you can offer anyone this season is your undivided attention and a listening ear."
        "May the quiet beauty of the season bring a deep sense of stillness and peace to your life."
        "Keep your heart open to the magic of small beginnings and simple joys."
        "The real celebration isn't what's happening outside, but the warmth and gratitude growing inside you."
        "May the true essence of the holidays inspire you to carry kindness into the coming new year."
        "A light heart, a helping hand, and a hopeful mind are the greatest holiday decorations."
        "True holiday wealth is measured by the number of smiles you share and receive."
        "Let the peace of the season sweep away the noise and busyness of everyday life."
        "Hope is the spark that keeps the winter warm."
        "May your spirit find renewal and your heart find rest during this special time of year."
        "The beautiful thing about Christmas is that it brings diverse hearts together under a shared banner of goodwill."
        "Let the simplicity of love be your guide through the winter celebrations."
        "May your home be an oasis of comfort, laughter, and light this season."
        "The true miracle of the holidays is the realization that we all have something valuable to contribute."
        "Every day can hold the spirit of Christmas if we choose to approach the world with a giving heart."
    }

    # Sequential list of 60 inspirational New Year / fresh beginning quotes
    variable ny_list {
        "Tomorrow is the first blank page of a 365-page book. Write a good one."
        "Your success and happiness lies in you. Resolve to keep happy, and your joy shall form an invincible host against difficulties."
        "Cheers to a new year and another chance for us to get it right."
        "Kindness, kindness, kindness. I want to make a New Year's prayer, not a resolution. I'm praying for courage."
        "And now we welcome the new year. Full of things that have never been."
        "Character is the ability to carry out a good resolution long after the excitement of the moment has passed."
        "Each year's regrets are envelopes in which messages of hope are found for the New Year."
        "The new year stands before us, like a chapter in a book, waiting to be written."
        "Every single year, we’re a different person. I don’t think we’re the same person all our lives."
        "An optimist stays up until midnight to see the New Year in. A pessimist stays up to make sure the old year leaves."
        "New Year's Day is every man's birthday."
        "The object of a New Year is not that we should have a new year. It is that we should have a new soul."
        "Write it on your heart that every day is the best day in the year."
        "Magic is believing in yourself. If you can do that, you can make anything happen."
        "The first step towards getting somewhere is to decide that you are not going to stay where you are."
        "It is never too late to be what you might have been."
        "Be at war with your vices, at peace with your neighbors, and let every new year find you a better man."
        "What the new year brings to you will depend a great deal on what you bring to the new year."
        "Go confidently in the direction of your dreams. Live the life you have imagined."
        "We spend January 1st walking through our lives, room by room, drawing up a list of work to be done, of cracks to be patched."
        "Don't live the same year 75 times and call it a life."
        "The magic in new beginnings is truly the most powerful of them all."
        "Your present circumstances don't determine where you can go; they merely determine where you start."
        "Every new beginning comes from some other beginning's end."
        "Appreciate how far you've come. Endure how far you're going."
        "A journey of a thousand miles begins with a single step."
        "Never underestimate the power you have to take your life in a new direction."
        "Celebrate what you want to see more of."
        "The future belongs to those who believe in the beauty of their dreams."
        "You are never too old to set another goal or to dream a new dream."
        "Drop the last year into the silent limbo of the past. Let it go, for it was imperfect."
        "This is a new year. A new beginning. And things will change."
        "Take a leap of faith and begin this wondrous new year by believing."
        "New year—a new chapter, new verse, or just the same old story? Ultimately, we write it."
        "With the new day comes new strength and new thoughts."
        "Learn from yesterday, live for today, hope for tomorrow."
        "The capacity to care is what gives life its deepest significance."
        "The secret of change is to focus all of your energy, not on fighting the old, but on building the new."
        "Although no one can go back and make a brand new start, anyone can start from now and make a brand new ending."
        "Do not wait until the conditions are perfect to begin. Beginning makes the conditions perfect."
        "Life is a progress, and not a station."
        "Keep your face always toward the sunshine, and shadows will fall behind you."
        "Open your eyes to the beauty around you, and let a wave of fresh potential carry you forward."
        "Make each day your masterpiece."
        "Great things are done by a series of small things brought together."
        "Believe you can and you're halfway there."
        "The best way to predict the future is to create it."
        "The only limit to our realization of tomorrow will be our doubts of today."
        "Nurture your mind with great thoughts, for you will never go any higher than you think."
        "Nothing is deep down completely lost if we have the vision to start over."
        "Real internal wealth is measured by what you are willing to give away to uplift another soul."
        "Step boldly into the unfamiliar; that is where your strength expands."
        "Let the noise of the past fade out so your vision for the future can speak clearly."
        "A clear purpose provides the blueprint for an extraordinary season of growth."
        "Do something today that your future self will thank you for."
        "The tiny, daily choices we make shape the path of the entire year ahead."
        "Look forward with eyes full of hope and a mind structured for resilience."
        "May the canvas of this upcoming year be painted with beautiful efforts and quiet milestones."
        "Every day is a fresh opportunity to impact someone's life for the better."
        "True newness starts in the mind, not just on the calendar page."
    }

    # Public binds for testing
    catch {unbind pub - "!xmas" [namespace current]::pub_xmas_show}
    catch {unbind pub - "!ny"   [namespace current]::pub_ny_show}
    bind pub - "!xmas" [namespace current]::pub_xmas_show
    bind pub - "!ny"   [namespace current]::pub_ny_show

    proc init {} {
        variable xmas_interval
        variable ny_interval
        
        # Kill any orphans left behind in the global scope before starting fresh ones
        kill_all_orphans
        
        # Start fresh loops
        start_xmas_timer
        start_ny_timer
        
        putlog "XmasAutoshow: Loaded successfully. Loops updated cleanly."
        
        # Safe forced announcement execution delayed shortly on start
        utimer 3 [namespace current]::fetch_and_show_xmas
        utimer 6 [namespace current]::fetch_and_show_ny
    }

    # --- ENHANCED SAFE TIMER CLEANUP ---
    proc kill_all_orphans {} {
        # Scan through the global utimer pool and drop anything tied to our specific execution calls
        foreach t [utimers] {
            set command [lindex $t 1]
            if {[string match "*fetch_and_show_xmas*" $command] || [string match "*fetch_and_show_ny*" $command]} {
                catch {killutimer [lindex $t 2]}
            }
        }
    }

    proc start_xmas_timer {} {
        variable xmas_interval
        variable xmas_timer_id
        critical_xmas_timer
        set xmas_timer_id [utimer [expr {$xmas_interval * 60}] [namespace current]::fetch_and_show_xmas]
    }

    proc critical_xmas_timer {} {
        variable xmas_timer_id
        if {$xmas_timer_id ne ""} {
            catch {killutimer $xmas_timer_id}
            set xmas_timer_id ""
        }
    }

    proc start_ny_timer {} {
        variable ny_interval
        variable ny_timer_id
        critical_ny_timer
        set ny_timer_id [utimer [expr {$ny_interval * 60}] [namespace current]::fetch_and_show_ny]
    }

    proc critical_ny_timer {} {
        variable ny_timer_id
        if {$ny_timer_id ne ""} {
            catch {killutimer $ny_timer_id}
            set ny_timer_id ""
        }
    }

    # --- COMMAND EXECUTION ---
    proc pub_xmas_show {nick uhost hand chan arg} {
        variable channel
        if {[string equal -nocase $chan $channel]} {
            fetch_and_show_xmas 1
        }
    }

    proc pub_ny_show {nick uhost hand chan arg} {
        variable channel
        if {[string equal -nocase $chan $channel]} {
            fetch_and_show_ny 1
        }
    }

    proc fetch_and_show_xmas {{manual 0}} {
        variable channel
        variable xmas_list
        variable xmas_index
        
        if {$manual == 0} { start_xmas_timer }

        if {!$manual} {
            if {![validchan $channel] || ![onchan $::botnick $channel]} { return }
        }

        set current_time [clock seconds]
        set current_year [clock format $current_time -format "%Y"]
        
        if {[catch {clock scan "$current_year-12-25 00:00:00" -format "%Y-%m-%d %H:%M:%S"} xmas_time]} {
            set xmas_time [clock scan "$current_year-12-25 00:00:00"]
        }

        if {$current_time > $xmas_time} {
            incr current_year
            if {[catch {clock scan "$current_year-12-25 00:00:00" -format "%Y-%m-%d %H:%M:%S"} xmas_time]} {
                set xmas_time [clock scan "$current_year-12-25 00:00:00"]
            }
        }

        set diff [expr {$xmas_time - $current_time}]
        if {$diff <= 0} {
            putserv "PRIVMSG $channel :\00306***\003 \00304MERRY CHRISTMAS EVERYONE!\003 \00306***\003"
            return
        }

        set days [expr {$diff / 86400}]
        set remaining_seconds [expr {$diff % 86400}]
        set hours [expr {$remaining_seconds / 3600}]

        set current_quote [lindex $xmas_list $xmas_index]
        set msg "\00312Christmas Countdown\003: \00306$days\003 days, \00306$hours\003 hours. $current_quote"
        
        putserv "PRIVMSG $channel :$msg"
        set xmas_index [expr {($xmas_index + 1) % [llength $xmas_list]}]
    }

    proc fetch_and_show_ny {{manual 0}} {
        variable channel
        variable ny_list
        variable ny_index
        
        if {$manual == 0} { start_ny_timer }

        if {!$manual} {
            if {![validchan $channel] || ![onchan $::botnick $channel]} { return }
        }

        set current_time [clock seconds]
        set current_year [clock format $current_time -format "%Y"]
        set next_year [expr {$current_year + 1}]
        
        if {[catch {clock scan "$next_year-01-01 00:00:00" -format "%Y-%m-%d %H:%M:%S"} ny_time]} {
            set ny_time [clock scan "$next_year-01-01 00:00:00"]
        }

        set diff [expr {$ny_time - $current_time}]
        if {$diff <= 0} {
            putserv "PRIVMSG $channel :\00304***\003 \00306HAPPY NEW YEAR EVERYONE!\003 \00304***\003"
            return
        }

        set days [expr {$diff / 86400}]
        set remaining_seconds [expr {$diff % 86400}]
        set hours [expr {$remaining_seconds / 3600}]

        set current_quote [lindex $ny_list $ny_index]
        set msg "\00304New Years Countdown\003: \00306$days\003 days, \00306$hours\003 hours. $current_quote"
        
        putserv "PRIVMSG $channel :$msg"
        set ny_index [expr {($ny_index + 1) % [llength $ny_list]}]
    }

    proc unload {args} {
        kill_all_orphans
        critical_xmas_timer
        critical_ny_timer
        putlog "XmasAutoshow: Unloaded completely."
    }
}

# Initialize the script safely
::XmasAutoshow::init

putlog "Loaded EggCountodwn.tcl by asl_pls @ irc.underx.org"